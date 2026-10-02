import 'package:flutter/widgets.dart';

import '../../core/account/account_store.dart';
import '../../core/identity/identity.dart';
import '../../core/redact.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/widgets.dart';

/// Каркас главного окна до фазы 2: показывает, что профиль есть на этом
/// устройстве. Идентификаторы — только через redact.
class HomeStub extends StatelessWidget {
  const HomeStub({super.key, required this.account, required this.profile});

  final LocalAccount account;

  /// Разобранный профиль; null — восстановлен по фразе без имени, профиль
  /// придёт с сервера (фаза 2).
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    final avatar = account.avatarPng;
    final name = profile?.name;
    final fp = fingerprint(account.masterPub);
    return YlSurface(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(YlSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const YlLogo(),
                const SizedBox(height: YlSpace.s8),
                // Баннер — не шире колонки онбординга, на телефоне — во всю ширину.
                Container(
                  height: YlSize.avatarLg + 2 * YlSpace.s6,
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: YlSize.onboardingAsideW),
                  decoration: BoxDecoration(
                    color: c.bannerByName(profile?.bannerColor),
                    borderRadius: YlRadius.xl,
                  ),
                  alignment: Alignment.center,
                  // Без имени — первые два символа отпечатка, через redact: в
                  // режиме стримера отпечатка не видно, и букв тоже.
                  child: ValueListenableBuilder<bool>(
                    valueListenable: streamerMode,
                    builder: (context, _, _) => YlAvatar.user(
                      name: name,
                      colorIndex: avatarColorIndex(account.masterPub, c.avatarPalette.length),
                      fallbackInitials: redact(RedactKind.fingerprint, fp, l) == fp
                          ? fp.substring(0, 2)
                          : '',
                      size: YlSize.avatarLg,
                      image: avatar == null ? null : MemoryImage(avatar),
                    ),
                  ),
                ),
                const SizedBox(height: YlSpace.s4),
                Text(
                  name ?? l.homeNoName,
                  textAlign: TextAlign.center,
                  style: YlText.title.copyWith(color: c.ink),
                ),
                const SizedBox(height: YlSpace.s5),
                _Row(
                  label: l.homeFingerprint,
                  value: RedactedText(
                    RedactKind.fingerprint,
                    fp,
                    style: YlText.mono.copyWith(color: c.inkSoft),
                  ),
                ),
                const SizedBox(height: YlSpace.s2),
                _Row(
                  label: l.homeDevice,
                  value: Text(_deviceName(account), style: YlText.body.copyWith(color: c.inkSoft)),
                ),
                const SizedBox(height: YlSpace.s6),
                Text(
                  l.homeNoServers,
                  textAlign: TextAlign.center,
                  style: YlText.caption.copyWith(color: c.subtle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _deviceName(LocalAccount a) => (DeviceCert.fromMap(a.deviceCert.payloadMap())).name;
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    // На узком экране значение переносится под подпись.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: YlSpace.s3,
      runSpacing: YlSpace.s1,
      children: [
        Text(label, style: YlText.label.copyWith(color: c.muted)),
        value,
      ],
    );
  }
}
