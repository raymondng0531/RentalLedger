import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Groups all authentication use cases in one file since
/// each one is a thin delegation to the repository.
///
/// Use cases exist to satisfy Clean Architecture and provide
/// a place for business logic to grow without bloating providers.

// ───── Login ─────

/// Use case for signing in with email and password.
class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<UserEntity> call(String email, String password) {
    return _repository.login(email, password);
  }
}

// ───── Register ─────

/// Use case for creating a new account.
class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  Future<UserEntity> call(String email, String password, String displayName) {
    return _repository.register(email, password, displayName);
  }
}

// ───── Logout ─────

/// Use case for signing out.
class LogoutUseCase {
  const LogoutUseCase(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}

// ───── Forgot Password ─────

/// Use case for sending a password reset email.
class ForgotPasswordUseCase {
  const ForgotPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<void> call(String email) => _repository.forgotPassword(email);
}
