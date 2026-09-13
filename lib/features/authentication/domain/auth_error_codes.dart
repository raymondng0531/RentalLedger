/// Stable, machine-readable codes for authentication failures.
///
/// ## Why this exists
///
/// `LoginPage` has to tell one failure apart from the others for a special
/// reason: when the user dismisses the Google sheet, nothing should be shown at
/// all. A cancelled sign-in is not an error the user needs to be told about —
/// they are the one who cancelled it.
///
/// That decision used to be made by comparing the *display string*:
///
/// ```dart
/// } else if (errorMessage != 'Sign in cancelled.') {
/// ```
///
/// which made a piece of control flow depend on English prose. Translating the
/// message into Malay would have silently broken it — the comparison would stop
/// matching, the snackbar would appear after every cancellation, and nothing
/// would fail to compile or fail a test. Any future rewording ("Sign-in
/// cancelled", a trailing full stop removed) carried the same risk.
///
/// Comparing a code instead decouples the two: the code is the contract, the
/// message is free to be translated and reworded. This mirrors how
/// `AppException.code` / `Failure.code` were already designed — the field
/// existed but was unused on this path, so this wires up what was already
/// there rather than adding a new mechanism.
class AuthErrorCodes {
  const AuthErrorCodes._();

  /// The user dismissed the provider's sign-in sheet.
  ///
  /// Not a failure to report: the caller suppresses the message entirely and
  /// leaves the user on the login page.
  static const String cancelled = 'auth/cancelled';

  // ───── Firebase Auth error codes ─────
  //
  // A failure's `message` is a *fallback*, never what the user reads: Firebase's
  // own error text must not be shown raw, and the app's English sentences must
  // not be shown in a Malay session. The data layer therefore attaches one of
  // these codes to every failure it maps, and the presentation layer turns the
  // code into a localized string (`localizeAuthError` in auth_provider.dart).
  //
  // The values are Firebase's own error codes verbatim (`auth/…`), so a code
  // raised by the SDK can be traced straight back to the case that mapped it.

  /// `invalid-email` — the address is not a valid email.
  static const String invalidEmail = 'auth/invalid-email';

  /// `user-disabled` — the account has been disabled by an administrator.
  static const String userDisabled = 'auth/user-disabled';

  /// `user-not-found` — no account exists for this email.
  static const String userNotFound = 'auth/user-not-found';

  /// `wrong-password` / `invalid-credential` — the credentials did not match.
  ///
  /// Both Firebase codes mean the same thing to the user, and mapping them to
  /// one code keeps them from drifting into two different sentences.
  static const String wrongPassword = 'auth/wrong-password';

  /// `invalid-credential` — see [wrongPassword].
  static const String invalidCredential = 'auth/invalid-credential';

  /// `email-already-in-use` — registration for an email that already has one.
  static const String emailAlreadyInUse = 'auth/email-already-in-use';

  /// `operation-not-allowed` — the sign-in method is disabled in the console.
  static const String operationNotAllowed = 'auth/operation-not-allowed';

  /// `too-many-requests` — Firebase rate-limited the attempt.
  static const String tooManyRequests = 'auth/too-many-requests';

  /// `weak-password` — Firebase rejected the password as too weak.
  static const String weakPassword = 'auth/weak-password';

  /// `invalid-action-code` — the reset code is not (or no longer) usable.
  static const String invalidActionCode = 'auth/invalid-action-code';

  /// `expired-action-code` — the reset code was valid but has since expired.
  static const String expiredActionCode = 'auth/expired-action-code';

  /// `network-request-failed` — the request never reached Firebase.
  static const String networkRequestFailed = 'auth/network-request-failed';

  /// `requires-recent-login` — the operation needs a fresh sign-in.
  static const String requiresRecentLogin = 'auth/requires-recent-login';

  // ───── App-local codes (no Firebase equivalent) ─────

  /// The reset page was opened without an action code in the link.
  static const String missingActionCode = 'auth/missing-action-code';

  /// Validating the action code failed for a reason that was not a Firebase
  /// error (so it carries no Firebase code of its own).
  static const String verifyLinkFailed = 'auth/verify-link-failed';

  /// Anything unmapped or unexpected — shown as the generic error sentence.
  static const String unexpected = 'auth/unexpected';

  /// The app is running without a Firebase configuration, so auth cannot work.
  static const String notConfigured = 'auth/not-configured';
}
