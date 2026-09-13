import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/spring_sheet.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../expenses/domain/entities/category_entity.dart';
import '../utils/filter_periods.dart';

/// The shared filter UI: the Touch 'n Go eWallet style option tiles, the
/// filter button, the active-filter chips, and the bottom sheet that ties them
/// together.
///
/// These began life private to `history_page.dart`. They are lifted here
/// unchanged so a second screen (Bill History) can present the same filter
/// experience without a second, drifting implementation of it. The move is
/// deliberately behaviour-preserving: History renders exactly what it rendered
/// before.
///
/// The one generalisation is that the sheet no longer knows History's own
/// vocabularies. It renders whatever [FilterSectionSpec]s it is handed, in the
/// order it is handed them, and returns the user's choices as a
/// [FilterSheetResult]. History passes its Type/Period/Category/Status
/// sections; Bill History passes Status/Period/Category/Member.

// ─────────────────────────────────────────────────────────────
// Option model
// ─────────────────────────────────────────────────────────────

/// One selectable tile: the stored [value] and the [label] shown for it.
@immutable
class FilterOption {
  const FilterOption({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;
}

/// A group of option tiles rendered under one uppercase section label.
@immutable
class FilterOptionGroup {
  const FilterOptionGroup({
    required this.options,
    required this.selected,
    this.multiSelect = false,
  });

  final List<FilterOption> options;

  /// The currently-selected values. EMPTY means "All" — the sheet always
  /// renders an explicit "All" tile first, which clears this set.
  final Set<String> selected;

  /// `true` → tapping a tile toggles it (several may be on at once).
  /// `false` → tapping a tile replaces the selection (only one at a time);
  /// an already-selected tile stays selected, matching the original Status
  /// section, whose taps never toggled off.
  final bool multiSelect;
}

// ─────────────────────────────────────────────────────────────
// Section specs
// ─────────────────────────────────────────────────────────────

/// One section of the filter sheet. Callers pass these in the order the
/// sections should appear, so a screen can arrange them freely.
sealed class FilterSectionSpec {
  const FilterSectionSpec({required this.label});

  /// Uppercase section heading, and the key this section's selection is
  /// returned under in [FilterSheetResult.selections].
  ///
  /// This stays a **stable key**: it is what [FilterSheetResult.select] is
  /// asked for, so it must not change with the language. The heading the user
  /// reads comes from [localizedLabel].
  final String label;

  /// The heading shown above the section, in the active language.
  ///
  /// Option sections are handed an already-localized label by their caller, so
  /// the default is the label itself; the period and category sections are
  /// rendered by the sheet alone and answer with their own fixed heading.
  String localizedLabel(AppLocalizations l10n) => label;
}

/// A grid of option tiles (History's Type and Status, Bill History's Status
/// and Recorded-by).
class FilterOptionsSection extends FilterSectionSpec {
  const FilterOptionsSection({
    required super.label,
    required this.group,
  });

  final FilterOptionGroup group;
}

/// The shared period section: the preset tiles plus a custom date range.
class FilterPeriodSection extends FilterSectionSpec {
  const FilterPeriodSection({required this.preset, required this.range})
      : super(label: 'Period');

  /// One of [FilterPeriods.presets], `'custom'`, or `null` for All.
  final String? preset;
  final DateTimeRange? range;

  @override
  String localizedLabel(AppLocalizations l10n) => l10n.labelPeriod;
}

/// The shared category dropdown.
class FilterCategorySection extends FilterSectionSpec {
  FilterCategorySection({
    required this.category,
    required this.categories,
  }) : super(label: 'Category');

  final String? category;
  final List<CategoryEntity> categories;

  @override
  String localizedLabel(AppLocalizations l10n) => l10n.labelCategory;
}

// ─────────────────────────────────────────────────────────────
// Result
// ─────────────────────────────────────────────────────────────

/// What the user chose, handed back on Apply.
///
/// [selections] is keyed by [FilterSectionSpec.label]; an empty set means that
/// section is on "All". Sections that were not rendered are simply absent.
@immutable
class FilterSheetResult {
  const FilterSheetResult({
    required this.selections,
    required this.category,
    required this.preset,
    required this.range,
  });

  final Map<String, Set<String>> selections;
  final String? category;
  final String? preset;
  final DateTimeRange? range;

  /// The chosen values for [label], or an empty set when that section is on
  /// "All" (or was not part of the sheet).
  Set<String> select(String label) => selections[label] ?? const <String>{};

  /// The single chosen value for a single-select section, or `null` for "All".
  String? single(String label) {
    final chosen = select(label);
    return chosen.isEmpty ? null : chosen.first;
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────

/// The filter bottom sheet. Edits are local drafts committed on Apply;
/// Reset clears every filter.
///
/// Nothing here is History-specific: the sheet renders the [sections] it is
/// given and reports the outcome through [onApply].
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.sections,
    required this.onApply,
  });

  final List<FilterSectionSpec> sections;

  final void Function(FilterSheetResult result) onApply;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  /// Drafts, keyed by section label. Only option sections appear here.
  late final Map<String, Set<String>> _selections = {
    for (final section in widget.sections)
      if (section is FilterOptionsSection) section.label: {...section.group.selected},
  };

  late String? _category = _initialCategory();
  late String? _preset = _initialPreset();
  late DateTimeRange? _range = _initialRange();

  String? _initialCategory() {
    for (final s in widget.sections) {
      if (s is FilterCategorySection) return s.category;
    }
    return null;
  }

  String? _initialPreset() {
    for (final s in widget.sections) {
      if (s is FilterPeriodSection) return s.preset;
    }
    return null;
  }

  DateTimeRange? _initialRange() {
    for (final s in widget.sections) {
      if (s is FilterPeriodSection) return s.range;
    }
    return null;
  }

  void _reset() {
    setState(() {
      for (final set in _selections.values) {
        set.clear();
      }
      _category = null;
      _preset = null;
      _range = null;
    });
  }

  Future<void> _pickCustomRange(DateTimeRange? initial) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _preset = 'custom';
      });
    }
  }

  FilterSheetResult _result() => FilterSheetResult(
    // Copied so the caller never holds the sheet's own mutable drafts.
    selections: {for (final e in _selections.entries) e.key: {...e.value}},
    category: _category,
    preset: _preset,
    range: _range,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Drag handle ──
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          decoration: BoxDecoration(
            // Alpha over the sheet's own surface, so it follows the sheet.
            color: colors.textHint.withAlpha(120),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // ── Title + Reset ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.labelFilters,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(onPressed: _reset, child: Text(l10n.actionReset)),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Scrollable filter sections ──
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in widget.sections)
                  FilterSection(
                    // The heading only — the section's own label stays the
                    // stable key its selection is reported under.
                    label: section.localizedLabel(l10n),
                    child: switch (section) {
                      FilterOptionsSection(:final group) => _buildOptions(
                        section.label,
                        group,
                        l10n,
                      ),
                      FilterPeriodSection() => _buildPeriod(theme),
                      FilterCategorySection() => _buildCategory(section, l10n),
                    },
                  ),
              ],
            ),
          ),
        ),

        // ── Apply ──
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => widget.onApply(_result()),
                child: Text(l10n.actionApply),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(
    String label,
    FilterOptionGroup group,
    AppLocalizations l10n,
  ) {
    final selected = _selections[label]!;

    return FilterOptionGrid(
      children: [
        FilterSelectableOption(
          label: l10n.periodAll,
          selected: selected.isEmpty,
          onTap: () => setState(selected.clear),
        ),
        for (final option in group.options)
          FilterSelectableOption(
            label: option.label,
            icon: option.icon,
            selected: selected.contains(option.value),
            onTap: () => setState(() {
              if (group.multiSelect) {
                if (!selected.remove(option.value)) {
                  selected.add(option.value);
                }
              } else {
                selected
                  ..clear()
                  ..add(option.value);
              }
            }),
          ),
      ],
    );
  }

  Widget _buildPeriod(ThemeData theme) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterOptionGrid(
          children: [
            FilterSelectableOption(
              label: FilterPeriods.labelFor(null, l10n),
              selected: _preset == null && _range == null,
              onTap:
                  () => setState(() {
                    _preset = null;
                    _range = null;
                  }),
            ),
            for (var i = 0; i < FilterPeriods.presets.length; i++)
              FilterSelectableOption(
                label: FilterPeriods.labelFor(FilterPeriods.presets[i], l10n),
                selected: _preset == FilterPeriods.presets[i],
                onTap:
                    () => setState(() {
                      _preset = FilterPeriods.presets[i];
                      _range = null;
                    }),
              ),
            FilterSelectableOption(
              label: FilterPeriods.labelFor(FilterPeriods.custom, l10n),
              selected: _preset == FilterPeriods.custom,
              onTap: () => _pickCustomRange(_range),
            ),
          ],
        ),
        if (_range != null)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 2),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 15,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormatUtils.formatDateShort(_range!.start, l10n.localeName)} – '
                  '${DateFormatUtils.formatDateShort(_range!.end, l10n.localeName)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategory(FilterCategorySection section, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<String?>(
        value: _category,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: l10n.categoryAll,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        items: [
          DropdownMenuItem(child: Text(l10n.categoryAll)),
          ...section.categories.map(
            (c) => DropdownMenuItem(
              value: c.categoryId,
              child: Text(
                // A default category shows its localized label; a category the
                // user renamed shows the user's own text.
                VocabularyLabels.categoryOrNull(
                      l10n: l10n,
                      categoryId: c.categoryId,
                      name: c.name,
                    ) ??
                    c.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (v) => setState(() => _category = v),
      ),
    );
  }
}

