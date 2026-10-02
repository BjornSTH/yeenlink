import 'dart:typed_data';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../../core/account/platform_bridge.dart';
import '../../core/identity/identity.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/icons/yl_icon.dart';
import '../../ui/illustrations/aside_spots.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/pressable.dart';
import '../../ui/widgets/widgets.dart';
import 'onboarding_controller.dart';

/// Ширина колонки шага (OnbSteps, 440). Токена нет — запрошен
/// onboarding-content-w; до него — это значение из макета.
const double _contentWidth = 440;

/// Первый вход (docs/mockups/src/03-onboarding, phase-1.pdf).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.bridge,
    required this.onOpenApp,
  });

  final OnboardingController controller;
  final PlatformBridge bridge;
  final VoidCallback onOpenApp;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  OnboardingController get c => widget.controller;

  final _name = TextEditingController();
  final _about = TextEditingController();
  final _pin = TextEditingController();
  final _pinRepeat = TextEditingController();
  final _phrase = TextEditingController();
  final _invite = TextEditingController();

  // Подсказки, которые появляются после действия.
  String? _seedNotice;
  bool _saveWarning = false;
  String? _joinNotice;

  @override
  void initState() {
    super.initState();
    c.addListener(_sync);
  }

  @override
  void didUpdateWidget(OnboardingScreen old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      old.controller.removeListener(_sync);
      c.addListener(_sync);
    }
  }

  // Поля PIN и фразы очищаются контроллером — повторяем это в полях ввода.
  void _sync() {
    if (c.pin.isEmpty && _pin.text.isNotEmpty) _pin.clear();
    if (c.pinRepeat.isEmpty && _pinRepeat.text.isNotEmpty) _pinRepeat.clear();
    if (c.phrase.isEmpty && _phrase.text.isNotEmpty) _phrase.clear();
    if (c.name.isEmpty && _name.text.isNotEmpty) _name.clear();
    if (c.about.isEmpty && _about.text.isNotEmpty) _about.clear();
    setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    for (final t in [_name, _about, _pin, _pinRepeat, _phrase, _invite]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = YlColors.of(context);
    return YlSurface(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= YlSize.onboardingAsideW + _contentWidth + 4 * YlSpace.s8;
          final content = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentWidth),
            child: KeyedSubtree(key: ValueKey(c.step), child: _stepView(context)),
          );
          if (wide) {
            return Row(
              children: [
                const _Aside(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(YlSpace.s8),
                      child: content,
                    ),
                  ),
                ),
              ],
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(YlSpace.s5, YlSpace.s5, YlSpace.s5, YlSpace.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const YlLogo(size: YlSize.logoSm),
                  const SizedBox(height: YlSpace.s6),
                  content,
                ],
              ),
            ),
          );
        },
      ),
    ).withColor(colors.bg100);
  }

  Widget _stepView(BuildContext context) {
    final l = L10n.of(context);
    final views = switch (c.step) {
      OnbStep.welcome => _welcome(l),
      OnbStep.profile => _profile(l),
      OnbStep.seed => _seed(l),
      OnbStep.pin => _pinStep(l),
      OnbStep.join => _join(l),
      OnbStep.restore => _restore(l),
      OnbStep.done => _done(l),
    };
    final n = c.stepNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (n != null) ...[
          YlStepBar(
            step: n,
            total: OnboardingController.createSteps.length,
            caption: l.onbStep(n, OnboardingController.createSteps.length),
          ),
          const SizedBox(height: YlSpace.s6),
        ],
        ..._gap(views, YlSpace.s6),
      ],
    );
  }

  // --- шаги -----------------------------------------------------------------

  List<Widget> _welcome(L10n l) => [
    _Heading(l.onbWelcomeTitle, l.onbWelcomeText, big: true),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YlButton(label: l.onbWelcomeCreate, onPressed: c.startCreate, expand: true),
        const SizedBox(height: YlSpace.s3),
        YlButton(
          label: l.onbWelcomeRestore,
          onPressed: c.startRestore,
          kind: YlButtonKind.secondary,
          expand: true,
        ),
      ],
    ),
    _Note(l.onbWelcomeNote),
  ];

  List<Widget> _profile(L10n l) {
    final err = c.draftError;
    String? nameError;
    if (err == DraftError.nameTooLong) nameError = l.onbNameTooLong(Limits.nameMaxRunes);
    if (err == DraftError.nameControl) nameError = l.onbNameControl;
    return [
      _Heading(l.onbProfileTitle, l.onbProfileText),
      Row(
        children: [
          _AvatarPicker(
            image: c.avatar?.png,
            busy: c.avatarBusy,
            label: c.avatar == null ? l.onbAvatarPick : l.onbAvatarChange,
            onTap: c.chooseAvatar,
          ),
          const SizedBox(width: YlSpace.s4),
          Expanded(
            child: _BannerSwatches(
              title: l.onbBannerColor,
              selected: c.bannerIndex,
              labelFor: l.onbBannerColorN,
              onSelect: (i) => c.update((c) => c.bannerIndex = i),
            ),
          ),
        ],
      ),
      if (c.avatarFailed) _Note(l.onbAvatarError, danger: true),
      YlInput(
        label: l.onbName,
        placeholder: l.onbNameHint,
        controller: _name,
        error: nameError,
        textInputAction: TextInputAction.next,
        onChanged: (v) => c.update((c) => c.name = v),
      ),
      YlInput(
        label: l.onbAbout,
        placeholder: l.onbAboutHint,
        controller: _about,
        lines: 3,
        error: err == DraftError.aboutTooLong ? l.onbAboutTooLong(Limits.aboutMaxRunes) : null,
        onChanged: (v) => c.update((c) => c.about = v),
      ),
      _BackNext(
        back: l.onbBack,
        onBack: c.back,
        // Без имени кнопка неактивна и говорит, чего не хватает.
        next: err == DraftError.nameEmpty ? l.onbNameEmpty : l.onbNext,
        onNext: err == null ? c.toSeed : null,
      ),
    ];
  }

  List<Widget> _seed(L10n l) {
    final words = c.identity?.words ?? const <String>[];
    return [
      _Heading(l.onbSeedTitle, l.onbSeedText),
      _WarnBox(icon: YlIconData.shield, text: l.onbSeedWarning),
      _SeedGrid(words: words),
      Wrap(
        spacing: YlSpace.s2,
        runSpacing: YlSpace.s2,
        children: [
          YlButton(
            label: l.onbSeedCopy,
            icon: YlIconData.copy,
            kind: YlButtonKind.secondary,
            size: YlButtonSize.sm,
            onPressed: () async {
              await widget.bridge.copySensitive(words.join(' '));
              setState(() => _seedNotice = l.onbSeedCopied);
            },
          ),
          YlButton(
            label: l.onbSeedSave,
            icon: YlIconData.download,
            kind: YlButtonKind.secondary,
            size: YlButtonSize.sm,
            onPressed: () => setState(() => _saveWarning = true),
          ),
        ],
      ),
      if (_saveWarning)
        _WarnBox(
          text: l.onbSeedSaveWarning,
          action: YlButton(
            label: l.onbSeedSaveChoose,
            kind: YlButtonKind.secondary,
            size: YlButtonSize.sm,
            onPressed: () async {
              final numbered = [for (var i = 0; i < words.length; i++) '${i + 1}. ${words[i]}'];
              String notice;
              try {
                final ok = await widget.bridge.saveText(
                  l.onbSeedFileName,
                  l.onbSeedFileText(numbered.join('\n')),
                );
                if (!ok) return;
                notice = l.onbSeedSaved;
              } on Object {
                notice = l.onbSeedSaveFailed;
              }
              setState(() {
                _saveWarning = false;
                _seedNotice = notice;
              });
            },
          ),
        ),
      if (_seedNotice != null) _Note(_seedNotice!),
      YlCheckbox(
        label: l.onbSeedConfirm,
        value: c.seedConfirmed,
        onChanged: (v) => c.update((c) => c.seedConfirmed = v),
      ),
      _BackNext(
        back: l.onbBack,
        onBack: c.back,
        next: l.onbNext,
        onNext: c.seedConfirmed ? c.toPin : null,
      ),
    ];
  }

  List<Widget> _pinStep(L10n l) {
    Future<void> save() async {
      final os = widget.bridge.platform;
      final model = await widget.bridge.phoneModel();
      final device = os == 'android'
          ? (model == null || model.isEmpty ? l.deviceNamePhoneUnknown : l.deviceNamePhone(model))
          : l.deviceNameComputer(_osName[os] ?? os);
      await c.savePin(deviceName: device, platform: os);
    }

    return [
      _Heading(l.onbPinTitle, l.onbPinText),
      YlInput(
        label: l.onbPin,
        controller: _pin,
        obscure: true,
        mono: true,
        digitsOnly: true,
        maxLength: OnboardingController.pinLength,
        autofocus: true,
        textInputAction: TextInputAction.next,
        onChanged: (v) => c.update((c) => c.pin = v),
      ),
      YlInput(
        label: l.onbPinRepeat,
        controller: _pinRepeat,
        obscure: true,
        mono: true,
        digitsOnly: true,
        maxLength: OnboardingController.pinLength,
        error: c.pinMismatch ? l.onbPinMismatch : null,
        onChanged: (v) => c.update((c) => c.pinRepeat = v),
        onSubmitted: (_) => save(),
      ),
      if (c.saveError != null) _Note(l.onbPinSaveFailed(c.saveError!), danger: true),
      _BackNext(
        back: l.onbBack,
        onBack: c.saving ? null : c.back,
        next: c.saving
            ? l.onbPinSaving
            : c.pinReady || c.pinMismatch
            ? l.onbNext
            : l.onbPinEnterTwice,
        onNext: c.pinReady && !c.saving ? save : null,
      ),
    ];
  }

  List<Widget> _join(L10n l) => [
    _Heading(l.onbJoinTitle, l.onbJoinText),
    YlInput(
      label: l.onbJoinInvite,
      placeholder: l.onbJoinInviteHint,
      controller: _invite,
      mono: true,
    ),
    YlButton(
      label: l.onbJoinConnect,
      expand: true,
      onPressed: () => setState(() => _joinNotice = l.onbJoinNotReady),
    ),
    if (_joinNotice != null) _Note(_joinNotice!),
    _OrDivider(l.onbJoinOr),
    YlButton(
      label: l.onbJoinCatalog,
      icon: YlIconData.compass,
      kind: YlButtonKind.secondary,
      expand: true,
      onPressed: () => setState(() => _joinNotice = l.onbCatalogNotReady),
    ),
    YlButton(label: l.onbJoinSkip, kind: YlButtonKind.quiet, expand: true, onPressed: c.skipJoin),
  ];

  List<Widget> _restore(L10n l) {
    final e = c.phraseError;
    final error = switch (e?.error) {
      null => null,
      PhraseError.wordCount => l.onbRestoreWordCount(c.phraseWordCount),
      PhraseError.unknownWord => l.onbRestoreUnknownWord(
        e!.index! + 1,
        normalizeMnemonic(c.phrase).split(' ')[e.index!],
      ),
      PhraseError.checksum => l.onbRestoreChecksum,
    };
    return [
      _Heading(l.onbRestoreTitle, l.onbRestoreText),
      YlSegmented<RestoreTab>(
        segments: [
          YlSegment(RestoreTab.phrase, l.onbRestoreTabPhrase),
          YlSegment(RestoreTab.qr, l.onbRestoreTabQr),
        ],
        value: c.restoreTab,
        onChanged: (t) => c.update((c) => c.restoreTab = t),
      ),
      if (c.restoreTab == RestoreTab.phrase) ...[
        YlInput(
          label: l.onbRestorePhrase,
          placeholder: l.onbRestorePhraseHint,
          controller: _phrase,
          mono: true,
          lines: 4,
          error: error,
          onChanged: (v) => c.update((c) {
            c.phrase = v;
            c.phraseError = null;
          }),
        ),
        YlButton(
          label: c.checkingPhrase
              ? l.onbRestoreChecking
              : c.phraseWordCount == 0
              ? l.onbRestoreEnterPhrase
              : l.onbRestoreAction,
          expand: true,
          onPressed: c.phraseWordCount > 0 && !c.checkingPhrase ? c.checkPhrase : null,
        ),
      ] else
        _Card(child: _Note(l.onbRestoreQrStub, center: true)),
      YlButton(label: l.onbBack, kind: YlButtonKind.quiet, expand: true, onPressed: c.back),
    ];
  }

  List<Widget> _done(L10n l) => [
    const Align(alignment: Alignment.centerLeft, child: _SuccessMark()),
    _Heading(l.onbDoneTitle, c.mode == OnbMode.create ? l.onbDoneText : l.onbDoneRestoredText),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YlButton(label: l.onbDoneOpen, expand: true, onPressed: widget.onOpenApp),
        const SizedBox(height: YlSpace.s3),
        YlButton(
          label: l.onbDoneRestart,
          kind: YlButtonKind.quiet,
          expand: true,
          onPressed: () async {
            await c.restart();
            setState(() {
              _seedNotice = _joinNotice = null;
              _saveWarning = false;
            });
          },
        ),
      ],
    ),
  ];

  static const _osName = {'windows': 'Windows', 'linux': 'Linux', 'macos': 'macOS'};

  static List<Widget> _gap(List<Widget> items, double gap) => [
    for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
  ];
}

