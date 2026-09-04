import 'package:harvest/features/security/data/screen_guard.dart';

/// Records what the window flag was asked to do, without a window.
class FakeScreenGuard implements ScreenGuard {
  final List<bool> calls = [];

  bool? get secure => calls.isEmpty ? null : calls.last;

  @override
  Future<void> setSecure({required bool secure}) async => calls.add(secure);
}
