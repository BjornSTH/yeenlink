import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/codec/codec.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/protocol/handshake.dart';

/// Общие векторы входа (testdata/vectors/auth) — те же проверяет
/// server/pkg/protocol.
final Map<String, dynamic> v =
    jsonDecode(File('../testdata/vectors/auth/auth.json').readAsStringSync())
        as Map<String, dynamic>;

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
]);

String _toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List f(String k) => _hex(v[k] as String);
Uint8List key(String k) => _hex((v['keys'] as Map<String, dynamic>)[k] as String);

void main() {
  test('подписываемые байты и подпись клиента — как в Go', () async {
    expect(_toHex(certHash(f('tls_cert_der'))), v['tls_cert_hash']);
    final ts = v['ts'] as int;
    expect(
      _toHex(serverPreimage(f('client_nonce'), f('nonce'), ts, f('tls_cert_hash'))),
      v['server_preimage'],
    );
    expect(_toHex(clientPreimage(f('nonce'), key('server_pub'), ts)), v['client_preimage']);
    expect(
      _toHex(await signAuth(key('device_seed'), f('nonce'), key('server_pub'), ts)),
      v['client_sig'],
    );
  });

  test('кадр hello совпадает с Go байт в байт', () async {
    final hello = helloPayload(
      masterPub: key('master_pub'),
      devicePub: key('device_pub'),
      deviceCert: f('device_cert'),
      clientNonce: f('client_nonce'),
    );
    expect(_toHex(Frame(Op.hello, id: 1, data: hello).encode()), v['frame_hello']);
    final fromGo = Frame.decode(f('frame_hello_resume')).decodeD()! as Map<String, Object?>;
    final r = fromGo['resume']! as Map<String, Object?>;
    expect(r['last_event'], 42);
    final again = helloPayload(
      masterPub: key('master_pub'),
      devicePub: key('device_pub'),
      deviceCert: f('device_cert'),
      clientNonce: f('client_nonce'),
      resume: (session: r['session']! as Uint8List, lastEvent: 42),
    );
    expect(_toHex(Frame(Op.hello, id: 1, data: again).encode()), v['frame_hello_resume']);
  });

  test('сертификат устройства и server_info из векторов', () async {
    final cert = await openDeviceCert(Signed.decode(f('device_cert')), key('master_pub'));
    expect(_toHex(cert.devicePub), (v['keys'] as Map)['device_pub']);
    await expectLater(
      openDeviceCert(Signed.decode(f('device_cert_foreign')), key('master_pub')),
      throwsA(
        isA<IdentityException>().having((e) => e.error, 'error', IdentityError.signerMismatch),
      ),
    );
    final info = await openServerInfo(Signed.decode(f('server_info')));
    expect(_toHex(info.serverPub), (v['keys'] as Map)['server_pub']);
    expect(info.name, 'Ночной привал');
  });

  for (final c in (v['challenge_cases'] as List).cast<Map<String, dynamic>>()) {
    test('challenge: ${c['name']}', () async {
      final ch = Challenge.fromMap(
        ylDecode(_hex(c['challenge'] as String))! as Map<String, Object?>,
      );
      final seen = c['seen_cert_hash'] == null ? null : _hex(c['seen_cert_hash'] as String);
      String got;
      try {
        final unbound = await verifyChallenge(
          ch,
          pinnedServerPub: _hex(c['pinned_server_pub'] as String),
          clientNonce: f('client_nonce'),
          seenCertHash: seen,
        );
        got = unbound ? 'unbound' : 'ok';
      } on ChallengeException catch (e) {
        got = e.error == ChallengeError.wrongServer ? 'wrong_server' : 'cert_not_signed';
      }
      expect(got, c['expect']);
    });
  }
}
