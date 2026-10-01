import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/redact.dart';
import '../l10n/gen/app_localizations.dart';
import '../ui/theme/yl_theme.dart';
import '../ui/widgets/widgets.dart';

// Данные витрины — идентификаторы, поэтому на экран они идут через redact.
const _demoServer = 'nightcamp.ru';
const _demoAddress = '185.12.40.7:8443';
const _demoTimer = '1:12:40';
const _reactionPlusOne = '+1';

/// Витрина базовых виджетов: `flutter run -t lib/main_showcase.dart`.
class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).scTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ylTheme(Brightness.dark),
      home: const ShowcasePage(),
    );
  }
}

/// На широком окне темы стоят рядом, на узком — переключаются сегментами.
class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  Brightness _narrowTheme = Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = YlColors.of(context);
    return YlSurface(
      color: c.bg000,
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 2 * ShowcasePanel.width) {
            return const SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ShowcasePanel(brightness: Brightness.dark)),
                  Expanded(child: ShowcasePanel(brightness: Brightness.light)),
                ],
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(YlSpace.s4),
                child: YlSegmented<Brightness>(
                  segments: [
                    YlSegment(Brightness.dark, l10n.scThemeDark),
                    YlSegment(Brightness.light, l10n.scThemeLight),
                  ],
                  value: _narrowTheme,
                  onChanged: (b) => setState(() => _narrowTheme = b),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(child: ShowcasePanel(brightness: _narrowTheme)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Все девять компонентов во всех состояниях в одной теме.
class ShowcasePanel extends StatelessWidget {
  const ShowcasePanel({super.key, required this.brightness});

  /// Ширина, при которой панель смотрится как в превью дизайн-системы.
  static const double width = 560;

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ylTheme(brightness),
      child: Builder(
        builder: (context) => YlSurface(
          child: ValueListenableBuilder<bool>(
            valueListenable: streamerMode,
            builder: (context, _, _) => _PanelBody(brightness: brightness),
          ),
        ),
      ),
    );
  }
}

class _PanelBody extends StatefulWidget {
  const _PanelBody({required this.brightness});

  final Brightness brightness;

