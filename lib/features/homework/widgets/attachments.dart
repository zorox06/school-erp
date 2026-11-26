part of '../screen.dart';

class AttachmentPicker extends StatelessWidget {
  final List<LocalAttachment> files;
  final bool enabled, scan;
  final VoidCallback onChanged;
  const AttachmentPicker({
    super.key,
    required this.files,
    required this.enabled,
    required this.onChanged,
    this.scan = false,
  });
  Future<void> pick(BuildContext context, String kind) async {
    final c = AppScope.of(context);
    if (!enabled || c.auth.userId == null) {
      tell(context, 'Connect your school account before attaching files.');
      return;
    }
    if (files.length >= 5) {
      tell(context, 'You can attach up to five files.');
      return;
    }
    try {
      LocalAttachment? file;
      if (kind == 'camera') file = await SchoolMedia.photo(c.auth.userId!);
      if (kind == 'scan' && context.mounted) {
        file = await openPage<LocalAttachment>(
          context,
          DocumentScannerScreen(owner: c.auth.userId!),
        );
      }
      if (kind == 'file') {
        final picked = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (picked != null) {
          final length = await picked.length();
          if (length == null || length == 0 || length > 10485760) {
            throw const FormatException('File too large');
          }
          final bytes = await picked.readAsBytes();
          final name = picked.name.toLowerCase();
          final mime = name.endsWith('.pdf')
              ? 'application/pdf'
              : name.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          file = await SchoolMedia.persist(
            c.auth.userId!,
            bytes,
            mime,
            name: picked.name,
          );
        }
      }
      if (file != null && context.mounted) {
        files.add(file);
        onChanged();
      }
    } catch (_) {
      if (context.mounted) {
        tell(
          context,
          'Choose a readable PDF or photo under 10 MB. Check camera/file permissions if needed.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scan ? 'Share clear pages.' : 'A photo says it clearly.',
              style: textStyle(17, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              scan ? 'Crop and enhance your work, then save it as a PDF.' : 'Capture the board or choose a file. Attachments stay private.',
              style: textStyle(12, color: context.tones.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => pick(context, scan ? 'scan' : 'camera'),
                  icon: Icon(
                    scan
                        ? Icons.document_scanner_outlined
                        : Icons.camera_alt_outlined,
                    size: 18,
                  ),
                  label: Text(scan ? 'Scan work' : 'Board photo'),
                ),
                TextButton.icon(
                  onPressed: () => pick(context, 'file'),
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Choose file'),
                ),
              ],
            ),
          ],
        ),
      ),
      for (var i = 0; i < files.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: files[i].preview != null
              ? Image.memory(
                  files[i].preview!,
                  width: 46,
                  height: 54,
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                )
              : files[i].mime.startsWith('image/')
              ? Image.file(
                  File(files[i].path),
                  width: 46,
                  height: 54,
                  cacheWidth: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                )
              : Icon(
                  files[i].mime == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: context.tones.teal,
                ),
          title: Text(
            files[i].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "${files[i].preview != null ? 'Scanned PDF · ' : ''}${(files[i].bytes / 1024).ceil()} KB · On this device",
          ),
          trailing: IconButton(
            tooltip: 'Remove ${files[i].name}',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              files.removeAt(i);
              onChanged();
            },
          ),
        ),
    ],
  );
}
