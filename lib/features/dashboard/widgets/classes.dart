part of '../screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = c.snapshot.classes
        .where(
          (e) => (e.title ?? '').toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return ContentList(
      onRefresh: c.refresh,
      children: [
        const ScreenHeading(
          'Your classes',
          eyebrow: 'Teacher workspace',
          subtitle: 'A place for every little mind.',
        ),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Search your classes',
            prefixIcon: Icon(LucideIcons.search, size: 19),
          ),
        ),
        const SizedBox(height: 22),
        if (items.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.users,
            title: 'Your classroom, coming soon.',
            message: 'Classes assigned to you by your school will appear here. There are no classes linked to this account yet.',
          )
        else
          ...items.map(
            (e) => RecordTile(
              e,
              icon: LucideIcons.users,
              onTap: () {
                c.chooseClass(e.id);
                openPage(context, ClassDetailScreen(record: e));
              },
            ),
          ),
        const SizedBox(height: 18),
        const InfoBanner(
          'Class access is managed by your school. Contact the office if an assignment is missing.',
        ),
      ],
    );
  }
}

class ClassDetailScreen extends StatelessWidget {
  final SchoolRecord record;
  const ClassDetailScreen({super.key, required this.record});
  @override
  Widget build(BuildContext context) => AppPage(
    title: record.title ?? 'Class',
    eyebrow: 'Your classroom',
    children: [
      const Tag('CLASS SPACE'),
      const SizedBox(height: 18),
      Surface(
        child: Column(
          children: [
            SettingRow(
              LucideIcons.clipboardCheck,
              'Mark attendance',
              onTap: () =>
                  openPage(context, const AttendanceScreen(teacher: true)),
            ),
            const Divider(),
            SettingRow(
              LucideIcons.bookOpen,
              'Class homework',
              onTap: () => openPage(context, const LearningPage(teacher: true)),
            ),
            const Divider(),
            SettingRow(
              LucideIcons.users,
              'Class register',
              onTap: () => openPage(context, const ClassRegisterScreen()),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        record.description ?? '—',
        style: textStyle(13, color: context.tones.muted),
      ),
    ],
  );
}

class ClassRegisterScreen extends StatelessWidget {
  const ClassRegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(
    title: 'Class register',
    eyebrow: 'Your class',
    children: [
      EmptyPanel(
        icon: LucideIcons.users,
        title: 'No children to show yet',
        message: 'Your school will add children to this class. No names or student details have been added.',
      ),
    ],
  );
}
