import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// A calendar-month section header, e-wallet style ("AUGUST 2026").
///
/// Lifted verbatim out of `history_page.dart`, where it was private, so Bill
/// History's month grouping renders identically to History's instead of
/// growing a second, drifting copy of the same style. History's rendering is
/// unchanged — this is the same widget under a public name.
///
/// The label itself is produced by `monthYearHeader` in `history_grouping.dart`,
/// which is also shared.
class HistoryMonthHeader extends StatelessWidget {
  const HistoryMonthHeader({super.key, required this.label});

  /// Uppercase month header, e.g. "AUGUST 2026".
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        18,
        AppConstants.pagePadding,
        6,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
