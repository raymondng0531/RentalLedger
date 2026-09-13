import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/member_name_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/activity_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/implicit_animated_list.dart';
import '../../../../core/widgets/receipt_viewer.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../expenses/domain/entities/category_entity.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../members/domain/entities/house_member_entity.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../providers/bill_history_provider.dart';
import '../utils/bill_history.dart';
import '../utils/filter_periods.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../utils/history_grouping.dart';
import '../widgets/filter_widgets.dart';
import '../widgets/history_month_header.dart';

/// Bill History — a bill-centric read surface over bills that already exist.
///
/// This is an ADDITIONAL read surface. It does not replace, wrap, or alter the
/// existing History page, and it writes nothing: no Firestore collection,
/// field, index, rule or write path is touched. Every row it renders comes
/// from `billsProvider`, every payment detail from the `billPaid` events
/// History already derives — see [billHistoryProvider] and `bill_history.dart`
/// for the join and the filtering rules.
///
/// ## What this page deliberately does not claim
///
/// A bill carries no member attribution, so the "Recorded by" filter selects
/// on who RECORDED a payment (the Treasurer, per the transaction model) — it is
/// never an owner or payer filter, and the screen never says "Paid by". A bill
/// with no recorded payment — every Upcoming bill, and every amountless bill,
/// which settle without writing a transaction — cannot match a member filter,
/// so an active member filter necessarily hides those rows. The empty state
/// says so rather than leaving the user to guess.
class BillHistoryPage extends ConsumerStatefulWidget {
  const BillHistoryPage({super.key});

  @override
  ConsumerState<BillHistoryPage> createState() => _BillHistoryPageState();
}

