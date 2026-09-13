import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/receipt_viewer.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Receipt / proof image picker for financial transactions.
///
/// Reproduces the canonical Add-Expense receipt upload UI (Take Photo /
/// Choose Photo → thumbnail → Preview / Remove) so every money-movement form
/// shares one look and one behaviour. The widget owns the locally-selected
/// image only for preview; the local path (blob URL on web, file path on
/// native) is forwarded via [onChanged] so the caller can stage it for upload
/// when the transaction is committed.
class ProofPicker extends StatefulWidget {
  const ProofPicker({
    super.key,
    required this.onChanged,
    this.heading,
  });

  /// Called with the selected local path (or `null` when removed).
  final ValueChanged<String?> onChanged;

  /// Section heading shown above the picker.
  ///
  /// Defaults to the localized "Receipt / Proof" when the caller passes none.
  final String? heading;

  @override
  State<ProofPicker> createState() => _ProofPickerState();
}

class _ProofPickerState extends State<ProofPicker> {
  final ImagePicker _picker = ImagePicker();
  XFile? _file;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _file = picked);
        widget.onChanged(picked.path);
      }
    } catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(
        context,
        AppLocalizations.of(context).expensePhotoError,
      );
    }
  }

  void _remove() {
    setState(() => _file = null);
    widget.onChanged(null);
  }

  /// Confirms before removing the proof image.
  Future<void> _confirmRemove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expenseRemoveProofTitle),
        content: Text(l10n.expenseRemoveProofMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (confirmed == true) _remove();
  }

  /// Builds the image widget (web-safe: network on web, file on native).
  Widget _image({required double height, double? width}) {
    final image = kIsWeb
        ? Image.network(
            _file!.path,
            height: height,
            width: width,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_outlined, size: 48),
          )
        : Image.file(
            File(_file!.path),
            height: height,
            width: width,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_outlined, size: 48),
          );
    return image;
  }

  /// Opens a full-screen zoomable viewer of the selected proof.
  ///
  /// The `Colors.white54` error glyphs below are deliberately NOT themed:
  /// [ReceiptViewer] draws its own fixed black ground in every mode, so white
  /// is the correct ink there and `context.colors` does not apply.
  void _showFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptViewer(
          title:
              widget.heading ?? AppLocalizations.of(context).labelReceiptProof,
          image: kIsWeb
              ? Image.network(
                  _file!.path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 48),
                )
              : Image.file(
                  File(_file!.path),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.heading ?? l10n.labelReceiptProof,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_file == null)
          // ── Upload buttons: Take Photo / Choose Photo ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(l10n.actionTakePhoto),
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
                  label: Text(l10n.actionChoosePhoto),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          )
        else
          // ── Thumbnail + Preview / Remove actions ──
          Column(
            children: [
              GestureDetector(
                onTap: _showFullscreen,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  child: _image(height: 180, width: double.infinity),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showFullscreen,
                      icon: const Icon(Icons.remove_red_eye_outlined,
                          size: 18),
                      label: Text(l10n.expensePreviewProof),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _confirmRemove,
                      icon: Icon(Icons.close, size: 18, color: colors.error),
                      label: Text(
                        l10n.actionRemove,
                        style: TextStyle(color: colors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
