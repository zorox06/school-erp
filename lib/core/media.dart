import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import 'phase_one/store.dart';

class LocalAttachment {
  final String id, path, mime, name;
  final int bytes;
  const LocalAttachment({
    required this.id,
    required this.path,
    required this.mime,
    required this.name,
    required this.bytes,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'mime': mime,
    'name': name,
    'bytes': bytes,
  };
}

class SchoolMedia {
  static final _revoked = <String>{};
  static void activate(String owner) => _revoked.remove(owner);
  static Future<Directory> directory(String owner) async {
    if (_revoked.contains(owner)) throw StateError('Account signed out');
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(owner)) {
      throw ArgumentError('Invalid account');
    }
    final root = await getApplicationSupportDirectory();
    final dir = Directory(paths.join(root.path, 'schoolday-media', owner));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<LocalAttachment> persist(
    String owner,
    Uint8List bytes,
    String mime, {
    String? name,
  }) async {
    if (bytes.isEmpty || bytes.length > 10485760) {
      throw const FormatException('Files must be under 10 MB');
    }
    final id = operationId();
    final ext = mime == 'application/pdf'
        ? 'pdf'
        : mime == 'image/png'
        ? 'png'
        : 'jpg';
    final file = File(paths.join((await directory(owner)).path, '$id.$ext'));
    if (_revoked.contains(owner)) throw StateError("Account signed out");
    await file.writeAsBytes(bytes, flush: true);
    if (_revoked.contains(owner)) {
      if (await file.exists()) await file.delete();
      throw StateError("Account signed out");
    }
    return LocalAttachment(
      id: id,
      path: file.path,
      mime: mime,
      name: name ?? 'Attachment.$ext',
      bytes: bytes.length,
    );
  }

  static Future<LocalAttachment?> photo(
    String owner, {
    ImageSource source = ImageSource.camera,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final bytes = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 75,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) {
      throw const FormatException('Unable to prepare this photo');
    }
    return persist(owner, bytes, 'image/jpeg', name: 'Board photo.jpg');
  }

  static Future<Uint8List?> capturePage({
    ImageSource source = ImageSource.camera,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    return FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
  }

  static Future<LocalAttachment> document(
    String owner,
    List<Uint8List> pages,
  ) async {
    if (pages.isEmpty || pages.length > 5) {
      throw const FormatException('Choose one to five pages');
    }
    return persist(
      owner,
      await compute(_pdf, pages),
      'application/pdf',
      name: 'Completed work.pdf',
    );
  }

  static Future<void> clear(String owner) async {
    _revoked.add(owner);
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(owner)) return;
    final root = paths.join(
      (await getApplicationSupportDirectory()).path,
      'schoolday-media',
    );
    final dir = Directory(paths.join(root, owner));
    if (!paths.isWithin(root, dir.path)) throw StateError('Unsafe media path');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

Uint8List processScan(Map<String, dynamic> request) {
  var source = im.decodeImage(request['bytes'] as Uint8List);
  if (source == null) throw const FormatException('Unsupported image');
  source = im.bakeOrientation(source);
  if (source.width > 2000 || source.height > 2000) {
    source = im.copyResize(
      source,
      width: source.width >= source.height ? 2000 : null,
      height: source.height > source.width ? 2000 : null,
    );
  }
  final rect = (request['crop'] as List).cast<num>();
  source = im.copyCrop(
    source,
    x: (rect[0] * source.width).round(),
    y: (rect[1] * source.height).round(),
    width: ((rect[2] - rect[0]) * source.width).round().clamp(1, source.width),
    height: ((rect[3] - rect[1]) * source.height).round().clamp(
      1,
      source.height,
    ),
  );
  if (request['enhance'] == true) {
    source = im.adjustColor(
      im.grayscale(source),
      contrast: 1.25,
      brightness: 1.1,
    );
  }
  if (request['rotate'] == true) source = im.copyRotate(source, angle: 90);
  return im.encodeJpg(source, quality: 82);
}

Future<Uint8List> _pdf(List<Uint8List> pages) async {
  final doc = pdf.Document(compress: true);
  for (final bytes in pages) {
    final image = pdf.MemoryImage(bytes);
    doc.addPage(
      pdf.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pdf.EdgeInsets.all(20),
        build: (_) =>
            pdf.Center(child: pdf.Image(image, fit: pdf.BoxFit.contain)),
      ),
    );
  }
  return doc.save();
}
