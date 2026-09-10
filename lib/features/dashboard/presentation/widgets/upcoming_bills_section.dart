import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/implicit_animated_list.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../../../../features/expenses/domain/entities/bill_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart';
import '../../../../features/expenses/presentation/widgets/bill_mark_paid_sheet.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';

/// Upcoming Bills — the house's recurring/due bills, newest-first, with the
/// Treasurer's Add Bill/Edit/Delete/Mark Paid controls and members' Remind
/// Treasurer. Self-contained: it watches its own realtime bill stream, so it
/// stays independently renderable and reorderable on the Dashboard.
class UpcomingBillsSection extends ConsumerWidget {
  const UpcomingBillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final billsAsync = ref.watch(billsProvider);
    final house = ref.watch(currentHouseProvider);
    final user = ref.watch(currentUserProvider);
    final isTreasurer =
        house != null && user != null && house.treasurerId == user.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.spacingLg,
            AppConstants.pagePadding,
            AppConstants.spacingSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Upcoming Bills',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Only the Treasurer can add bills.
              if (isTreasurer)
                TextButton.icon(
                  onPressed: () => _showAddBillDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Bill'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        billsAsync.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          error:
              (_, __) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.pagePadding,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Could not load bills. Pull to refresh.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          data: (bills) {
            // Only show unpaid bills.
            final unpaid = bills.where((b) => !b.isPaid).toList();

            if (unpaid.isEmpty) {
              return AnimatedSwitcher(
                duration: AppDurations.standard,
                child: Card(
                  key: const ValueKey('no-bills'),
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppConstants.pagePadding,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.event_repeat_outlined,
                      color: AppTheme.textHint,
                    ),
                    title: const Text('No upcoming bills'),
                    subtitle: const Text(
                      'Add recurring bills to track them here.',
                    ),
                    trailing: const Icon(
                      Icons.add,
                      color: AppTheme.primaryGreen,
                    ),
                    onTap: () => _showAddBillDialog(context, ref),
                  ),
                ),
              );
            }