class _BillHistoryPageState extends ConsumerState<BillHistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Empty means "All". Multi-select, matching History's Type section.
  final Set<BillHistoryStatus> _statuses = {};

  String? _categoryId;

  /// The member who recorded the payment — never an owner or payer.
  String? _memberUserId;

  String? _datePreset;
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BillHistoryFilters get _filters => BillHistoryFilters(
    statuses: _statuses,
    categoryId: _categoryId,
    searchQuery: _searchQuery,
    memberUserId: _memberUserId,
    preset: _datePreset,
    range: _customRange,
  );

  bool get _hasActiveFilters => !_filters.isEmpty;

  Future<void> _openFilterSheet(
    List<CategoryEntity> categories,
    List<HouseMemberEntity> members,
  ) async {
    final l10n = AppLocalizations.of(context);
    // The sheet keys each section's selection by its label, so the label and
    // the key have to be the same string — the localized one, taken once and
    // reused on both sides.
    final statusSection = l10n.labelStatus;
    final memberSection = l10n.labelRecordedBy;

    await showFilterSheet(
      context,
      // Status leads: for a bill, paid/overdue/upcoming is the primary axis.
      sections: [
        FilterOptionsSection(
          label: statusSection,
          group: FilterOptionGroup(
            multiSelect: true,
            selected: {for (final s in _statuses) s.key},
            options: [
              for (final s in BillHistoryStatus.values)
                FilterOption(
                  value: s.key,
                  label: billHistoryStatusLabel(s, l10n),
                ),
            ],
          ),
        ),
        FilterPeriodSection(preset: _datePreset, range: _customRange),
        FilterCategorySection(category: _categoryId, categories: categories),
        FilterOptionsSection(
          label: memberSection,
          group: FilterOptionGroup(
            selected: {if (_memberUserId != null) _memberUserId!},
            options: [
              for (final m in members)
                FilterOption(value: m.userId, label: _memberLabel(m, l10n)),
            ],
          ),
        ),
      ],
      onApply: (result) {
        setState(() {
          _statuses
            ..clear()
            ..addAll(
              result
                  .select(statusSection)
                  .map(BillHistoryStatus.fromKey)
                  .whereType<BillHistoryStatus>(),
            );
          _categoryId = result.category;
          _datePreset = result.preset;
          _customRange = result.range;
          _memberUserId = result.single(memberSection);
        });
      },
    );
  }

  void _resetFilters() {
    setState(() {
      _statuses.clear();
      _categoryId = null;
      _memberUserId = null;
      _datePreset = null;
      _customRange = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final billHistoryAsync = ref.watch(billHistoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    // All records (active + inactive): a settled bill's recorder may since have
    // left the house, and their name must still resolve. Same source and same
    // collapse the Dashboard/History use for historical activity.
    final membersAsync = ref.watch(allMembersStreamProvider);

    final categories = categoriesAsync.value ?? const <CategoryEntity>[];
    final categoryMap = {for (final c in categories) c.categoryId: c.name};

    final members = mergeMemberRecordsByUser(
      membersAsync.value ?? const <HouseMemberEntity>[],
    );
    // Fallback order: displayName → "Unknown Member". Never a Firebase UID.
    final nameMap = {for (final m in members) m.userId: _memberLabel(m, l10n)};

    return Scaffold(
      appBar: AppBar(
        // No drawer: this is a pushed sub-page, so the AppBar's automatic back
        // button is the way out, matching every other detail route.
        title: Text(l10n.navBillHistory),
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800), the same
        // read-surface width the History page uses.
        child: Column(
          children: [
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                8,
                AppConstants.pagePadding,
                4,
              ),
              child: TextField(
                controller: _searchController,
                onChanged:
                    (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n.billHistorySearchHint,
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
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                4,
                AppConstants.pagePadding,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilterButton(
                      activeCount: _filters.activeCount,
                      onTap: () => _openFilterSheet(categories, members),
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
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  4,
                  AppConstants.pagePadding,
                  4,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final status in _statuses)
                      SummaryChip(
                        label: billHistoryStatusLabel(status, l10n),
                        onDeleted:
                            () => setState(() => _statuses.remove(status)),
                      ),
                    if (_categoryId != null)
                      SummaryChip(
                        // The stored category name is shown through the shared
                        // vocabulary mapping, so a default keeps its localized
                        // label while a category the user renamed stays their
                        // own text.
                        label: '${l10n.labelCategory}: '
                            '${VocabularyLabels.categoryOrNull(
                              l10n: l10n,
                              categoryId: _categoryId,
                              name: categoryMap[_categoryId],
                            ) ?? ''}',
                        onDeleted: () => setState(() => _categoryId = null),
                      ),
                    if (_memberUserId != null)
                      SummaryChip(
                        label: '${l10n.labelRecordedBy}: '
                            '${nameMap[_memberUserId] ?? l10n.commonUnknownMember}',
                        onDeleted: () => setState(() => _memberUserId = null),
                      ),
                    if (_datePreset != null && _customRange == null)
                      SummaryChip(
                        label: FilterPeriods.labelFor(_datePreset!, l10n),
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
              child: billHistoryAsync.when(
                loading: () => const Shimmer(child: SkeletonListBody()),
                error:
                    (e, _) => ErrorDisplay(
                      message:
                          e is Failure
                              ? FailureMessages.of(e, l10n)
                              : l10n.billHistoryLoadFailed,
                      onRetry: () => refreshBillHistory(ref),
                    ),
                data:
                    (entries) => _buildList(
                      applyBillHistoryFilters(entries, _filters),
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
    List<BillHistoryEntry> entries,
    Map<String, String> categoryMap,
    Map<String, String> nameMap,
  ) {
    final l10n = AppLocalizations.of(context);
    if (entries.isEmpty) {
      return EmptyState(
        title: _hasActiveFilters ? l10n.emptyNoResults : l10n.billHistoryEmpty,
        description: _emptyDescription(l10n),
        icon:
            _hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.receipt_long_outlined,
      );
    }

    // Group AFTER filtering, so a month never renders an empty header. Each row
    // is filed under its own date (payment date when paid, due date otherwise),
    // which is also the date the Period filter selected it by — so a row can
    // never appear under a month it was not filtered against.
    final sections = groupItemsByMonth(entries, (e) => e.filterDate, l10n);
    final rows = <_BillHistoryRow>[];
    for (final section in sections) {
      rows.add(_MonthRow(section.label, section.year, section.month));
      rows.addAll(section.items.map(_EntryRow.new));
    }

    return ImplicitAnimatedList<_BillHistoryRow>(
      items: rows,
      itemKey: (row) => row.key,
      initialStagger: AppDurations.stagger,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder:
          (context, row) => switch (row) {
            _MonthRow(label: final label) => HistoryMonthHeader(label: label),
            _EntryRow(entry: final entry) => _BillHistoryTile(
              entry: entry,
              categoryMap: categoryMap,
              nameMap: nameMap,
              onTap: () => _openBillDetails(entry),
            ),
          },
    );
  }

  /// The empty state's explanation, which must not mislead.
  ///
  /// With a member filter active the result is empty for a structural reason —
  /// only a bill with a recorded payment can name a recorder — so the user is
  /// told that, instead of being told to "adjust the filters" as though a
  /// different choice would have matched.
  String? _emptyDescription(AppLocalizations l10n) {
    if (!_hasActiveFilters) {
      return l10n.billHistoryEmptyDescription;
    }
    if (_memberUserId != null) {
      return l10n.billHistoryMemberFilterEmpty;
    }
    return l10n.historyNoResultsHint;
  }

  /// Opens the EXISTING bill detail route — the "existing bill reference" the
  /// billPaid event resolves to.
  void _openBillDetails(BillHistoryEntry entry) {
    context.push(RouteNames.billDetails.replaceFirst(':billId', entry.billId));
  }
}

/// The display name for a member record — the same fallback History uses.
///
/// Never a Firebase UID. Resolving an unresolvable member to "Unknown Member"
/// is the pre-existing, house-wide behaviour.
String _memberLabel(HouseMemberEntity member, AppLocalizations l10n) =>
    (member.displayName?.isNotEmpty == true)
        ? member.displayName!
        : l10n.commonUnknownMember;

// ─────────────────────────────────────────────────────────────
// Rows
// ─────────────────────────────────────────────────────────────

/// One row of the sectioned Bill History list: a month header or a bill.
///
/// Mirrors History's `HistoryRow` shape (and its month key format) so both
/// lists diff the same way through [ImplicitAnimatedList].
sealed class _BillHistoryRow {
  const _BillHistoryRow();

  String get key;
}

class _MonthRow extends _BillHistoryRow {
  const _MonthRow(this.label, this.year, this.month);

  final String label;
  final int year;
  final int month;

  @override
  String get key => 'month-$year-$month';
}

class _EntryRow extends _BillHistoryRow {
  const _EntryRow(this.entry);

  final BillHistoryEntry entry;

  @override
  String get key => entry.billId;
}

/// One bill, rendered with the shared activity card.
///
/// Layout:
/// [icon]  Electricity                    RM 120.00
///         Due 20 Sep 2026 • Raymond Ng • 6 Aug 2026 • 5:03 PM
///         [Paid] [Utilities] [Bank Transfer] [Covers 2026-08] [Receipt]
///
/// The amount is a plain magnitude, not money in or out, so it carries no
/// sign and the theme's default colour — matching the Dashboard's Upcoming
/// Bills rows. An amountless bill states "Reminder" instead of a fabricated
/// "RM 0.00", the same treatment those rows use.
class _BillHistoryTile extends StatelessWidget {
  const _BillHistoryTile({
    required this.entry,
    required this.categoryMap,
    required this.nameMap,
    this.onTap,
  });

  final BillHistoryEntry entry;
  final Map<String, String> categoryMap;
  final Map<String, String> nameMap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final payment = entry.latestPayment;
    final (IconData icon, Color color) = _visual(entry.status, colors: colors);
    final categoryName =
        entry.categoryId == null ? null : categoryMap[entry.categoryId];

    // Due date first and always: §1's due date is a property of the bill, while
    // the payment line below it only exists once something was recorded.
    final subtitle = <String>[
      l10n.billDueOn(
        DateFormatUtils.formatDateShort(entry.dueDate, l10n.localeName),
      ),
      if (payment != null) ...[
        if (payment.recordedByUserId != null)
          shortMemberName(
            nameMap[payment.recordedByUserId] ?? l10n.commonUnknownMember,
          ),
        '${DateFormatUtils.formatDateShort(payment.date, l10n.localeName)} '
            '${DateFormatUtils.formatTime(payment.date, l10n.localeName)}',
      ],
    ].join(' • ');

    return ActivityCard(
      title: entry.title,
      subtitle: subtitle,
      amount: entry.amount ?? 0,
      amountLabel: entry.hasAmount ? null : l10n.billReminderOnly,
      amountSign: '',
      amountColor: entry.hasAmount ? null : colors.textSecondary,
      icon: icon,
      iconColor: color,
      chips: _buildChips(payment, categoryName, colors, l10n),
      onTap: onTap,
    );
  }

  /// Status / category / payment chips — only the ones that apply.
  List<Widget> _buildChips(
    BillHistoryPayment? payment,
    String? categoryName,
    AppColors colors,
    AppLocalizations l10n,
  ) {
    final chips = <Widget>[
      ActivityChip(
        // Status is a derived value (paid / overdue / upcoming), so the label
        // is chosen from the value and never from any text.
        label: billHistoryStatusLabel(entry.status, l10n),
        color: _visual(entry.status, colors: colors).$2,
      ),
    ];

    if (categoryName != null) {
      chips.add(ActivityChip(label: categoryName, color: colors.textSecondary));
    }

    final method = payment?.paymentMethod;
    if (method != null && method.trim().isNotEmpty) {
      // The STORED payment method ("Cash", "Bank Transfer", …) is what is
      // branched on; only the chip's wording is localized.
      chips.add(
        ActivityChip(
          label: VocabularyLabels.paymentMethod(method, l10n),
          color: colors.statusApproved,
        ),
      );
    }

    final period = payment?.periodLabel;
    if (period != null && period.trim().isNotEmpty) {
      // "Covers <month>" — the same field the transaction detail page names,
      // so the vocabulary matches. The stored period is shown verbatim.
      chips.add(
        ActivityChip(
          label: l10n.billHistoryCoversPeriod(period),
          color: colors.textSecondary,
        ),
      );
    }

    // A recurring bill keeps ONE billId as it rolls forward, so it can hold
    // several settlements. The row shows the latest; the count is what stops
    // that from reading as the only one.
    if (entry.payments.length > 1) {
      chips.add(
        ActivityChip(
          label: l10n.billHistoryPaymentCount(entry.payments.length),
          color: colors.textSecondary,
        ),
      );
    }

    final receiptUrl = payment?.receiptUrl;
    if (receiptUrl != null && receiptUrl.trim().isNotEmpty) {
      chips.add(_ReceiptChip(receiptUrl: receiptUrl, l10n: l10n));
    }

    return chips;
  }
}

/// A tappable "Receipt" chip that opens the shared full-screen viewer.
///
/// Reuses [ActivityChip] for its appearance and [ReceiptViewer] for the viewer,
/// so a bill payment's proof is shown the same way an expense receipt or a
/// direct payment's proof already is.
class _ReceiptChip extends StatelessWidget {
  const _ReceiptChip({required this.receiptUrl, required this.l10n});

  final String receiptUrl;
  final AppLocalizations l10n;

  /// The `Colors.white54` error glyph below is deliberately NOT themed:
  /// [ReceiptViewer] paints its own fixed black ground in every mode, so white
  /// is the correct ink there and `context.colors` does not apply.
  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ReceiptViewer(
              title: l10n.labelReceiptProof,
              image: Image.network(
                receiptUrl,
                fit: BoxFit.contain,
                loadingBuilder:
                    (context, child, progress) =>
                        progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                errorBuilder:
                    (_, __, ___) => const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(7),
      child: ActivityChip(
        label: AppLocalizations.of(context).labelReceipt,
        color: context.colors.statusApproved,
      ),
    );
  }
}

/// The leading icon and its colour for a status.
///
/// The icon is the bill icon History already uses for bill tiles; the colours
/// are the app's existing status palette (paid = green, overdue = red,
/// not-yet-due = amber).
///
/// Takes the resolved [AppColors] rather than reading them itself: it is a
/// top-level function with no `BuildContext`.
(IconData, Color) _visual(BillHistoryStatus status, {required AppColors colors}) {
  switch (status) {
    case BillHistoryStatus.paid:
      return (Icons.receipt_long_outlined, colors.success);
    case BillHistoryStatus.overdue:
      return (Icons.receipt_long_outlined, colors.error);
    case BillHistoryStatus.upcoming:
      return (Icons.receipt_long_outlined, colors.statusPending);
  }
}
