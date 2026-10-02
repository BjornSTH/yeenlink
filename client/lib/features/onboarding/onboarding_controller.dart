import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../core/account/account_store.dart';
import '../../core/account/avatar.dart';
import '../../core/identity/identity.dart';

/// Шаги первого входа (docs/spec.md, «Карта экранов»; макет OnbSteps).
/// Создание: профиль → фраза → PIN → подключение → готово.
/// Восстановление: фраза → PIN → готово.
enum OnbStep { welcome, profile, seed, pin, join, restore, done }

enum OnbMode { create, restore }

enum RestoreTab { phrase, qr }

/// Почему имя или «о себе» не подходят.
enum DraftError { nameEmpty, nameTooLong, nameControl, nameBidi, aboutTooLong, aboutBidi }

/// Состояние первого входа. Виджеты только показывают его и зовут методы.
class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.store,
    required this.pickImage,
    Future<Identity> Function()? newIdentity,
  }) : _newIdentity = newIdentity ?? _randomIdentity;

  final AccountStore store;

  /// Выбор картинки для аватара; null — отменили.
  final Future<Uint8List?> Function() pickImage;
  final Future<Identity> Function() _newIdentity;

  /// Шагов в создании профиля — для полосы «Шаг N из M».
  static const createSteps = [OnbStep.profile, OnbStep.seed, OnbStep.pin, OnbStep.join];

  /// Длина PIN-кода.
  static const pinLength = 6;

  OnbStep _step = OnbStep.welcome;
  OnbMode _mode = OnbMode.create;
  OnbStep get step => _step;
  OnbMode get mode => _mode;

  /// Номер шага создания с единицы или null, если полоса не показывается.
  int? get stepNumber {
    if (_mode != OnbMode.create) return null;
    final i = createSteps.indexOf(_step);
    return i < 0 ? null : i + 1;
  }

  // Шаг «Как вас называть?».
  String name = '';
  String about = '';
  int bannerIndex = 0;
  AvatarImage? avatar;
  bool avatarBusy = false;
  bool avatarFailed = false;

  String get bannerColor => bannerColors[bannerIndex];

  DraftError? get draftError {
    final n = normalizeText(name);
    if (n.isEmpty) return DraftError.nameEmpty;
    if (n.runes.length > Limits.nameMaxRunes) return DraftError.nameTooLong;
    if (n.runes.any((r) => r < 0x20 || (r >= 0x7F && r <= 0x9F))) return DraftError.nameControl;
    if (n.runes.any(isBidiControl)) return DraftError.nameBidi;
    final a = normalizeText(about);
    if (a.runes.length > Limits.aboutMaxRunes) return DraftError.aboutTooLong;
    if (a.runes.any(isBidiControl)) return DraftError.aboutBidi;
    return null;
  }

  // Шаг «Секретная фраза».
  Identity? _identity;
  Identity? get identity => _identity;
  bool seedConfirmed = false;

  // Шаг PIN.
  String pin = '';
  String pinRepeat = '';
  bool saving = false;
  String? saveError;

  bool get pinMismatch => pinRepeat.length == pinLength && pin != pinRepeat;
  bool get pinReady => pin.length == pinLength && pin == pinRepeat;

  // Восстановление.
  RestoreTab restoreTab = RestoreTab.phrase;
  String phrase = '';
  bool checkingPhrase = false;
  PhraseException? phraseError;

  /// Сколько слов во введённой фразе — для ошибки «нужно 12».
  int get phraseWordCount => normalizeMnemonic(phrase).split(' ').where((w) => w.isNotEmpty).length;

  LocalAccount? _account;
  LocalAccount? get account => _account;

  void _go(OnbStep s) {
    _step = s;
    notifyListeners();
  }

  void startCreate() {
    _mode = OnbMode.create;
    _go(OnbStep.profile);
  }

  void startRestore() {
    _mode = OnbMode.restore;
    _go(OnbStep.restore);
  }

  void back() {
    _go(switch (_step) {
      OnbStep.profile || OnbStep.restore => OnbStep.welcome,
      OnbStep.seed => OnbStep.profile,
      OnbStep.pin => _mode == OnbMode.create ? OnbStep.seed : OnbStep.restore,
      _ => _step,
    });
  }

  void update(void Function(OnboardingController c) change) {
    change(this);
    notifyListeners();
  }

  Future<void> chooseAvatar() async {
    final bytes = await pickImage();
    if (bytes == null) return;
    update((c) {
      c.avatarBusy = true;
      c.avatarFailed = false;
    });
    try {
      avatar = await prepareAvatar(bytes);
    } on Object {
      avatarFailed = true;
    }
    avatarBusy = false;
    notifyListeners();
  }

  /// К фразе. Фраза создаётся один раз и не меняется, если вернуться назад.
  Future<void> toSeed() async {
    if (draftError != null) return;
    _identity ??= await _newIdentity();
    _go(OnbStep.seed);
  }

  void toPin() {
    if (!seedConfirmed) return;
    pin = pinRepeat = '';
    saveError = null;
    _go(OnbStep.pin);
  }

  Future<void> checkPhrase() async {
    update((c) {
      c.checkingPhrase = true;
      c.phraseError = null;
    });
    try {
      _identity?.wipe();
      _identity = await Identity.fromMnemonic(phrase);
      pin = pinRepeat = '';
      saveError = null;
      _step = OnbStep.pin;
    } on PhraseException catch (e) {
      phraseError = e;
    }
    checkingPhrase = false;
    notifyListeners();
  }

  /// Сохраняет ключи под PIN. [deviceName] — «Компьютер · Linux» и т. п.
  Future<void> savePin({required String deviceName, required String platform}) async {
    final id = _identity;
    if (!pinReady || id == null || saving) return;
    update((c) {
      c.saving = true;
      c.saveError = null;
    });
    try {
      _account = _mode == OnbMode.create
          ? await store.create(
              identity: id,
              pin: pin,
              draft: ProfileDraft(
                name: name,
                about: about,
                bannerColor: bannerColor,
                avatar: avatar,
              ),
              deviceName: deviceName,
              platform: platform,
            )
          : await store.restore(identity: id, pin: pin, deviceName: deviceName, platform: platform);
      id.wipe();
      _identity = null;
      pin = pinRepeat = phrase = '';
      _step = _mode == OnbMode.create ? OnbStep.join : OnbStep.done;
    } on Object catch (e) {
      saveError = '$e';
    }
    saving = false;
    notifyListeners();
  }

  void skipJoin() => _go(OnbStep.done);

  @override
  void dispose() {
    _identity?.wipe();
    super.dispose();
  }

  static Future<Identity> _randomIdentity() =>
      Identity.fromEntropy(SecretKeyData.random(length: 16).bytes);
}
