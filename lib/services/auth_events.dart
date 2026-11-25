import 'dart:async';

/// Why the signed-in state of the active host may have changed.
enum AuthEvent {
  /// A request got 401: the stored token is no longer valid.
  unauthorized,

  /// A login, registration or manual token was stored.
  signedIn,

  /// The rider logged out.
  signedOut,

  /// The rider asked for the login screen (phone, after skipping it).
  loginRequested,
}

/// App-wide signal bus for session changes (D-122). The clients report a 401
/// here without knowing about screens; `AuthGate` listens and returns to the
/// login screen.
class AuthEvents {
  AuthEvents._();

  static final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  static Stream<AuthEvent> get stream => _controller.stream;

  static void emit(AuthEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Called by every client on a 401 response.
  static void reportUnauthorized() => emit(AuthEvent.unauthorized);
}
