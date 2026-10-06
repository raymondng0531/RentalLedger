/// Base exception class for infrastructure-level errors.
///
/// These are caught by repositories and converted into [Failure] objects
/// so that presentation layers never deal with raw exceptions.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.arguments});

  final String message;
  final String? code;

  /// Values a rendered message needs, keyed by the `FailureCodes.arg*`
  /// constants — see `Failure.arguments`. The [message] stays as the
  /// developer-facing English text; a repository copies this map onto the
  /// `Failure` it builds so the presentation layer can compose the sentence.
  final Map<String, Object?>? arguments;

  @override
  String toString() => message;
}

/// Exception thrown when a Firebase operation fails.
class AppFirebaseException extends AppException {
  const AppFirebaseException(super.message, {super.code});
}

/// Exception thrown when there is no network.
class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection.']);
}

/// Exception thrown when authentication fails.
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

/// Exception thrown when a cache operation fails.
class CacheException extends AppException {
  const CacheException(super.message);
}

/// Exception thrown when input validation fails.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.arguments});
}

/// Exception thrown when a write is refused because the record is no longer in
/// the state the operation requires.
///
/// This is the data layer's concurrency boundary. Two clients racing the same
/// transition — a double-tapped Approve, a stale browser tab reimbursing an
/// expense that was already paid — must not both succeed, and the loser must
/// fail with a message explaining why rather than silently no-op or, worse,
/// write a second time.
class ConflictException extends AppException {
  const ConflictException(super.message, {super.code, super.arguments});
}
