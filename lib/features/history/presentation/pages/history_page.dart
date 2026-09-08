import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/activity_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/implicit_animated_list.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/spring_sheet.dart';
import '../../../../features/expenses/domain/entities/category_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../providers/history_provider.dart';
import '../utils/history_grouping.dart';

/// History screen — full transaction history with search and a filter
/// bottom sheet (Touch 'n Go eWallet style).
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Type filter (multi-select) ──
  final Set<String> _selectedTypes = {};

  // ── Category / Status filters ──
  String? _categoryFilter;
  String? _statusFilter;

  // ── Date range filter ──
  String? _datePreset; // 'today', '7d', ... 'custom'. null = all
  DateTimeRange? _customRange;

  // ── Period presets shown in the filter sheet ──
  static const _periodPresets = [
    'today',
    'yesterday',
    '7d',
    '30d',
    '90d',
    'month',
    'lastmonth',
  ];

  static const _periodLabels = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days',
    'This Month',
    'Last Month',
  ];

  // ── Type options shown in the filter sheet ──
  static const _typeFilters = [
    'deposit',
    'payment',
    'expense',
    'expensePaid',
    'bill',
    'adjustment',
  ];

  static const _typeLabels = [
    'Deposit',
    'Direct Payment',
    'Expense',
    'Expense Paid',
    'Bill',
    'Adjustment',
  ];

  static const _typeIcons = [
    Icons.arrow_downward_rounded,
    Icons.payment_outlined,
    Icons.receipt_long_outlined,
    Icons.payments_outlined,
    Icons.event_repeat_outlined,
    Icons.swap_horiz_rounded,
  ];

  // ── Status options (applies to expenses) ──
  static const _statusFilters = ['pending', 'approved', 'paid', 'rejected'];
  static const _statusLabels = ['Pending', 'Approved', 'Paid', 'Rejected'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Computes the active date range based on the selected preset.
  (DateTime, DateTime)? get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_datePreset) {
      case 'today':
        return (today, today.add(const Duration(days: 1)));
      case 'yesterday':
        return (today.subtract(const Duration(days: 1)), today);
      case '7d':
        return (
          today.subtract(const Duration(days: 6)),
          today.add(const Duration(days: 1)),
        );
      case '30d':
        return (
          today.subtract(const Duration(days: 29)),
          today.add(const Duration(days: 1)),
        );
      case '90d':
        return (
          today.subtract(const Duration(days: 89)),
          today.add(const Duration(days: 1)),
        );
      case 'month':
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1),
        );
      case 'lastmonth':
        return (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 1),
        );
      default:
        return _customRange != null
            ? (_customRange!.start, _customRange!.end)
            : null;
    }
  }

  List<HistoryEvent> _applyFilters(List<HistoryEvent> events) {
    var filtered = events;

    // ── Search by entity name or event label ──
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((e) {
            final title = e.title?.toLowerCase() ?? '';
            final label = _eventLabel(e.type).toLowerCase();
            return title.contains(_searchQuery) || label.contains(_searchQuery);
          }).toList();
    }

    // ── Filter by type (multi-select; empty set means all) ──
    if (_selectedTypes.isNotEmpty) {
      filtered =
          filtered.where((e) {
            for (final t in _selectedTypes) {
              if (_matchesType(t, e.type)) return true;
            }
            return false;
          }).toList();
    }

    // ── Filter by category (only expense events carry one) ──
    if (_categoryFilter != null) {
      filtered =
          filtered.where((e) => e.categoryId == _categoryFilter).toList();
    }

    // ── Filter by status (expense milestones carry a status) ──
    if (_statusFilter != null) {
      filtered = filtered.where((e) => e.status == _statusFilter).toList();
    }

    // ── Filter by date range ──
    final range = _activeRange;
    if (range != null) {
      final (start, end) = range;
      filtered =
          filtered
              .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
              .toList();
    }

    return filtered;
  }

  bool _matchesType(String filter, HistoryEventType type) {
    switch (filter) {
      case 'deposit':
        return type == HistoryEventType.deposit;
      case 'payment':
        return type == HistoryEventType.directPayment;
      case 'expense':
        return type == HistoryEventType.expenseSubmitted ||
            type == HistoryEventType.expenseApproved ||
            type == HistoryEventType.expenseRejected;
      case 'expensePaid':
        return type == HistoryEventType.expensePaid;
      case 'bill':
        return type == HistoryEventType.billCreated ||
            type == HistoryEventType.billPaid;
      case 'adjustment':
        return type == HistoryEventType.adjustment;
      default:
        return false;
    }
  }

  /// Opens the filter bottom sheet. Applies the chosen filters on "Apply".
  Future<void> _openFilterSheet(List<CategoryEntity> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
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
              child: _FilterSheet(
                types: _selectedTypes,
                category: _categoryFilter,
                status: _statusFilter,
                preset: _datePreset,
                range: _customRange,
                categories: categories,
                onApply: (types, category, status, preset, range) {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedTypes
                      ..clear()
                      ..addAll(types);
                    _categoryFilter = category;
                    _statusFilter = status;
                    _datePreset = preset;
                    _customRange = range;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedTypes.clear();
      _categoryFilter = null;
      _statusFilter = null;
      _datePreset = null;
      _customRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider(_selectedTypes.join(',')));
    final categoriesAsync = ref.watch(categoriesProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final categories = categoriesAsync.value ?? const <CategoryEntity>[];
    // Resolve display names for the tile subtitle + category chip.
    final categoryMap = {for (final c in categories) c.categoryId: c.name};
    final members = membersAsync.value ?? const <HouseMemberEntity>[];
    // Fallback order: displayName → "Unknown Member". Never a Firebase UID.
    final nameMap = {
      for (final m in members)
        m.userId:
            (m.displayName?.isNotEmpty == true
                ? m.displayName!
                : 'Unknown Member'),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menu',
        ),
        title: const Text('History'),
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800).
        child: Column(
          children: [
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                          : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // ── Filter button row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterButton(
                      activeCount: _activeFilterCount,
                      onTap: () => _openFilterSheet(categories),
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Clear all'),
                    ),
                  ],
                ],
              ),
            ),

            // ── Active filter summary chips ──
            if (_hasActiveFilters)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in _selectedTypes.toList())
                      _SummaryChip(
                        label: _typeLabelFor(type),
                        onDeleted:
                            () => setState(() => _selectedTypes.remove(type)),
                      ),
                    if (_categoryFilter != null)
                      _SummaryChip(
                        label: 'Category: $_categoryFilter',
                        onDeleted: () => setState(() => _categoryFilter = null),
                      ),
                    if (_statusFilter != null)
                      _SummaryChip(
                        label: 'Status: ${_statusLabelFor(_statusFilter!)}',
                        onDeleted: () => setState(() => _statusFilter = null),
                      ),
                    if (_datePreset != null && _customRange == null)
                      _SummaryChip(
                        label: _periodLabelFor(_datePreset!),
                        onDeleted: () => setState(() => _datePreset = null),
                      ),
                    if (_customRange != null)
                      _SummaryChip(
                        label:
                            '${DateFormatUtils.formatDateShort(_customRange!.start)} – '
                            '${DateFormatUtils.formatDateShort(_customRange!.end)}',
                        onDeleted: () => setState(() => _customRange = null),
                      ),
                    if (_searchQuery.isNotEmpty)
                      _SummaryChip(
                        label: '"$_searchQuery"',
                        onDeleted: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // ── Results ──
            Expanded(
              child: historyAsync.when(
                loading: () => const Shimmer(child: SkeletonListBody()),
                error:
                    (e, _) => ErrorDisplay(
                      message:
                          e is Failure ? e.message : 'Could not load history.',
                      onRetry:
                          () => ref.invalidate(
                            historyProvider(_selectedTypes.join(',')),
                          ),
                    ),
                data:
                    (items) =>
                        _buildList(_applyFilters(items), categoryMap, nameMap),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    List<HistoryEvent> events,
    Map<String, String> categoryMap,
    Map<String, String> nameMap,
  ) {
    if (events.isEmpty) {
      return EmptyState(
        title: _hasActiveFilters ? 'No results found' : 'No activity yet',
        description:
            _hasActiveFilters
                ? 'Try adjusting your search or filters.'
                : 'Deposits, expenses, and bills will appear here.',
        icon:
            _hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.receipt_long_outlined,
      );
    }

    // Group AFTER filtering/search, so empty months never render a header.
    // Sections are newest-month-first, events newest-first within each month.
    final sections = groupEventsByMonth(events);
    final rows = buildHistoryRows(sections);

    // AnimatedList: new rows slide in at the top, removed ones slide out,
    // as the stream updates in real time. Month headers are rows too, so a
    // month appearing/disappearing animates like any other change.
    return ImplicitAnimatedList<HistoryRow>(
      items: rows,
      itemKey: (row) => row.key,
      initialStagger: AppDurations.stagger,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, row) {
        return switch (row) {
          MonthHeaderRow(section: final section) => _MonthHeader(
            label: section.label,
          ),
          HistoryEventRow(event: final event) => _HistoryTile(
            event: event,
            categoryMap: categoryMap,
            nameMap: nameMap,
            onTap: () => _openDetails(event),
          ),
        };
      },
    );
  }

  /// Opens the matching detail page for an event. Adjustments have no detail
  /// screen; everything else maps to its own page.
  void _openDetails(HistoryEvent event) {
    switch (event.type) {
      case HistoryEventType.expenseSubmitted:
      case HistoryEventType.expenseApproved:
      case HistoryEventType.expensePaid:
      case HistoryEventType.expenseRejected:
        if (event.refId != null) {
          context.push(
            RouteNames.expenseDetails.replaceFirst(':expenseId', event.refId!),
          );
        }
        break;
      case HistoryEventType.deposit:
        context.push(RouteNames.depositDetails, extra: event);
        break;
      case HistoryEventType.directPayment:
        context.push(RouteNames.directPaymentDetails, extra: event);
        break;
      case HistoryEventType.billCreated:
      case HistoryEventType.billPaid:
        if (event.refId != null) {
          context.push(
            RouteNames.billDetails.replaceFirst(':billId', event.refId!),
          );
        }
        break;
      case HistoryEventType.adjustment:
        break; // no detail page for adjustments
    }
  }

  bool get _hasActiveFilters =>
      _selectedTypes.isNotEmpty ||
      _categoryFilter != null ||
      _statusFilter != null ||
      _searchQuery.isNotEmpty ||
      _datePreset != null ||
      _customRange != null;

  int get _activeFilterCount =>
      (_selectedTypes.isNotEmpty ? 1 : 0) +
      (_categoryFilter != null ? 1 : 0) +
      (_statusFilter != null ? 1 : 0) +
      (_datePreset != null || _customRange != null ? 1 : 0) +
      (_searchQuery.isNotEmpty ? 1 : 0);

  String _typeLabelFor(String type) {
    final index = _typeFilters.indexOf(type);
    return index >= 0 ? _typeLabels[index] : type;
  }

  String _statusLabelFor(String status) {
    final index = _statusFilters.indexOf(status);
    return index >= 0 ? _statusLabels[index] : status;
  }

  String _periodLabelFor(String preset) {
    if (preset == 'custom') {
      return 'Custom Range';
    }
    final index = _periodPresets.indexOf(preset);
    return index >= 0 ? _periodLabels[index] : preset;
  }
}

