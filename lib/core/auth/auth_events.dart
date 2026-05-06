import 'dart:async';

/// Minimalni kanal za događaje autentikacije (npr. prisilni logout na 401).
class AuthEvents {
  AuthEvents._();

  static final AuthEvents instance = AuthEvents._();

  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get stream => _controller.stream;

  void emit(AuthEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }
}

sealed class AuthEvent {
  const AuthEvent();
}

class AuthEventForceLogout extends AuthEvent {
  const AuthEventForceLogout({this.message});

  final String? message;
}

