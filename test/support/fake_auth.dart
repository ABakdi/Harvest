import 'dart:async';

import 'package:harvest/features/security/domain/auth_gateway.dart';

/// The device's unlock prompt, faked: it answers whatever the test says
/// and can be held open to stand in for a prompt still on screen.
class FakeAuthGateway implements AuthGateway {
  /// What the next prompt answers.
  AuthOutcome outcome = AuthOutcome.unlocked;

  /// Whether the device has anything to check against at all.
  bool available = true;

  /// Holds [authenticate] open until [release], so a test can act while
  /// the prompt is still up.
  bool gate = false;

  /// How many times the prompt was actually shown.
  int calls = 0;

  final _held = Completer<void>();

  void release() {
    if (!_held.isCompleted) _held.complete();
  }

  @override
  Future<bool> canAuthenticate() async => available;

  @override
  Future<AuthOutcome> authenticate({required String reason}) async {
    calls++;
    if (gate) await _held.future;
    return outcome;
  }
}
