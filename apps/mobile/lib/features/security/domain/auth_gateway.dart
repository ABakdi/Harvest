import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_gateway.g.dart';

/// What the device answered when asked to prove who is holding it.
enum AuthOutcome {
  /// The right person; lift the shield.
  unlocked,

  /// Wrong finger, cancelled, or a system interruption — stay locked
  /// and let them try again.
  refused,

  /// The device has no fingerprint, PIN, pattern or password set, so
  /// there is nothing to check against (checkpoint rule L5).
  noCredentials,

  /// Too many failed tries; the OS is holding the door shut for a bit.
  lockedOut,

  /// The prompt itself could not be shown.
  unavailable,
}

/// The device's own unlock prompt, behind an interface.
///
/// The lock's rules are worth testing and a real fingerprint is not
/// available to a test, so — like `NotificationGateway` — the plugin
/// sits behind this and the phase machine talks to the interface.
abstract interface class AuthGateway {
  /// Whether this device can check anything at all: a biometric, or a
  /// PIN/pattern/password to fall back on.
  Future<bool> canAuthenticate();

  /// Shows the device's prompt. [reason] is the line the OS displays.
  Future<AuthOutcome> authenticate({required String reason});
}

/// [AuthGateway] over `local_auth`.
class LocalAuthGateway implements AuthGateway {
  LocalAuthGateway([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      // `isDeviceSupported` is the one that counts: it is true when
      // there is a biometric *or* a device credential to fall back on,
      // which is exactly the promise the setting makes.
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<AuthOutcome> authenticate({required String reason}) async {
    try {
      // biometricOnly stays false on purpose: whatever the phone
      // accepts to unlock itself, Harvest accepts here (rule L2).
      final ok = await _auth.authenticate(localizedReason: reason);
      return ok ? AuthOutcome.unlocked : AuthOutcome.refused;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware => AuthOutcome.noCredentials,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => AuthOutcome.lockedOut,
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          AuthOutcome.unavailable,
        // Cancelled, timed out, already running, or a device error:
        // none of them are a reason to open the door.
        _ => AuthOutcome.refused,
      };
    } on Object {
      return AuthOutcome.refused;
    }
  }
}

@Riverpod(keepAlive: true)
AuthGateway authGateway(Ref ref) => LocalAuthGateway();