extension on Widget {
  Widget withColor(Color color) => ColoredBox(color: color, child: this);
}

// --- части экрана -------------------------------------------------------------

/// Левая колонка приветствия на ПК.
class _Aside extends StatelessWidget {
  const _Aside();

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return Container(
      width: YlSize.onboardingAsideW,
      color: c.bg000,
      child: Stack(
        children: [
          const Positioned.fill(child: AsideSpots()),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              2 * YlSpace.s8,
              2 * YlSpace.s8,
              2 * YlSpace.s8,
              YlSpace.s6 + YlSpace.s6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const YlLogo(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.onbAsideTitle, style: YlText.display.copyWith(color: c.ink)),
                      const SizedBox(height: YlSpace.s8),
                      _Feature(YlIconData.server, l.onbFeatureVpsTitle, l.onbFeatureVpsText),
                      const SizedBox(height: YlSpace.s5),
                      _Feature(YlIconData.user, l.onbFeatureProfileTitle, l.onbFeatureProfileText),
                      const SizedBox(height: YlSpace.s5),
                      _Feature(YlIconData.key, l.onbFeatureKeyTitle, l.onbFeatureKeyText),
                    ],
                  ),
                ),
                Text(l.onbAsideFooter, style: YlText.caption.copyWith(color: c.subtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.text);

  final YlIconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: YlSize.avatarMd,
          height: YlSize.avatarMd,
          decoration: BoxDecoration(color: c.bg300, borderRadius: YlRadius.lg),
          alignment: Alignment.center,
          child: YlIcon(icon, color: c.accent, size: YlSize.iconSm + YlSpace.s1),
        ),
        const SizedBox(width: YlSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: YlText.bodyLg.copyWith(color: c.ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: YlSpace.s1),
              Text(
                text,
                style: YlText.label.copyWith(color: c.muted, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.text, {this.big = false});

  final String title;
  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: (big ? YlText.h1 : YlText.h2).copyWith(color: c.ink)),
        ),
        const SizedBox(height: YlSpace.s3),
        Text(text, style: YlText.bodyLg.copyWith(color: c.muted)),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.danger = false, this.center = false});

  final String text;
  final bool danger;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: YlText.label.copyWith(
          color: danger ? c.dangerInk : c.subtle,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(YlSpace.s5),
    decoration: BoxDecoration(color: YlColors.of(context).bg300, borderRadius: YlRadius.xl),
    child: child,
  );
}

