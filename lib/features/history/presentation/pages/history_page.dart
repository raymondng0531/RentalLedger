import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/vocabulary_labels.dart';
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
import '../../../../l10n/generated/app_localizations.dart';
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
  // These are stable filter KEYS, never display text — the label shown for a
  // key comes from `_typeLabelFor`.
  static const _typeFilters = [
    'deposit',
    'payment',
    'expense',
    'expensePaid',
    'bill',
    'adjustment',
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
  // Stored status values, as written to and read back from Firestore.
  static const _statusFilters = ['pending', 'approved', 'paid', 'rejected'];

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

  List<HistoryEvent> _applyFilters(
    List<HistoryEvent> events,
    AppLocalizations l10n,
  ) {
    var filtered = events;

    // ── Search by entity name or event label ──
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((e) {
            final title = e.title?.toLowerCase() ?? '';
            final label = _eventLabel(e.type, l10n).toLowerCase();
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
    final l10n = AppLocalizations.of(context);
    // The sheet keys each section's selection by its label, so the label and
    // the lookup must be the same localized string within this call.
    final typeSection = l10n.labelType;
    final statusSection = l10n.labelStatus;

    await showFilterSheet(
      context,
      sections: [
        FilterOptionsSection(
          label: typeSection,
          group: FilterOptionGroup(
            multiSelect: true,
            selected: _selectedTypes,
            options: [
              for (var i = 0; i < _typeFilters.length; i++)
                FilterOption(
                  value: _typeFilters[i],
                  label: _typeLabelFor(_typeFilters[i], l10n),
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
          label: statusSection,
          group: FilterOptionGroup(
            selected: {if (_statusFilter != null) _statusFilter!},
            options: [
              for (var i = 0; i < _statusFilters.length; i++)
                FilterOption(
                  value: _statusFilters[i],
                  label: _statusLabelFor(_statusFilters[i], l10n),
                ),
            ],
          ),
        ),
      ],
      onApply: (result) {
        setState(() {
          _selectedTypes
            ..clear()
            ..addAll(result.select(typeSection));
          _categoryFilter = result.category;
          _statusFilter = result.single(statusSection);
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
    final l10n = AppLocalizations.of(context);
    final historyAsync = ref.watch(historyProvider(_selectedTypes.join(',')));
    final categoriesAsync = ref.watch(categoriesProvider);
    // All records (active + inactive former members): a history tile still
    // needs the actor/payer's name after they leave the house.
    final membersAsync = ref.watch(allMembersStreamProvider);
    final categories = categoriesAsync.value ?? const <CategoryEntity>[];
    // Resolve display names for the tile subtitle + category chip.
    final categoryMap = {for (final c in categories) c.categoryId: c.name};
    final members = membersAsync.value ?? const <HouseMemberEntity>[];
    // Fallback order: displayName → the localized unknown-member label. Never
    // a Firebase UID.
    final nameMap = {
      for (final m in members)
        m.userId:
            (m.displayName?.isNotEmpty == true
                ? m.displayName!
                : l10n.commonUnknownMember),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          // "Menu" is the ordinary word in Malaysian Malay too, so both
          // locales carry the same text — the key exists so the tooltip
          // still follows a runtime language switch like every other label.
          tooltip: l10n.navMenu,
        ),
        title: Text(l10n.navHistory),
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
                  hintText: l10n.historySearchHint,
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
                      child: Text(l10n.actionClearAll),
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
                        label: _typeLabelFor(type, l10n),
                        onDeleted:
                            () => setState(() => _selectedTypes.remove(type)),
                      ),
                    if (_categoryFilter != null)
                      SummaryChip(
                        // The chip's wording is composed from the localized
                        // field label — "Category" / "Kategori" — so the two
                        // languages cannot drift apart.
                        label: '${l10n.labelCategory}: $_categoryFilter',
                        onDeleted: () => setState(() => _categoryFilter = null),
                      ),
                    if (_statusFilter != null)
                      SummaryChip(
                        label:
                            '${l10n.labelStatus}: '
                            '${_statusLabelFor(_statusFilter!, l10n)}',
                        onDeleted: () => setState(() => _statusFilter = null),
                      ),
                    if (_datePreset != null && _customRange == null)
                      SummaryChip(
                        label: _periodLabelFor(_datePreset!, l10n),
                        onDeleted: () => setState(() => _datePreset = null),
                      ),
                    if (_customRange != null)
                      SummaryChip(
                        label:
                            '${DateFormatUtils.formatDateShort(_customRange!.start, l10n.localeName)} – '
                            '${DateFormatUtils.formatDateShort(_customRange!.end, l10n.localeName)}',
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
                          e is Failure
                              ? FailureMessages.of(e, l10n)
                              : l10n.historyLoadError,
                      onRetry:
                          () => ref.invalidate(
                            historyProvider(_selectedTypes.join(',')),
                          ),
                    ),
                data:
                    (items) => _buildList(
                      _applyFilters(items, l10n),
                      categoryMap,
                      nameMap,
                    ),
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
    final l10n = AppLocalizations.of(context);
    if (events.isEmpty) {
      return EmptyState(
        title: _hasActiveFilters ? l10n.emptyNoResults : l10n.emptyNoActivity,
        description:
            _hasActiveFilters
                ? l10n.historyNoResultsHint
                : l10n.historyEmptyDescription,
        icon:
            _hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.receipt_long_outlined,
      );
    }

    // Group AFTER filtering/search, so empty months never render a header.
    // Sections are newest-month-first, events newest-first within each month.
    final sections = groupEventsByMonth(events, l10n);
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

  /// The label shown for a Type filter key.
  ///
  /// Branches on the stable filter key, never on the label, and returns the
  /// active locale's wording for it.
  String _typeLabelFor(String type, AppLocalizations l10n) {
    switch (type) {
      case 'deposit':
        return l10n.txnTypeDeposit;
      case 'payment':
        return l10n.txnTypeDirectPayment;
      case 'expense':
        return l10n.txnTypeExpense;
      case 'expensePaid':
        return l10n.historyTypeExpensePaid;
      case 'bill':
        return l10n.txnTypeBill;
      case 'adjustment':
        return l10n.txnTypeAdjustment;
      default:
        return type;
    }
  }

  /// The label shown for a Status filter.
  ///
  /// The filter holds the STORED status value, which is what selects the label;
  /// an unrecognised value falls back to itself, exactly as before.
  String _statusLabelFor(String status, AppLocalizations l10n) {
    return VocabularyLabels.statusBadge(status, l10n);
  }

  String _periodLabelFor(String preset, AppLocalizations l10n) =>
      FilterPeriods.labelFor(preset, l10n);
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
    final l10n = AppLocalizations.of(context);
    // The title is always the real entity name — never a backend event label.
    final title =
        (event.title?.isNotEmpty ?? false)
            ? event.title!
            : _fallbackTitle(event.type, l10n);
    // The person named on the tile: for a money-in transaction this is the
    // member who physically paid (paidByUserId) when recorded — deposits show
    // the payer, not the Treasurer who recorded it. Legacy deposits fall back
    // to the recorder. Everything else uses the performer.
    final personId = event.paidByUserId ?? event.userId;
    final userName = personId == null ? null : nameMap[personId];
    // Category chip: a default category shows its localized label, a category
    // the user renamed shows the user's own text. A category the map cannot
    // resolve still renders no chip, exactly as before.
    final storedCategoryName =
        event.categoryId == null ? null : categoryMap[event.categoryId];
    final categoryName =
        storedCategoryName == null
            ? null
            : VocabularyLabels.categoryOrNull(
                  l10n: l10n,
                  categoryId: event.categoryId,
                  name: storedCategoryName,
                ) ??
                storedCategoryName;
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
        '${DateFormatUtils.formatDateShort(event.date, l10n.localeName)} • '
        '${DateFormatUtils.formatTime(event.date, l10n.localeName)}';
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
      chips: _buildChips(categoryName, colors, l10n),
      onTap: onTap,
    );
  }

  /// Builds the status / payment-method / category chips (only relevant ones).
  List<ActivityChip> _buildChips(
    String? categoryName,
    AppColors colors,
    AppLocalizations l10n,
  ) {
    final chips = <ActivityChip>[];
    final (statusLabel, statusColor) = _statusChip(
      event.type,
      colors: colors,
      l10n: l10n,
    );
    chips.add(ActivityChip(label: statusLabel, color: statusColor));
    final method = _paymentMethodLabel(event.paymentSource, l10n);
    if (method != null) {
      chips.add(ActivityChip(label: method, color: colors.statusApproved));
    }
    if (categoryName != null) {
      chips.add(ActivityChip(label: categoryName, color: colors.textSecondary));
    }
    return chips;
  }
}

/// Human-readable label for an event type.
///
/// The [type] itself is a stable code the app branches on; only the wording
/// returned here is localized. It is used both as the tile's fallback title and
/// as the text the search box matches against, so searching for what is on
/// screen always finds it.
String _eventLabel(HistoryEventType type, AppLocalizations l10n) {
  switch (type) {
    case HistoryEventType.deposit:
      return l10n.txnTypeDeposit;
    case HistoryEventType.directPayment:
      return l10n.txnTypeDirectPayment;
    case HistoryEventType.adjustment:
      return l10n.txnTypeAdjustment;
    case HistoryEventType.expenseSubmitted:
      return l10n.historyExpenseSubmitted;
    case HistoryEventType.expenseApproved:
      return l10n.historyExpenseApproved;
    case HistoryEventType.expensePaid:
      return l10n.historyTypeExpensePaid;
    case HistoryEventType.expenseRejected:
      return l10n.historyExpenseRejected;
    case HistoryEventType.billCreated:
      return l10n.historyBillCreated;
    case HistoryEventType.billPaid:
      return l10n.historyBillPaid;
  }
}

/// Generic title when an event has no entity name (e.g. a note-less deposit).
String _fallbackTitle(HistoryEventType type, AppLocalizations l10n) =>
    _eventLabel(type, l10n);

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
///
/// The event [type] decides both the wording and the colour; the label is the
/// active locale's.
(String, Color) _statusChip(
  HistoryEventType type, {
  required AppColors colors,
  required AppLocalizations l10n,
}) {
  switch (type) {
    case HistoryEventType.expenseSubmitted:
      return (l10n.statusSubmitted, colors.statusPending);
    case HistoryEventType.expenseApproved:
      return (l10n.statusApproved, colors.statusApproved);
    case HistoryEventType.expensePaid:
      return (l10n.statusPaid, colors.success);
    case HistoryEventType.expenseRejected:
      return (l10n.statusRejected, colors.error);
    case HistoryEventType.deposit:
      return (l10n.txnTypeDeposit, colors.success);
    case HistoryEventType.directPayment:
      return (l10n.txnTypeDirectPayment, colors.statusDirectPayment);
    case HistoryEventType.adjustment:
      return (l10n.txnTypeAdjustment, colors.textSecondary);
    case HistoryEventType.billCreated:
      return (l10n.historyUpcomingBill, colors.statusPending);
    case HistoryEventType.billPaid:
      return (l10n.historyBillPaid, colors.success);
  }
}

/// Payment source chip label, or null when not applicable.
///
/// The STORED source (`personal` / `central`) is what is branched on; the text
/// comes from the shared vocabulary mapping.
String? _paymentMethodLabel(String? source, AppLocalizations l10n) {
  switch (source) {
    case 'personal':
      return l10n.paymentSourcePersonal;
    case 'central':
      return l10n.paymentSourceCentral;
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
