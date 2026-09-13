import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/animated_pressable.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/category_entity.dart';

/// A horizontal wrap of pill-style category chips.
///
/// Premium neutral style with an immediately obvious selected state:
/// - Unselected: surface background, light divider border, muted text, a small
///   category-color dot, no shadow.
/// - Selected: light teal tint, clearly visible teal border, stronger teal
///   text, the same color dot, and a subtle scale lift.
///
/// Selection animates only the chip whose state changes — background, border,
/// label colour/weight and scale over [AppDurations.standard] (200ms) with an
/// ease-out curve — so switching category feels premium and responsive, never
/// noisy.
///
/// Each category keeps a small colored dot so its identity survives the
/// neutral treatment — the category color is reserved for the dot, the detail
/// pages, and charts, not for chip outlines.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.categories,
    this.selectedId,
    this.onSelected,
  });

  final List<CategoryEntity> categories;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppConstants.spacingSm,
      runSpacing: AppConstants.spacingSm,
      children: [
        for (final category in categories)
          _CategoryChip(
            category: category,
            isSelected: category.categoryId == selectedId,
            onTap: () => onSelected?.call(category.categoryId),
          ),
      ],
    );
  }
}

/// A single category chip with an animated selected state.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final CategoryEntity category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(category.color);
    final colors = context.colors;
    // A seeded default category shows its localized label; a category the user
    // renamed shows the user's own text. The stored `category.name` is never
    // rewritten.
    final label = VocabularyLabels.category(
      l10n: AppLocalizations.of(context),
      categoryId: category.categoryId,
      name: category.name,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: AnimatedPressable(
        scaleAmount: 0.95,
        onTap: onTap,
        child: AnimatedScale(
          // A subtle persistent lift marks the selected chip.
          scale: isSelected ? 1.04 : 1.0,
          duration: AppDurations.standard,
          curve: AppEasing.easeOut,
          child: AnimatedContainer(
            duration: AppDurations.standard,
            curve: AppEasing.easeOut,
            // Selected = light teal fill + clear teal border; unselected =
            // quiet surface + divider border. Only the chip whose state
            // actually changed animates.
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withAlpha(36)
                  : colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? colors.primary : colors.divider,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingXs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Small color dot keeps the category identity.
                //
                // Painted from the STORED `category.color` verbatim in both
                // modes. The palette is Firestore data, not theme data — the
                // chip's own border, fill and label already carry the selected
                // state, so the dot is identity only and is never the sole
                // signal for anything. Rewriting it here would desync the dot
                // from the same category's colour on the detail pages.
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: AppDurations.standard,
                  curve: AppEasing.easeOut,
                  style: TextStyle(
                    color: isSelected ? colors.primary : colors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 13,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
