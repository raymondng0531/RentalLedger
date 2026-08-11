import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../features/history/presentation/providers/history_provider.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';

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
      body: SingleChildScrollView(
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
                    _InfoRow(
                      icon: Icons.person_outlined,
                      label: 'Performed By',
                      value: performedBy ?? '—',
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
          ],
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
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
