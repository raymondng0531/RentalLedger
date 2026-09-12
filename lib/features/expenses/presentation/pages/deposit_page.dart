import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../members/domain/entities/house_member_entity.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/payment_method_chips.dart';
import '../widgets/proof_picker.dart';

/// Record Deposit screen — add money to the Central Account.
///
/// An actual money movement IN, so a receipt/proof image is required and the
/// deposit is attributed to the member who physically paid it ([paidByUserId]),
/// with optional payment method, month/period (e.g. monthly rental) and purpose.
/// The Treasurer records it — [performedBy] stays the Treasurer.
class DepositPage extends ConsumerStatefulWidget {
  const DepositPage({super.key});

  @override
  ConsumerState<DepositPage> createState() => _DepositPageState();
}

/// Common purposes for a Central Account contribution / top-up.
const List<String> _depositPurposes = [
  'Monthly Rental',
  'House Contribution',
  'General Top-up',
  'Utilities',
  'Other',
];

class _DepositPageState extends ConsumerState<DepositPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _periodController = TextEditingController();

  /// Selected member who physically paid (null → falls back to the Treasurer).
  String? _paidByUserId;
  String? _purpose;
  String? _paymentMethod;

  /// Whether a proof image is currently staged for upload.
  bool _hasProof = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _onProofChanged(String? path) {
    setState(() => _hasProof = path != null);
    ref.read(depositProvider.notifier).setProofPath(path);
  }

  Future<void> _handleDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasProof) return; // Button is disabled; belt-and-braces.

    final amount = double.parse(_amountController.text);
    final user = ref.read(currentUserProvider);

    final errorMessage = await ref.read(depositProvider.notifier).deposit(
          amount: amount,
          notes: _notesController.text.trim(),
          paidByUserId: _paidByUserId ?? user?.uid,
          paymentMethod: _paymentMethod,
          periodLabel: _periodController.text.trim().isEmpty
              ? null
              : _periodController.text.trim(),
          purpose: _purpose,
        );

    if (!mounted) return;

    if (errorMessage == null) {
      // Pop-up toast that auto-dismisses, then back to dashboard.
      SnackbarUtils.showSuccess(context, 'Deposit recorded');
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(context, errorMessage);
    }
  }

  String _memberLabel(HouseMemberEntity m) =>
      (m.displayName?.isNotEmpty ?? false) ? m.displayName! : 'Member';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(depositProvider);
    final isLoading = state.isLoading;
    final membersAsync = ref.watch(membersStreamProvider);
    final currentUser = ref.watch(currentUserProvider);
    final colors = context.colors;

    final members = membersAsync.value ?? const <HouseMemberEntity>[];
    final memberUids = {for (final m in members) m.userId};

    // Default the payer to the Treasurer themselves (the usual contributor)
    // once the member list is known; a real payer can be chosen below.
    String? selectedPaidBy = _paidByUserId;
    if (selectedPaidBy == null &&
        currentUser != null &&
        memberUids.contains(currentUser.uid)) {
      selectedPaidBy = currentUser.uid;
    }
    final dropdownValue = memberUids.contains(selectedPaidBy)
        ? selectedPaidBy
        : null;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Record Deposit'),
        backgroundColor: colors.surface,
      ),
      body: ResponsivePage(
        maxWidth: AppContentWidth.form,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Icon ──
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 36,
                        color: colors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Add money to the Central Account.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // ── Amount ──
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Amount (RM)',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final amount = double.tryParse(v);
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Paid by (who physically paid the money in) ──
                  DropdownButtonFormField<String>(
                    value: dropdownValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Paid by',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: [
                      for (final m in members)
                        DropdownMenuItem(
                          value: m.userId,
                          child: Text(
                            _memberLabel(m),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _paidByUserId = v),
                  ),
                  const SizedBox(height: 16),

                  // ── Purpose (optional) ──
                  DropdownButtonFormField<String>(
                    value: _purpose,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Purpose (optional)',
                      hintText: 'e.g. Monthly Rental',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    items: [
                      for (final p in _depositPurposes)
                        DropdownMenuItem(value: p, child: Text(p)),
                    ],
                    onChanged: (v) => setState(() => _purpose = v),
                  ),
                  const SizedBox(height: 16),

                  // ── Payment method (optional) ──
                  Text(
                    'Payment Method',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  PaymentMethodChips(
                    selected: _paymentMethod,
                    onSelected: (v) => setState(() => _paymentMethod = v),
                  ),
                  const SizedBox(height: 16),

                  // ── For month / period (optional, e.g. monthly rental) ──
                  TextFormField(
                    controller: _periodController,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'For month (optional)',
                      hintText: 'e.g. 2026-09',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Proof (required — actual money movement) ──
                  ProofPicker(
                    heading: 'Receipt / Proof (required)',
                    onChanged: _onProofChanged,
                  ),
                  const SizedBox(height: 24),

                  // ── Notes ──
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'e.g. Sep rent for Ahmad & Mei',
                      prefixIcon: Icon(Icons.note_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  PressScale(
                    child: FilledButton(
                      onPressed: (isLoading || !_hasProof)
                          ? null
                          : _handleDeposit,
                      child: isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                // Ink on the FilledButton's fill.
                                color: colors.onPrimary,
                              ),
                            )
                          : const Text('Record Deposit'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_hasProof)
                    Text(
                      'Attach a receipt or proof above to record the deposit.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
