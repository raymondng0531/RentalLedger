import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../l10n/generated/app_localizations.dart';
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
///
/// With [memberRequest] the same form is a member's **Submit Deposit**: the
/// payer is fixed to the member themselves and submitting creates a Pending
/// deposit request for the Treasurer to approve — nothing reaches the ledger
/// until then. The Treasurer's direct Record Deposit is unchanged.
class DepositPage extends ConsumerStatefulWidget {
  const DepositPage({super.key, this.memberRequest = false});

  /// True for the member's Submit Deposit flow (see the class docs).
  final bool memberRequest;

  @override
  ConsumerState<DepositPage> createState() => _DepositPageState();
}

/// Common purposes for a Central Account contribution / top-up.
///
/// These are the **stored** values — they are written to Firestore verbatim and
/// displayed as-is on the transaction detail page, so they are never
/// translated. Only the label the dropdown shows is localized, via
/// [_purposeLabel].
const List<String> _depositPurposes = [
  'Monthly Rental',
  'House Contribution',
  'General Top-up',
  'Utilities',
  'Other',
];

/// Localized label for a stored deposit purpose (see [_depositPurposes]).
///
/// An unrecognised purpose is shown exactly as stored.
String _purposeLabel(String stored, AppLocalizations l10n) {
  switch (stored) {
    case 'Monthly Rental':
      return l10n.depositPurposeMonthlyRental;
    case 'House Contribution':
      return l10n.depositPurposeHouseContribution;
    case 'General Top-up':
      return l10n.depositPurposeGeneralTopUp;
    case 'Utilities':
      return l10n.depositPurposeUtilities;
    case 'Other':
      return l10n.depositPurposeOther;
    default:
      return stored;
  }
}

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
    if (widget.memberRequest) {
      ref.read(submitDepositRequestProvider.notifier).setProofPath(path);
    } else {
      ref.read(depositProvider.notifier).setProofPath(path);
    }
  }

  String? get _periodLabel => _periodController.text.trim().isEmpty
      ? null
      : _periodController.text.trim();

  Future<void> _handleDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasProof) return; // Button is disabled; belt-and-braces.
    if (widget.memberRequest) return _handleSubmitRequest();

    final amount = double.parse(_amountController.text);
    final user = ref.read(currentUserProvider);

    final errorMessage = await ref.read(depositProvider.notifier).deposit(
          amount: amount,
          notes: _notesController.text.trim(),
          paidByUserId: _paidByUserId ?? user?.uid,
          paymentMethod: _paymentMethod,
          periodLabel: _periodLabel,
          purpose: _purpose,
        );

    if (!mounted) return;

    if (errorMessage == null) {
      // Pop-up toast that auto-dismisses, then back to dashboard.
      SnackbarUtils.showSuccess(
          context, AppLocalizations.of(context).depositRecorded);
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(
        context,
        FailureMessages.forError(errorMessage, AppLocalizations.of(context)),
      );
    }
  }

  /// Member flow: submit a Pending deposit request for the Treasurer.
  Future<void> _handleSubmitRequest() async {
    final amount = double.parse(_amountController.text);
    final errorMessage =
        await ref.read(submitDepositRequestProvider.notifier).submit(
              amount: amount,
              notes: _notesController.text.trim(),
              paymentMethod: _paymentMethod,
              periodLabel: _periodLabel,
              purpose: _purpose,
            );

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (errorMessage == null) {
      SnackbarUtils.showSuccess(context, l10n.depositSubmittedForApproval);
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(
        context,
        FailureMessages.forError(errorMessage, l10n),
      );
    }
  }

  String _memberLabel(HouseMemberEntity m, AppLocalizations l10n) =>
      (m.displayName?.isNotEmpty ?? false) ? m.displayName! : l10n.labelMember;

  @override
  Widget build(BuildContext context) {
    final memberRequest = widget.memberRequest;
    final state = memberRequest
        ? ref.watch(submitDepositRequestProvider)
        : ref.watch(depositProvider);
    final isLoading = state.isLoading;
    final membersAsync = ref.watch(membersStreamProvider);
    final currentUser = ref.watch(currentUserProvider);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

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
          tooltip: l10n.actionBack,
        ),
        title: Text(
          memberRequest ? l10n.actionSubmitDeposit : l10n.depositRecordTitle,
        ),
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
                    memberRequest
                        ? l10n.depositSubmitSubtitle
                        : l10n.depositSubtitle,
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
                    decoration: InputDecoration(
                      labelText: l10n.expenseFieldAmountRm,
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return l10n.expenseFieldRequired;
                      }
                      final amount = double.tryParse(v);
                      if (amount == null || amount <= 0) {
                        return l10n.expenseFieldInvalidAmount;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Paid by (who physically paid the money in) ──
                  // A member always deposits for themselves, so the payer is
                  // shown, not chosen.
                  if (memberRequest)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.labelPaidBy,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      child: Text(
                        (currentUser?.displayName.isNotEmpty ?? false)
                            ? currentUser!.displayName
                            : l10n.depositPaidByYou,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: dropdownValue,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.labelPaidBy,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      items: [
                        for (final m in members)
                          DropdownMenuItem(
                            value: m.userId,
                            child: Text(
                              _memberLabel(m, l10n),
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
                    decoration: InputDecoration(
                      labelText: l10n.depositPurposeLabel,
                      hintText: l10n.depositPurposeHint,
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                    items: [
                      // The item's *value* stays the stored purpose; only the
                      // text shown for it is localized.
                      for (final p in _depositPurposes)
                        DropdownMenuItem(
                            value: p, child: Text(_purposeLabel(p, l10n))),
                    ],
                    onChanged: (v) => setState(() => _purpose = v),
                  ),
                  const SizedBox(height: 16),

                  // ── Payment method (optional) ──
                  Text(
                    l10n.labelPaymentMethod,
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
                    decoration: InputDecoration(
                      labelText: l10n.expenseFieldForMonth,
                      hintText: l10n.expenseFieldForMonthHint,
                      prefixIcon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Proof (required — actual money movement) ──
                  ProofPicker(
                    heading: l10n.labelReceiptProofRequired,
                    onChanged: _onProofChanged,
                  ),
                  const SizedBox(height: 24),

                  // ── Notes ──
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.depositNotesLabel,
                      hintText: l10n.depositNotesHint,
                      prefixIcon: const Icon(Icons.note_outlined),
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
                          : Text(
                              memberRequest
                                  ? l10n.actionSubmitDeposit
                                  : l10n.depositRecordTitle,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_hasProof)
                    Text(
                      memberRequest
                          ? l10n.depositSubmitProofRequiredHint
                          : l10n.depositProofRequiredHint,
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