/// Wraps the sheet in the app's modal presentation — same shape, radius and
/// width cap everywhere it is opened from.
///
/// The sheet's surface comes entirely from here: [SpringSheet] animates
/// position and opacity only and paints no background of its own, so this
/// `backgroundColor` is the whole of it. It is therefore read from the palette
/// rather than hardcoded — an explicit white would override the dark
/// `bottomSheetTheme` and render a white sheet in dark mode. Light mode is
/// unchanged: `surfaceElevated` is `#FFFFFFFF`, exactly the shipped value.
Future<void> showFilterSheet(
  BuildContext context, {
  required List<FilterSectionSpec> sections,
  required void Function(FilterSheetResult result) onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppConstants.radiusBottomSheet),
        topRight: Radius.circular(AppConstants.radiusBottomSheet),
      ),
    ),
    builder: (ctx) => SpringSheet(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FilterSheet(
              sections: sections,
              onApply: (result) {
                Navigator.pop(ctx);
                onApply(result);
              },
            ),
          ),
        ),
      ),
    ),
  );
}

/// The filter button that opens the filter bottom sheet.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final hasActive = activeCount > 0;
    return Material(
      // Resting fill is the app's quiet grey — in dark mode the muted surface,
      // because the page tone itself would leave the control invisible.
      color:
          hasActive
              ? colors.primary.withAlpha(12)
              : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: hasActive ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.labelFilters,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasActive ? colors.primary : colors.textPrimary,
                ),
              ),
              if (hasActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: TextStyle(
                      // Ink on the teal fill follows the on-primary role:
                      // white in light mode, deep teal in dark, where white on
                      // the lightened brand teal measures about 1.9:1.
                      color: colors.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small removable chip summarising an active filter.
class SummaryChip extends StatelessWidget {
  const SummaryChip({
    super.key,
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: context.colors.primary.withAlpha(60)),
    );
  }
}

/// An uppercase section label above its control.
class FilterSection extends StatelessWidget {
  const FilterSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A responsive grid of selectable option tiles (2 columns on phones,
/// 3 on wider sheets).
class FilterOptionGrid extends StatelessWidget {
  const FilterOptionGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 480 ? 3 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.9,
          children: children,
        );
      },
    );
  }
}

/// A clean, tappable option tile with a border, a check when selected, and a
/// green tint — the Touch 'n Go eWallet style instead of a wall of chips.
class FilterSelectableOption extends StatelessWidget {
  const FilterSelectableOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      // The sheet's own surface when unselected, so the tile reads as a
      // recessed well rather than a raised card on the elevated sheet.
      color: selected ? colors.primary.withAlpha(12) : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colors.primary : colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
