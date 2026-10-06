import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/month_picker_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/bill_entity.dart';
import '../providers/expense_provider.dart';
import '../widgets/payment_method_chips.dart';
import '../widgets/proof_picker.dart';

/// Bottom sheet used by Mark Paid on an amount-bearing bill.
///
/// A bill payment is an actual money movement out of the Central Account (one
/// Direct Payment transaction per paid month), so the Treasurer attaches that
/// month's receipt/proof and records the payment period. Upload happens when
/// the notifier commits — the sheet only stages the local image.
///
/// Pops `true` when the bill was successfully marked paid.
class BillMarkPaidSheet extends ConsumerStatefulWidget {
  const BillMarkPaidSheet({super.key, required this.bill});

  final BillEntity bill;

  @override
  ConsumerState<BillMarkPaidSheet> createState() => _BillMarkPaidSheetState();
}

class _BillMarkPaidSheetState extends ConsumerState<BillMarkPaidSheet> {
  late final TextEditingController _periodController;

  String? _paymentMethod;

  /// Local path of the staged proof image (web blob URL / native file path).
  String? _proofPath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // The month being paid defaults to the current one (recurring bills roll
    // monthly and each month is settled as it comes due). Editable.
    _periodController = TextEditingController(text: currentPeriodLabel());
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  void _onProofChanged(String? path) {
    setState(() => _proofPath = path);
  }

  Future<void> _confirm() async {
    if (_submitting || _proofPath == null) return;
    setState(() => _submitting = true);

    try {
      // The proof path is passed straight through — this sheet owns the staged
      // image, so the notifier's own pending proof path is not relied upon.
      final period = _periodController.text.trim();
      await ref.read(billActionsProvider.notifier).markPaid(
            widget.bill,
            proofPath: _proofPath,
            paymentMethod: _paymentMethod,
            periodLabel: period.isEmpty ? null : period,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // The notifier has no BuildContext, so a guard it owns is recognised
      // here by its stable TYPE and shown localized. A refusal from the data
      // layer (already paid, insufficient balance, ...) is recognized by its
      // stable CODE and described with the arguments it carried.
      final l10n = AppLocalizations.of(context);
      SnackbarUtils.showError(
        context,
        e is PermissionFailure
            ? l10n.billTreasurerOnlyMarkPaid
            : FailureMessages.of(e, l10n),
      );
    } on AppException catch (e) {
      // An amount-bearing bill requires its receipt/proof. The notifier tags
      // that refusal with a stable code (never with text).
      if (!mounted) return;
      setState(() => _submitting = false);
      SnackbarUtils.showError(
        context,
        e.code == ExpenseErrorCodes.proofRequired
            ? AppLocalizations.of(context).billProofRequired
            : AppLocalizations.of(context).billMarkPaidFailed,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      SnackbarUtils.showError(
        context,
        AppLocalizations.of(context).billMarkPaidFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Padding(
      // Keep the sheet above the on-screen keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.statusDirectPayment.withAlpha(20),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: colors.statusDirectPayment,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.billMarkPaidConfirm(bill.title),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          bill.isRecurring
                              ? l10n.billRollsToNextMonth
                              : l10n.billSettles,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyUtils.format(bill.amount ?? 0, localeCode: l10n.localeName),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.statusDirectPayment,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── For month ──
              MonthPickerField(
                controller: _periodController,
                labelText: l10n.billPaymentCoversMonth,
                hintText: l10n.billPaymentCoversMonthHint,
              ),
              const SizedBox(height: 16),

              // ── Payment method (optional) ──
              Text(
                l10n.labelPaymentMethod,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              PaymentMethodChips(
                selected: _paymentMethod,
                onSelected: (v) => setState(() => _paymentMethod = v),
              ),
              const SizedBox(height: 18),

              // ── Proof (required — actual money movement) ──
              ProofPicker(
                heading: l10n.labelReceiptProofRequired,
                onChanged: _onProofChanged,
              ),
              const SizedBox(height: 20),

              // ── Actions ──
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(l10n.actionCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_submitting || _proofPath == null)
                          ? null
                          : _confirm,
                      child: _submitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                // Ink on the FilledButton's fill.
                                color: colors.onPrimary,
                              ),
                            )
                          : Text(l10n.billConfirmPayment),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
