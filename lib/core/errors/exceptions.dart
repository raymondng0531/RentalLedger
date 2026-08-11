/// Base exception class for infrastructure-level errors.
///
/// These are caught by repositories and converted into [Failure] objects
/// so that presentation layers never deal with raw exceptions.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;
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
  const ValidationException(super.message);
}
