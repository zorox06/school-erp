part of '../screen.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});
  @override
  State<StaffAttendanceScreen> createState() => _StaffState();
}

class _StaffState extends State<StaffAttendanceScreen> {
  List<SchoolRow> staff = [];
  bool busy = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final h = AppScope.of(context).features;
      try {
        final r = h == null
            ? []
            : await h.gateway.call('erp_staff', {'p_school': h.school}) as List;
        if (mounted) {
          setState(
            () => staff = r
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          );
        }
      } catch (_) {
        if (mounted) tell(context, 'Teacher list could not be loaded.');
      } finally {
        if (mounted) setState(() => busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).features;
    return AppPage(
      title: 'The teaching team.',
      eyebrow: 'Today’s teacher attendance',
      children: [
        if (busy) const LinearProgressIndicator(),
        if (staff.isEmpty && !busy)
          const InfoBanner('No teachers linked to this school.'),
        ...staff.map(
          (s) => ListTile(
            title: Text(s['name'] as String? ?? 'Teacher'),
            subtitle: Text(DateFormat('d MMM yyyy').format(DateTime.now())),
            trailing: PopupMenuButton<String>(
              tooltip: 'Record teacher attendance',
              onSelected: (v) async {
                await h?.queue('staff_attendance', {
                  'user_id': s['id'],
                  'day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'status': v,
                });
                if (context.mounted) {
                  tell(context, 'Teacher attendance queued.');
                }
              },
              itemBuilder: (_) => [
                'present',
                'absent',
                'leave',
              ].map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
