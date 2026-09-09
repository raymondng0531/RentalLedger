import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/receipt_viewer.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../features/history/presentation/providers/history_provider.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../providers/expense_provider.dart' show categoriesProvider;
import '../widgets/receipt_image.dart';

/// Deposit Details — read-only finance-style view of a Deposit event.
class DepositDetailsPage extends StatelessWidget {
  const DepositDetailsPage({super.key, required this.event});
  final HistoryEvent event;

  @override
  Widget build(BuildContext context) {
    return _TransactionDetailsView(
      event: event,
      title: 'Deposit Details',
      icon: Icons.savings_outlined,
      color: AppTheme.successGreen,
    );
  }
}

/// Direct Payment Details — read-only finance-style view of a Direct Payment.
class DirectPaymentDetailsPage extends StatelessWidget {
  const DirectPaymentDetailsPage({super.key, required this.event});
  final HistoryEvent event;

  @override
  Widget build(BuildContext context) {
    return _TransactionDetailsView(
      event: event,
      title: 'Direct Payment Details',
      icon: Icons.credit_card_rounded,
      color: AppTheme.statusDirectPayment,
    );
  }
}

/// Shared layout for the deposit / direct-payment detail screens.
class _TransactionDetailsView extends ConsumerWidget {
  const _TransactionDetailsView({
    required this.event,
    required this.title,
    required this.icon,
    required this.color,
  });

  final HistoryEvent event;
  final String title;
  final IconData icon;
  final Color color;

  /// Opens the stored proof full-screen (canvas `Image.network`, which the
  /// Storage CORS already authorizes — the same path the expense detail page
  /// uses for saved receipts).
  void _openReceipt(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ReceiptViewer(
              title: 'Receipt / Proof',
              image: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder:
                    (_, __, ___) => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load receipt',
                            style: TextStyle(color: Colors.white54),
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
    final theme = Theme.of(context);
    final members =
        ref.watch(membersStreamProvider).value ?? const <HouseMemberEntity>[];
    // Fallback order: displayName → "Unknown Member". Never a Firebase UID.
    final nameMap = {
      for (final m in members)
        m.userId:
            (m.displayName?.isNotEmpty == true
                ? m.displayName!
                : 'Unknown Member'),
    };
    final performedBy =
        event.userId == null
            ? null
            : (nameMap[event.userId] ?? 'Unknown Member');
    final paidBy = event.paidByUserId == null
        ? null
        : (nameMap[event.paidByUserId] ?? 'Unknown Member');

    // Category name for direct payments that carry one.
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final matches = categories.where((c) => c.categoryId == event.categoryId);
    final categoryName = matches.isEmpty ? null : matches.first.name;

    final isInflow = event.amount >= 0;
    final amountColor = isInflow ? AppTheme.successGreen : AppTheme.errorRed;
    final sign = isInflow ? '+' : '-';
    final dateLine =
        '${DateFormatUtils.formatDateShort(event.date)} • ${DateFormatUtils.formatTime(event.date)}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(title),
        backgroundColor: Colors.white,
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
                color: AppTheme.backgroundLight,
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
                                  : title.replaceAll(' Details', ''),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              performedBy != null ? 'by $performedBy' : '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$sign${CurrencyUtils.format(event.amount.abs())}',
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
                color: AppTheme.backgroundLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: dateLine,
                      ),
                      if (paidBy != null)
                        _InfoRow(
                          icon: Icons.person_pin_outlined,
                          label: 'Paid By',
                          value: paidBy,
                        ),
                      _InfoRow(
                        icon: Icons.person_outlined,
                        label: 'Performed By',
                        value: performedBy ?? '—',
                      ),
                      if (event.paymentMethod != null)
                        _InfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Payment Method',
                          value: event.paymentMethod!,
                        ),
                      if (event.periodLabel != null)
                        _InfoRow(
                          icon: Icons.calendar_month_outlined,
                          label: 'Covers Month',
                          value: event.periodLabel!,
                        ),
                      if (event.purpose != null)
                        _InfoRow(
                          icon: Icons.label_outline,
                          label: 'Purpose',
                          value: event.purpose!,
                        ),
                      if (categoryName != null)
                        _InfoRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: categoryName,
                        ),
                      _InfoRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Payment Source',
                        value:
                            event.paymentSource == 'personal'
                                ? 'Personal'
                                : 'Central Account',
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
                  color: AppTheme.backgroundLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt / Proof',
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
                            label: const Text('View Receipt'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
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
