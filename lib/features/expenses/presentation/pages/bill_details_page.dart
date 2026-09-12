import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../features/expenses/domain/entities/bill_entity.dart';
import '../../../../features/expenses/domain/entities/category_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart';

/// Bill Details — real-time finance-style view of a single bill.
class BillDetailsPage extends ConsumerWidget {
  const BillDetailsPage({super.key, required this.billId});
  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final billsAsync = ref.watch(billsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? const <CategoryEntity>[];

    return billsAsync.when(
      loading:
          () => Scaffold(
            backgroundColor: colors.surface,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              title: const Text('Bill Details'),
              backgroundColor: colors.surface,
            ),
            body: const Shimmer(child: SkeletonDetailBody()),
          ),
      error:
          (e, _) => Scaffold(
            backgroundColor: colors.surface,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              title: const Text('Bill Details'),
              backgroundColor: colors.surface,
            ),
            body: ErrorDisplay(
              message: 'Could not load bill.',
              onRetry: () => ref.invalidate(billsProvider),
            ),
          ),
      data: (bills) {
        final billMap = {for (final b in bills) b.billId: b};
        final bill = billMap[billId];
        if (bill == null) {
          return Scaffold(
            backgroundColor: colors.surface,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              title: const Text('Bill Details'),
              backgroundColor: colors.surface,
            ),
            body: const ErrorDisplay(message: 'Bill not found.'),
          );
        }
        return _BillDetailContent(bill: bill, categories: categories);
      },
    );
  }
}

class _BillDetailContent extends StatelessWidget {
  const _BillDetailContent({required this.bill, required this.categories});

  final BillEntity bill;
  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final categoryName =
        categories
            .firstWhere(
              (c) => c.categoryId == bill.categoryId,
              orElse:
                  () => CategoryEntity(
                    categoryId: bill.categoryId,
                    name: bill.categoryId,
                  ),
            )
            .name;
    final isPaid = bill.isPaid;
    final statusColor = isPaid ? colors.success : colors.statusPending;
    final statusLabel = isPaid ? 'Paid' : 'Upcoming Bill';
    final amount = bill.amount;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: const Text('Bill Details'),
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
                          color: statusColor.withAlpha(22),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 24,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Crossfades when the bill is marked paid live.
                            AnimatedSwitcher(
                              duration: AppDurations.standard,
                              switchInCurve: AppEasing.easeOut,
                              switchOutCurve: AppEasing.accelerate,
                              child: Container(
                                key: ValueKey(isPaid),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(16),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        amount != null
                            ? CurrencyUtils.format(amount)
                            : 'Reminder',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color:
                              amount != null
                                  ? colors.textPrimary
                                  : colors.textSecondary,
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
                      _Row(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: categoryName,
                      ),
                      _Row(
                        icon: Icons.event_available_outlined,
                        label: 'Due Date',
                        value: DateFormatUtils.formatDate(bill.dueDate),
                      ),
                      _Row(
                        icon: Icons.repeat_rounded,
                        label: 'Recurring',
                        value: bill.isRecurring ? 'Yes — rolls monthly' : 'No',
                      ),
                      _Row(
                        icon: Icons.calendar_today_outlined,
                        label: 'Created',
                        value: DateFormatUtils.formatDate(bill.createdAt),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
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
