import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// The common payment methods offered for money moving in or out of the
/// Central Account.
const List<String> kPaymentMethods = [
  'Cash',
  'Bank Transfer',
  'e-Wallet',
  'Card',
];

/// A single-select row of payment-method choice chips.
///
/// Optional — the caller may pass `null` [selected] and tapping the selected
/// chip again deselects it, so a transaction can be recorded without forcing a
/// method.
class PaymentMethodChips extends StatelessWidget {
  const PaymentMethodChips({
    super.key,
    this.options = kPaymentMethods,
    this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: selected == option,
            showCheckmark: false,
            // Matches the CategoryPicker: solid teal when selected, quiet
            // surface with a divider border when not.
            selectedColor: colors.primary,
            backgroundColor: colors.surface,
            // Not a palette colour: this is Material's "paint no surface tint
            // over my own fill" switch, and stays transparent in both modes.
            surfaceTintColor: Colors.transparent,
            side: BorderSide(
              color: selected == option ? colors.primary : colors.divider,
              width: selected == option ? 1.5 : 1.0,
            ),
            labelStyle: TextStyle(
              // Ink on the teal fill follows the palette's on-primary role:
              // white in light mode, deep teal in dark, where the brand teal
              // is lightened and white would measure about 1.9:1.
              color: selected == option ? colors.onPrimary : colors.textPrimary,
              fontWeight:
                  selected == option ? FontWeight.w600 : FontWeight.w500,
            ),
            onSelected: (_) => onSelected(selected == option ? null : option),
          ),
      ],
    );
  }
}
