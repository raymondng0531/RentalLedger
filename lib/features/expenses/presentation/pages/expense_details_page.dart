import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/animated_balance.dart';
import '../../../../core/widgets/animated_status_badge.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/receipt_viewer.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../../../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../../members/domain/entities/house_member_entity.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_picker.dart';
import '../widgets/receipt_image.dart';

/// Expense Details screen — full view of a single expense.
///
/// Displays: receipt image, title, description, amount, category,
/// status timeline, payment source, approver info.
class ExpenseDetailsPage extends ConsumerWidget {
  const ExpenseDetailsPage({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));

    return expenseAsync.when(
      // Loading always carries a back button too — otherwise a slow stream
      // leaves the user stuck with no way back.
      loading:
          () => Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              title: const Text('Expense Details'),
              backgroundColor: Colors.white,
            ),
            body: const Shimmer(child: SkeletonDetailBody()),
          ),
      error:
          (error, _) => Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              title: const Text('Expense Details'),
              backgroundColor: Colors.white,
            ),
            body: ErrorDisplay(
              message: 'Could not load expense.',
              onRetry: () => ref.invalidate(expenseDetailProvider(expenseId)),
            ),
          ),
      data: (expense) {
        if (expense == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              title: const Text('Expense Details'),
              backgroundColor: Colors.white,
            ),
            body: const ErrorDisplay(message: 'Expense not found.'),
          );
        }
        return _ExpenseDetailContent(expense: expense, ref: ref);
      },
    );
  }
}

class _ExpenseDetailContent extends StatelessWidget {
  const _ExpenseDetailContent({required this.expense, required this.ref});

  final ExpenseEntity expense;
  final WidgetRef ref;

