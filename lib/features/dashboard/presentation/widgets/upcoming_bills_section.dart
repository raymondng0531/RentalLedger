import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/implicit_animated_list.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../../../../features/expenses/domain/entities/bill_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart';
import '../../../../features/expenses/presentation/widgets/bill_mark_paid_sheet.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Upcoming Bills — the house's recurring/due bills, newest-first, with the
/// Treasurer's Add Bill/Edit/Delete/Mark Paid controls and members' Remind
/// Treasurer. Self-contained: it watches its own realtime bill stream, so it
/// stays independently renderable and reorderable on the Dashboard.
class UpcomingBillsSection extends ConsumerWidget {
  const UpcomingBillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
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
                  l10n.billUpcomingBills,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Always offered: this section shows unpaid bills only, so the
              // route to every bill — settled ones included — must not depend
              // on there being anything left to show here.
              TextButton(
                onPressed: () => context.push(RouteNames.billHistory),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(l10n.actionSeeAll),
              ),
              // Only the Treasurer can add bills.
              if (isTreasurer)
                TextButton.icon(
                  onPressed: () => _showAddBillDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.billAdd),
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
                    Icon(Icons.error_outline, size: 18, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.billListLoadFailed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
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
                    leading: Icon(
                      Icons.event_repeat_outlined,
                      color: colors.textHint,
                    ),
                    title: Text(l10n.billNoneUpcoming),
                    subtitle: Text(l10n.billNoneUpcomingHint),
                    trailing: Icon(Icons.add, color: colors.primary),
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
                  final l10n = AppLocalizations.of(context);
                  // Countdown colors: green >7d, orange 3-7d, red due/overdue.
                  final urgency = bill.urgency;
                  final dueColor = switch (urgency) {
                    BillUrgency.red => colors.error,
                    BillUrgency.orange => colors.statusPending,
                    BillUrgency.green => colors.success,
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
                                          Icon(
                                            Icons.repeat_rounded,
                                            size: 14,
                                            color: colors.primary,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      bill.countdownLabel(l10n),
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
                                    ? CurrencyUtils.format(bill.amount!, localeCode: l10n.localeName)
                                    : l10n.billReminderOnly,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: bill.hasAmount
                                      ? null
                                      : colors.textSecondary,
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
                                          l10n.billDueOn(
                                            DateFormatUtils.formatDateShort(
                                              bill.dueDate,
                                              l10n.localeName,
                                            ),
                                          ),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colors.textSecondary,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (bill.reminderEnabled) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.notifications_active_outlined,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Treasurer-only: edit + delete.
                                if (isTreasurer) ...[
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: colors.textSecondary,
                                    ),
                                    onPressed:
                                        () => _showEditBillDialog(
                                          context,
                                          ref,
                                          bill,
                                        ),
                                    tooltip: l10n.billEditTooltip,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: colors.error,
                                    ),
                                    onPressed:
                                        () => _confirmDeleteBill(
                                          context,
                                          ref,
                                          bill,
                                        ),
                                    tooltip: l10n.billDeleteTooltip,
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
                                        ? l10n.billReminderOn
                                        : l10n.billSetReminder,
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
                                            isPaid
                                                ? l10n.statusPaid
                                                : l10n.billMarkPaid,
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
                                          label: Text(
                                            l10n.actionRemindTreasurer,
                                            style: const TextStyle(fontSize: 12),
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
      SnackbarUtils.showSuccess(
        context,
        AppLocalizations.of(context).actionReminderSent,
      );
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
      final colors = context.colors;
      final paid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        // `surfaceElevated` — the palette's documented role for sheets and
        // dialogs, and the exact opaque white V1.0 shipped in light mode.
        backgroundColor: colors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => BillMarkPaidSheet(bill: bill),
      );
      if (paid == true && context.mounted) {
        SnackbarUtils.showSuccess(
          context,
          AppLocalizations.of(context).billMarkedPaid,
        );
      }
      return;
    }

    // A bill without an amount records no transaction — the plain confirm is
    // enough.
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              AppLocalizations.of(ctx).billMarkPaidConfirm(bill.title),
            ),
            content: Text(
              bill.isRecurring
                  ? AppLocalizations.of(ctx).billRollNextMonth
                  : AppLocalizations.of(ctx).billWillBeMarkedPaid,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(ctx).actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(ctx).billMarkPaid),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(billActionsProvider.notifier).markPaid(bill);
        if (context.mounted) {
          SnackbarUtils.showSuccess(
            context,
            AppLocalizations.of(context).billMarkedPaid,
          );
        }
      } on Failure catch (e) {
        // Surfaces the refusal as-is: "already marked paid" (a second tap) and
        // "insufficient balance" both need to reach the Treasurer rather than
        // failing silently.
        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          SnackbarUtils.showError(context, FailureMessages.of(e, l10n));
        }
      } catch (_) {
        if (context.mounted) {
          SnackbarUtils.showError(
            context,
            AppLocalizations.of(context).billMarkPaidFailed,
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
            title: Text(AppLocalizations.of(ctx).billDeleteTitle),
            content: Text(bill.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(ctx).actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                // A destructive confirm: the error accent, not the brand teal.
                // The dark palette lightens it, and the button's inherited
                // `onPrimary` ink stays legible on it (~6:1).
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                ),
                child: Text(AppLocalizations.of(ctx).actionDelete),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(billActionsProvider.notifier).deleteBill(bill.billId);
      if (context.mounted) {
        SnackbarUtils.showSuccess(
          context,
          AppLocalizations.of(context).billDeleted,
        );
      }
    }
  }

  /// Opens the Add/Edit bill dialog, pre-filled when editing.
  void _showEditBillDialog(
    BuildContext context,
    WidgetRef ref,
    BillEntity bill,
  ) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
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
            title: Text(l10n.billEditTitle),
            content: StatefulBuilder(
              builder:
                  (ctx, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: l10n.billName,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: l10n.billAmountRmOptional,
                          hintText: l10n.billAmountHint,
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
                            // Was `Colors.grey.withAlpha(20)` — the palette's
                            // placeholder tint is that same grey in light mode.
                            color: colors.placeholderTint.withAlpha(20),
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
                                l10n.billDueDateLabel(
                                  DateFormatUtils.formatDate(
                                    dueDate,
                                    l10n.localeName,
                                  ),
                                ),
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
                        title: Text(
                          l10n.billRepeatMonthly,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          l10n.billRepeatMonthlyHint,
                          style: const TextStyle(fontSize: 12),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: colors.primary,
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(ctx).actionCancel),
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
                    SnackbarUtils.showSuccess(
                      context,
                      AppLocalizations.of(context).billUpdated,
                    );
                  }
                },
                child: Text(AppLocalizations.of(ctx).actionSave),
              ),
            ],
          ),
    );
  }

  void _showAddBillDialog(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    bool isRecurring = false;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.billAdd),
            content: StatefulBuilder(
              builder:
                  (ctx, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: l10n.billName,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      // Amount is optional — can act as a reminder only.
                      TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: l10n.billAmountRmOptional,
                          hintText: l10n.billAmountHint,
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
                            // Was `Colors.grey.withAlpha(20)` — the palette's
                            // placeholder tint is that same grey in light mode.
                            color: colors.placeholderTint.withAlpha(20),
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
                                l10n.billDueDateLabel(
                                  DateFormatUtils.formatDate(
                                    dueDate,
                                    l10n.localeName,
                                  ),
                                ),
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
                        title: Text(
                          l10n.billRepeatMonthly,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          l10n.billRepeatMonthlyHint,
                          style: const TextStyle(fontSize: 12),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: colors.primary,
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(ctx).actionCancel),
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
                child: Text(AppLocalizations.of(ctx).actionAdd),
              ),
            ],
          ),
    );
  }
}
