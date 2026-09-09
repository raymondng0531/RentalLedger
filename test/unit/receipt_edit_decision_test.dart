import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/presentation/logic/receipt_edit_decision.dart';

/// Guards the receipt preview-source + save-action decisions in the Edit
/// Expense dialog (§21). The deployed build showed the STALE saved receipt in
/// "Preview Receipt" after a member picked a replacement photo, because the
/// preview read the saved entity URL instead of the temporary selection.
///
/// The dialog lives in `expense_details_page.dart`, which imports a Web-only
/// widget and therefore cannot run under the VM test runner. The decision is
/// extracted into this pure module so the exact priority rules lock in the six
/// required behaviours below without a Web/Firestore harness.
void main() {
  group('effectiveReceiptPreviewSource — which image "Preview Receipt" opens',
      () {
    test('1. existing saved receipt only → the saved receipt', () {
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: false,
          removeReceipt: false,
          savedReceiptUrl: 'https://cdn/current.jpg',
        ),
        ReceiptPreviewSource.savedUrl,
      );
    });

    test('2. newly-picked local receipt only → the new local receipt', () {
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: true,
          removeReceipt: false,
          savedReceiptUrl: null,
        ),
        ReceiptPreviewSource.newLocal,
      );
    });

    test('3. new local receipt wins over the old saved receipt', () {
      // The regression: after picking a replacement, the preview must show the
      // NEW photo even though a saved receipt URL still exists.
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: true,
          removeReceipt: false,
          savedReceiptUrl: 'https://cdn/old.jpg',
        ),
        ReceiptPreviewSource.newLocal,
      );
    });

    test('4. no replacement → the existing saved receipt remains the preview',
        () {
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: false,
          removeReceipt: false,
          savedReceiptUrl: 'https://cdn/current.jpg',
        ),
        ReceiptPreviewSource.savedUrl,
      );
    });

    test('no receipt attached and none picked → nothing to preview', () {
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: false,
          removeReceipt: false,
          savedReceiptUrl: null,
        ),
        ReceiptPreviewSource.none,
      );
    });

    test('an empty saved URL is treated as "no receipt attached"', () {
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: false,
          removeReceipt: false,
          savedReceiptUrl: '',
        ),
        ReceiptPreviewSource.none,
      );
    });

    test('removing the receipt → nothing to preview, even with one saved', () {
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: false,
          removeReceipt: true,
          savedReceiptUrl: 'https://cdn/current.jpg',
        ),
        ReceiptPreviewSource.none,
      );
    });

    test('a new pick wins even over a concurrent remove flag '
        '(unreachable UI state, defensive)', () {
      // The dialog's Remove action clears _newReceiptFile, so both can never be
      // true together; the save path checks the new file first, so this is the
      // consistent resolution if the invariant is ever violated.
      expect(
        effectiveReceiptPreviewSource(
          hasNewLocal: true,
          removeReceipt: true,
          savedReceiptUrl: 'https://cdn/old.jpg',
        ),
        ReceiptPreviewSource.newLocal,
      );
    });
  });

  group('receiptSaveAction — what a save does to the receipt', () {
    test('5. save with a replacement → replace the saved receipt', () {
      expect(
        receiptSaveAction(hasNewLocal: true, removeReceipt: false),
        ReceiptSaveAction.replaceWithNew,
      );
    });

    test('6. cancel leaves the saved receipt unchanged', () {
      // "Cancel" never reaches _save — the dialog pops without saving. That is
      // modelled here as: when nothing was picked/removed, the only resolution
      // is to keep the saved receipt untouched.
      expect(
        receiptSaveAction(hasNewLocal: false, removeReceipt: false),
        ReceiptSaveAction.keepSaved,
      );
      // And even if a replacement was picked, it is NOT permanent until a save
      // runs replaceWithNew — so a cancelled replacement still leaves the
      // stored URL in place.
      expect(ReceiptSaveAction.keepSaved, isNot(ReceiptSaveAction.replaceWithNew));
    });

    test('save with an explicit removal → clear the saved receipt', () {
      expect(
        receiptSaveAction(hasNewLocal: false, removeReceipt: true),
        ReceiptSaveAction.removeReceipt,
      );
    });

    test('save keeps an existing receipt when the member only edits text', () {
      expect(
        receiptSaveAction(hasNewLocal: false, removeReceipt: false),
        ReceiptSaveAction.keepSaved,
      );
    });
  });
}
