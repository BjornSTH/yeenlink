import 'dart:typed_data';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'signed.dart';

/// Ограничения полей — те же, что в server/pkg/identity (spec/identity.md).
abstract final class Limits {
  static const nameMaxRunes = 32;
  static const aboutMaxRunes = 300;
  static const deviceNameMaxRunes = 64;
  static const reasonMaxRunes = 200;
  static const avatarMaxBytes = 512 * 1024;
  static const bannerMaxBytes = 1024 * 1024;
  static const profileVersion = 1;
}

const List<String> platforms = ['windows', 'linux', 'android', 'macos'];

/// Цвета баннера — имена токенов; неизвестное имя показывается как первое.
const List<String> bannerColors = ['banner-1', 'banner-2', 'banner-3', 'banner-4', 'banner-5'];

// Unicode White_Space — тот же набор, что unicode.IsSpace в Go. String.trim
// в Dart срезает ещё и U+FEFF, поэтому своя обрезка.
bool _isSpace(int r) =>
    (r >= 0x09 && r <= 0x0D) ||
    r == 0x20 ||
    r == 0x85 ||
    r == 0xA0 ||
    r == 0x1680 ||
    (r >= 0x2000 && r <= 0x200A) ||
    r == 0x2028 ||
    r == 0x2029 ||
    r == 0x202F ||
    r == 0x205F ||
    r == 0x3000;

// Как unicode.IsControl в Go: C0, DEL и C1.
bool _isControl(int r) => r < 0x20 || (r >= 0x7F && r <= 0x9F);

/// Символы управления направлением текста: U+202A–202E, U+2066–2069, U+200E,
/// U+200F — ими подделывают имена. Запрещены во всех текстовых полях, как в Go.
/// ZWJ (U+200D) разрешён — он нужен эмодзи.
bool isBidiControl(int r) =>
    (r >= 0x202A && r <= 0x202E) || (r >= 0x2066 && r <= 0x2069) || r == 0x200E || r == 0x200F;

/// Канонический вид текстового поля: NFC и без пробелов по краям.
String normalizeText(String s) {
  final runes = unorm.nfc(s).runes.toList();
  var a = 0;
  var b = runes.length;
  while (a < b && _isSpace(runes[a])) {
    a++;
  }
  while (b > a && _isSpace(runes[b - 1])) {
    b--;
  }
  return String.fromCharCodes(runes.sublist(a, b));
}

Never _bad(String msg) => throw IdentityException(IdentityError.badPayload, msg);

void _checkText(String field, String s, int min, int max, {bool multiline = false}) {
  if (s != normalizeText(s)) _bad('$field не нормализовано (NFC, без пробелов по краям)');
  final n = s.runes.length;
  if (n < min || n > max) _bad('$field: $n символов, нужно $min–$max');
  for (final r in s.runes) {
    final code = r.toRadixString(16).padLeft(4, '0').toUpperCase();
    if (_isControl(r) && !(multiline && r == 0x0A)) _bad('$field: управляющий символ U+$code');
    if (isBidiControl(r)) _bad('$field: символ направления текста U+$code');
  }
}

Uint8List _key(String field, Object? v) {
  if (v is Uint8List && v.length == 32) return v;
  _bad('$field: нужно 32 байта');
}

int _uint(String field, Object? v) {
  if (v is int && v >= 0) return v;
  _bad('$field: нужно целое ≥ 0');
}

String _text(String field, Object? v) {
  if (v is String) return v;
  _bad('$field: нужен текст');
}

/// Картинка по хешу.
class BlobRef {
  const BlobRef({required this.sha256, required this.mime, required this.size});

  factory BlobRef.fromMap(String field, Object? v) {
    if (v is! Map<String, Object?>) _bad('$field: нужен словарь');
    final sha = v['sha256'];
    if (sha is! Uint8List || sha.length != 32) _bad('$field.sha256: нужно 32 байта');
    return BlobRef(
      sha256: sha,
      mime: _text('$field.mime', v['mime']),
      size: _uint('$field.size', v['size']),
    );
  }

  final Uint8List sha256;
  final String mime;
  final int size;

  Map<String, Object?> toMap() => {'sha256': sha256, 'mime': mime, 'size': size};

  void _validate(String field, int maxSize) {
    if (mime != 'image/png' && mime != 'image/webp') _bad('$field.mime «$mime»');
    if (size == 0 || size > maxSize) _bad('$field.size $size: нужно 1–$maxSize');
  }
}

/// Payload t = "profile", подписывает master.
class Profile {
  const Profile({
    required this.master,
    required this.seq,
    required this.name,
    this.about = '',
    this.avatar,
    this.banner,
    this.bannerColor,
    this.wall = true,
    required this.nextKeyHash,
    this.home,
    required this.updated,
    this.v = Limits.profileVersion,
  });

  factory Profile.fromMap(Map<String, Object?> m) => Profile(
    v: _uint('v', m['v']),
    master: _key('master', m['master']),
    seq: _uint('seq', m['seq']),
    name: _text('name', m['name']),
    about: _text('about', m['about']),
    avatar: m['avatar'] == null ? null : BlobRef.fromMap('avatar', m['avatar']),
    banner: m['banner'] == null ? null : BlobRef.fromMap('banner', m['banner']),
    bannerColor: m['banner_color'] == null ? null : _text('banner_color', m['banner_color']),
    wall: m['wall'] is bool ? m['wall']! as bool : _bad('wall: нужен bool'),
    nextKeyHash: _key('next_key_hash', m['next_key_hash']),
    home: m['home'] == null ? null : _text('home', m['home']),
    updated: _uint('updated', m['updated']),
  );

