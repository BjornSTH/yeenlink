/// Личность: фраза BIP39, ключи SLIP-0010, конверт Signed и payload
/// (spec/identity.md). Та же логика на Go — server/pkg/identity.
library;

export 'bip39.dart';
export 'keys.dart';
export 'payloads.dart';
export 'signed.dart';
export 'slip10.dart' show SlipNode, hardened, parsePath;
