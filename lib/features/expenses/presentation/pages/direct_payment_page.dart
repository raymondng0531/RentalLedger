import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../providers/expense_provider.dart';

/// Direct Payment screen — record a payment made directly from the Central Account.
class DirectPaymentPage extends ConsumerStatefulWidget {
  const DirectPaymentPage({super.key});

  @override
  ConsumerState<DirectPaymentPage> createState() => _DirectPaymentPageState();
}

class _DirectPaymentPageState extends ConsumerState<DirectPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);

    final errorMessage =
        await ref.read(directPaymentProvider.notifier).payDirectly(
              amount: amount,
              notes: _titleController.text.trim(),
            );

    if (!mounted) return;

    if (errorMessage == null) {
      // Pop-up toast that auto-dismisses, then back to dashboard.
      SnackbarUtils.showSuccess(context, 'Payment recorded');
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directPaymentProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Direct Payment'),
        backgroundColor: Colors.white,
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
                        color: AppTheme.statusDirectPayment.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.payment_outlined,
                        size: 36,
                        color: AppTheme.statusDirectPayment,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Pay directly from the Central Account.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'What was it for?',
                      prefixIcon: Icon(Icons.receipt_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
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
                  const SizedBox(height: 24),

                  PressScale(
                    child: FilledButton(
                      onPressed: isLoading ? null : _handlePayment,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : const Text('Record Payment'),
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
