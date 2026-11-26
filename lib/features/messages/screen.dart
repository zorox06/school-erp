import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/school_features.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../../ui/quick_sheet.dart';

part 'widgets/compose.dart';
part 'widgets/conversation.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesState();
}

class _MessagesState extends State<MessagesScreen> {
  String query = '';
  String? selectedId;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final records = (c.features?.rows('conversations') ?? <SchoolRow>[])
        .where(
          (r) => '${r['contact_name'] ?? ''} ${r['student_name'] ?? ''}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    final wide = MediaQuery.sizeOf(context).width >= 950;
    SchoolRecord record(SchoolRow r) => SchoolRecord(
      id: r['id'] as String,
      title: r['contact_name'] as String?,
      fields: r,
    );
    final list = RefreshIndicator(
      onRefresh: () => c.features?.refresh() ?? c.refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(22),
            sliver: SliverList.list(
              children: [
                ScreenHeading(
                  'A conversation away.',
                  eyebrow: 'Your inbox',
                  subtitle: 'A private connection between home and school.',
                  trailing: IconButton(
                    tooltip: 'New conversation',
                    onPressed: () =>
                        openPage(context, const ComposeMessageScreen()),
                    icon: const Icon(LucideIcons.squarePen),
                  ),
                ),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search conversations',
                    prefixIcon: Icon(LucideIcons.search),
                  ),
                ),
                const SizedBox(height: 20),
                if (records.isEmpty)
                  const EmptyPanel(
                    icon: LucideIcons.messagesSquare,
                    title: 'Good conversations start here.',
                    message: 'Approved school conversations will appear here.',
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverList.builder(
              itemCount: records.length,
              itemBuilder: (context, i) {
                final r = records[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Surface(
                    onTap: () => wide
                        ? setState(() => selectedId = r['id'] as String)
                        : openPage(
                            context,
                            ConversationScreen(record: record(r)),
                          ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(LucideIcons.messageCircle),
                      title: Text(
                        r['contact_name'] as String? ?? 'School conversation',
                      ),
                      subtitle: Text(r['student_name'] as String? ?? ''),
                      trailing: (r['unread_count'] as num? ?? 0) > 0
                          ? const Badge()
                          : const Icon(LucideIcons.chevronRight, size: 18),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (c.features?.hasMore['conversations'] == true)
                  TextButton(
                    onPressed: c.features!.moreConversations,
                    child: const Text('Load more conversations'),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
    if (!wide) return list;
    final selected = records.where((r) => r['id'] == selectedId).firstOrNull;
    return Row(
      children: [
        SizedBox(width: 310, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? const Center(child: Text('Select a conversation'))
              : ConversationScreen(
                  key: ValueKey(selectedId),
                  record: record(selected),
                ),
        ),
      ],
    );
  }
}
