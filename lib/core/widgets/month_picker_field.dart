import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';

/// The stored form of a month/period, e.g. `2026-10` — the value the
/// "For month" fields have always written to `periodLabel`.
String formatPeriodLabel(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// The current month in stored form — the default for every "For month" field.
String currentPeriodLabel([DateTime? now]) =>
    formatPeriodLabel(now ?? DateTime.now());

/// Parses a stored `YYYY-MM` value, or null when it is not one.
DateTime? parsePeriodLabel(String? value) {
  final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(match.group(1)!), month);
}

/// A "For month" field that is picked, not typed.
///
/// Tapping it opens [showMonthPicker]; the chosen month is written to
/// [controller] in the stored `YYYY-MM` form, so callers read the value
/// exactly as before. The field stays optional: a clear button empties it.
/// Typing is disabled, so no on-screen keyboard opens for it.
class MonthPickerField extends StatelessWidget {
  const MonthPickerField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;

  Future<void> _pick(BuildContext context) async {
    final picked = await showMonthPicker(
      context,
      initial: parsePeriodLabel(controller.text) ?? DateTime.now(),
    );
    if (picked != null) controller.text = formatPeriodLabel(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextFormField(
        controller: controller,
        readOnly: true,
        showCursor: false,
        onTap: () => _pick(context),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: value.text.isEmpty
              ? const Icon(Icons.arrow_drop_down_rounded)
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.monthPickerClear,
                  onPressed: controller.clear,
                ),
        ),
      ),
    );
  }
}

/// Shows a month + year picker and returns the first day of the chosen month,
/// or null when dismissed.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(initial: initial),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
    final now = DateTime.now();
    final monthName = DateFormat.MMM(l10n.localeName);

    return AlertDialog(
      title: Text(l10n.monthPickerTitle),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Year ──
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: l10n.monthPickerPreviousYear,
                  onPressed: () => setState(() => _year--),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: l10n.monthPickerNextYear,
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Months ──
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var m = 1; m <= 12; m++)
                  _MonthChip(
                    label: monthName.format(DateTime(_year, m)),
                    selected: _year == widget.initial.year &&
                        m == widget.initial.month,
                    isCurrent: _year == now.year && m == now.month,
                    colors: colors,
                    onTap: () =>
                        Navigator.of(context).pop(DateTime(_year, m)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.isCurrent,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isCurrent;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    if (selected) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(shape: shape, padding: EdgeInsets.zero),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        shape: shape,
        padding: EdgeInsets.zero,
        // The current month is outlined in the brand colour so it is easy to
        // find even when another month is selected.
        side: BorderSide(
          color: isCurrent ? colors.primary : colors.textHint.withAlpha(80),
        ),
        foregroundColor: colors.textPrimary,
      ),
      child: Text(label),
    );
  }
}
