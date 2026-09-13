import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/receipt_viewer.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../features/history/presentation/providers/history_provider.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../providers/expense_provider.dart' show categoriesProvider;
import '../widgets/receipt_image.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Deposit Details — read-only finance-style view of a Deposit event.
class DepositDetailsPage extends StatelessWidget {
  const DepositDetailsPage({super.key, required this.event});
  final HistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _TransactionDetailsView(
      event: event,
      title: l10n.depositDetailsTitle,
      // Shown in place of the record's own title when it carries none — the
      // transaction type, NOT the app-bar title with " Details" trimmed off
      // (a localized string must never be used for control flow).
      fallbackTitle: l10n.txnTypeDeposit,
      icon: Icons.savings_outlined,
      color: context.colors.success,
    );
  }
}

/// Direct Payment Details — read-only finance-style view of a Direct Payment.
class DirectPaymentDetailsPage extends StatelessWidget {
  const DirectPaymentDetailsPage({super.key, required this.event});
  final HistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _TransactionDetailsView(
      event: event,
      title: l10n.directPaymentDetailsTitle,
      fallbackTitle: l10n.txnTypeDirectPayment,
      icon: Icons.credit_card_rounded,
      color: context.colors.statusDirectPayment,
    );
  }
}

/// Shared layout for the deposit / direct-payment detail screens.
class _TransactionDetailsView extends ConsumerWidget {
  const _TransactionDetailsView({
    required this.event,
    required this.title,
    required this.fallbackTitle,
    required this.icon,
    required this.color,
  });

  final HistoryEvent event;
  final String title;

  /// Used in place of the record's own title when it carries none (the
  /// transaction type's localized name). Kept as its own field so the header
  /// never has to derive it from [title] with string surgery.
  final String fallbackTitle;

  final IconData icon;
  final Color color;

  /// Opens the stored proof full-screen (canvas `Image.network`, which the
  /// Storage CORS already authorizes — the same path the expense detail page
  /// uses for saved receipts).
  ///
  /// The `Colors.white54` failure glyphs below are deliberately NOT themed:
  /// [ReceiptViewer] draws its own fixed black ground in every mode, so white
  /// is the correct ink there and `context.colors` does not apply.
  void _openReceipt(BuildContext context, String url) {
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ReceiptViewer(
              title: l10n.labelReceiptProof,
              image: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder:
                    (_, __, ___) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.errorFailedToLoadReceipt,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
    // All records (active + inactive former members): a transaction detail
    // still needs the performer/payer's name after they leave the house.
    final members =
        ref.watch(allMembersStreamProvider).value ?? const <HouseMemberEntity>[];
    // Fallback order: displayName → "Unknown Member". Never a Firebase UID.
    final nameMap = {
      for (final m in members)
        m.userId:
            (m.displayName?.isNotEmpty == true
                ? m.displayName!
                : l10n.commonUnknownMember),
    };
    final performedBy =
        event.userId == null
            ? null
            : (nameMap[event.userId] ?? l10n.commonUnknownMember);
    final paidBy = event.paidByUserId == null
        ? null
        : (nameMap[event.paidByUserId] ?? l10n.commonUnknownMember);

    // Category name for direct payments that carry one.
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final matches = categories.where((c) => c.categoryId == event.categoryId);
    final categoryName = matches.isEmpty ? null : matches.first.name;

    final isInflow = event.amount >= 0;
    final amountColor = isInflow ? colors.success : colors.error;
    final sign = isInflow ? '+' : '-';
    final dateLine =
        '${DateFormatUtils.formatDateShort(event.date, l10n.localeName)} • '
        '${DateFormatUtils.formatTime(event.date, l10n.localeName)}';

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: l10n.actionBack,
        ),
        title: Text(title),
        backgroundColor: colors.surface,
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800).
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ──
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: colors.surfaceMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withAlpha(22),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, size: 24, color: color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (event.title?.isNotEmpty ?? false)
                                  ? event.title!
                                  : fallbackTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              performedBy != null
                                  ? l10n.txnByPerson(performedBy)
                                  : '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$sign${CurrencyUtils.format(event.amount.abs(), localeCode: l10n.localeName)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Info card ──
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: colors.surfaceMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: l10n.labelDate,
                        value: dateLine,
                      ),
                      if (paidBy != null)
                        _InfoRow(
                          icon: Icons.person_pin_outlined,
                          label: l10n.labelPaidBy,
                          value: paidBy,
                        ),
                      _InfoRow(
                        icon: Icons.person_outlined,
                        label: l10n.labelPerformedBy,
                        value: performedBy ?? '—',
                      ),
                      if (event.paymentMethod != null)
                        _InfoRow(
                          icon: Icons.payments_outlined,
                          label: l10n.labelPaymentMethod,
                          value: VocabularyLabels.paymentMethod(
                            event.paymentMethod,
                            l10n,
                          ),
                        ),
                      if (event.periodLabel != null)
                        _InfoRow(
                          icon: Icons.calendar_month_outlined,
                          label: l10n.txnCoversMonth,
                          value: event.periodLabel!,
                        ),
                      if (event.purpose != null)
                        _InfoRow(
                          icon: Icons.label_outline,
                          label: l10n.labelPurpose,
                          value: event.purpose!,
                        ),
                      if (categoryName != null)
                        _InfoRow(
                          icon: Icons.category_outlined,
                          label: l10n.labelCategory,
                          value: VocabularyLabels.category(
                            l10n: l10n,
                            categoryId: event.categoryId,
                            name: categoryName,
                          ),
                        ),
                      _InfoRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: l10n.labelPaymentSource,
                        // Keyed on the STORED source value.
                        value: VocabularyLabels.paymentSource(
                          event.paymentSource,
                          l10n,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Receipt / proof ──
              if (event.receiptUrl != null) ...[
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: colors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.labelReceiptProof,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          child: ReceiptImage(
                            receiptUrl: event.receiptUrl!,
                            height: 180,
                            width: double.infinity,
                            onTap: () => _openReceipt(
                              context,
                              event.receiptUrl!,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openReceipt(context, event.receiptUrl!),
                            icon: const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 18,
                            ),
                            label: Text(l10n.actionViewReceipt),
                          ),
                        ),
                      ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Padding(
      // Uniform vertical rhythm so every row sits at the same spacing.
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        // Center vertically for single-line rows; a wrapped value still keeps
        // the icon + label optically centered without shifting the columns.
        // (Row defaults to CrossAxisAlignment.center.)
        children: [
          // Fixed-width icon slot: every glyph is centered in the same
          // footprint, so all labels begin at the same x regardless of the
          // icon's shape.
          SizedBox(
            width: 24,
            child: Center(
              child: Icon(icon, size: 18, color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          // Label follows the icon slot at a constant offset.
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          // Value column: right-aligned to a single shared edge (all rows are
          // the same width). Expanded makes long values wrap instead of
          // overflowing the row or pushing the label off.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
