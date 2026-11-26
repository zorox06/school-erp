import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/fees.dart';
import '../../ui/components.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final list = c.snapshot.invoices
        .where((e) => tab == 0 ? !feeClosed(e) : feeClosed(e))
        .toList();
    return ContentList(
      onRefresh: c.refresh,
      children: [
        const ScreenHeading(
          'Fee statements',
          eyebrow: 'School fees',
          subtitle: 'Balances and statements for the selected student.',
        ),
        Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            color: context.tones.ink,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'TOTAL OUTSTANDING',
                    style: textStyle(
                      10,
                      color: const Color(0xFFBED9CB),
                      weight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    LucideIcons.wallet,
                    color: Color(0xFFC5DED2),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                outstandingFees(c.snapshot.invoices),
                style: textStyle(
                  43,
                  color: Colors.white,
                  weight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                c.snapshot.invoices.isEmpty
                    ? 'Your school hasn’t shared a fee statement yet.'
                    : 'Based on the statements shared by your school.',
                style: textStyle(11, color: const Color(0xFFDAE8DF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        FilterTabs(
          labels: const ['Due payments', 'Closed statements'],
          selected: tab,
          onSelected: (i) => setState(() => tab = i),
        ),
        const SizedBox(height: 23),
        if (list.isEmpty)
          EmptyPanel(
            icon: tab == 0 ? LucideIcons.receipt : LucideIcons.folderOpen,
            title: tab == 0
                ? 'No outstanding statements'
                : 'No closed statements',
            message: tab == 0
                ? 'Statements with a balance will appear here.'
                : 'Paid, waived and cancelled statements appear here.',
            color: context.tones.amber,
            background: context.tones.amberWash,
          )
        else
          ...list.map(
            (e) => RecordTile(
              e,
              icon: LucideIcons.receipt,
              onTap: () => openPage(context, InvoiceScreen(record: e)),
            ),
          ),
        const SizedBox(height: 20),
        const InfoBanner(
          'Contact the school office if a payment or balance needs correcting.',
          icon: LucideIcons.shieldCheck,
        ),
      ],
    );
  }
}

class InvoiceScreen extends StatelessWidget {
  final SchoolRecord record;
  const InvoiceScreen({super.key, required this.record});
  @override
  Widget build(BuildContext context) => AppPage(
    title: record.title ?? 'Fee statement',
    eyebrow: 'School fees',
    children: [
      const Tag('STATEMENT'),
      const SizedBox(height: 22),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Amount', style: textStyle(12, color: context.tones.muted)),
            const SizedBox(height: 8),
            Text(
              statementAmount(record)?.display ?? 'Amount unavailable',
              style: textStyle(34, weight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              record.description ?? 'No fee breakdown has been shared.',
              style: textStyle(13, color: context.tones.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      if (!feeClosed(record) && feeFields(record).containsKey('balance_due'))
        InfoBanner(
          'Outstanding: ${statementAmount(record, balance: true)?.display ?? 'Balance unavailable'}',
        ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to school fees'),
      ),
    ],
  );
}