class _BackNext extends StatelessWidget {
  const _BackNext({
    required this.back,
    required this.onBack,
    required this.next,
    required this.onNext,
  });

  final String back;
  final VoidCallback? onBack;
  final String next;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      YlButton(label: back, kind: YlButtonKind.quiet, onPressed: onBack),
      const SizedBox(width: YlSpace.s3),
      Expanded(
        child: YlButton(label: next, onPressed: onNext, expand: true),
      ),
    ],
  );
}

/// Янтарная плашка предупреждения (warn-*), по желанию с действием.
class _WarnBox extends StatelessWidget {
  const _WarnBox({required this.text, this.icon, this.action});

  final String text;
  final YlIconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: YlSpace.s4, vertical: YlSpace.s3),
      decoration: BoxDecoration(
        color: c.warnBg,
        borderRadius: YlRadius.lg,
        border: Border.all(color: c.warnBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                YlIcon(icon!, color: c.accentInk, size: YlSize.iconSm + YlSpace.s1),
                const SizedBox(width: YlSpace.s3),
              ],
              Expanded(
                child: Text(text, style: YlText.banner.copyWith(color: c.warnInk)),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: YlSpace.s3), action!],
        ],
      ),
    );
  }
}

class _SeedGrid extends StatelessWidget {
  const _SeedGrid({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        const columns = 3;
        final cell = (box.maxWidth - (columns - 1) * YlSpace.s2) / columns;
        return Wrap(
          spacing: YlSpace.s2,
          runSpacing: YlSpace.s2,
          children: [
            for (var i = 0; i < words.length; i++)
              Container(
                width: cell,
                height: YlSize.seedCellH,
                padding: const EdgeInsets.symmetric(horizontal: YlSpace.s3),
                decoration: BoxDecoration(color: c.bg300, borderRadius: YlRadius.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: YlSpace.s5,
                      child: Text('${i + 1}', style: YlText.monoXs.copyWith(color: c.subtle)),
                    ),
                    const SizedBox(width: YlSpace.s2),
                    Expanded(
                      child: Text(words[i], style: YlText.mono.copyWith(color: c.ink)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    Widget line() => Expanded(child: Container(height: 1, color: c.bg400));
    return Row(
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: YlSpace.s3),
          child: Text(text, style: YlText.caption.copyWith(color: c.subtle)),
        ),
        line(),
      ],
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Container(
      width: YlSize.successMark,
      height: YlSize.successMark,
      decoration: BoxDecoration(
        color: c.bg400,
        shape: BoxShape.circle,
        border: Border.all(color: c.accent, width: YlSize.focusRing),
      ),
      alignment: Alignment.center,
      child: YlIcon(YlIconData.check, color: c.accent, size: YlSize.successMark / 2),
    );
  }
}

/// Круглая кнопка выбора аватара с пунктиром (tokens: avatar-picker).
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.image,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final List<int>? image;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Pressable(
      onTap: busy ? null : onTap,
      semanticLabel: label,
      builder: (context, s) => SizedBox.square(
        dimension: YlSize.avatarPicker,
        child: image != null
            ? ClipOval(child: Image.memory(_bytes(image!), fit: BoxFit.cover))
            : CustomPaint(
                painter: _DashedCircle(color: s.hovered ? c.accent : c.borderStrong, fill: c.bg300),
                child: Center(
                  child: YlIcon(YlIconData.plus, color: c.muted, size: YlSize.iconSm + YlSpace.s2),
                ),
              ),
      ),
    );
  }

  static Uint8List _bytes(List<int> b) => b is Uint8List ? b : Uint8List.fromList(b);
}

class _DashedCircle extends CustomPainter {
  _DashedCircle({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    canvas.drawCircle(center, r, Paint()..color = fill);
    // Пунктир border-strong 2 px (tokens: avatar-picker): штрих и пробел — по
    // три толщины, как у CSS dashed.
    const stroke = YlSize.focusRing;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final radius = r - stroke / 2;
    final dashes = (2 * 3.141592653589793 * radius / (6 * stroke)).floor();
    final step = 2 * 3.141592653589793 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step / 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color || old.fill != fill;
}

/// Пять кружков цвета баннера (tokens: swatch, banner-1…5).
class _BannerSwatches extends StatelessWidget {
  const _BannerSwatches({
    required this.title,
    required this.selected,
    required this.labelFor,
    required this.onSelect,
  });

  final String title;
  final int selected;
  final String Function(int n) labelFor;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final palette = c.bannerPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: YlText.label.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s2),
        Wrap(
          spacing: YlSpace.s2,
          runSpacing: YlSpace.s2,
          children: [
            for (var i = 0; i < palette.length; i++)
              Pressable(
                onTap: () => onSelect(i),
                selected: i == selected,
                semanticLabel: labelFor(i + 1),
                builder: (context, s) => Container(
                  width: YlSize.swatch,
                  height: YlSize.swatch,
                  decoration: BoxDecoration(
                    color: palette[i],
                    shape: BoxShape.circle,
                    // Выбранный — кольцо: зазор цветом фона, затем accent.
                    boxShadow: i == selected || s.focused
                        ? [
                            BoxShadow(color: c.accent, spreadRadius: 2 * YlSize.focusRing),
                            BoxShadow(color: c.bg100, spreadRadius: YlSize.focusRing),
                          ]
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
