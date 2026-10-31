import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/media.dart';
import '../core/theme.dart';
import '../ui/components.dart';

class DocumentScannerScreen extends StatefulWidget {
  final String owner;
  const DocumentScannerScreen({super.key, required this.owner});
  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final pages = <Uint8List>[];
  Uint8List? current;
  double imageAspect = 3 / 4;
  Rect crop = const Rect.fromLTRB(.04, .04, .96, .96);
  bool enhance = true, rotate = false, busy = false;
  Future<void> capture(ImageSource source) async {
    if (busy || pages.length >= 5) return;
    try {
      final bytes = await SchoolMedia.capturePage(source: source);
      if (bytes != null && mounted) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final aspect = frame.image.width / frame.image.height;
        frame.image.dispose();
        codec.dispose();
        if (!mounted) return;
        setState(() {
          current = bytes;
          imageAspect = aspect;
          crop = const Rect.fromLTRB(.04, .04, .96, .96);
          rotate = false;
        });
      }
    } catch (_) {
      if (mounted) {
        tell(
          context,
          'The camera or photo library is unavailable. Check device permissions.',
        );
      }
    }
  }

  Future<void> usePage() async {
    if (current == null || busy) return;
    setState(() => busy = true);
    try {
      final bytes = await compute(processScan, {
        'bytes': current,
        'crop': [crop.left, crop.top, crop.right, crop.bottom],
        'enhance': enhance,
        'rotate': rotate,
      });
      if (mounted) {
        setState(() {
          pages.add(bytes);
          current = null;
        });
      }
    } catch (_) {
      if (mounted) {
        tell(context, 'Couldn’t crop this page. Please try another photo.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan completed work')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Clear pages. Simple submission.',
                        style: textStyle(22, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drag the four crop corners, enhance the page, then save up to five pages as one PDF.',
                        style: textStyle(13, color: Palette.muted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: (viewport.maxHeight * .40).clamp(220.0, 380.0),
                  child: current == null
                      ? pages.isEmpty
                            ? const Center(
                                child: Icon(
                                  Icons.document_scanner_outlined,
                                  size: 80,
                                  color: Palette.teal,
                                ),
                              )
                            : ListView.builder(
                                itemCount: pages.length,
                                itemBuilder: (context, i) => ListTile(
                                  leading: Image.memory(
                                    pages[i],
                                    width: 48,
                                    height: 64,
                                    cacheWidth: 96,
                                    fit: BoxFit.contain,
                                  ),
                                  title: Text('Page ${i + 1}'),
                                  trailing: IconButton(
                                    tooltip: 'Remove page ${i + 1}',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: busy
                                        ? null
                                        : () =>
                                              setState(() => pages.removeAt(i)),
                                  ),
                                ),
                              )
                      : LayoutBuilder(
                          builder: (context, box) => Center(
                            child: AspectRatio(
                              aspectRatio: imageAspect,
                              child: LayoutBuilder(
                                builder: (context, frame) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      current!,
                                      fit: BoxFit.fill,
                                      cacheWidth: 1200,
                                    ),
                                    CustomPaint(painter: _CropPainter(crop)),
                                    for (var corner = 0; corner < 4; corner++)
                                      Positioned(
                                        left:
                                            (corner % 2 == 0
                                                    ? crop.left
                                                    : crop.right) *
                                                frame.maxWidth -
                                            22,
                                        top:
                                            (corner < 2
                                                    ? crop.top
                                                    : crop.bottom) *
                                                frame.maxHeight -
                                            22,
                                        child: Semantics(
                                          label:
                                              'Crop ${['top left', 'top right', 'bottom left', 'bottom right'][corner]} corner',
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanUpdate: busy
                                                ? null
                                                : (event) => setState(() {
                                                    final x =
                                                            event.delta.dx /
                                                            frame.maxWidth,
                                                        y =
                                                            event.delta.dy /
                                                            frame.maxHeight;
                                                    crop = Rect.fromLTRB(
                                                      corner % 2 == 0
                                                          ? (crop.left + x)
                                                                .clamp(
                                                                  0,
                                                                  crop.right -
                                                                      .15,
                                                                )
                                                          : crop.left,
                                                      corner < 2
                                                          ? (crop.top + y)
                                                                .clamp(
                                                                  0,
                                                                  crop.bottom -
                                                                      .15,
                                                                )
                                                          : crop.top,
                                                      corner % 2 == 1
                                                          ? (crop.right + x)
                                                                .clamp(
                                                                  crop.left +
                                                                      .15,
                                                                  1,
                                                                )
                                                          : crop.right,
                                                      corner >= 2
                                                          ? (crop.bottom + y)
                                                                .clamp(
                                                                  crop.top +
                                                                      .15,
                                                                  1,
                                                                )
                                                          : crop.bottom,
                                                    );
                                                  }),
                                            child: const SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: Center(
                                                child: Icon(
                                                  Icons.crop_free,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                if (current != null)
                  ExpansionTile(
                    title: const Text('Precise crop controls'),
                    children: [
                      for (var edge = 0; edge < 4; edge++)
                        ListTile(
                          title: Text(
                            [
                              'Left crop edge',
                              'Top crop edge',
                              'Right crop edge',
                              'Bottom crop edge',
                            ][edge],
                          ),
                          subtitle: Slider(
                            value: [
                              crop.left,
                              crop.top,
                              crop.right,
                              crop.bottom,
                            ][edge],
                            min: 0,
                            max: 1,
                            semanticFormatterCallback: (v) =>
                                '${(v * 100).round()} percent',
                            onChanged: busy
                                ? null
                                : (v) => setState(() {
                                    crop = Rect.fromLTRB(
                                      edge == 0
                                          ? v.clamp(0, crop.right - .15)
                                          : crop.left,
                                      edge == 1
                                          ? v.clamp(0, crop.bottom - .15)
                                          : crop.top,
                                      edge == 2
                                          ? v.clamp(crop.left + .15, 1)
                                          : crop.right,
                                      edge == 3
                                          ? v.clamp(crop.top + .15, 1)
                                          : crop.bottom,
                                    );
                                  }),
                          ),
                        ),
                    ],
                  ),
                if (current != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 10,
                      children: [
                        FilterChip(
                          label: const Text('Enhance'),
                          selected: enhance,
                          onSelected: busy
                              ? null
                              : (v) => setState(() => enhance = v),
                        ),
                        FilterChip(
                          label: const Text('Rotate 90°'),
                          selected: rotate,
                          onSelected: busy
                              ? null
                              : (v) => setState(() => rotate = v),
                        ),
                        FilledButton(
                          onPressed: busy ? null : usePage,
                          child: Text(busy ? 'Processing…' : 'Use page'),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (current == null)
                        Wrap(
                          spacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: busy || pages.length >= 5
                                  ? null
                                  : () => capture(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                            ),
                            TextButton.icon(
                              onPressed: busy || pages.length >= 5
                                  ? null
                                  : () => capture(ImageSource.gallery),
                              icon: const Icon(Icons.photo_outlined),
                              label: const Text('Photos'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: busy || pages.isEmpty || current != null
                            ? null
                            : () async {
                                setState(() => busy = true);
                                try {
                                  final file = await SchoolMedia.document(
                                    widget.owner,
                                    pages,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context, file);
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    tell(
                                      context,
                                      'Couldn’t create the PDF. Try fewer pages.',
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              },
                        child: Text(
                          'Save PDF · ${pages.length} ${pages.length == 1 ? 'page' : 'pages'}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CropPainter extends CustomPainter {
  final Rect crop;
  _CropPainter(this.crop);
  @override
  void paint(Canvas canvas, Size size) {
    final selected = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(selected)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
    canvas.drawRect(
      selected,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.crop != crop;
}
