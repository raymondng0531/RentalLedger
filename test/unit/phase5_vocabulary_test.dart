import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/constants/firestore_constants.dart';
import 'package:rental_ledger/core/utils/vocabulary_labels.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 5 — the stored vocabulary is *displayed* localized and *stored* in
/// English.
///
/// Two things are proved separately, and they are different in kind:
///
/// 1. **The mapping.** Every stored token the app can hold resolves to the right
///    label in both locales.
/// 2. **The non-mutation.** The stored constants themselves are unchanged. This
///    is the phase's hard rule: a localization pass must not quietly rewrite the
///    strings that Firestore rules, queries and Cloud Functions depend on.

late AppLocalizations _en;
late AppLocalizations _ms;

void main() {
  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
    _ms = await AppLocalizations.delegate.load(const Locale('ms'));
  });

  group('the stored values are untouched', () {
    test('expense statuses are still the bare lowercase tokens', () {
      // These are compared against in `expense_provider`, written by the
      // Treasurer flow, and read by the security rules. If a localization pass
      // ever "helpfully" translated one, every query would silently stop
      // matching.
      expect(FirestoreConstants.statusPending, 'pending');
      expect(FirestoreConstants.statusApproved, 'approved');
      expect(FirestoreConstants.statusRejected, 'rejected');
      expect(FirestoreConstants.statusPaid, 'paid');
    });

    test('transaction types are still the stored English nouns', () {
      expect(FirestoreConstants.transactionDeposit, 'Deposit');
      expect(FirestoreConstants.transactionReimbursement, 'Reimbursement');
      expect(FirestoreConstants.transactionDirectPayment, 'Direct Payment');
      expect(FirestoreConstants.transactionAdjustment, 'Adjustment');
    });

    test('roles and payment sources are unchanged', () {
      expect(FirestoreConstants.roleTreasurer, 'Treasurer');
      expect(FirestoreConstants.roleMember, 'Member');
      expect(FirestoreConstants.paymentPersonal, 'personal');
      expect(FirestoreConstants.paymentCentral, 'central');
    });

    test('the seeded category names are unchanged', () {
      // `CategoryEntity.defaults` is what gets *written* to a new house.
      final byId = {
        for (final c in CategoryEntity.defaults) c.categoryId: c.name,
      };
      expect(byId, {
        'rent': 'Rent',
        'utilities': 'Utilities',
        'food': 'Food',
        'household': 'Household',
        'maintenance': 'Maintenance',
        'internet': 'Internet',
        'other': 'Other',
      });
    });

    test('a stored token is never equal to its localized label', () {
      // The regression guard for the whole phase: if a mapping function ever
      // returned the stored value for a *translatable* token, the UI would show
      // English in a Malay session.
      expect(FirestoreConstants.statusPending, isNot(_ms.statusPending));
      expect(FirestoreConstants.statusApproved, isNot(_ms.statusApproved));
      expect(FirestoreConstants.statusRejected, isNot(_ms.statusRejected));
      expect(FirestoreConstants.statusPaid, isNot(_ms.statusPaid));
      expect(
          FirestoreConstants.transactionReimbursement, isNot(_ms.txnTypeReimbursement));
      expect(FirestoreConstants.transactionDirectPayment,
          isNot(_ms.txnTypeDirectPayment));
      expect(FirestoreConstants.transactionAdjustment, isNot(_ms.txnTypeAdjustment));
    });
  });

  group('status labels', () {
    test('activity card labels — English', () {
      expect(VocabularyLabels.activityStatus('paid', _en), 'Paid');
      expect(VocabularyLabels.activityStatus('approved', _en), 'Approved');
      expect(VocabularyLabels.activityStatus('rejected', _en), 'Rejected');
    });

    test('a pending expense reads "Submitted" on a card, as it always has', () {
      // The card describes what the member did; the badge on the detail page
      // names the state. Both wordings are preserved, not invented.
      expect(VocabularyLabels.activityStatus('pending', _en), 'Submitted');
      expect(VocabularyLabels.activityStatus(null, _en), 'Submitted');
    });

    test('the same statuses in Malay', () {
      expect(VocabularyLabels.activityStatus('paid', _ms), 'Dibayar');
      expect(VocabularyLabels.activityStatus('approved', _ms), 'Diluluskan');
      expect(VocabularyLabels.activityStatus('rejected', _ms), 'Ditolak');
      expect(VocabularyLabels.activityStatus('pending', _ms), 'Dihantar');
    });

    test('badge labels name the state itself', () {
      expect(VocabularyLabels.statusBadge('pending', _en), 'Pending');
      expect(VocabularyLabels.statusBadge('approved', _en), 'Approved');
      expect(VocabularyLabels.statusBadge('rejected', _en), 'Rejected');
      expect(VocabularyLabels.statusBadge('paid', _en), 'Paid');

      expect(VocabularyLabels.statusBadge('pending', _ms), 'Menunggu');
      expect(VocabularyLabels.statusBadge('paid', _ms), 'Dibayar');
    });

    test('an unknown status falls through to the stored value', () {
      // Never invent a label for something the app does not recognise; showing
      // the raw value is honest and localizable later.
      expect(VocabularyLabels.statusBadge('escalated', _en), 'escalated');
      expect(VocabularyLabels.statusBadge(null, _en), '');
    });

    test('the badge label is never the stored token', () {
      for (final status in const ['pending', 'approved', 'rejected', 'paid']) {
        expect(VocabularyLabels.statusBadge(status, _ms), isNot(status));
      }
    });
  });

  group('transaction types', () {
    test('English', () {
      expect(VocabularyLabels.transactionType('Deposit', _en), 'Deposit');
      expect(VocabularyLabels.transactionType('Reimbursement', _en),
          'Reimbursement');
      expect(VocabularyLabels.transactionType('Direct Payment', _en),
          'Direct Payment');
      expect(VocabularyLabels.transactionType('Adjustment', _en), 'Adjustment');
    });

    test('Malay', () {
      expect(VocabularyLabels.transactionType('Deposit', _ms), 'Deposit');
      expect(VocabularyLabels.transactionType('Reimbursement', _ms),
          'Bayaran Balik');
      expect(VocabularyLabels.transactionType('Direct Payment', _ms),
          'Bayaran Terus');
      expect(VocabularyLabels.transactionType('Adjustment', _ms), 'Pelarasan');
    });

    test('a user-authored purpose is shown exactly as stored', () {
      // The transaction `purpose` field can hold free text the user typed.
      expect(VocabularyLabels.transactionType('Monthly Rental', _ms),
          'Monthly Rental');
      expect(VocabularyLabels.transactionType(null, _en), '');
    });
  });

  group('payment source and method', () {
    test('source — both locales', () {
      expect(VocabularyLabels.paymentSource('personal', _en), 'Personal');
      expect(VocabularyLabels.paymentSource('central', _en), 'Central Account');
      expect(VocabularyLabels.paymentSource('personal', _ms), 'Peribadi');
      expect(VocabularyLabels.paymentSource('central', _ms), 'Akaun Pusat');
    });

    test('method — the stored token is never changed, only its label', () {
      const stored = ['Cash', 'Bank Transfer', 'e-Wallet', 'Card'];
      for (final method in stored) {
        expect(VocabularyLabels.paymentMethod(method, _ms), isNot(method),
            reason: '$method must translate in Malay');
      }
      expect(VocabularyLabels.paymentMethod('Cash', _en), 'Cash');
      expect(VocabularyLabels.paymentMethod('Cash', _ms), 'Tunai');
      expect(VocabularyLabels.paymentMethod('Bank Transfer', _ms),
          'Pindahan Bank');
      expect(VocabularyLabels.paymentMethod('e-Wallet', _ms), 'e-Dompet');
      expect(VocabularyLabels.paymentMethod('Card', _ms), 'Kad');
    });

    test('an unrecognised method is echoed, not dropped', () {
      expect(VocabularyLabels.paymentMethod('Cheque', _en), 'Cheque');
      expect(VocabularyLabels.paymentMethod(null, _en), '');
    });
  });

  group('roles', () {
    test('Treasurer and Member translate for display', () {
      expect(VocabularyLabels.role('Treasurer', _en), 'Treasurer');
      expect(VocabularyLabels.role('Member', _en), 'Member');
      expect(VocabularyLabels.role('Treasurer', _ms), 'Bendahari');
      expect(VocabularyLabels.role('Member', _ms), 'Ahli');
    });

    test('the stored role is never the displayed Malay label', () {
      expect(VocabularyLabels.role(FirestoreConstants.roleTreasurer, _ms),
          isNot(FirestoreConstants.roleTreasurer));
    });
  });

  group('categories', () {
    test('a default category shows its localized label', () {
      expect(VocabularyLabels.category(l10n: _en, categoryId: 'rent', name: 'Rent'),
          'Rent');
      expect(VocabularyLabels.category(l10n: _ms, categoryId: 'rent', name: 'Rent'),
          'Sewa');
      expect(
          VocabularyLabels.category(l10n: _ms, categoryId: 'food', name: 'Food'),
          'Makanan');
      expect(
          VocabularyLabels.category(
              l10n: _ms, categoryId: 'maintenance', name: 'Maintenance'),
          'Penyelenggaraan');
    });

    test('every seeded default translates in Malay', () {
      for (final c in CategoryEntity.defaults) {
        final label = VocabularyLabels.category(
            l10n: _ms, categoryId: c.categoryId, name: c.name);
        if (c.name == 'Internet') continue; // deliberately identical
        expect(label, isNot(c.name), reason: '${c.name} must translate');
      }
    });

    test("a category the user renamed is shown with the user's own text", () {
      // The phase's explicit rule: never overwrite or "correct" user data.
      expect(
        VocabularyLabels.category(
            l10n: _ms, categoryId: 'rent', name: 'Sewa Rumah Kita'),
        'Sewa Rumah Kita',
      );
      expect(
        VocabularyLabels.category(
            l10n: _en, categoryId: 'food', name: 'Groceries'),
        'Groceries',
      );
    });

    test('a custom category with no known id is shown verbatim', () {
      expect(
        VocabularyLabels.category(
            l10n: _ms, categoryId: 'abc123', name: 'Pet Insurance'),
        'Pet Insurance',
      );
    });

    test('a renamed default is not re-translated by its stored name', () {
      // The stored name is still 'Rent' here (the rename is by id in this
      // fixture) — so the default label is correct. But once the name differs
      // from the seeded one, the user's text wins.
      expect(
        VocabularyLabels.category(l10n: _ms, categoryId: 'rent', name: 'Rent'),
        'Sewa',
      );
      expect(
        VocabularyLabels.category(
            l10n: _ms, categoryId: 'rent', name: 'Rent (upstairs)'),
        'Rent (upstairs)',
      );
    });

    test('a name-only lookup still recognizes a default', () {
      // Some call sites only carry the name map, not the ids.
      expect(VocabularyLabels.category(l10n: _ms, name: 'Utilities'), 'Utiliti');
      expect(VocabularyLabels.category(l10n: _ms, name: 'Other'), 'Lain-lain');
    });

    test('categoryOrNull yields null rather than an empty label', () {
      expect(VocabularyLabels.categoryOrNull(l10n: _en), isNull);
      expect(VocabularyLabels.categoryOrNull(l10n: _en, categoryId: 'rent'),
          'Rent');
      expect(VocabularyLabels.categoryOrNull(l10n: _ms, name: 'Other'),
          'Lain-lain');
    });
  });

  group('locale independence', () {
    test('a mapping never mutates process-global intl state', () {
      VocabularyLabels.activityStatus('paid', _ms);
      VocabularyLabels.category(l10n: _ms, categoryId: 'rent', name: 'Rent');
      expect(VocabularyLabels.activityStatus('paid', _en), 'Paid');
    });

    test('the same call in two locales is stable and repeatable', () {
      expect(VocabularyLabels.paymentMethod('Card', _ms), 'Kad');
      expect(VocabularyLabels.paymentMethod('Card', _en), 'Card');
      expect(VocabularyLabels.paymentMethod('Card', _ms), 'Kad');
    });
  });
}
