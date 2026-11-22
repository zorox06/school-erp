import 'data.dart';

/// The ERP supplies amounts in major currency units as numbers or decimal text.
/// Retaining the scale lets us add invoice balances without binary rounding.
class FeeAmount {
  final BigInt units;
  final int scale;
  final String currency;
  const FeeAmount(this.units, this.scale, this.currency);

  static FeeAmount? parse(Object? raw, Object? code) {
    final text = raw?.toString().trim() ?? '';
    if (!RegExp(r'^\d{1,18}(\.\d{1,6})?$').hasMatch(text)) return null;
    final currency = code?.toString().trim().toUpperCase() ?? '';
    final parts = text.split('.');
    return FeeAmount(
      BigInt.parse(parts.join()),
      parts.length == 2 ? parts.last.length : 0,
      currency,
    );
  }

  FeeAmount plus(FeeAmount other) {
    if (currency != other.currency) throw ArgumentError('Currencies differ');
    final digits = scale > other.scale ? scale : other.scale;
    final ten = BigInt.from(10);
    return FeeAmount(
      units * ten.pow(digits - scale) +
          other.units * ten.pow(digits - other.scale),
      digits,
      currency,
    );
  }

  String get display {
    final text = units.toString().padLeft(scale + 1, '0');
    final point = text.length - scale;
    final value = scale == 0
        ? text
        : '${text.substring(0, point)}.${text.substring(point)}';
    return currency.isEmpty ? value : '$currency $value';
  }
}

Map<String, dynamic> feeFields(SchoolRecord record) => {
  if (record.fields['data'] is Map)
    ...Map<String, dynamic>.from(record.fields['data'] as Map),
  ...record.fields,
};

String feeStatus(SchoolRecord record) =>
    (record.status ?? '').trim().toLowerCase();
bool feeClosed(SchoolRecord record) => const {
  'paid',
  'void',
  'voided',
  'cancelled',
  'canceled',
  'waived',
}.contains(feeStatus(record));
FeeAmount? statementAmount(SchoolRecord record, {bool balance = false}) {
  final f = feeFields(record);
  final raw = balance
      ? f['balance_due'] ??
            (const {'partial', 'partially_paid'}.contains(feeStatus(record))
                ? null
                : f['amount'])
      : f['amount'];
  return FeeAmount.parse(raw, f['currency']);
}

String outstandingFees(List<SchoolRecord> invoices) {
  if (invoices.isEmpty) return '—';
  final totals = <String, FeeAmount>{};
  for (final r in invoices.where((r) => !feeClosed(r))) {
    final amount = statementAmount(r, balance: true);
    if (amount == null || amount.currency.isEmpty) return 'Balance unavailable';
    totals.update(
      amount.currency,
      (current) => current.plus(amount),
      ifAbsent: () => amount,
    );
  }
  if (totals.isEmpty) return 'Nothing due';
  return (totals.keys.toList()..sort())
      .map((code) => totals[code]!.display)
      .join('\n');
}
