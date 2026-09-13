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
import '../providers/expense_provider.dart';
import '../widgets/category_picker.dart';
import '../widgets/payment_method_chips.dart';
import '../widgets/proof_picker.dart';

/// Direct Payment screen — record a payment made directly from the Central
/// Account.
///
/// An actual money movement OUT, so a receipt/proof image is required. The
/// payment may carry an optional category, payment method and month/period.
class DirectPaymentPage extends ConsumerStatefulWidget {
  const DirectPaymentPage({super.key});

  @override
  ConsumerState<DirectPaymentPage> createState() => _DirectPaymentPageState();
}

class _DirectPaymentPageState extends ConsumerState<DirectPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _periodController = TextEditingController();

  String? _selectedCategory;
  String? _paymentMethod;

  /// Whether a proof image is currently staged for upload.
  bool _hasProof = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _onProofChanged(String? path) {
    setState(() => _hasProof = path != null);
    ref.read(directPaymentProvider.notifier).setProofPath(path);
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasProof) return; // Button is disabled; belt-and-braces.

    final amount = double.parse(_amountController.text);

    final errorMessage =
        await ref.read(directPaymentProvider.notifier).payDirectly(
              amount: amount,
              notes: _titleController.text.trim(),
              categoryId: _selectedCategory,
              paymentMethod: _paymentMethod,
              periodLabel: _periodController.text.trim().isEmpty
                  ? null
                  : _periodController.text.trim(),
            );

    if (!mounted) return;

    if (errorMessage == null) {
      // Pop-up toast that auto-dismisses, then back to dashboard.
      SnackbarUtils.showSuccess(
          context, AppLocalizations.of(context).directPaymentRecorded);
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(
        context,
        FailureMessages.forError(errorMessage, AppLocalizations.of(context)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directPaymentProvider);
    final isLoading = state.isLoading;
    final categoriesAsync = ref.watch(categoriesProvider);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.actionDirectPayment),
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
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.statusDirectPayment.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.payment_outlined,
                        size: 36,
                        color: colors.statusDirectPayment,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    l10n.directPaymentSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.expenseFieldTitle,
                      hintText: l10n.directPaymentTitleHint,
                      prefixIcon: const Icon(Icons.receipt_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l10n.expenseFieldRequired
                        : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
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
                  const SizedBox(height: 20),

                  // ── Category (optional) ──
                  Text(
                    l10n.labelCategory,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    loading: () => const Wrap(
                      spacing: 8,
                      children: [CircularProgressIndicator()],
                    ),
                    error: (_, __) =>
                        Text(l10n.expenseCategoriesLoadError),
                    data: (categories) => CategoryPicker(
                      categories: categories,
                      selectedId: _selectedCategory,
                      onSelected: (id) =>
                          setState(() => _selectedCategory = id),
                    ),
                  ),
                  const SizedBox(height: 20),

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

                  // ── For month / period (optional) ──
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

                  PressScale(
                    child: FilledButton(
                      onPressed: (isLoading || !_hasProof)
                          ? null
                          : _handlePayment,
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
                          : Text(l10n.directPaymentRecord),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_hasProof)
                    Text(
                      l10n.directPaymentProofRequiredHint,
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
