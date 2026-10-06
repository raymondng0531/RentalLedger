import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/receipt_viewer.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../members/domain/entities/house_member_entity.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../../domain/entities/deposit_request_entity.dart';
import '../providers/expense_provider.dart';
import '../widgets/receipt_image.dart';

/// Deposit Request Details — a member's submitted deposit, as the Treasurer
/// reviews it (Approve / Reject) or the submitter tracks it (Cancel while
/// Pending).
///
/// Realtime: the page follows the request document, so an approval from
/// another device flips the status here immediately, and a cancelled request
/// shows the "no longer exists" state rather than stale data.
class DepositRequestDetailsPage extends ConsumerWidget {
  const DepositRequestDetailsPage({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final requestAsync = ref.watch(depositRequestDetailProvider(requestId));

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.depositRequestTitle),
        backgroundColor: colors.surface,
      ),
      body: requestAsync.when(
        loading: () => const LoadingIndicator(),
        error: (_, __) => ErrorDisplay(message: l10n.errorLoadFailed),
        data: (request) => request == null
            ? ErrorDisplay(message: l10n.errorRecordMissing)
            : _DepositRequestContent(request: request),
      ),
    );
  }
}

class _DepositRequestContent extends ConsumerWidget {
  const _DepositRequestContent({required this.request});

  final DepositRequestEntity request;

