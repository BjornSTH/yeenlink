import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../identity/identity.dart';
import '../vault/key_vault.dart';
import '../vault/master_lock.dart';
import 'avatar.dart';
import 'pin_guard.dart';

/// Профиль на этом устройстве (spec/identity.md, «Хранение»).
class LocalAccount {
  const LocalAccount({
    required this.masterPub,
    required this.devicePub,
    required this.deviceCert,
    this.profile,
    this.avatarPng,
  });

  final Uint8List masterPub;
  final Uint8List devicePub;
  final Signed deviceCert;

  /// Подписанный профиль. После восстановления по фразе его нет, пока профиль
  /// не придёт с сервера (фаза 2).
  final Signed? profile;
  final Uint8List? avatarPng;
}

/// Что человек ввёл на шаге «Как вас называть?».
class ProfileDraft {
  const ProfileDraft({required this.name, this.about = '', this.bannerColor, this.avatar});

  final String name;
  final String about;
  final String? bannerColor;
  final AvatarImage? avatar;
}

/// Нужно подождать перед следующей попыткой PIN.
class PinWait implements Exception {
  const PinWait(this.left);
  final Duration left;
}

/// Ключи и профиль этого устройства.
///
/// В [KeyVault] — только секреты: блоб главного ключа под PIN и seed ключа
/// устройства. Подписанные профиль и сертификат устройства и аватар — в
/// обычной папке приложения [dir]: они не секретны и на Windows не влезли бы
/// в одну запись Диспетчера учётных данных.
class AccountStore {
  AccountStore({
    required this.vault,
    required this.dir,
    PinGuard? guard,
    int Function()? nowMs,
    this.kdfParams,
  }) : guard = guard ?? PinGuard(vault),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const masterKey = 'yl.master.v1';
  static const deviceKey = 'yl.device.v1';

  final KeyVault vault;
  final Directory dir;
  final PinGuard guard;
  final int Function() _nowMs;

  /// Параметры KDF; null — выбрать под устройство ([KdfParams.choose]).
  final KdfParams? kdfParams;

  File get _profileFile => File('${dir.path}/profile.signed');
  File get _certFile => File('${dir.path}/device_cert.signed');
  File get _avatarFile => File('${dir.path}/avatar.png');

  /// Профиль на этом устройстве или null, если его ещё нет.
  Future<LocalAccount?> load() async {
    final blob = await vault.read(masterKey);
    final seed = await vault.read(deviceKey);
    if (blob == null || seed == null || !_certFile.existsSync()) return null;
    final cert = Signed.decode(await _certFile.readAsBytes());
    final devicePub = await publicKeyOf(seed);
    final parsed = await openDeviceCert(cert, cert.k);
    if (!_same(parsed.devicePub, devicePub)) {
      throw StateError('сертификат устройства не от этого ключа');
    }
    Signed? profile;
    if (_profileFile.existsSync()) {
      profile = Signed.decode(await _profileFile.readAsBytes());
      await openProfile(profile);
    }
    return LocalAccount(
      masterPub: cert.k,
      devicePub: devicePub,
      deviceCert: cert,
      profile: profile,
      avatarPng: _avatarFile.existsSync() ? await _avatarFile.readAsBytes() : null,
    );
  }

  /// Новый профиль: ключ устройства, блоб под PIN, подписанные профиль и
  /// сертификат устройства. Главный ключ после этого остаётся только в блобе.
  Future<LocalAccount> create({
    required Identity identity,
    required String pin,
    required ProfileDraft draft,
    required String deviceName,
    required String platform,
  }) async {
    final now = _nowMs();
    final signedProfile = await _signProfile(identity, draft, seq: 1, now: now);
    final account = await _store(identity, pin, deviceName, platform, now);
    return _saveProfile(account, signedProfile, draft.avatar);
  }

  /// Восстановление по фразе: новый ключ устройства и сертификат. Профиля нет —
  /// его можно указать сразу ([saveRestoredProfile]) или он придёт с сервера
  /// (фаза 2). Список устройств — тоже в фазе 2.
  Future<LocalAccount> restore({
    required Identity identity,
    required String pin,
    required String deviceName,
    required String platform,
  }) => _store(identity, pin, deviceName, platform, _nowMs());

