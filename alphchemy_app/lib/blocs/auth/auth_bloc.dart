import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class AuthEvent {
  const AuthEvent();
}

class SignInSubmitted extends AuthEvent {
  final String email;
  final String password;

  const SignInSubmitted({required this.email, required this.password});
}

class SignUpSubmitted extends AuthEvent {
  final String email;
  final String password;
  final String confirmPassword;

  const SignUpSubmitted({required this.email, required this.password, required this.confirmPassword});
}

class ResetPasswordSubmitted extends AuthEvent {
  final String email;

  const ResetPasswordSubmitted({required this.email});
}

class ChangePasswordSubmitted extends AuthEvent {
  final String password;
  final String confirmPassword;

  const ChangePasswordSubmitted({required this.password, required this.confirmPassword});
}

class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthSubmitting extends AuthState {
  const AuthSubmitting();
}

// Session established; the router redirect handles navigation.
class AuthSucceeded extends AuthState {
  const AuthSucceeded();
}

// Success without a session change; the page shows a dialog.
class AuthInfo extends AuthState {
  final String message;

  const AuthInfo({required this.message});
}

class AuthFailed extends AuthState {
  final String message;

  const AuthFailed({required this.message});
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient client;

  AuthBloc({required this.client}) : super(const AuthInitial()) {
    on<SignInSubmitted>(_onSignIn);
    on<SignUpSubmitted>(_onSignUp);
    on<ResetPasswordSubmitted>(_onResetPassword);
    on<ChangePasswordSubmitted>(_onChangePassword);
    on<SignOutRequested>(_onSignOut);
  }

  Future<void> _onSignIn(SignInSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthSubmitting());

    if (event.email.isEmpty || event.password.isEmpty) {
      _emitFailed(emit, "Email and password are required");
      return;
    }

    try {
      await client.auth.signInWithPassword(email: event.email, password: event.password);
      emit(const AuthSucceeded());
    } catch (error) {
      _emitFailed(emit, error.toString());
    }
  }

  Future<void> _onSignUp(SignUpSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthSubmitting());

    if (event.email.isEmpty || event.password.isEmpty) {
      _emitFailed(emit, "Email and password are required");
      return;
    }
    if (event.password != event.confirmPassword) {
      _emitFailed(emit, "Passwords do not match");
      return;
    }

    try {
      final response = await client.auth.signUp(email: event.email, password: event.password);
      if (response.session != null) {
        emit(const AuthSucceeded());
      } else {
        const info = AuthInfo(message: "Check your email to confirm your account");
        emit(info);
      }
    } catch (error) {
      _emitFailed(emit, error.toString());
    }
  }

  Future<void> _onResetPassword(ResetPasswordSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthSubmitting());

    if (event.email.isEmpty) {
      _emitFailed(emit, "Email is required");
      return;
    }

    try {
      final redirectTo = Uri.base.resolve("/reset-password").toString();
      await client.auth.resetPasswordForEmail(event.email, redirectTo: redirectTo);
      const info = AuthInfo(message: "Check your email for a password reset link");
      emit(info);
    } catch (error) {
      _emitFailed(emit, error.toString());
    }
  }

  Future<void> _onChangePassword(ChangePasswordSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthSubmitting());

    if (event.password.isEmpty) {
      _emitFailed(emit, "Password is required");
      return;
    }
    if (event.password != event.confirmPassword) {
      _emitFailed(emit, "Passwords do not match");
      return;
    }

    try {
      final attributes = UserAttributes(password: event.password);
      await client.auth.updateUser(attributes);
      const info = AuthInfo(message: "Password updated");
      emit(info);
    } catch (error) {
      _emitFailed(emit, error.toString());
    }
  }

  Future<void> _onSignOut(SignOutRequested event, Emitter<AuthState> emit) async {
    emit(const AuthSubmitting());

    try {
      await client.auth.signOut();
      emit(const AuthSucceeded());
    } catch (error) {
      _emitFailed(emit, error.toString());
    }
  }

  void _emitFailed(Emitter<AuthState> emit, String message) {
    final state = AuthFailed(message: message);
    emit(state);
  }
}
