import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: selected == option,
            showCheckmark: false,
            selectedColor: AppTheme.primaryGreen,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            side: BorderSide(
              color: selected == option
                  ? AppTheme.primaryGreen
                  : AppTheme.dividerColor,
              width: selected == option ? 1.5 : 1.0,
            ),
            labelStyle: TextStyle(
              color: selected == option ? Colors.white : AppTheme.textPrimary,
              fontWeight:
                  selected == option ? FontWeight.w600 : FontWeight.w500,
            ),
            onSelected: (_) => onSelected(selected == option ? null : option),
          ),
      ],
    );
  }
}