  /// Локальный профиль после восстановления: seq = 0, поэтому любой профиль
  /// с сервера (seq ≥ 1) его заменит.
  Future<LocalAccount> saveRestoredProfile({
    required Identity identity,
    required ProfileDraft draft,
  }) async {
    final account = await load();
    if (account == null) throw StateError('профиля на устройстве нет');
    final signed = await _signProfile(identity, draft, seq: 0, now: _nowMs());
    return _saveProfile(account, signed, draft.avatar);
  }

  Future<Signed> _signProfile(
    Identity identity,
    ProfileDraft draft, {
    required int seq,
    required int now,
  }) {
    final profile = Profile(
      master: identity.masterPub,
      seq: seq,
      name: normalizeText(draft.name),
      about: normalizeText(draft.about),
      avatar: draft.avatar?.ref,
      bannerColor: draft.bannerColor,
      nextKeyHash: identity.nextKeyHash,
      updated: now,
    )..validate();
    final map = profile.toMap();
    final seed = Uint8List.fromList(identity.masterSeed);
    // Ed25519 на чистом Dart — в отдельном изоляте, чтобы не стопорить интерфейс.
    return Isolate.run(() => Signed.sign(SignedType.profile, map, seed));
  }

  Future<LocalAccount> _saveProfile(
    LocalAccount account,
    Signed profile,
    AvatarImage? avatar,
  ) async {
    await _profileFile.writeAsBytes(profile.encode(), flush: true);
    if (avatar != null) await _avatarFile.writeAsBytes(avatar.png, flush: true);
    return LocalAccount(
      masterPub: account.masterPub,
      devicePub: account.devicePub,
      deviceCert: account.deviceCert,
      profile: profile,
      avatarPng: avatar?.png,
    );
  }

  Future<LocalAccount> _store(
    Identity identity,
    String pin,
    String deviceName,
    String platform,
    int now,
  ) async {
    await wipe();
    await dir.create(recursive: true);
    final deviceSeed = Uint8List.fromList(SecretKeyData.random(length: 32).bytes);
    final masterSeed = Uint8List.fromList(identity.masterSeed);
    final name = normalizeText(deviceName);
    // Ключ устройства и подпись сертификата — в отдельном изоляте.
    final (devicePub, signedCert) = await Isolate.run(() async {
      final pub = await publicKeyOf(deviceSeed);
      final cert = DeviceCert(devicePub: pub, name: name, platform: platform, created: now)
        ..validate();
      return (pub, await Signed.sign(SignedType.deviceCert, cert.toMap(), masterSeed));
    });
    final blob = await MasterLock.seal(
      entropy: identity.entropy,
      secret: pin,
      kind: SecretKind.pin,
      masterPub: identity.masterPub,
      params: kdfParams ?? await KdfParams.choose(),
    );
    await vault.write(masterKey, blob);
    await vault.write(deviceKey, deviceSeed);
    await _certFile.writeAsBytes(signedCert.encode(), flush: true);
    return LocalAccount(
      masterPub: identity.masterPub,
      devicePub: devicePub,
      deviceCert: signedCert,
    );
  }

  /// Расшифровывает главный ключ PIN-кодом. Неверный PIN — [WrongSecret],
  /// пауза после ошибок — [PinWait]. Вызывающий затирает личность ([Identity.wipe]).
  Future<Identity> unlock(String pin) async {
    final wait = await guard.wait();
    if (wait != null) throw PinWait(wait);
    final account = await load();
    final blob = await vault.read(masterKey);
    if (account == null || blob == null) throw StateError('профиля на устройстве нет');
    try {
      final entropy = await MasterLock.open(blob: blob, secret: pin, masterPub: account.masterPub);
      await guard.succeeded();
      return Identity.fromEntropy(entropy);
    } on WrongSecret {
      await guard.failed();
      rethrow;
    }
  }

  /// Стирает профиль с устройства. Вернуть его можно только по фразе.
  Future<void> wipe() async {
    for (final k in [masterKey, deviceKey, PinGuard.key]) {
      await vault.delete(k);
    }
    for (final f in [_profileFile, _certFile, _avatarFile]) {
      if (f.existsSync()) await f.delete();
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
