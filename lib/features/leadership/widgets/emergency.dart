part of '../screen.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyState();
}

class _EmergencyState extends State<EmergencyScreen> {
  final title = TextEditingController(), body = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final c = AppScope.of(context);
    if (!c.workspace.isLeadership ||
        !c.canWrite ||
        c.features == null ||
        title.text.trim().isEmpty ||
        body.text.trim().isEmpty) {
      tell(context, 'A leadership account, title and message are required.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast to the whole school?'),
        content: Text('${title.text.trim()}\n\n${body.text.trim()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Broadcast'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await c.features!.queue('emergency', {
        'title': title.text.trim(),
        'body': body.text.trim(),
      });
      if (mounted) {
        tell(
          context,
          'Broadcast queued. Delivery requires configured and permitted device alerts.',
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) tell(context, 'Couldn’t save the broadcast.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Reach the whole school.',
    eyebrow: 'Emergency broadcast',
    children: [
      const InfoBanner(
        'Use for urgent school safety information. Emergency alerts bypass app quiet hours, subject to each device’s permissions.',
      ),
      const SizedBox(height: 20),
      TextField(
        controller: title,
        maxLength: 140,
        decoration: const InputDecoration(labelText: 'Alert title'),
      ),
      TextField(
        controller: body,
        maxLength: 8000,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(labelText: 'Clear instructions'),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        'Review emergency broadcast',
        icon: LucideIcons.siren,
        onPressed: send,
        busy: busy,
      ),
    ],
  );
}