/// The filter button that opens the filter bottom sheet.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    return Material(
      color:
          hasActive
              ? AppTheme.primaryGreen.withAlpha(12)
              : AppTheme.backgroundLight,
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
                color:
                    hasActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      hasActive ? AppTheme.primaryGreen : AppTheme.textPrimary,
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
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
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
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.onDeleted});
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
      side: BorderSide(color: AppTheme.primaryGreen.withAlpha(60)),
    );
  }
}

/// The filter bottom sheet content. Edits are local drafts committed on
/// Apply; Reset clears every filter.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.types,
    required this.category,
    required this.status,
    required this.preset,
    required this.range,
    required this.categories,
    required this.onApply,
  });

  final Set<String> types;
  final String? category;
  final String? status;
  final String? preset;
  final DateTimeRange? range;
  final List<CategoryEntity> categories;

  final void Function(
    Set<String> types,
    String? category,
    String? status,
    String? preset,
    DateTimeRange? range,
  )
  onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _types = {...widget.types};
  late String? _category = widget.category;
  late String? _status = widget.status;
  late String? _preset = widget.preset;
  late DateTimeRange? _range = widget.range;

  void _reset() {
    setState(() {
      _types.clear();
      _category = null;
      _status = null;
      _preset = null;
      _range = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _preset = 'custom';
      });
    }
  }

  Widget _option({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return _SelectableOption(
      label: label,
      selected: selected,
      icon: icon,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Drag handle ──
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          decoration: BoxDecoration(
            color: AppTheme.textHint.withAlpha(120),
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
                  'Filters',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(onPressed: _reset, child: const Text('Reset')),
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
                // ── Type ──
                _FilterSection(
                  label: 'Type',
                  child: _OptionGrid(
                    children: [
                      _option(
                        label: 'All',
                        selected: _types.isEmpty,
                        onTap: () => setState(_types.clear),
                      ),
                      for (
                        var i = 0;
                        i < _HistoryPageState._typeFilters.length;
                        i++
                      )
                        _option(
                          label: _HistoryPageState._typeLabels[i],
                          icon: _HistoryPageState._typeIcons[i],
                          selected: _types.contains(
                            _HistoryPageState._typeFilters[i],
                          ),
                          onTap:
                              () => setState(() {
                                final t = _HistoryPageState._typeFilters[i];
                                if (_types.contains(t)) {
                                  _types.remove(t);
                                } else {
                                  _types.add(t);
                                }
                              }),
                        ),
                    ],
                  ),
                ),

                // ── Period ──
                _FilterSection(
                  label: 'Period',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OptionGrid(
                        children: [
                          _option(
                            label: 'All',
                            selected: _preset == null && _range == null,
                            onTap:
                                () => setState(() {
                                  _preset = null;
                                  _range = null;
                                }),
                          ),
                          for (
                            var i = 0;
                            i < _HistoryPageState._periodPresets.length;
                            i++
                          )
                            _option(
                              label: _HistoryPageState._periodLabels[i],
                              selected:
                                  _preset ==
                                  _HistoryPageState._periodPresets[i],
                              onTap:
                                  () => setState(() {
                                    _preset =
                                        _HistoryPageState._periodPresets[i];
                                    _range = null;
                                  }),
                            ),
                          _option(
                            label: 'Custom Range',
                            selected: _preset == 'custom',
                            onTap: _pickCustomRange,
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
                                color: AppTheme.primaryGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormatUtils.formatDateShort(_range!.start)} – '
                                '${DateFormatUtils.formatDateShort(_range!.end)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Category ──
                _FilterSection(
                  label: 'Category',
                  child: SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String?>(
                      value: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'All Categories',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...widget.categories.map(
                          (c) => DropdownMenuItem(
                            value: c.categoryId,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
                ),

                // ── Status ──
                _FilterSection(
                  label: 'Status',
                  child: _OptionGrid(
                    children: [
                      _option(
                        label: 'All',
                        selected: _status == null,
                        onTap: () => setState(() => _status = null),
                      ),
                      for (
                        var i = 0;
                        i < _HistoryPageState._statusFilters.length;
                        i++
                      )
                        _option(
                          label: _HistoryPageState._statusLabels[i],
                          selected:
                              _status == _HistoryPageState._statusFilters[i],
                          onTap:
                              () => setState(() {
                                _status = _HistoryPageState._statusFilters[i];
                              }),
                        ),
                    ],
                  ),
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
                onPressed:
                    () => widget.onApply(
                      _types,
                      _category,
                      _status,
                      _preset,
                      _range,
                    ),
                child: const Text('Apply'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.label, required this.child});
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
              color: AppTheme.textSecondary,
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
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.children});
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
class _SelectableOption extends StatelessWidget {
  const _SelectableOption({
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
    return Material(
      color: selected ? AppTheme.primaryGreen.withAlpha(12) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryGreen : AppTheme.dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color:
                      selected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? AppTheme.primaryGreen : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppTheme.primaryGreen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A calendar-month section header, e-wallet style ("AUGUST 2026").
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// One finance-style activity card.
///
/// Layout:
/// [icon]  Groceries                     -RM84.50
///         Raymond Ng • 10 Aug 2026 • 8:35 PM
///         [Paid] [Personal] [Food]
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.event,
    required this.categoryMap,
    required this.nameMap,
    this.onTap,
  });

  final HistoryEvent event;
  final Map<String, String> categoryMap;
  final Map<String, String> nameMap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The title is always the real entity name — never a backend event label.
    final title =
        (event.title?.isNotEmpty ?? false)
            ? event.title!
            : _fallbackTitle(event.type);
    final userName = event.userId == null ? null : nameMap[event.userId];
    final categoryName =
        event.categoryId == null ? null : categoryMap[event.categoryId];
    final (IconData icon, Color color) = _tileVisual(
      event.type,
      event.categoryId,
    );
    final (String sign, Color amountColor) = _amountStyle(
      event.type,
      event.amount,
    );

    final dateLine =
        '${DateFormatUtils.formatDateShort(event.date)} • ${DateFormatUtils.formatTime(event.date)}';
    final subtitle =
        userName != null
            ? '${shortMemberName(userName)} • $dateLine'
            : dateLine;

    return ActivityCard(
      title: title,
      subtitle: subtitle,
      amount: event.amount,
      amountSign: sign,
      amountColor: amountColor,
      icon: icon,
      iconColor: color,
      chips: _buildChips(categoryName),
      onTap: onTap,
    );
  }

  /// Builds the status / payment-method / category chips (only relevant ones).
  List<ActivityChip> _buildChips(String? categoryName) {
    final chips = <ActivityChip>[];
    final (statusLabel, statusColor) = _statusChip(event.type);
    chips.add(ActivityChip(label: statusLabel, color: statusColor));
    final method = _paymentMethodLabel(event.paymentSource);
    if (method != null) {
      chips.add(ActivityChip(label: method, color: AppTheme.statusApproved));
    }
    if (categoryName != null) {
      chips.add(
        ActivityChip(label: categoryName, color: AppTheme.textSecondary),
      );
    }
    return chips;
  }
}

/// Generic title when an event has no entity name (e.g. a note-less deposit).
String _fallbackTitle(HistoryEventType type) {
  switch (type) {
    case HistoryEventType.deposit:
      return 'Deposit';
    case HistoryEventType.directPayment:
      return 'Direct Payment';
    case HistoryEventType.adjustment:
      return 'Adjustment';
    case HistoryEventType.expenseSubmitted:
      return 'Expense Submitted';
    case HistoryEventType.expenseApproved:
      return 'Expense Approved';
    case HistoryEventType.expensePaid:
      return 'Expense Paid';
    case HistoryEventType.expenseRejected:
      return 'Expense Rejected';
    case HistoryEventType.billCreated:
      return 'Bill Created';
    case HistoryEventType.billPaid:
      return 'Bill Paid';
  }
}

/// Human-readable label used for search matching.
String _eventLabel(HistoryEventType type) {
  switch (type) {
    case HistoryEventType.deposit:
      return 'Deposit';
    case HistoryEventType.directPayment:
      return 'Direct Payment';
    case HistoryEventType.adjustment:
      return 'Adjustment';
    case HistoryEventType.expenseSubmitted:
      return 'Expense Submitted';
    case HistoryEventType.expenseApproved:
      return 'Expense Approved';
    case HistoryEventType.expensePaid:
      return 'Expense Paid';
    case HistoryEventType.expenseRejected:
      return 'Expense Rejected';
    case HistoryEventType.billCreated:
      return 'Bill Created';
    case HistoryEventType.billPaid:
      return 'Bill Paid';
  }
}

/// Leading icon: category-driven for expenses, type-driven otherwise.
(IconData, Color) _tileVisual(HistoryEventType type, String? categoryId) {
  switch (type) {
    case HistoryEventType.deposit:
      return (Icons.savings_outlined, AppTheme.successGreen);
    case HistoryEventType.directPayment:
      return (Icons.credit_card_rounded, AppTheme.statusDirectPayment);
    case HistoryEventType.adjustment:
      return (Icons.swap_horiz_rounded, AppTheme.textSecondary);
    case HistoryEventType.billCreated:
      return (Icons.receipt_long_outlined, AppTheme.statusPending);
    case HistoryEventType.billPaid:
      return (Icons.receipt_long_outlined, AppTheme.successGreen);
    // Expense milestones: use the category icon when known.
    case HistoryEventType.expenseSubmitted:
      return (categoryIcon(categoryId), AppTheme.statusPending);
    case HistoryEventType.expenseApproved:
      return (categoryIcon(categoryId), AppTheme.statusApproved);
    case HistoryEventType.expensePaid:
      return (categoryIcon(categoryId), AppTheme.successGreen);
    case HistoryEventType.expenseRejected:
      return (categoryIcon(categoryId), AppTheme.errorRed);
  }
}

/// Status / type chip label + colour.
(String, Color) _statusChip(HistoryEventType type) {
  switch (type) {
    case HistoryEventType.expenseSubmitted:
      return ('Submitted', AppTheme.statusPending);
    case HistoryEventType.expenseApproved:
      return ('Approved', AppTheme.statusApproved);
    case HistoryEventType.expensePaid:
      return ('Paid', AppTheme.successGreen);
    case HistoryEventType.expenseRejected:
      return ('Rejected', AppTheme.errorRed);
    case HistoryEventType.deposit:
      return ('Deposit', AppTheme.successGreen);
    case HistoryEventType.directPayment:
      return ('Direct Payment', AppTheme.statusDirectPayment);
    case HistoryEventType.adjustment:
      return ('Adjustment', AppTheme.textSecondary);
    case HistoryEventType.billCreated:
      return ('Upcoming Bill', AppTheme.statusPending);
    case HistoryEventType.billPaid:
      return ('Bill Paid', AppTheme.successGreen);
  }
}

/// Payment method chip label, or null when not applicable.
String? _paymentMethodLabel(String? source) {
  switch (source) {
    case 'personal':
      return 'Personal';
    case 'central':
      return 'Central Account';
    default:
      return null;
  }
}

/// Returns the sign + colour for the amount column.
(String, Color) _amountStyle(HistoryEventType type, double amount) {
  switch (type) {
    case HistoryEventType.deposit:
      return ('+', AppTheme.successGreen);
    case HistoryEventType.adjustment:
      // Adjustment can go either way, depending on the signed amount.
      return amount >= 0
          ? ('+', AppTheme.successGreen)
          : ('-', AppTheme.errorRed);
    case HistoryEventType.directPayment:
    case HistoryEventType.billPaid:
    case HistoryEventType.expensePaid:
      return ('-', AppTheme.errorRed);
    default:
      // Status milestones (Submitted / Approved / Rejected, Bill Created):
      // neutral, no sign — the money hasn't moved yet.
      return ('', AppTheme.textSecondary);
  }
}
