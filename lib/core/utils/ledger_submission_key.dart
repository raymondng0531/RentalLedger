/// The idempotency key for the money movement currently being submitted.
///
/// Every ledger write (Deposit, Direct Payment, Reimbursement) creates exactly
/// one transaction document. A repeated submission — a double tap, a retry
/// after a timeout, a flaky connection that made the user press the button
/// again — must NOT create a second one. The data source gets its idempotency
/// from the document id: writing with a key that already has a ledger row is a
/// repeat of a movement that already happened, and is ignored.
///
/// That only works if every attempt at the *same* logical submission carries
/// the *same* key. This class owns that lifecycle:
///
///   * [key] mints a key on first use and returns it for every retry until the
///     submission is known to have committed.
///   * [clear] is called only after a successful commit, so the next deposit is
///     a genuinely new movement with a fresh key.
///
/// A failed attempt deliberately keeps the key: nothing was written, so the
/// user's retry is the same submission and must not be able to produce two
/// ledger rows.
class LedgerSubmissionKey {
  /// The key currently in flight, if any.
  String? _key;

  /// Returns this submission's key, minting one with [generate] on first use.
  ///
  /// [generate] is injected rather than hard-wired to `Uuid().v4()` so the
  /// reuse behaviour is unit-testable without depending on randomness.
  String key(String Function() generate) => _key ??= generate();

  /// Whether a submission is currently in flight.
  bool get isPending => _key != null;

  /// Forgets the current key — call after the movement is committed, so the
  /// next submission is a new one.
  void clear() => _key = null;
}
