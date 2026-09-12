import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
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
import '../../../../features/expenses/domain/entities/category_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../providers/history_provider.dart';
import '../utils/filter_periods.dart';
import '../utils/history_grouping.dart';
import '../widgets/filter_widgets.dart';
import '../widgets/history_month_header.dart';

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
  // The vocabulary and its date arithmetic now live in FilterPeriods, shared
  // with Bill History so the two screens cannot disagree about what
  // "Last 7 Days" means. History's own behaviour is unchanged.

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
  /// Delegates to the shared FilterPeriods vocabulary so History and Bill
  /// History resolve periods identically.
  (DateTime, DateTime)? get _activeRange =>
      FilterPeriods.resolve(preset: _datePreset, range: _customRange);

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
      filtered =
          filtered.where((e) => FilterPeriods.contains(range, e.date)).toList();
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
  ///
  /// The sheet itself is shared (see filter_widgets.dart); History supplies
  /// its own sections in its own order — Type, Period, Category, Status — so
  /// what the user sees here is unchanged.
  Future<void> _openFilterSheet(List<CategoryEntity> categories) async {
    await showFilterSheet(
      context,
      sections: [
        FilterOptionsSection(
          label: 'Type',
          group: FilterOptionGroup(
            multiSelect: true,
            selected: _selectedTypes,
            options: [
              for (var i = 0; i < _typeFilters.length; i++)
                FilterOption(
                  value: _typeFilters[i],
                  label: _typeLabels[i],
                  icon: _typeIcons[i],
                ),
            ],
          ),
        ),
        FilterPeriodSection(preset: _datePreset, range: _customRange),
        FilterCategorySection(
          category: _categoryFilter,
          categories: categories,
        ),
        FilterOptionsSection(
          label: 'Status',
          group: FilterOptionGroup(
            selected: {if (_statusFilter != null) _statusFilter!},
            options: [
              for (var i = 0; i < _statusFilters.length; i++)
                FilterOption(
                  value: _statusFilters[i],
                  label: _statusLabels[i],
                ),
            ],
          ),
        ),
      ],
      onApply: (result) {
        setState(() {
          _selectedTypes
            ..clear()
            ..addAll(result.select('Type'));
          _categoryFilter = result.category;
          _statusFilter = result.single('Status');
          _datePreset = result.preset;
          _customRange = result.range;
        });
      },
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
    // All records (active + inactive former members): a history tile still
    // needs the actor/payer's name after they leave the house.
    final membersAsync = ref.watch(allMembersStreamProvider);
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
                    child: FilterButton(
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
                      SummaryChip(
                        label: _typeLabelFor(type),
                        onDeleted:
                            () => setState(() => _selectedTypes.remove(type)),
                      ),
                    if (_categoryFilter != null)
                      SummaryChip(
                        label: 'Category: $_categoryFilter',
                        onDeleted: () => setState(() => _categoryFilter = null),
                      ),
                    if (_statusFilter != null)
                      SummaryChip(
                        label: 'Status: ${_statusLabelFor(_statusFilter!)}',
                        onDeleted: () => setState(() => _statusFilter = null),
                      ),
                    if (_datePreset != null && _customRange == null)
                      SummaryChip(
                        label: _periodLabelFor(_datePreset!),
                        onDeleted: () => setState(() => _datePreset = null),
                      ),
                    if (_customRange != null)
                      SummaryChip(
                        label:
                            '${DateFormatUtils.formatDateShort(_customRange!.start)} – '
                            '${DateFormatUtils.formatDateShort(_customRange!.end)}',
                        onDeleted: () => setState(() => _customRange = null),
                      ),
                    if (_searchQuery.isNotEmpty)
                      SummaryChip(
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
          MonthHeaderRow(section: final section) => HistoryMonthHeader(
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

  String _periodLabelFor(String preset) => FilterPeriods.labelFor(preset);
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
    final colors = context.colors;
    // The title is always the real entity name — never a backend event label.
    final title =
        (event.title?.isNotEmpty ?? false)
            ? event.title!
            : _fallbackTitle(event.type);
    // The person named on the tile: for a money-in transaction this is the
    // member who physically paid (paidByUserId) when recorded — deposits show
    // the payer, not the Treasurer who recorded it. Legacy deposits fall back
    // to the recorder. Everything else uses the performer.
    final personId = event.paidByUserId ?? event.userId;
    final userName = personId == null ? null : nameMap[personId];
    final categoryName =
        event.categoryId == null ? null : categoryMap[event.categoryId];
    final (IconData icon, Color color) = _tileVisual(
      event.type,
      event.categoryId,
      colors: colors,
    );
    final (String sign, Color amountColor) = _amountStyle(
      event.type,
      event.amount,
      colors: colors,
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
      chips: _buildChips(categoryName, colors),
      onTap: onTap,
    );
  }

  /// Builds the status / payment-method / category chips (only relevant ones).
  List<ActivityChip> _buildChips(String? categoryName, AppColors colors) {
    final chips = <ActivityChip>[];
    final (statusLabel, statusColor) = _statusChip(event.type, colors: colors);
    chips.add(ActivityChip(label: statusLabel, color: statusColor));
    final method = _paymentMethodLabel(event.paymentSource);
    if (method != null) {
      chips.add(ActivityChip(label: method, color: colors.statusApproved));
    }
    if (categoryName != null) {
      chips.add(ActivityChip(label: categoryName, color: colors.textSecondary));
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
///
/// Takes the resolved [AppColors] rather than reading them itself: it is a
/// top-level function with no `BuildContext`, and the tile's own build is the
/// one place that knows which theme is active.
(IconData, Color) _tileVisual(
  HistoryEventType type,
  String? categoryId, {
  required AppColors colors,
}) {
  switch (type) {
    case HistoryEventType.deposit:
      return (Icons.savings_outlined, colors.success);
    case HistoryEventType.directPayment:
      return (Icons.credit_card_rounded, colors.statusDirectPayment);
    case HistoryEventType.adjustment:
      return (Icons.swap_horiz_rounded, colors.textSecondary);
    case HistoryEventType.billCreated:
      return (Icons.receipt_long_outlined, colors.statusPending);
    case HistoryEventType.billPaid:
      return (Icons.receipt_long_outlined, colors.success);
    // Expense milestones: use the category icon when known.
    case HistoryEventType.expenseSubmitted:
      return (categoryIcon(categoryId), colors.statusPending);
    case HistoryEventType.expenseApproved:
      return (categoryIcon(categoryId), colors.statusApproved);
    case HistoryEventType.expensePaid:
      return (categoryIcon(categoryId), colors.success);
    case HistoryEventType.expenseRejected:
      return (categoryIcon(categoryId), colors.error);
  }
}

/// Status / type chip label + colour.
(String, Color) _statusChip(HistoryEventType type, {required AppColors colors}) {
  switch (type) {
    case HistoryEventType.expenseSubmitted:
      return ('Submitted', colors.statusPending);
    case HistoryEventType.expenseApproved:
      return ('Approved', colors.statusApproved);
    case HistoryEventType.expensePaid:
      return ('Paid', colors.success);
    case HistoryEventType.expenseRejected:
      return ('Rejected', colors.error);
    case HistoryEventType.deposit:
      return ('Deposit', colors.success);
    case HistoryEventType.directPayment:
      return ('Direct Payment', colors.statusDirectPayment);
    case HistoryEventType.adjustment:
      return ('Adjustment', colors.textSecondary);
    case HistoryEventType.billCreated:
      return ('Upcoming Bill', colors.statusPending);
    case HistoryEventType.billPaid:
      return ('Bill Paid', colors.success);
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
(String, Color) _amountStyle(
  HistoryEventType type,
  double amount, {
  required AppColors colors,
}) {
  switch (type) {
    case HistoryEventType.deposit:
      return ('+', colors.success);
    case HistoryEventType.adjustment:
      // Adjustment can go either way, depending on the signed amount.
      return amount >= 0 ? ('+', colors.success) : ('-', colors.error);
    case HistoryEventType.directPayment:
    case HistoryEventType.billPaid:
    case HistoryEventType.expensePaid:
      return ('-', colors.error);
    default:
      // Status milestones (Submitted / Approved / Rejected, Bill Created):
      // neutral, no sign — the money hasn't moved yet.
      return ('', colors.textSecondary);
  }
}
