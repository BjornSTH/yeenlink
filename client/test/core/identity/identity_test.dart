import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yeenlink/core/codec/codec.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/identity/wordlist_en.dart';

/// Официальные векторы BIP39, SLIP-0010, RFC 8032 и общие векторы личности
/// (testdata/vectors) — те же проверяет server/pkg/identity.
final String _root = p.join('..', 'testdata', 'vectors');

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(p.join(_root, path)).readAsStringSync()) as Map<String, dynamic>;

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
]);

String _toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<void> _openAs(Signed s, String open, List<int> master) async {
  switch (open) {
    case 'verify':
      await s.verify();
    case SignedType.profile:
      await openProfile(s);
    case SignedType.deviceCert:
      await openDeviceCert(s, master);
    case SignedType.revoke:
      await openRevoke(s, master);
    case SignedType.devices:
      await openDevices(s, master);
    default:
      fail('неизвестный open $open');
  }
}

void main() {
  test('список BIP39 официальный', () {
    final text = '${bip39English.join('\n')}\n';
    expect(
      hash.sha256.convert(utf8.encode(text)).toString(),
      '2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda',
    );
    expect(bip39English, hasLength(2048));
  });

  test('BIP39: официальные векторы trezor', () async {
    final v = _json('bip39/vectors.json');
    final cases = (v['english'] as List).cast<List<dynamic>>();
    expect(cases, hasLength(24));
    for (final c in cases) {
      final entropy = _hex(c[0] as String);
      final mnemonic = c[1] as String;
      expect(entropyToMnemonic(entropy), mnemonic);
      expect(mnemonicToEntropy(mnemonic), entropy);
      expect(_toHex(await mnemonicToSeed(mnemonic, v['passphrase'] as String)), c[2]);
    }
  });

  test('SLIP-0010 ed25519: официальные векторы', () async {
    var n = 0;
    for (final vec
        in (_json('slip10/ed25519.json')['vectors'] as List).cast<Map<String, dynamic>>()) {
      for (final c in (vec['chains'] as List).cast<Map<String, dynamic>>()) {
        final node = SlipNode.derive(_hex(vec['seed'] as String), parsePath(c['path'] as String));
        expect(_toHex(node.chainCode), c['chain_code'], reason: c['path'] as String);
        expect(_toHex(node.key), c['private'], reason: c['path'] as String);
        expect(
          '00${_toHex(await publicKeyOf(node.key))}',
          c['public'],
          reason: c['path'] as String,
        );
        n++;
      }
    }
    expect(n, 12);
  });

  test('SLIP-0010: обычный индекс для ed25519 запрещён', () {
    expect(() => SlipNode.master(Uint8List(16)).child(0), throwsArgumentError);
  });

  test('Ed25519: RFC 8032, тест 1', () async {
    final pair = await keyPairOf(
      _hex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'),
    );
    final sig = await Ed25519().sign(const [], keyPair: pair);
    expect(
      _toHex(sig.bytes),
      'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
    );
  });

  test('ключи: фраза → те же байты, что в Go', () async {
    final f = _json('identity/keys.json');
    for (final k in (f['keys'] as List).cast<Map<String, dynamic>>()) {
      final id = await Identity.fromMnemonic('  ${(k['mnemonic'] as String).toUpperCase()} ');
      final name = k['name'] as String;
      expect(_toHex(id.entropy), k['entropy'], reason: name);
      expect(_toHex(await mnemonicToSeed(id.mnemonic)), k['seed'], reason: name);
      expect(_toHex(id.masterSeed), k['master_seed'], reason: name);
      expect(_toHex(id.masterPub), k['master_pub'], reason: name);
      expect(fingerprint(id.masterPub), k['fingerprint'], reason: name);
      expect(shortFingerprint(id.masterPub), k['short_fingerprint'], reason: name);
      expect(_toHex(id.nextPub), k['next_pub'], reason: name);
      expect(_toHex(id.nextKeyHash), k['next_key_hash'], reason: name);
      final again = await Identity.fromEntropy(id.entropy);
      expect(again.masterPub, id.masterPub);
    }
    for (final d in (f['devices'] as List).cast<Map<String, dynamic>>()) {
      expect(_toHex(await publicKeyOf(_hex(d['seed'] as String))), d['pub']);
    }
    for (final b in (f['bad_mnemonic'] as List).cast<Map<String, dynamic>>()) {
      expect(
        () => Identity.fromMnemonic(b['mnemonic'] as String),
        throwsA(
          isA<PhraseException>()
              .having((e) => e.error.wire, 'error', b['error'])
              .having((e) => e.index, 'index', b['error'] == 'unknown_word' ? b['index'] : null),
        ),
      );
    }
  });

  group('конверты: те же байты, что в Go', () {
    final keys = _json('identity/keys.json');
    final seeds = {
      for (final k in (keys['keys'] as List).cast<Map<String, dynamic>>())
        k['name'] as String: _hex(k['master_seed'] as String),
    };
    final f = _json('identity/envelopes.json');

    for (final e in (f['envelopes'] as List).cast<Map<String, dynamic>>()) {
      test(e['name'] as String, () async {
        final pBytes = jsonToCbor(jsonEncode(e['payload']));
        expect(_toHex(pBytes), e['p']);

        // Тот же payload из типизированной структуры.
        final map = ylDecode(pBytes)! as Map<String, Object?>;
        final typed = switch (e['t']) {
          SignedType.profile => (Profile.fromMap(map)..validate()).toMap(),
          SignedType.deviceCert => (DeviceCert.fromMap(map)..validate()).toMap(),
          SignedType.revoke => (Revoke.fromMap(map)..validate()).toMap(),
          SignedType.devices => (Devices.fromMap(map)..validate()).toMap(),
          _ => fail('тип ${e['t']}'),
        };
        expect(_toHex(ylEncode(typed)), e['p']);

        final s = await Signed.sign(e['t'] as String, typed, seeds[e['signer']]!);
        expect(_toHex(s.k), e['k']);
        expect(_toHex(s.s), e['s']);
        expect(_toHex(s.encode()), e['signed']);

        final dec = Signed.decode(_hex(e['signed'] as String));
        await _openAs(dec, e['t'] as String, dec.k);
      });
    }

    for (final b in (f['bad'] as List).cast<Map<String, dynamic>>()) {
      test('bad_${b['name']}', () async {
        final s = Signed.decode(_hex(b['signed'] as String));
        final master = b['master'] == null ? Uint8List(0) : _hex(b['master'] as String);
        await expectLater(
          _openAs(s, b['open'] as String, master),
          throwsA(isA<IdentityException>().having((x) => x.error.wire, 'error', b['error'])),
        );
      });
    }
  });

  test('типы конвертов не начинаются друг с друга', () {
    for (final a in SignedType.all) {
      for (final b in SignedType.all) {
        if (a != b) expect(b.startsWith(a), isFalse, reason: '$b начинается с $a');
      }
    }
  });

  test('символы направления текста запрещены, ZWJ разрешён', () {
    for (final r in [0x202A, 0x202E, 0x2066, 0x2069, 0x200E, 0x200F]) {
      expect(isBidiControl(r), isTrue, reason: r.toRadixString(16));
    }
    for (final r in [0x200D, 0x2029, 0x2065, 0x206A, 0x61]) {
      expect(isBidiControl(r), isFalse, reason: r.toRadixString(16));
    }
  });

  test('нормализация текста как в Go: NFC, Unicode-пробелы, но не U+FEFF', () {
    expect(normalizeText('  Йож \n'), 'Йож');
    expect(normalizeText('　Имя '), 'Имя');
    expect(normalizeText('﻿Имя'), '﻿Имя');
  });
}