  @override
  State<_PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<_PanelBody> {
  bool _noise = true;
  bool _ptt = false;
  String _quality = '720p';
  int _tab = 0;
  bool _plusOne = true;
  TextEditingController? _name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _name ??= TextEditingController(text: L10n.of(context).scInputNameValue);
  }

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l10n = L10n.of(context);
    final dark = widget.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(YlSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dark ? l10n.scThemeDark : l10n.scThemeLight,
            style: YlText.h2.copyWith(color: c.ink),
          ),
          _Section(
            title: l10n.scSectionButton,
            child: Wrap(
              spacing: YlSpace.s2,
              runSpacing: YlSpace.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                YlButton(label: l10n.scButtonJoin, onPressed: () {}),
                YlButton(
                  label: l10n.scButtonHaveProfile,
                  onPressed: () {},
                  kind: YlButtonKind.secondary,
                ),
                YlButton(label: l10n.scButtonBack, onPressed: () {}, kind: YlButtonKind.quiet),
                YlButton(label: l10n.scButtonLeave, onPressed: () {}, kind: YlButtonKind.danger),
                YlButton(label: l10n.scButtonDisabled, onPressed: null),
                YlButton(label: l10n.scButtonManage, onPressed: () {}, size: YlButtonSize.sm),
                YlButton(
                  label: l10n.scButtonManage,
                  onPressed: () {},
                  size: YlButtonSize.sm,
                  kind: YlButtonKind.secondary,
                ),
              ],
            ),
          ),
          _Section(
            title: l10n.scSectionToggle,
            child: Column(
              children: [
                YlToggle(
                  label: l10n.scToggleNoise,
                  description: l10n.scToggleNoiseHint,
                  value: _noise,
                  onChanged: (v) => setState(() => _noise = v),
                ),
                const SizedBox(height: YlSpace.s4),
                YlToggle(
                  label: l10n.scTogglePtt,
                  description: l10n.scTogglePttHint,
                  value: _ptt,
                  onChanged: (v) => setState(() => _ptt = v),
                ),
                const SizedBox(height: YlSpace.s4),
                YlToggle(
                  label: l10n.scToggleLocked,
                  lockedReason: l10n.scToggleLockedReason,
                  value: false,
                  onChanged: null,
                ),
                const SizedBox(height: YlSpace.s4),
                YlToggle(
                  label: l10n.scToggleStreamer,
                  description: l10n.scToggleStreamerHint,
                  value: streamerMode.value,
                  onChanged: (v) => streamerMode.value = v,
                ),
              ],
            ),
          ),
          _Section(
            title: l10n.scSectionSegmented,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                YlSegmented<String>(
                  segments: const [
                    YlSegment('480p', '480p'),
                    YlSegment('720p', '720p'),
                    YlSegment('1080p', '1080p', available: false),
                  ],
                  value: _quality,
                  onChanged: (v) => setState(() => _quality = v),
                  note: l10n.scSegStreamNote,
                ),
                const SizedBox(height: YlSpace.s3),
                YlSegmented<int>(
                  segments: [
                    YlSegment(0, l10n.scSegAll),
                    YlSegment(1, l10n.scSegPending),
                    YlSegment(2, l10n.scSegBans),
                  ],
                  value: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                ),
              ],
            ),
          ),
          _Section(
            title: l10n.scSectionInput,
            child: Column(
              children: [
                YlInput(label: l10n.scInputName, controller: _name),
                const SizedBox(height: YlSpace.s3),
                YlInput(label: l10n.scInputInvite, placeholder: l10n.scInputInviteHint, mono: true),
                const SizedBox(height: YlSpace.s3),
                YlInput(label: l10n.scInputAbout),
              ],
            ),
          ),
          _Section(
            title: l10n.scSectionAvatar,
            child: Wrap(
              spacing: YlSpace.s3,
              runSpacing: YlSpace.s3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                YlAvatar.user(name: l10n.scNameKrivozub, status: YlStatus.online),
                YlAvatar.user(name: l10n.scNameSavanna, status: YlStatus.idle),
                YlAvatar.user(name: l10n.scNameKhokhotun, status: YlStatus.dnd),
                YlAvatar.user(name: l10n.scNameSpotted, status: YlStatus.offline),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: YlSpace.s2),
                  child: YlAvatar.user(name: l10n.scNameSpotted, size: 56, speaking: true),
                ),
                YlAvatar.server(name: l10n.scServerName),
                YlAvatar.server(name: l10n.scServerName, squared: false),
              ],
            ),
          ),
          _Section(
            title: l10n.scSectionChip,
            child: Wrap(
              spacing: YlSpace.s2,
              runSpacing: YlSpace.s2,
              children: [
                YlChip.role(label: l10n.scRoleMaster, roleColor: c.roleMaster),
                YlChip.role(label: l10n.scRolePlayer, roleColor: c.rolePlayer),
                YlChip.role(label: l10n.scRoleGuest, roleColor: c.roleGuest),
                YlChip.role(label: l10n.scRoleBot, roleColor: c.roleBot),
                YlChip.reaction(
                  label: _reactionPlusOne,
                  count: _plusOne ? 4 : 3,
                  mine: _plusOne,
                  onTap: () => setState(() => _plusOne = !_plusOne),
                ),
                YlChip.reaction(label: l10n.scReactionDice, count: 2, onTap: () {}),
              ],
            ),
          ),
          _Section(
            title: l10n.scSectionBadge,
            child: const Wrap(
              spacing: YlSpace.s3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [YlBadge.live(), YlBadge.bot(), YlBadge.count(2), YlBadge.count(120)],
            ),
          ),
          _Section(
            title: l10n.scSectionBanner,
            child: ClipRRect(
              borderRadius: YlRadius.lg,
              child: Column(
                children: [
                  YlStatusBanner(
                    kind: YlBannerKind.warn,
                    message: l10n.scBannerReconnecting(
                      redact(RedactKind.serverName, _demoServer, l10n),
                      2,
                      3,
                    ),
                    address: _demoAddress,
                  ),
                  YlStatusBanner(kind: YlBannerKind.ok, message: l10n.scBannerFailover),
                  YlStatusBanner(
                    kind: YlBannerKind.err,
                    message: l10n.scBannerOffline,
                    actionLabel: l10n.bannerRetry,
                    onAction: () {},
                  ),
                ],
              ),
            ),
          ),
          _Section(
            title: l10n.scSectionChannelRow,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: YlMetrics.channelColumnWidth,
                  padding: const EdgeInsets.all(YlSpace.s2),
                  decoration: BoxDecoration(color: c.bg200, borderRadius: YlRadius.lg),
                  child: Column(
                    children: [
                      YlChannelRow(name: l10n.scChannelGeneral, selected: true, onTap: () {}),
                      YlChannelRow(name: l10n.scChannelNews, unread: true, onTap: () {}),
                      YlChannelRow(name: l10n.scChannelScreens, onTap: () {}),
                      YlChannelRow(
                        name: l10n.scChannelTavern,
                        kind: YlChannelKind.voice,
                        selected: true,
                        connected: true,
                        timer: _demoTimer,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: YlSpace.s4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(YlSpace.s2),
                    decoration: BoxDecoration(color: c.bg200, borderRadius: YlRadius.lg),
                    child: Column(
                      children: [
                        YlChannelRow(name: l10n.scChannelGeneral, touch: true, onTap: () {}),
                        YlChannelRow(
                          name: l10n.scChannelTavern,
                          kind: YlChannelKind.voice,
                          touch: true,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: YlSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: YlText.overline.copyWith(color: c.subtle)),
          const SizedBox(height: YlSpace.s3),
          child,
        ],
      ),
    );
  }
}
