import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/press_scale.dart';
import '../providers/expense_provider.dart';

/// Record Deposit screen — add money to the Central Account.
class DepositPage extends ConsumerStatefulWidget {
  const DepositPage({super.key});

  @override
  ConsumerState<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends ConsumerState<DepositPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);

    final errorMessage = await ref.read(depositProvider.notifier).deposit(
          amount: amount,
          notes: _notesController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(depositProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Record Deposit'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
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
                      color: AppTheme.successGreen.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      size: 36,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Add money to the Central Account.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
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

                // ── Notes ──
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Monthly top-up',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                PressScale(
                  child: FilledButton(
                    onPressed: isLoading ? null : _handleDeposit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,
                            ),
                          )
                        : const Text('Record Deposit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