  /// Opens a full-screen dialog to view the receipt image.
  void _showReceiptFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ReceiptViewer(
              image: ReceiptImage(
                receiptUrl: url,
                fit: BoxFit.contain,
                loadingBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                errorBuilder:
                    (_) => const Center(
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

  /// Opens the edit dialog for the member's own pending expense.
  ///
  /// The submitter may fix the title, amount, description, category, or receipt
  /// before the Treasurer reviews it. Rejected/approved/paid expenses are not
  /// editable.
  void _showEditDialog(BuildContext context, ExpenseEntity expense) {
    final categories =
        ref.read(categoriesProvider).value ?? const <CategoryEntity>[];
    showDialog<void>(
      context: context,
      builder: (_) => _EditExpenseDialog(
        expense: expense,
        categories: categories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Resolve the raw category id to its name/colour/icon for display.
    final categoriesAsync = ref.watch(categoriesProvider);
    final category = categoriesAsync.value?.firstWhere(
      (c) => c.categoryId == expense.categoryId,
      orElse:
          () => CategoryEntity(
            categoryId: expense.categoryId,
            name: expense.categoryId,
          ),
    );
    final categoryName = category?.name ?? expense.categoryId;
    final categoryColor = Color(category?.color ?? 0xFF00897B);

    // Always resolve the purchaser's display name — never show a UID.
    // Use a map lookup (not firstWhere + orElse) so we don't construct a
    // HouseMemberEntity where the stream actually holds HouseMemberModels.
    final members =
        ref.watch(membersStreamProvider).value ?? const <HouseMemberEntity>[];
    final memberByName = {for (final m in members) m.userId: m};
    final purchaserName =
        memberByName[expense.purchasedBy]?.displayName ??
        expense.displayName ??
        'Unknown Member';

    // Only the purchaser can edit/delete their own pending expense (matches
    // the Firestore rules).
    final currentUser = ref.watch(currentUserProvider);
    final canEdit =
        expense.isEditable && expense.purchasedBy == currentUser?.uid;
    final canDelete =
        expense.isDeletable && expense.purchasedBy == currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: const Text('Expense Details'),
        backgroundColor: Colors.white,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(context, expense),
              tooltip: 'Edit',
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, expense),
              tooltip: 'Delete',
              color: AppTheme.errorRed,
            ),
        ],
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800).
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card: icon + title + status + amount ──
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: AppTheme.backgroundLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: categoryColor.withAlpha(22),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              categoryIcon(expense.categoryId),
                              size: 24,
                              color: categoryColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              expense.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedStatusBadge(
                            status: expense.status,
                            size: StatusBadgeSize.medium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedBalance(
                        balance: expense.amount,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Purchased by $purchaserName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Receipt image ──
              if (expense.receiptUrl != null &&
                  expense.receiptUrl!.isNotEmpty) ...[
                Text(
                  'Receipt',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  // onTap (not a wrapping GestureDetector) so the web HTML
                  // <img> platform view can forward its DOM click here too.
                  child: ReceiptImage(
                    receiptUrl: expense.receiptUrl!,
                    height: 200,
                    width: double.infinity,
                    onTap: () =>
                        _showReceiptFullscreen(context, expense.receiptUrl!),
                    loadingBuilder: (_) => Container(
                      height: 200,
                      color: Colors.grey.withAlpha(20),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorBuilder: (_) => Container(
                      height: 200,
                      color: Colors.grey.withAlpha(20),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Receipt unavailable',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Explicit affordance: the web platform-view slot can swallow
                // taps over the image, so offer an obvious button as well.
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showReceiptFullscreen(context, expense.receiptUrl!),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                    label: const Text('Preview Receipt'),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Details card ──
              _buildInfoSection(context, [
                _InfoRow(
                  label: 'Category',
                  value: categoryName,
                  icon: Icons.category_outlined,
                ),
                _InfoRow(
                  label: 'Payment Source',
                  value:
                      expense.isPersonal
                          ? 'Personal (reimbursement)'
                          : 'Central Account',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _InfoRow(
                  label: 'Submitted',
                  value: DateFormatUtils.formatDate(expense.createdAt),
                  icon: Icons.calendar_today_outlined,
                ),
                _InfoRow(
                  label: 'Purchased By',
                  value: purchaserName,
                  icon: Icons.person_outlined,
                ),
              ]),

              // ── Reject reason (shown when rejected) ──
              if (expense.isRejected &&
                  expense.rejectReason != null &&
                  expense.rejectReason!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorRed.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppTheme.errorRed,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rejected',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${expense.rejectReason}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Description ──
              if (expense.description != null &&
                  expense.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  expense.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],

              // ── Timeline ──
              const SizedBox(height: 24),
              Text(
                'Timeline',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildTimeline(context),

              // ── Treasurer Actions ──
              if (expense.isPending || expense.isApproved) ...[
                const SizedBox(height: 32),
                _buildTreasurerActions(context, expense),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreasurerActions(BuildContext context, ExpenseEntity expense) {
    // Role check: only the Treasurer can approve/reject/mark paid.
    final house = ref.watch(currentHouseProvider);
    final user = ref.watch(currentUserProvider);
    final isTreasurer =
        house != null && user != null && house.treasurerId == user.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Treasurer: approve / reject / mark paid ──
        if (isTreasurer) ...[
          Text(
            'Treasurer Actions',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Pending → Approve or Reject
          if (expense.isPending) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, expense),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _doApprove(context, expense.expenseId),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],

          // Approved → Mark Paid
          if (expense.isApproved) ...[
            FilledButton.icon(
              onPressed:
                  () => _confirmAction(
                    context,
                    'Mark as Paid',
                    'Mark "${expense.title}" as reimbursed from the Central Account?',
                    () => _doMarkPaid(context, expense.expenseId),
                  ),
              icon: const Icon(Icons.wallet_outlined),
              label: const Text('Mark as Paid'),
            ),
          ],
        ] else if (user != null && expense.purchasedBy == user.uid) ...[
          // ── Submitter only: nudge the Treasurer to reimburse ──
          // The button is hidden for everyone else (other members AND the
          // Treasurer); the action itself re-checks the permission below.
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _remindTreasurer(context, expense),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Remind Treasurer'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  /// Sends a reimbursement reminder notification to the Treasurer.
  ///
  /// Only the expense submitter may send it (defense-in-depth: the button is
  /// hidden for everyone else, but the action re-checks too). The recipient is
  /// the Treasurer's Firebase UID, resolved from member data with the house
  /// document as a fallback — never a display name — and the submitter is
  /// skipped so no one reminds themselves.
  Future<void> _remindTreasurer(
    BuildContext context,
    ExpenseEntity expense,
  ) async {
    final house = ref.read(currentHouseProvider);
    final user = ref.read(currentUserProvider);
    if (house == null || user == null) return;

    // Permission guard: only the expense submitter can remind the Treasurer.
    if (expense.purchasedBy != user.uid) {
      if (context.mounted) {
        SnackbarUtils.showError(
          context,
          'Only the submitter can remind the Treasurer.',
        );
      }
      return;
    }

    // Trace the Treasurer from house member data (authoritative), falling back
    // to the house document for houses created before member roles existed.
    final members =
        ref.read(membersStreamProvider).value ?? const <HouseMemberEntity>[];
    var treasurerId = '';
    for (final member in members) {
      if (member.role == FirestoreConstants.roleTreasurer) {
        treasurerId = member.userId;
        break;
      }
    }
    if (treasurerId.isEmpty) treasurerId = house.treasurerId;

    if (treasurerId.isEmpty) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Could not find the Treasurer.');
      }
      return;
    }
    // Never remind yourself.
    if (treasurerId == user.uid) return;

    // Resolve the submitter's display name for the notification body.
    final memberByName = {for (final m in members) m.userId: m};
    final submitterName =
        memberByName[expense.purchasedBy]?.displayName ??
        expense.displayName ??
        user.displayName;

    await NotificationRemoteDataSource().createNotification(
      userId: treasurerId,
      title: 'Reimbursement Reminder',
      body: '"$submitterName" reminded you about the expense "${expense.title}".',
      type: FirestoreConstants.notificationReminder,
      relatedId: expense.expenseId,
    );

    if (context.mounted) {
      SnackbarUtils.showSuccess(context, 'Reminder sent to Treasurer');
    }
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onConfirm();
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  /// Confirms with the member, then deletes their own Pending expense and
  /// returns to the previous screen.
  ///
  /// Cancellation leaves the expense untouched. The action itself re-checks
  /// ownership + status (the button is already gated to the owner of a pending
  /// expense; the provider and Firestore rule enforce it independently).
  Future<void> _confirmDelete(
    BuildContext context,
    ExpenseEntity expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${expense.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return; // cancelled — keep the expense.

    final error = await ref
        .read(deleteExpenseProvider.notifier)
        .delete(expense);
    if (!context.mounted) return;
    if (error != null) {
      SnackbarUtils.showError(context, error);
    } else {
      SnackbarUtils.showSuccess(context, 'Expense deleted');
      Navigator.of(context).pop();
    }
  }

  Future<void> _doApprove(BuildContext context, String expenseId) async {
    final error = await ref
        .read(approveExpenseProvider.notifier)
        .approve(expenseId);
    if (error != null && context.mounted) {
      SnackbarUtils.showError(context, error);
    }
  }

  Future<void> _doReject(
    BuildContext context,
    String expenseId, {
    String? reason,
  }) async {
    final error = await ref
        .read(rejectExpenseProvider.notifier)
        .reject(expenseId, reason: reason);
    if (error != null && context.mounted) {
      SnackbarUtils.showError(context, error);
    }
  }

  /// Shows the reject dialog with an optional reason field.
  void _showRejectDialog(BuildContext context, ExpenseEntity expense) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reject Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Reject "${expense.title}"?'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText:
                        'e.g. Receipt is blurry, please upload a clearer one.',
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _doReject(
                    context,
                    expense.expenseId,
                    reason:
                        reasonController.text.trim().isEmpty
                            ? null
                            : reasonController.text.trim(),
                  );
                },
                child: const Text('Reject'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _doMarkPaid(BuildContext context, String expenseId) async {
    final error = await ref.read(markPaidProvider.notifier).markPaid(expenseId);
    if (error != null && context.mounted) {
      SnackbarUtils.showError(context, error);
    }
  }

  Widget _buildInfoSection(BuildContext context, List<_InfoRow> rows) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          children:
              rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            row.icon,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            row.label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          const Spacer(),
                          Text(
                            row.value,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final theme = Theme.of(context);
    // Always show the complete workflow. The Paid step is hidden only
    // when the expense was rejected.
    final steps = <_TimelineStep>[
      // Step 1: Submitted — always present and complete.
      _TimelineStep(
        title: 'Submitted',
        subtitle: DateFormatUtils.formatDateTime(expense.createdAt),
        isComplete: true,
        isLast: false,
      ),
      if (expense.isRejected)
        // Rejected → ends here, no Paid step.
        _TimelineStep(
          title: 'Rejected',
          subtitle:
              expense.approvedAt != null
                  ? DateFormatUtils.formatDateTime(expense.approvedAt!)
                  : 'Rejected',
          isComplete: true,
          isLast: true,
          isError: true,
        )
      else ...[
        // Step 2: Approved.
        _TimelineStep(
          title: 'Approved',
          subtitle:
              expense.approvedAt != null
                  ? DateFormatUtils.formatDateTime(expense.approvedAt!)
                  : 'Waiting...',
          isComplete: expense.isApproved || expense.isPaid,
          isLast: false,
        ),
        // Step 3: Paid.
        _TimelineStep(
          title: 'Paid',
          subtitle:
              expense.paidAt != null
                  ? DateFormatUtils.formatDateTime(expense.paidAt!)
                  : 'Waiting...',
          isComplete: expense.isPaid,
          isLast: true,
        ),
      ],
    ];

    // The timeline is a historical record — it updates instantly with no
    // animation (the status badge handles the animated transition).
    return Column(
      children:
          steps.map((step) {
            final color =
                step.isError
                    ? AppTheme.errorRed
                    : step.isComplete
                    ? AppTheme.successGreen
                    : AppTheme.textHint;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Timeline line ──
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!step.isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: color.withAlpha(80),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Step content ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color:
                                  step.isComplete || step.isError
                                      ? color
                                      : AppTheme.textHint,
                            ),
                          ),
                          Text(
                            step.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

/// Dialog to edit the member's own pending expense.
///
/// Lets the submitter fix the title, amount, description, category, and receipt
/// (take photo / choose photo / replace / remove) before the Treasurer reviews
/// it. Payment source is intentionally locked — it cannot be changed after
/// submission. Only pending expenses are editable; rejected/approved/paid stay
/// immutable.
class _EditExpenseDialog extends ConsumerStatefulWidget {
  const _EditExpenseDialog({
    required this.expense,
    required this.categories,
  });

  final ExpenseEntity expense;
  final List<CategoryEntity> categories;

  @override
  ConsumerState<_EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends ConsumerState<_EditExpenseDialog> {
  final _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late String _selectedCategory;

  /// A newly-picked receipt (uploaded on save, replacing the current one).
  ///
  /// XFile is cross-platform: on native it wraps the file path, on web the
  /// picker returns a blob URL. (File(picked.path) throws on web.)
  XFile? _newReceiptFile;
  bool _removeReceipt = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _titleController = TextEditingController(text: expense.title);
    _amountController = TextEditingController(
      text: expense.amount.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: expense.description ?? '',
    );
    _selectedCategory = expense.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _newReceiptFile = picked;
          _removeReceipt = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(
        context,
        'Could not pick a photo. Please try again.',
      );
    }
  }

  /// Opens a full-screen viewer for a resolved receipt image.
  void _showReceiptFullscreen(Widget image) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReceiptViewer(image: image)),
    );
  }

  /// Live preview of the newly-picked receipt (web-safe: blob URL on web,
  /// local file on native) so the member can confirm before saving.
  Widget _buildNewReceiptPreview() {
    final file = _newReceiptFile!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: GestureDetector(
        onTap: () => _showReceiptFullscreen(
          kIsWeb
              ? Image.network(
                  file.path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 48),
                )
              : Image.file(
                  File(file.path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 48),
                ),
        ),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: kIsWeb
              ? Image.network(
                  file.path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey),
                )
              : Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey),
                ),
        ),
      ),
    );
  }

  /// Opens the currently-attached (stored) receipt in the full-screen viewer,
  /// fitted to show the whole receipt. Shared by the preview tap and the
  /// explicit "Preview Receipt" button.
  void _openCurrentReceiptFullscreen() {
    final url = widget.expense.receiptUrl;
    if (url == null || url.isEmpty) return;
    _showReceiptFullscreen(ReceiptImage(receiptUrl: url, fit: BoxFit.contain));
  }

  /// Shows the currently-attached receipt so the member can view it before
  /// deciding to replace or remove it.
  Widget _buildCurrentReceiptPreview() {
    final url = widget.expense.receiptUrl!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        // onTap (not a wrapping GestureDetector) so the web HTML <img>
        // platform view can forward its DOM click here too.
        child: ReceiptImage(
          receiptUrl: url,
          fit: BoxFit.cover,
          onTap: _openCurrentReceiptFullscreen,
          loadingBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_) => const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    try {
      final expense = widget.expense;

      // Resolve the effective receipt: a newly-picked one replaces the current
      // (uploaded on save); an explicit remove clears it.
      String? receiptUrl = expense.receiptUrl;
      if (_newReceiptFile != null) {
        final house = ref.read(currentHouseProvider);
        if (house != null) {
          receiptUrl = await ref
              .read(expenseDataSourceProvider)
              .uploadReceipt(
                  houseId: house.houseId, filePath: _newReceiptFile!.path);
        }
      } else if (_removeReceipt) {
        receiptUrl = null;
      }

      final description = _descriptionController.text.trim();
      final updated = _buildUpdatedExpense(
        expense,
        title: title,
        amount: amount,
        description: description.isEmpty ? null : description,
        categoryId: _selectedCategory,
        receiptUrl: receiptUrl,
      );

      final repo = ref.read(expenseRepositoryProvider);
      await repo.updateExpense(updated);

      ref.invalidate(expenseDetailProvider(expense.expenseId));
      ref.invalidate(expenseListProvider);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackbarUtils.showError(context, 'Could not update. Please try again.');
    }
  }

  /// Builds the receipt picker row and its current state line.
  Widget _buildReceiptSection(BuildContext context) {
    final expense = widget.expense;
    final hasCurrent =
        expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty;
    final showingNew = _newReceiptFile != null;
    final theme = Theme.of(context);

    // Status line describing the effective outcome.
    final (IconData, Color, String) status;
    if (showingNew) {
      status = (
        Icons.check_circle_outline,
        AppTheme.successGreen,
        'New receipt selected — will replace the current one on save.',
      );
    } else if (_removeReceipt) {
      status = (
        Icons.delete_outline,
        AppTheme.errorRed,
        'Receipt will be removed on save.',
      );
    } else if (hasCurrent) {
      status = (
        Icons.image_outlined,
        AppTheme.textSecondary,
        'Current receipt attached.',
      );
    } else {
      status = (
        Icons.image_not_supported_outlined,
        AppTheme.textSecondary,
        'No receipt attached.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(status.$1, size: 18, color: status.$2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(status.$3, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
        // Live preview so the member can visually confirm the receipt:
        // the newly-picked one when selected, otherwise the current one.
        if (showingNew) ...[
          const SizedBox(height: 10),
          _buildNewReceiptPreview(),
        ] else if (hasCurrent && !_removeReceipt) ...[
          const SizedBox(height: 10),
          _buildCurrentReceiptPreview(),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose Photo'),
              ),
            ),
          ],
        ),
        if ((hasCurrent || showingNew) && !_removeReceipt) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              // Preview the CURRENT stored receipt (the new one, when picked,
              // is previewed by tapping its thumbnail above). Explicit button:
              // the web platform-view slot can swallow taps over the image, so
              // the action must be obvious and not rely on the HTML tap alone.
              if (hasCurrent) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCurrentReceiptFullscreen,
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                    label: const Text('Preview Receipt'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _removeReceipt = true;
                    _newReceiptFile = null;
                  }),
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.errorRed,
                  ),
                  label: const Text(
                    'Remove receipt',
                    style: TextStyle(color: AppTheme.errorRed),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Edit Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (RM)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.categories.isNotEmpty)
              CategoryPicker(
                categories: widget.categories,
                selectedId: _selectedCategory,
                onSelected: (id) => setState(() => _selectedCategory = id),
              )
            else
              Text('No categories available.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Text(
              'Receipt',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildReceiptSection(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child:
              _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
        ),
      ],
    );
  }
}

/// Reconstructs an [ExpenseEntity] with the member-editable fields applied.
///
/// Built explicitly (rather than [ExpenseEntity.copyWith]) so that cleared
/// fields can be written as null — `copyWith`'s `?? this.x` fallbacks cannot
/// null a field, but the datasource uses `FieldValue.delete()` on null to
/// clear it. Payment source, status, and the approval trail are carried over
/// untouched.
ExpenseEntity _buildUpdatedExpense(
  ExpenseEntity expense, {
  required String title,
  required double amount,
  required String? description,
  required String categoryId,
  required String? receiptUrl,
}) {
  return ExpenseEntity(
    expenseId: expense.expenseId,
    houseId: expense.houseId,
    purchasedBy: expense.purchasedBy,
    approvedBy: expense.approvedBy,
    reimbursedBy: expense.reimbursedBy,
    title: title,
    description: description,
    categoryId: categoryId,
    amount: amount,
    receiptUrl: receiptUrl,
    paymentSource: expense.paymentSource,
    status: expense.status,
    rejectReason: expense.rejectReason,
    createdAt: expense.createdAt,
    approvedAt: expense.approvedAt,
    paidAt: expense.paidAt,
    updatedAt: expense.updatedAt,
    displayName: expense.displayName,
  );
}

class _InfoRow {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
}

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    this.isLast = false,
    this.isError = false,
  });
  final String title;
  final String subtitle;
  final bool isComplete;
  final bool isLast;
  final bool isError;
}