  final int v;
  final Uint8List master;
  final int seq;
  final String name;
  final String about;
  final BlobRef? avatar;
  final BlobRef? banner;
  final String? bannerColor;
  final bool wall;
  final Uint8List nextKeyHash;
  final String? home;
  final int updated;

  /// Цвет баннера для показа: неизвестное имя — первый цвет.
  String get bannerColorOrDefault =>
      bannerColors.contains(bannerColor) ? bannerColor! : bannerColors.first;

  Map<String, Object?> toMap() => {
    'v': v,
    'master': master,
    'seq': seq,
    'name': name,
    'about': about,
    'avatar': ?avatar?.toMap(),
    'banner': ?banner?.toMap(),
    'banner_color': ?bannerColor,
    'wall': wall,
    'next_key_hash': nextKeyHash,
    'home': ?home,
    'updated': updated,
  };

  void validate() {
    if (v != Limits.profileVersion) _bad('версия профиля $v');
    if (seq == 0) _bad('seq начинается с 1');
    if (updated == 0) _bad('нет updated');
    if (banner != null && bannerColor != null) _bad('banner и banner_color вместе');
    _checkText('name', name, 1, Limits.nameMaxRunes);
    _checkText('about', about, 0, Limits.aboutMaxRunes, multiline: true);
    if (bannerColor != null) _checkText('banner_color', bannerColor!, 1, 32);
    avatar?._validate('avatar', Limits.avatarMaxBytes);
    banner?._validate('banner', Limits.bannerMaxBytes);
  }
}

/// Payload t = "device_cert", подписывает master.
class DeviceCert {
  const DeviceCert({
    required this.devicePub,
    required this.name,
    required this.platform,
    required this.created,
  });

  factory DeviceCert.fromMap(Map<String, Object?> m) => DeviceCert(
    devicePub: _key('device_pub', m['device_pub']),
    name: _text('name', m['name']),
    platform: _text('platform', m['platform']),
    created: _uint('created', m['created']),
  );

  final Uint8List devicePub;
  final String name;
  final String platform;
  final int created;

  Map<String, Object?> toMap() => {
    'device_pub': devicePub,
    'name': name,
    'platform': platform,
    'created': created,
  };

  void validate() {
    _checkText('name', name, 1, Limits.deviceNameMaxRunes);
    if (!platforms.contains(platform)) _bad('платформа «$platform»');
    if (created == 0) _bad('нет created');
  }
}

/// Payload t = "revoke", подписывает master.
class Revoke {
  const Revoke({required this.devicePub, required this.reason, required this.at});

  factory Revoke.fromMap(Map<String, Object?> m) => Revoke(
    devicePub: _key('device_pub', m['device_pub']),
    reason: _text('reason', m['reason']),
    at: _uint('at', m['at']),
  );

  final Uint8List devicePub;
  final String reason;
  final int at;

  Map<String, Object?> toMap() => {'device_pub': devicePub, 'reason': reason, 'at': at};

  void validate() {
    _checkText('reason', reason, 0, Limits.reasonMaxRunes);
    if (at == 0) _bad('нет at');
  }
}

/// Payload t = "devices", подписывает master.
class Devices {
  const Devices({required this.seq, required this.active, required this.revoked});

  factory Devices.fromMap(Map<String, Object?> m) {
    List<Uint8List> keys(String field) {
      final v = m[field];
      if (v is! List<Object?>) _bad('$field: нужен список');
      return [for (final k in v) _key(field, k)];
    }

    return Devices(seq: _uint('seq', m['seq']), active: keys('active'), revoked: keys('revoked'));
  }

  final int seq;
  final List<Uint8List> active;
  final List<Uint8List> revoked;

  Map<String, Object?> toMap() => {'seq': seq, 'active': active, 'revoked': revoked};

  void validate() {
    if (seq == 0) _bad('seq начинается с 1');
    final seen = <String>{};
    for (final k in [...active, ...revoked]) {
      if (!seen.add(String.fromCharCodes(k))) _bad('ключ устройства повторяется');
    }
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<Map<String, Object?>> _open(Signed s, String t) async {
  if (s.t != t) throw IdentityException(IdentityError.wrongType, 'ожидался «$t», получен «${s.t}»');
  await s.verify();
  return s.payloadMap();
}

void _signer(Signed s, List<int> master, String t) {
  if (!_sameBytes(s.k, master)) {
    throw IdentityException(IdentityError.signerMismatch, '$t подписан не главным ключом');
  }
}

/// Проверяет конверт профиля: подпись, поля и то, что подписал master из профиля.
Future<Profile> openProfile(Signed s) async {
  final p = Profile.fromMap(await _open(s, SignedType.profile))..validate();
  _signer(s, p.master, SignedType.profile);
  return p;
}

Future<DeviceCert> openDeviceCert(Signed s, List<int> master) async {
  final d = DeviceCert.fromMap(await _open(s, SignedType.deviceCert))..validate();
  _signer(s, master, SignedType.deviceCert);
  return d;
}

Future<Revoke> openRevoke(Signed s, List<int> master) async {
  final r = Revoke.fromMap(await _open(s, SignedType.revoke))..validate();
  _signer(s, master, SignedType.revoke);
  return r;
}

Future<Devices> openDevices(Signed s, List<int> master) async {
  final d = Devices.fromMap(await _open(s, SignedType.devices))..validate();
  _signer(s, master, SignedType.devices);
  return d;
}
