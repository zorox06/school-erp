import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/media.dart';
import '../core/native_features.dart';
import '../core/school_features.dart';
import '../core/theme.dart';
import 'components.dart';

class SchoolAttachments extends StatelessWidget {
  final List<dynamic> ids;
  const SchoolAttachments({super.key, required this.ids});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final id in ids)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Attachment(key: ValueKey(id), id: id as String),
        ),
      if (ids.isEmpty)
        const InfoBanner('No attachments were shared with this item.'),
    ],
  );
}

class _Attachment extends StatefulWidget {
  final String id;
  const _Attachment({super.key, required this.id});
  @override
  State<_Attachment> createState() => _AttachmentState();
}

class _AttachmentState extends State<_Attachment> {
  SchoolRow? metadata;
  String? imageUrl;
  bool busy = false, failed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (metadata == null &&
        !busy &&
        !failed &&
        !AppScope.of(context).dataSaver) {
      load();
    }
  }

  Future<void> load() async {
    final c = AppScope.of(context);
    final hub = c.features;
    if (hub == null) return;
    setState(() => busy = true);
    try {
      final row = Map<String, dynamic>.from(
        await hub.gateway.call('erp_asset_access', {
          'p_school': hub.school,
          'p_asset': widget.id,
        }) as Map,
      );
      final url = (row['mime'] as String).startsWith('image/')
          ? await hub.gateway.signedUrl(row['path'] as String)
          : null;
      if (mounted) {
        setState(() {
          failed = false;
          metadata = row;
          imageUrl = url;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open() async {
    if (metadata == null) {
      await load();
      if (!mounted || metadata == null) return;
    }
    final c = AppScope.of(context);
    final hub = c.features;
    if (hub == null) return;
    setState(() => busy = true);
    try {
      final fresh = Map<String, dynamic>.from(
        await hub.gateway.call('erp_asset_access', {
          'p_school': hub.school,
          'p_asset': widget.id,
        }) as Map,
      );
      final bytes = await hub.gateway.download(fresh['path'] as String);
      final file = await SchoolMedia.persist(
        hub.owner,
        bytes,
        fresh['mime'] as String,
      );
      await NativeSchoolFeatures.openFile(file.path, file.mime);
    } catch (_) {
      if (mounted) {
        tell(
          context,
          'Couldn’t open this attachment. Check access and install a PDF viewer if needed.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (metadata?['mime'] == 'application/pdf') ScanCover(id: widget.id),
        if (imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              cacheKey: '${AppScope.of(context).auth.userId}/${widget.id}',
              height: 170,
              fit: BoxFit.cover,
              memCacheWidth: AppScope.of(context).thumbnailWidth,
              fadeInDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              fadeOutDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 1000),
              maxWidthDiskCache: 512,
              maxHeightDiskCache: 512,
              placeholder: (_, _) => const SizedBox(
                height: 170,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, _, _) => const SizedBox(
                height: 100,
                child: Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            metadata?['mime'] == 'application/pdf'
                ? Icons.picture_as_pdf_outlined
                : Icons.image_outlined,
            color: context.tones.teal,
          ),
          title: Text(
            failed
                ? 'Attachment unavailable'
                : metadata?['mime'] == 'application/pdf'
                ? 'PDF document'
                : 'School attachment',
            style: textStyle(13, weight: FontWeight.w700),
          ),
          subtitle: Text(
            metadata == null
                ? 'Private file · Tap to load'
                : '${((metadata!['bytes'] as num) / 1024).ceil()} KB · Private',
            style: textStyle(11, color: context.tones.muted),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new, size: 20),
          onTap: busy ? null : open,
        ),
      ],
    ),
  );
}

class ScanCover extends StatefulWidget {
  final String id;
  const ScanCover({super.key, required this.id});
  @override
  State<ScanCover> createState() => _ScanCoverState();
}

class _ScanCoverState extends State<ScanCover> {
  (String, String)? identity;
  Future<File?>? cover;
  @override
  Widget build(BuildContext context) {
    final owner = AppScope.of(context).auth.userId;
    if (owner == null) return const SizedBox.shrink();
    if (identity != (owner, widget.id)) {
      identity = (owner, widget.id);
      cover = SchoolMedia.scanPreview(
        owner,
        widget.id,
      ).then((f) async => f != null && await f.exists() ? f : null);
    }
    return FutureBuilder<File?>(
      key: ValueKey(identity),
      future: cover,
      builder: (context, result) {
        final file = result.data;
        return file == null
            ? const SizedBox.shrink()
            : Image.file(
                file,
                height: 120,
                cacheWidth: 200,
                fit: BoxFit.contain,
                semanticLabel: 'Scanned first page',
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              );
      },
    );
  }
}
