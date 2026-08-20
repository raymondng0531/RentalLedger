import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/receipt_viewer.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_picker.dart';

/// Add Expense screen — form to submit a new expense claim with receipt photo.
///
/// Matches the Figma design: title, amount, category, payment source,
/// receipt upload (Take Photo / Choose Photo), and submit button.
class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  String _selectedCategory = 'other';
  String _paymentSource = 'central';
  // XFile is cross-platform: on native it wraps the file path, on web the
  // picker returns a blob URL. (File(picked.path) throws on web.)
  XFile? _receiptFile;

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
          _receiptFile = picked;
        });
        ref.read(createExpenseProvider.notifier).setReceiptPath(picked.path);
      }
    } catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context,
          'Could not take a photo. Please try again.');
    }
  }

  void _removeReceipt() {
    setState(() {
      _receiptFile = null;
    });
    ref.read(createExpenseProvider.notifier).setReceiptPath(null);
  }

  /// Builds the receipt image (web-safe: uses network on web, file on mobile).
  Widget _receiptImage({required double height, double? width}) {
    final image = kIsWeb
        ? Image.network(
            _receiptFile!.path,
            height: height,
            width: width,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
          )
        : Image.file(
            File(_receiptFile!.path),
            height: height,
            width: width,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
          );
    return image;
  }

  /// Opens a full-screen receipt viewer with zoom + pan.
  void _showReceiptFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptViewer(
          image: kIsWeb
              ? Image.network(
                  _receiptFile!.path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 48),
                )
              : Image.file(
                  File(_receiptFile!.path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 48),
                ),
        ),
      ),
    );
  }

  /// Confirms before removing the receipt.
  Future<void> _confirmRemoveReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Receipt'),
        content: const Text('Are you sure you want to remove this receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _removeReceipt();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;

    final errorMessage =
        await ref.read(createExpenseProvider.notifier).createExpense(
              title: _titleController.text,
              description: _descriptionController.text,
              categoryId: _selectedCategory,
              amount: amount,
              paymentSource: _paymentSource,
            );

    if (!mounted) return;

    if (errorMessage == null) {
      // Show a pop-up toast that auto-dismisses, then go back to dashboard.
      SnackbarUtils.showSuccess(context, 'Expense submitted');
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final state = ref.watch(createExpenseProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Add Expense'),
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
                // ── Title ──
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'What did you buy?',
                    prefixIcon: Icon(Icons.receipt_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

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

                // ── Description ──
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add more details...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Receipt Upload ──
                Text(
                  'Receipt',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                _buildReceiptSection(),
                const SizedBox(height: 20),

                // ── Category ──
                Text(
                  'Category',
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
                  error: (_, __) => const Text('Could not load categories'),
                  data: (categories) => CategoryPicker(
                    categories: categories,
                    selectedId: _selectedCategory,
                    onSelected: (id) =>
                        setState(() => _selectedCategory = id),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Payment Source ──
                Text(
                  'Payment Source',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _PaymentChip(
                      label: 'Central Account',
                      selected: _paymentSource == 'central',
                      onTap: () => setState(() => _paymentSource = 'central'),
                    ),
                    _PaymentChip(
                      label: 'Personal (reimburse me)',
                      selected: _paymentSource == 'personal',
                      onTap: () => setState(() => _paymentSource = 'personal'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Info text ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _paymentSource == 'personal'
                              ? 'You will be reimbursed from the Central Account after approval.'
                              : 'This will be paid directly from the Central Account.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Submit button (primary CTA, taller & with icon) ──
                SizedBox(
                  height: 56,
                  child: PressScale(
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : _handleSubmit,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        isLoading ? 'Submitting...' : 'Submit Expense',
                      ),
                      style: FilledButton.styleFrom(
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptSection() {
    if (_receiptFile != null) {
      // ── Receipt thumbnail + actions ──
      return Column(
        children: [
          GestureDetector(
            onTap: _showReceiptFullscreen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: _receiptImage(height: 180, width: double.infinity),
            ),
          ),
          const SizedBox(height: 10),

          // ── Preview + Remove actions ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showReceiptFullscreen,
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  label: const Text('Preview Receipt'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _confirmRemoveReceipt,
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.errorRed),
                  label: Text(
                    'Remove',
                    style: TextStyle(color: AppTheme.errorRed),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── Upload buttons: Take Photo / Choose Photo ──
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take Photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose Photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// A payment-source choice chip: solid green when selected, no tick.
class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      // Matches the CategoryPicker: solid teal when selected, clean white
      // with a subtle divider border when not.
      selectedColor: AppTheme.primaryGreen,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      side: BorderSide(
        color: selected ? AppTheme.primaryGreen : AppTheme.dividerColor,
        width: selected ? 1.5 : 1.0,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