  void _openReceipt(BuildContext context, String url) {
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptViewer(
          title: l10n.labelReceiptProof,
          image: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            // White on ReceiptViewer's fixed black ground — not themed, same
            // as the transaction details page.
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                l10n.errorFailedToLoadReceipt,
                style: const TextStyle(color: Colors.white54),
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

    final house = ref.watch(currentHouseProvider);
    final user = ref.watch(currentUserProvider);
    final isTreasurer =
        house != null && user != null && house.treasurerId == user.uid;
    final isSubmitter = user != null && user.uid == request.submittedBy;
    final reviewState = ref.watch(reviewDepositRequestProvider);
    final cancelState = ref.watch(cancelDepositRequestProvider);
    final busy = reviewState.isLoading || cancelState.isLoading;

    // Former members included, so a reviewed request still names its people.
    final members =
        ref.watch(allMembersStreamProvider).value ?? const <HouseMemberEntity>[];
    String nameOf(String? uid) {
      if (uid == null) return '—';
      for (final m in members) {
        if (m.userId == uid && (m.displayName?.isNotEmpty ?? false)) {
          return m.displayName!;
        }
      }
      return l10n.commonUnknownMember;
    }

    final amountText =
        CurrencyUtils.format(request.amount, localeCode: l10n.localeName);
    final submittedLine =
        '${DateFormatUtils.formatDateShort(request.createdAt, l10n.localeName)} • '
        '${DateFormatUtils.formatTime(request.createdAt, l10n.localeName)}';

    return ResponsivePage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            _SectionCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.success.withAlpha(22),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.savings_outlined,
                      size: 24,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.txnTypeDeposit,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.depositRequestSubmittedBy(
                            nameOf(request.submittedBy),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+$amountText',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Details ──
            _SectionCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.flag_outlined,
                    label: l10n.labelStatus,
                    trailing: StatusBadge(
                      // Stored value drives the colour; the label is localized.
                      status: request.status.toLowerCase(),
                      label: request.isApproved
                          ? l10n.statusApproved
                          : request.isRejected
                              ? l10n.statusRejected
                              : l10n.statusPending,
                    ),
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: l10n.labelDate,
                    value: submittedLine,
                  ),
                  _InfoRow(
                    icon: Icons.person_pin_outlined,
                    label: l10n.labelPaidBy,
                    value: nameOf(request.paidByUserId),
                  ),
                  if (request.paymentMethod != null)
                    _InfoRow(
                      icon: Icons.payments_outlined,
                      label: l10n.labelPaymentMethod,
                      value: VocabularyLabels.paymentMethod(
                        request.paymentMethod,
                        l10n,
                      ),
                    ),
                  if (request.periodLabel != null)
                    _InfoRow(
                      icon: Icons.calendar_month_outlined,
                      label: l10n.txnCoversMonth,
                      value: request.periodLabel!,
                    ),
                  if (request.purpose != null)
                    _InfoRow(
                      icon: Icons.label_outline,
                      label: l10n.labelPurpose,
                      value: request.purpose!,
                    ),
                  if (request.notes?.isNotEmpty ?? false)
                    _InfoRow(
                      icon: Icons.note_outlined,
                      label: l10n.depositNotesLabel,
                      value: request.notes!,
                    ),
                  if (request.reviewedBy != null)
                    _InfoRow(
                      icon: Icons.verified_user_outlined,
                      label: l10n.labelPerformedBy,
                      value: nameOf(request.reviewedBy),
                    ),
                  if (request.isRejected &&
                      (request.rejectReason?.isNotEmpty ?? false))
                    _InfoRow(
                      icon: Icons.info_outline,
                      label: l10n.statusRejected,
                      value: l10n.expenseRejectReason(request.rejectReason!),
                    ),
                ],
              ),
            ),

            // ── Proof ──
            if (request.receiptUrl?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _SectionCard(
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
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                      child: ReceiptImage(
                        receiptUrl: request.receiptUrl!,
                        height: 180,
                        width: double.infinity,
                        onTap: () =>
                            _openReceipt(context, request.receiptUrl!),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _openReceipt(context, request.receiptUrl!),
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
            ],

            // ── Actions (Pending only) ──
            if (request.isPending) ...[
              const SizedBox(height: 24),
              if (isTreasurer)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _showRejectDialog(
                                  context,
                                  ref,
                                  nameOf(request.submittedBy),
                                  amountText,
                                ),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(l10n.actionReject),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => _confirmApprove(
                                  context,
                                  ref,
                                  nameOf(request.submittedBy),
                                  amountText,
                                ),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l10n.actionApprove),
                      ),
                    ),
                  ],
                )
              else ...[
                Text(
                  l10n.depositRequestAwaitingReview,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (isSubmitter) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _confirmCancel(context, ref, amountText),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l10n.actionCancelRequest),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    WidgetRef ref,
    String name,
    String amountText,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.depositRequestApproveTitle),
        content: Text(l10n.depositRequestApproveConfirm(amountText, name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionApprove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error =
        await ref.read(reviewDepositRequestProvider.notifier).approve(request);
    if (!context.mounted) return;
    if (error == null) {
      SnackbarUtils.showSuccess(context, l10n.depositRequestApproved);
    } else {
      SnackbarUtils.showError(context, FailureMessages.forError(error, l10n));
    }
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    WidgetRef ref,
    String name,
    String amountText,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.depositRequestRejectTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.depositRequestRejectConfirm(amountText, name)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: l10n.expenseRejectReasonLabel,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            child: Text(l10n.actionReject),
          ),
        ],
      ),
    );
    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true) return;

    final error = await ref
        .read(reviewDepositRequestProvider.notifier)
        .reject(request, reason: reason);
    if (!context.mounted) return;
    if (error == null) {
      SnackbarUtils.showSuccess(context, l10n.depositRequestRejected);
    } else {
      SnackbarUtils.showError(context, FailureMessages.forError(error, l10n));
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String amountText,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.depositRequestCancelTitle),
        content: Text(l10n.depositRequestCancelConfirm(amountText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.depositRequestKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            child: Text(l10n.actionCancelRequest),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error =
        await ref.read(cancelDepositRequestProvider.notifier).cancel(request);
    if (!context.mounted) return;
    if (error == null) {
      SnackbarUtils.showSuccess(context, l10n.depositRequestCancelled);
      Navigator.of(context).pop();
    } else {
      SnackbarUtils.showError(context, FailureMessages.forError(error, l10n));
    }
  }
}

/// Muted rounded card, matching the transaction details page.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: context.colors.surfaceMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: Icon(icon, size: 18, color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ??
                  Text(
                    value ?? '—',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
