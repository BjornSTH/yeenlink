import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/net/server_address.dart';

void main() {
  test('разбор адресов', () {
    final cases = {
      'chat.example.org': const ServerAddress('chat.example.org', 443),
      '  Chat.Example.org:8443 ': const ServerAddress('chat.example.org', 8443),
      'https://chat.example.org/ws': const ServerAddress('chat.example.org', 443),
      '203.0.113.7:8443': const ServerAddress('203.0.113.7', 8443),
      '[2001:db8::1]:8443': const ServerAddress('2001:db8::1', 8443),
      '2001:db8::1': const ServerAddress('2001:db8::1', 443),
      'localhost:18443#a0d2·5f11·0c3e·99ab': const ServerAddress(
        'localhost',
        18443,
        fingerprint: 'A0D2·5F11·0C3E·99AB',
      ),
      'chat.example.org#A0D2:5F11:0C3E:99AB': const ServerAddress(
        'chat.example.org',
        443,
        fingerprint: 'A0D2·5F11·0C3E·99AB',
      ),
    };
    cases.forEach((input, want) => expect(ServerAddress.parse(input), want, reason: input));
  });

  test('ошибки', () {
    final cases = {
      '': AddressError.empty,
      'http://chat.example.org': AddressError.badScheme,
      'wss://chat.example.org': AddressError.badScheme,
      'chat..example.org': AddressError.badHost,
      'чат.рф': AddressError.badHost,
      '[2001:db8::1': AddressError.badHost,
      'chat.example.org:0': AddressError.badPort,
      'chat.example.org:65536': AddressError.badPort,
      'chat.example.org:08443': AddressError.badPort,
      'chat.example.org#A0D2·5F11': AddressError.badFingerprint,
      'chat.example.org#XYZ0·5F11·0C3E·99AB': AddressError.badFingerprint,
    };
    cases.forEach((input, want) {
      expect(
        () => ServerAddress.parse(input),
        throwsA(isA<AddressException>().having((e) => e.error, 'error', want)),
        reason: input,
      );
    });
  });

  test('адрес WebSocket с явным портом, и 443 тоже', () {
    for (final port in [443, 8443]) {
      final ws = ServerAddress('195.93.252.151', port).wsUri;
      expect(ws.port, port);
      expect(ws.toString(), 'wss://195.93.252.151:$port/ws');
    }
    expect(const ServerAddress('2001:db8::1', 443).wsUri.toString(), 'wss://[2001:db8::1]:443/ws');
  });

  test('authority и строка', () {
    expect(const ServerAddress('chat.example.org', 443).authority, 'chat.example.org');
    expect(const ServerAddress('2001:db8::1', 8443).authority, '[2001:db8::1]:8443');
    expect(
      const ServerAddress('h', 1, fingerprint: 'A0D2·5F11·0C3E·99AB').toString(),
      'h:1#A0D2·5F11·0C3E·99AB',
    );
  });
}
