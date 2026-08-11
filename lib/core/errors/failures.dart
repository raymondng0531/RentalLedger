/// Base failure class for application-level errors.
///
/// Every repository method returns a Result type that is either
/// a success value or a [Failure]. This prevents raw exceptions
/// from propagating to the UI layer.
sealed class Failure {
  const Failure(this.message, {this.code});

  /// Human-readable error description.
  final String message;

  /// Optional machine-readable error code for debugging.
  final String? code;
}

/// Failure when there is no network connection.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// Failure when the user is not authenticated.
class AuthenticationFailure extends Failure {
  const AuthenticationFailure([super.message = 'Authentication required.']);
}

/// Failure when the user lacks permission.
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'You do not have permission.']);
}

/// Failure when input validation fails.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Failure when a resource was not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found.']);
}

/// Failure when a Firebase service encounters an error.
class FirebaseFailure extends Failure {
  const FirebaseFailure(super.message, {super.code});
}

/// Failure when the app is offline.
class OfflineFailure extends Failure {
  const OfflineFailure([super.message = 'You are offline. Showing cached data.']);
}

/// Generic unknown failure.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
