import '../../l10n/generated/app_localizations.dart';
import '../errors/failure_codes.dart';
import '../errors/failures.dart';
import 'currency_utils.dart';

export '../errors/failure_codes.dart';

/// Turns a [Failure] into text a user can read, in their own language.
///
/// This is deliberately a **presentation-layer** concern and lives here rather
/// than on [Failure] itself: the domain, data and Firebase layers must never
/// hold a `BuildContext` or an [AppLocalizations], so a failure carries a
/// machine-readable [Failure.code] (and a developer-facing English
/// `message`) and the mapping to localized prose happens at the edge, where
/// the locale is known.
///
/// Resolution order:
/// 1. a known [Failure.code] → the matching localized message;
/// 2. [ValidationFailure] → its own message, which is authored at the call
///    site and is therefore already localized;
/// 3. otherwise → a localized message chosen by the failure's *type*, so an
///    unrecognised backend error still reads as plain language rather than
///    leaking an English exception string to the user.
class FailureMessages {
  FailureMessages._();

  /// The message to show the user for [failure].
  static String of(Failure failure, AppLocalizations l10n) {
    final byCode = forCode(failure.code, l10n, failure.arguments);
    if (byCode != null) return byCode;

    // A code this layer does not recognise still must not leak English prose,
    // so anything coded that is not a form-authored validation message is
    // described generically rather than passed through.
    if (failure.code != null && failure is! ValidationFailure) {
      return l10n.errorUnexpected;
    }

    return switch (failure) {
      // Validation copy is written where the rule is enforced — by the form
      // that owns the field — so it is already localized, and it is the only
      // text that tells the user which field to fix.
      ValidationFailure() => failure.message,
      NetworkFailure() => l10n.errorNetwork,
      OfflineFailure() => l10n.errorOffline,
      PermissionFailure() => l10n.errorPermission,
      NotFoundFailure() => l10n.errorNotFound,
      AuthenticationFailure() => l10n.errorAuthentication,
      FirebaseFailure() => l10n.errorUnexpected,
      UnknownFailure() => l10n.errorUnexpected,
    };
  }

  /// The localized message for a stable failure [code], or null when the code
  /// is absent or not one this layer knows about.
  ///
  /// Codes are never localized themselves — they are the stable contract
  /// between the layer that detects a problem and the layer that describes it.
  static String? forCode(
    String? code,
    AppLocalizations l10n, [
    Map<String, Object?>? arguments,
  ]) {
    switch (code) {
      case FailureCodes.network:
        return l10n.errorNetwork;
      case FailureCodes.offline:
        return l10n.errorOffline;
      case FailureCodes.permission:
        return l10n.errorPermission;
      case FailureCodes.notFound:
        return l10n.errorNotFound;
      case FailureCodes.authentication:
        return l10n.errorAuthentication;
      case FailureCodes.loadFailed:
        return l10n.errorLoadFailed;
      case FailureCodes.saveFailed:
        return l10n.errorSaveFailed;
      case FailureCodes.unexpected:
        return l10n.errorUnexpected;
      case FailureCodes.actionFailed:
        return l10n.errorActionFailed;
      case FailureCodes.noHouse:
        return l10n.errorNoHouse;
      case FailureCodes.notSignedIn:
        return l10n.errorNotSignedIn;
      case FailureCodes.billCreateFailed:
        return l10n.errorBillCreateFailed;

      // --- Refused financial transitions --------------------------------
      //
      // The sentences these replace are written inside Firestore transaction
      // bodies and interpolate a stored status token ("its current status is
      // \"approved\""), so they can neither be localized there nor shown here.
      // The refusal still carries its figures, which is why the balance case
      // can name both amounts in the user's own number format.
      case FailureCodes.insufficientBalance:
        return l10n.errorInsufficientBalance(
          _money(arguments?[FailureCodes.argAmount], l10n),
          _money(arguments?[FailureCodes.argBalance], l10n),
        );
      case FailureCodes.alreadyReviewed:
        return l10n.errorExpenseAlreadyReviewed;
      case FailureCodes.notAwaitingReimbursement:
        return l10n.errorExpenseNotAwaitingReimbursement;
      case FailureCodes.billAlreadyPaid:
        return l10n.errorBillAlreadyPaid;
      case FailureCodes.recordMissing:
        return l10n.errorRecordMissing;

      // --- House membership ---------------------------------------------
      case FailureCodes.houseAlreadyMember:
        return l10n.houseAlreadyMember;
      case FailureCodes.houseInvalidCode:
        return l10n.houseJoinInvalidCode;

      // Raw Firebase / Firestore codes, so a `FirebaseFailure` that already
      // carries one is described accurately instead of falling through to the
      // generic message. The code itself is never shown.
      case 'permission-denied':
        return l10n.errorPermission;
      case 'unavailable':
      case 'network-request-failed':
        return l10n.errorNetwork;
      case 'not-found':
        return l10n.errorNotFound;
      case 'unauthenticated':
      case 'requires-recent-login':
        return l10n.errorAuthentication;

      default:
        return null;
    }
  }

  /// The message to show for the value a notifier handed back.
  ///
  /// A notifier returns either a stable code (when one describes the failure)
  /// or its own already-displayable text, so the screen accepts both: a code is
  /// translated here, and anything else is shown as it stands.
  static String forError(String? value, AppLocalizations l10n) =>
      forCode(value, l10n) ?? value ?? l10n.errorUnexpected;

  /// Whether [code] is one this layer can turn into a sentence.
  ///
  /// Locale-free on purpose: a notifier that has no `BuildContext` uses this to
  /// decide whether to hand a code up to the screen or fall back to its own
  /// text. A code is only passed up when the screen can describe it, so a raw
  /// slug can never reach the user.
  static bool canDescribe(String? code) =>
      code != null && FailureCodes.describable.contains(code);

  /// Renders an argument that should be a currency figure.
  ///
  /// A missing or non-numeric argument degrades to zero rather than throwing:
  /// this runs while a screen is being built, and a malformed argument must not
  /// turn a refusal message into a crash.
  static String _money(Object? value, AppLocalizations l10n) =>
      CurrencyUtils.format(
        value is num ? value.toDouble() : 0,
        localeCode: l10n.localeName,
      );
}
