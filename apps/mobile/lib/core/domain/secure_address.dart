/// Whether [url] may carry a password, a token, a key share or an API
/// key (S6-12). Android's cleartext rule does not cover Dart's own HTTP
/// client, so the app says it itself: `https://` anywhere, plain
/// `http://` only to this device or the emulator's host.
bool isSecureAddress(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  if (uri.isScheme('https')) return true;
  return uri.isScheme('http') && localHosts.contains(uri.host);
}

/// The hosts plain `http://` may reach: this device, and the machine an
/// emulator runs on.
const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
