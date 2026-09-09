/// Pure decision helpers for editing an expense's attached receipt.
///
/// Editing a PENDING expense lets the member replace or remove the attached
/// receipt before saving (see §21 in docs/12_AI_DIRECTION.md). Two UI-state
/// transitions are easy to get subtly wrong — which image the dialog *previews*
/// and what the save does with the receipt. The deployed "Preview Receipt" bug
/// showed the stale saved receipt after a replacement photo had been picked,
/// because the preview read the saved entity URL instead of the temporary
/// selection.
///
/// These two decisions are extracted here as tiny pure functions over the
/// dialog's temporary edit state so the exact priority rules can be unit-tested
/// without a Web/Firestore harness. The edit dialog in
/// `expense_details_page.dart` (`_EditExpenseDialogState`) is the only caller;
/// it stays Web-aware, this file stays platform-free.
library;

/// Which receipt the edit dialog's preview should show right now.
enum ReceiptPreviewSource {
  /// A newly-picked local receipt — it replaces the stored one on save.
  newLocal,

  /// The currently-stored receipt URL (saved state, shown as-is).
  savedUrl,

  /// Nothing to show (the receipt is being removed, or none is attached).
  none,
}

/// Resolves which receipt the "Preview Receipt" action must open.
///
/// Priority (the required behaviour):
/// 1. A newly-picked local receipt always wins — previewing must show what will
///    replace the stored receipt on save, even when a stored receipt exists.
/// 2. An explicit removal leaves nothing to preview.
/// 3. Otherwise the stored receipt URL is shown, when one is attached.
/// 4. Otherwise there is nothing to preview.
ReceiptPreviewSource effectiveReceiptPreviewSource({
  required bool hasNewLocal,
  required bool removeReceipt,
  required String? savedReceiptUrl,
}) {
  if (hasNewLocal) return ReceiptPreviewSource.newLocal;
  if (removeReceipt) return ReceiptPreviewSource.none;
  if (savedReceiptUrl != null && savedReceiptUrl.isNotEmpty) {
    return ReceiptPreviewSource.savedUrl;
  }
  return ReceiptPreviewSource.none;
}

/// What saving the edit dialog should do with the attached receipt.
enum ReceiptSaveAction {
  /// Leave the stored receipt URL untouched.
  keepSaved,

  /// Upload the newly-picked local receipt and store its returned URL.
  replaceWithNew,

  /// Clear the stored receipt (explicitly removed by the member).
  removeReceipt,
}

/// Resolves the receipt outcome of saving the edit dialog.
///
/// Priority: a newly-picked receipt replaces the stored one; otherwise an
/// explicit removal clears it; otherwise the stored receipt is kept unchanged.
/// A new receipt only becomes permanent through [ReceiptSaveAction.replaceWithNew]
/// (the upload + Firestore write in `_save`) — this module models only the
/// save-time decision, so a member who cancels the dialog (never reaching
/// `_save`) always leaves the saved receipt untouched.
ReceiptSaveAction receiptSaveAction({
  required bool hasNewLocal,
  required bool removeReceipt,
}) {
  if (hasNewLocal) return ReceiptSaveAction.replaceWithNew;
  if (removeReceipt) return ReceiptSaveAction.removeReceipt;
  return ReceiptSaveAction.keepSaved;
}
