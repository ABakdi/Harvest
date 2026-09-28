import 'package:harvest/core/platform/secret_store.dart';

/// The Keystore, in a map.
class MemorySecrets implements SecretStore {
  final values = <String, String>{};

  /// Set to make every write fail quietly, as the Keystore can.
  bool dropWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (dropWrites) return;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
