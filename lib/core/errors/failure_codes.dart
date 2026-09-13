/// Stable, machine-readable identifiers for the conditions the UI has to
/// explain to a person.
///
/// A code is the contract between the layer that *detects* a condition — a
/// repository, a Firestore transaction, a Firebase call — and the presentation
/// layer that *describes* it. Neither side has to know the other's language:
/// the data layer never builds a sentence for the user, and the UI never has to
/// pattern-match on English prose to decide what to say.
///
/// This is why the codes live here rather than beside the localized strings:
/// the domain and data layers may reference [FailureCodes] without importing
/// anything from the presentation layer.
class FailureCodes {
  FailureCodes._();

  // --- Transport / platform -------------------------------------------------

  static const String network = 'error/network';
  static const String offline = 'error/offline';
  static const String permission = 'error/permission';
  static const String notFound = 'error/not-found';
  static const String authentication = 'error/authentication';
  static const String loadFailed = 'error/load-failed';
  static const String saveFailed = 'error/save-failed';
  static const String unexpected = 'error/unexpected';

  // --- Refused financial transitions ---------------------------------------

  /// A transition was refused and the data layer could not say why in a way
  /// the user could act on — the general "that did not work" case.
  static const String actionFailed = 'error/action-failed';

  /// The Central Account cannot cover the outflow.
  ///
  /// Carries `amount` and `balance` in the failure's arguments so the sentence
  /// can name both figures.
  static const String insufficientBalance = 'insufficient-balance';

  /// The record was already reviewed by somebody else.
  static const String alreadyReviewed = 'expense-already-reviewed';

  /// The record is not awaiting reimbursement, so it cannot be paid out.
  static const String notAwaitingReimbursement =
      'expense-not-awaiting-reimbursement';

  /// A bill was already paid for the period being submitted.
  static const String billAlreadyPaid = 'bill-already-paid';

  /// The record was deleted while the user was looking at it.
  static const String recordMissing = 'record-missing';

  // --- Guards whose wording predates localization ---------------------------
  //
  // These three replace sentences the notifiers used to return directly. Their
  // text is preserved exactly, so the codes exist for the sake of the layer
  // boundary rather than to change what anybody reads.

  /// An action needed an active house and none was loaded.
  static const String noHouse = 'error/no-house';

  /// An action needed a signed-in user and there was none.
  static const String notSignedIn = 'error/not-signed-in';

  /// A bill could not be created at all.
  static const String billCreateFailed = 'error/bill-create-failed';

  // --- House membership -----------------------------------------------------

  /// The join code resolved to a house the user already belongs to.
  static const String houseAlreadyMember = 'house/already-member';

  /// The join code matched no house.
  static const String houseInvalidCode = 'house/invalid-code';

  /// Argument keys carried alongside a code whose sentence names a figure.
  static const String argAmount = 'amount';
  static const String argBalance = 'balance';

  /// The codes this app defines.
  ///
  /// A layer that has no locale — a notifier deciding what to hand back to the
  /// screen, say — can use this to tell whether a code is one the presentation
  /// layer knows how to describe, without importing `AppLocalizations`.
  static const Set<String> defined = {
    network,
    offline,
    permission,
    notFound,
    authentication,
    loadFailed,
    saveFailed,
    unexpected,
    actionFailed,
    insufficientBalance,
    alreadyReviewed,
    notAwaitingReimbursement,
    billAlreadyPaid,
    recordMissing,
    houseAlreadyMember,
    houseInvalidCode,
    noHouse,
    notSignedIn,
    billCreateFailed,
  };

  /// Firebase's own codes, which reach us through `FirebaseException.code`.
  ///
  /// They are already stable identifiers, so they are described directly rather
  /// than translated into our own vocabulary.
  static const Set<String> firebase = {
    'permission-denied',
    'unavailable',
    'network-request-failed',
    'not-found',
    'unauthenticated',
    'requires-recent-login',
  };

  /// Every code the presentation layer can turn into a sentence.
  static const Set<String> describable = {...defined, ...firebase};
}
