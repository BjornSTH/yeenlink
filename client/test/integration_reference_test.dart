import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/reference.dart';

/// Эталон интеграционного теста не должен разойтись с testdata.
void main() {
  test('integration_test/reference.dart совпадает с testdata/vectors/identity', () {
    final keys =
        jsonDecode(File('../testdata/vectors/identity/keys.json').readAsStringSync()) as Map;
    final env =
        jsonDecode(File('../testdata/vectors/identity/envelopes.json').readAsStringSync()) as Map;
    final main = (keys['keys'] as List).cast<Map<String, dynamic>>().firstWhere(
      (k) => k['name'] == 'main',
    );
    final profile = (env['envelopes'] as List).cast<Map<String, dynamic>>().firstWhere(
      (e) => e['name'] == 'profile',
    );
    expect(refMnemonic, main['mnemonic']);
    expect(refMasterPub, main['master_pub']);
    expect(refFingerprint, main['fingerprint']);
    expect(refNextKeyHash, main['next_key_hash']);
    expect(refProfileSigned, profile['signed']);
    expect(refProfileSignature, profile['s']);
  });
}
