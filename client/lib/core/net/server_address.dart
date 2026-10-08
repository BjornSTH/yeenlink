/// Адрес сервера, который вводит человек: `host`, `host:port`, `[v6]:port`,
/// по желанию с `https://` и с отпечатком ключа сервера после `#`
/// (spec/auth.md, «Первый контакт и отпечаток»).
class ServerAddress {
  const ServerAddress(this.host, this.port, {this.fingerprint});

  /// Порт по умолчанию — 443.
  static const defaultPort = 443;

  final String host;
  final int port;

  /// Отпечаток из `#…` в каноническом виде `XXXX·XXXX·XXXX·XXXX` или null.
  final String? fingerprint;

  /// `host:port` для показа и хранения (IPv6 — в скобках).
  String get authority {
    final h = host.contains(':') ? '[$host]' : host;
    return port == defaultPort ? h : '$h:$port';
  }

  Uri get baseUri => Uri(scheme: 'https', host: host, port: port);

  @override
  String toString() => fingerprint == null ? authority : '$authority#$fingerprint';

  @override
  bool operator ==(Object other) =>
      other is ServerAddress &&
      other.host == host &&
      other.port == port &&
      other.fingerprint == fingerprint;

  @override
  int get hashCode => Object.hash(host, port, fingerprint);

  /// Разбирает ввод; ошибка — [FormatException] с причиной из [AddressError].
  static ServerAddress parse(String input) {
    var s = input.trim();
    if (s.isEmpty) throw const AddressException(AddressError.empty);
    String? fp;
    final hash = s.indexOf('#');
    if (hash >= 0) {
      fp = normalizeFingerprint(s.substring(hash + 1));
      if (fp == null) throw const AddressException(AddressError.badFingerprint);
      s = s.substring(0, hash);
    }
    final scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').firstMatch(s);
    if (scheme != null) {
      if (s.substring(0, scheme.end).toLowerCase() != 'https://') {
        throw const AddressException(AddressError.badScheme);
      }
      s = s.substring(scheme.end);
    }
    final slash = s.indexOf('/');
    if (slash >= 0) s = s.substring(0, slash);

    String host;
    String? portText;
    if (s.startsWith('[')) {
      final end = s.indexOf(']');
      if (end < 0) throw const AddressException(AddressError.badHost);
      host = s.substring(1, end);
      final rest = s.substring(end + 1);
      if (rest.isNotEmpty) {
        if (!rest.startsWith(':')) throw const AddressException(AddressError.badHost);
        portText = rest.substring(1);
      }
      if (!_isIPv6(host)) throw const AddressException(AddressError.badHost);
    } else {
      final colon = s.lastIndexOf(':');
      if (colon >= 0 && s.indexOf(':') != colon) {
        // Несколько двоеточий без скобок — голый IPv6 без порта.
        if (!_isIPv6(s)) throw const AddressException(AddressError.badHost);
        host = s.toLowerCase();
      } else {
        if (colon >= 0) {
          host = s.substring(0, colon);
          portText = s.substring(colon + 1);
        } else {
          host = s;
        }
        host = host.toLowerCase();
        if (!_isHostname(host)) throw const AddressException(AddressError.badHost);
      }
    }
    var port = defaultPort;
    if (portText != null) {
      final p = int.tryParse(portText);
      if (p == null || p < 1 || p > 65535 || portText != '$p') {
        throw const AddressException(AddressError.badPort);
      }
      port = p;
    }
    return ServerAddress(host, port, fingerprint: fp);
  }

  static bool _isHostname(String h) {
    if (h.isEmpty || h.length > 253) return false;
    final label = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');
    return h.split('.').every(label.hasMatch);
  }

  static bool _isIPv6(String h) => h.contains(':') && Uri.tryParse('http://[$h]/') != null;
}

/// Почему адрес не разобран.
enum AddressError { empty, badScheme, badHost, badPort, badFingerprint }

class AddressException implements Exception {
  const AddressException(this.error);
  final AddressError error;

  @override
  String toString() => 'AddressException(${error.name})';
}

/// Отпечаток в каноническом виде `XXXX·XXXX·XXXX·XXXX`: группы через `·`,
/// `:`, пробел или без разделителей, регистр не важен. null — не отпечаток.
String? normalizeFingerprint(String input) {
  final hex = input.replaceAll(RegExp(r'[\s·:.\-]'), '').toUpperCase();
  if (!RegExp(r'^[0-9A-F]{16}$').hasMatch(hex)) return null;
  return [for (var i = 0; i < 16; i += 4) hex.substring(i, i + 4)].join('·');
}
