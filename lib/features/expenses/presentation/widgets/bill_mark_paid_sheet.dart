import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
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
    final now = DateTime.now();
    _periodController = TextEditingController(
      text: '${now.year}-${now.month.toString().padLeft(2, '0')}',
    );
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
      SnackbarUtils.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      SnackbarUtils.showError(
        context,
        'Could not mark the bill as paid. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final theme = Theme.of(context);
    final colors = context.colors;

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
                          'Mark "${bill.title}" as paid?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          bill.isRecurring
                              ? 'Rolls the bill to next month.'
                              : 'Settles this bill.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyUtils.format(bill.amount ?? 0),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.statusDirectPayment,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── For month ──
              TextField(
                controller: _periodController,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Payment covers month',
                  hintText: 'e.g. 2026-09',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // ── Payment method (optional) ──
              Text(
                'Payment Method',
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
                heading: 'Receipt / Proof (required)',
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
                      child: const Text('Cancel'),
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
                          : const Text('Confirm Payment'),
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
