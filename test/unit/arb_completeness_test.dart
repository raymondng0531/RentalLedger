import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Whole-file integrity checks on the ARB sources.
///
/// `gen-l10n` is forgiving in ways that hide real defects:
///
/// * a key present in `app_en.arb` but absent from `app_ms.arb` falls back to
///   the English template, so a missing Malay translation ships silently;
/// * an empty string is a perfectly valid message, so a blank label renders as
///   a blank control with no error anywhere;
/// * a placeholder used in the message but not declared in `"placeholders"`
///   fails generation, but a placeholder *declared* and never used does not.
///
/// None of those can be caught by looking at one locale at a time, which is why
/// they are asserted here against the raw files rather than through the
/// generated class.

/// The ARB files, relative to the package root (the test runner's cwd).
const _enPath = 'lib/l10n/app_en.arb';
const _msPath = 'lib/l10n/app_ms.arb';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Message keys only — the `@key` metadata entries are stripped.
List<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toList();

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> ms;

  setUpAll(() {
    en = _read(_enPath);
    ms = _read(_msPath);
  });

  group('key parity', () {
    test('both files carry exactly the same message keys', () {
      final enKeys = _messageKeys(en);
      final msKeys = _messageKeys(ms);

      expect(
        msKeys.toSet().difference(enKeys.toSet()),
        isEmpty,
        reason: 'these keys exist only in $_msPath — app_en.arb is the template, '
            'so a key that is not in it is never generated',
      );
      expect(
        enKeys.toSet().difference(msKeys.toSet()),
        isEmpty,
        reason: 'these keys are missing from $_msPath — gen-l10n would silently '
            'ship the English string in a Malay UI',
      );
      expect(enKeys, msKeys, reason: 'same keys, same order, both files');
    });

    test('no message key is duplicated', () {
      // json.decode already collapses duplicates, so compare against the raw
      // text: a repeated key is a merge accident that would drop a translation.
      for (final path in const [_enPath, _msPath]) {
        final raw = File(path).readAsStringSync();
        final found = <String>[];
        for (final match
            in RegExp(r'^  "([^"@][^"]*)":', multiLine: true).allMatches(raw)) {
          found.add(match.group(1)!);
        }
        final duplicates = <String>{
          for (final k in found)
            if (found.where((x) => x == k).length > 1) k,
        };
        expect(duplicates, isEmpty, reason: '$path repeats these keys');
      }
    });
  });

  group('message content', () {
    test('no message is empty in either locale', () {
      for (final key in _messageKeys(en)) {
        expect((en[key] as String).trim(), isNotEmpty, reason: 'en $key');
        expect((ms[key] as String).trim(), isNotEmpty, reason: 'ms $key');
      }
    });

    test('every English key has a description', () {
      final undocumented = [
        for (final key in _messageKeys(en))
          if ((en['@$key'] as Map?)?['description'] == null) key,
      ];

      expect(undocumented, isEmpty,
          reason: 'a description is what tells a future translator what the '
              'string is for');
    });

    test('a message never embeds the product name', () {
      // 'Rental Ledger' is a proper noun and lives in AppConstants, not in a
      // translatable message. One message names it on purpose: the invite a
      // member sends to somebody outside the app has to say what they are
      // being invited to. It is carried verbatim in both locales — which is
      // the real rule — rather than translated.
      const namesProductOnPurpose = <String>{
        // The share sheet a member fills in to invite somebody: subject and
        // body both have to name the app being invited to.
        'houseShareSubject',
        'houseShareMessage',
      };

      for (final key in _messageKeys(en)) {
        if (namesProductOnPurpose.contains(key)) continue;
        expect(en[key], isNot(contains('Rental Ledger')), reason: 'en $key');
        expect(ms[key], isNot(contains('Rental Ledger')), reason: 'ms $key');
      }

      // Wherever it does appear it is the same proper noun, untranslated, in
      // both locales — never a localized rendering of the name.
      for (final key in namesProductOnPurpose) {
        expect(en[key], contains('Rental Ledger'),
            reason: '$key is allow-listed as naming the product but does not');
        expect(
          RegExp('Rental Ledger').allMatches(ms[key] as String).length,
          RegExp('Rental Ledger').allMatches(en[key] as String).length,
          reason: '$key must carry the product name verbatim in both locales',
        );
      }
    });

    test('a message never embeds a stored Firestore value as content', () {
      // Category chips and status labels are localized *through* the app's
      // vocabulary mapping, never by shipping the stored token as display text.
      const storedTokens = <String>[
        'pending',
        'approved',
        'rejected',
        'personal',
        'central',
      ];
      for (final key in _messageKeys(en)) {
        for (final token in storedTokens) {
          expect(
            en[key],
            isNot(equals(token)),
            reason: 'en $key must not be the stored value "$token"',
          );
        }
      }
    });
  });

  group('placeholders', () {
    /// Placeholder names used in a message body, e.g. `{count}`.
    Set<String> usedIn(String message) => RegExp(r'\{(\w+)[,}]')
        .allMatches(message)
        .map((m) => m.group(1)!)
        .toSet();

    /// Placeholder names declared in the key's `@` metadata.
    Set<String> declaredFor(String key) {
      final meta = en['@$key'] as Map?;
      final placeholders = meta?['placeholders'] as Map?;
      return (placeholders?.keys ?? const <String>[]).cast<String>().toSet();
    }

    test('every placeholder used in English is declared', () {
      for (final key in _messageKeys(en)) {
        final used = usedIn(en[key] as String);
        expect(used.difference(declaredFor(key)), isEmpty,
            reason: 'en $key uses undeclared placeholders');
      }
    });

    test('every placeholder used in Malay is declared in English', () {
      // Malay may legitimately use fewer placeholders (no plural branches), but
      // it must never invent one the generated API does not take.
      for (final key in _messageKeys(en)) {
        final used = usedIn(ms[key] as String);
        expect(used.difference(declaredFor(key)), isEmpty,
            reason: 'ms $key uses placeholders the generated getter will not '
                'accept');
      }
    });
  });

  group('generated lookups', () {
    late AppLocalizations enL10n;
    late AppLocalizations msL10n;

    setUpAll(() async {
      enL10n = await AppLocalizations.delegate.load(const Locale('en'));
      msL10n = await AppLocalizations.delegate.load(const Locale('ms'));
    });

    test('the generated class exposes every key in the file', () {
      // `AppLocalizations` is a normal Dart object, so its getters can be
      // enumerated — a key that failed to generate simply would not be here.
      const sample = <String>[
        'statusPending',
        'statusApproved',
        'statusRejected',
        'statusPaid',
        'statusSubmitted',
        'txnTypeDeposit',
        'txnTypeReimbursement',
        'txnTypeDirectPayment',
        'txnTypeAdjustment',
        'paymentSourcePersonal',
        'paymentSourceCentral',
        'paymentMethodCash',
        'paymentMethodBankTransfer',
        'paymentMethodEWallet',
        'paymentMethodCard',
        'categoryRent',
        'categoryUtilities',
        'categoryFood',
        'categoryHousehold',
        'categoryMaintenance',
        'categoryInternet',
        'categoryOther',
        'actionBack',
        'actionSave',
        'actionDelete',
        'actionCancel',
        'labelStatus',
        'labelCategory',
        'labelDueDate',
        'errorNetwork',
        'errorPermission',
        'errorNotFound',
        'errorAuthentication',
        'errorUnexpected',
      ];

      for (final key in sample) {
        expect(_messageKeys(en), contains(key),
            reason: '$key must exist in the template');
      }
      // Spot-check that they really resolve, in both locales.
      expect(enL10n.statusPending, 'Pending');
      expect(msL10n.statusPending, 'Menunggu');
      expect(enL10n.txnTypeDirectPayment, 'Direct Payment');
      expect(msL10n.txnTypeDirectPayment, 'Bayaran Terus');
    });

    test('no vocabulary message falls back to English by accident', () {
      // Keys whose Malay value is deliberately identical to the English one.
      // Each must be a proper noun or an established borrowing, never an
      // oversight — and every addition here is a deliberate decision.
      const identicalOnPurpose = <String, String>{
        'languageEnglish': 'a language is listed in its own language',
        'languageMalay': 'a language is listed in its own language',
        'actionDeposit': 'the ordinary word in Malaysian banking Malay',
        'txnTypeDeposit': 'the ordinary word in Malaysian banking Malay',
        'categoryInternet': 'no distinct Malay form in common use',
        'labelStatus': 'the ordinary Malay word, not a borrowing',
        'actionEdit': 'the ordinary Malay word, not a borrowing',
        'actionMenu': 'the ordinary Malay word, not a borrowing',
        'navMenu': 'the ordinary Malay word, not a borrowing',
        'expenseMenuTooltip':
            'the ordinary Malay word, not a borrowing',
      };

      final suspicious = <String>[];
      for (final key in _messageKeys(en)) {
        if (en[key] != ms[key]) continue;
        if (!identicalOnPurpose.containsKey(key)) suspicious.add(key);
      }

      expect(
        suspicious,
        isEmpty,
        reason: 'these keys read identically in both locales — translate them '
            'in app_ms.arb, or record why they are the same',
      );

      // Guard against the allow-list drifting out of date: every entry must
      // actually still be identical in both files, or it is dead weight that
      // would silently excuse a future missing translation.
      for (final key in identicalOnPurpose.keys) {
        expect(en[key], ms[key],
            reason: '$key is allow-listed as identical but is not');
      }
    });
  });
}