            return AnimatedSwitcher(
              duration: AppDurations.standard,
              child: ImplicitAnimatedList<BillEntity>(
                key: const ValueKey('bills-list'),
                items: unpaid,
                itemKey: (bill) => bill.billId,
                initialStagger: AppDurations.stagger,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemBuilder: (context, bill) {
                  // Countdown colors: green >7d, orange 3-7d, red due/overdue.
                  final urgency = bill.urgency;
                  final dueColor = switch (urgency) {
                    BillUrgency.red => AppTheme.errorRed,
                    BillUrgency.orange => AppTheme.statusPending,
                    BillUrgency.green => AppTheme.successGreen,
                  };
                  final isPaid = bill.isPaid;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppConstants.pagePadding,
                      vertical: 3,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top row: icon, title, amount ──
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: dueColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  bill.isOverdue
                                      ? Icons.error_outline_rounded
                                      : bill.isDueToday
                                      ? Icons.schedule_rounded
                                      : Icons.event_repeat_outlined,
                                  size: 18,
                                  color: dueColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            bill.title,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (bill.isRecurring) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.repeat_rounded,
                                            size: 14,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      bill.countdownLabel,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: dueColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                bill.hasAmount
                                    ? CurrencyUtils.format(bill.amount!)
                                    : 'Reminder',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      bill.hasAmount
                                          ? null
                                          : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // ── Due date + reminder status + treasurer actions ──
                          Padding(
                            padding: const EdgeInsets.only(left: 48),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Due ${DateFormatUtils.formatDateShort(bill.dueDate)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppTheme.textSecondary,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (bill.reminderEnabled) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.notifications_active_outlined,
                                          size: 14,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Treasurer-only: edit + delete.
                                if (isTreasurer) ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppTheme.textSecondary,
                                    ),
                                    onPressed:
                                        () => _showEditBillDialog(
                                          context,
                                          ref,
                                          bill,
                                        ),
                                    tooltip: 'Edit bill',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppTheme.errorRed,
                                    ),
                                    onPressed:
                                        () => _confirmDeleteBill(
                                          context,
                                          ref,
                                          bill,
                                        ),
                                    tooltip: 'Delete bill',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Action buttons ──
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      () => _toggleReminder(context, ref, bill),
                                  icon: Icon(
                                    bill.reminderEnabled
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_none_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    bill.reminderEnabled
                                        ? 'Reminder On'
                                        : 'Set Reminder',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Treasurer → Mark Paid; Member → Remind Treasurer.
                              Expanded(
                                child:
                                    isTreasurer
                                        ? FilledButton.icon(
                                          onPressed:
                                              isPaid
                                                  ? null
                                                  : () => _markBillPaid(
                                                    context,
                                                    ref,
                                                    bill,
                                                  ),
                                          icon: const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            isPaid ? 'Paid' : 'Mark Paid',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        )
                                        : OutlinedButton.icon(
                                          onPressed:
                                              () => _remindTreasurer(
                                                context,
                                                ref,
                                                bill,
                                              ),
                                          icon: const Icon(
                                            Icons.notifications_active_outlined,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Remind Treasurer',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    BillEntity bill,
  ) async {
    await ref.read(billActionsProvider.notifier).toggleReminder(bill);
  }

  /// Sends a payment reminder notification to the Treasurer.
  Future<void> _remindTreasurer(
    BuildContext context,
    WidgetRef ref,
    BillEntity bill,
  ) async {
    await ref.read(billActionsProvider.notifier).remindTreasurer(bill);
    if (context.mounted) {
      SnackbarUtils.showSuccess(context, 'Reminder sent to Treasurer');
    }
  }

  Future<void> _markBillPaid(
    BuildContext context,
    WidgetRef ref,
    BillEntity bill,
  ) async {
    if (bill.hasAmount) {
      // An amount-bearing bill payment moves real money out of the Central
      // Account (one Direct Payment transaction per paid month) → require that
      // month's receipt/proof via the Mark Paid sheet.
      final paid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => BillMarkPaidSheet(bill: bill),
      );
      if (paid == true && context.mounted) {
        SnackbarUtils.showSuccess(context, 'Bill marked as paid');
      }
      return;
    }

    // A bill without an amount records no transaction — the plain confirm is
    // enough.
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Mark "${bill.title}" as paid?'),
            content: Text(
              bill.isRecurring
                  ? 'This will roll the bill to next month.'
                  : 'This bill will be marked as paid.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Mark Paid'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(billActionsProvider.notifier).markPaid(bill);
        if (context.mounted) {
          SnackbarUtils.showSuccess(context, 'Bill marked as paid');
        }
      } on Failure catch (e) {
        // Surfaces the refusal as-is: "already marked paid" (a second tap) and
        // "insufficient balance" both need to reach the Treasurer rather than
        // failing silently.
        if (context.mounted) SnackbarUtils.showError(context, e.message);
      } catch (_) {
        if (context.mounted) {
          SnackbarUtils.showError(
            context,
            'Could not mark the bill as paid. Please try again.',
          );
        }
      }
    }
  }

  /// Confirms and deletes a bill.
  Future<void> _confirmDeleteBill(
    BuildContext context,
    WidgetRef ref,
    BillEntity bill,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Bill?'),
            content: Text(bill.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(billActionsProvider.notifier).deleteBill(bill.billId);
      if (context.mounted) {
        SnackbarUtils.showSuccess(context, 'Bill deleted');
      }
    }
  }

  /// Opens the Add/Edit bill dialog, pre-filled when editing.
  void _showEditBillDialog(
    BuildContext context,
    WidgetRef ref,
    BillEntity bill,
  ) {
    final titleController = TextEditingController(text: bill.title);
    final amountController = TextEditingController(
      text: bill.amount?.toStringAsFixed(2) ?? '',
    );
    DateTime dueDate = bill.dueDate;
    bool isRecurring = bill.isRecurring;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Bill'),
            content: StatefulBuilder(
              builder:
                  (ctx, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Bill name',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (RM) — optional',
                          hintText: 'Leave blank for reminder only',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (picked != null) setState(() => dueDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Due: ${DateFormatUtils.formatDate(dueDate)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isRecurring,
                        onChanged: (v) => setState(() => isRecurring = v),
                        title: const Text(
                          'Repeat every month',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Auto-create the next bill each month',
                          style: TextStyle(fontSize: 12),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) return;
                  final amount = double.tryParse(amountController.text);
                  Navigator.pop(ctx);
                  await ref
                      .read(billActionsProvider.notifier)
                      .updateBill(
                        bill.billId,
                        title: titleController.text,
                        amount: amount != null && amount > 0 ? amount : null,
                        dueDate: dueDate,
                        isRecurring: isRecurring,
                      );
                  if (context.mounted) {
                    SnackbarUtils.showSuccess(context, 'Bill updated');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showAddBillDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    bool isRecurring = false;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Add Bill'),
            content: StatefulBuilder(
              builder:
                  (ctx, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Bill name',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      // Amount is optional — can act as a reminder only.
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (RM) — optional',
                          hintText: 'Leave blank for reminder only',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Calendar date picker for due date.
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (picked != null) {
                            setState(() => dueDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Due: ${DateFormatUtils.formatDate(dueDate)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Recurring toggle ──
                      SwitchListTile(
                        value: isRecurring,
                        onChanged: (v) => setState(() => isRecurring = v),
                        title: const Text(
                          'Repeat every month',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Auto-create the next bill each month',
                          style: TextStyle(fontSize: 12),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) return;
                  final amount = double.tryParse(amountController.text);
                  Navigator.pop(ctx);
                  await ref
                      .read(createBillProvider.notifier)
                      .createBill(
                        title: titleController.text,
                        amount: amount != null && amount > 0 ? amount : null,
                        dueDate: dueDate,
                        isRecurring: isRecurring,
                      );
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }
}
