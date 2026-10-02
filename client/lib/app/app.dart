import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import '../core/account/account_store.dart';
import '../core/account/platform_bridge.dart';
import '../core/identity/identity.dart';
import '../core/vault/key_vault.dart';
import '../features/home/home_stub.dart';
import '../features/onboarding/onboarding_controller.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../l10n/gen/app_localizations.dart';
import '../ui/theme/yl_theme.dart';
import '../ui/widgets/widgets.dart';

/// Зависимости приложения; в тестах подменяются.
class AppServices {
  const AppServices({required this.store, required this.bridge, required this.pickImage});

  final AccountStore store;
  final PlatformBridge bridge;
  final Future<Uint8List?> Function() pickImage;

  /// Хранилище по `--dart-define=YL_VAULT`: `secure` (по умолчанию) или
  /// `file` — незашифрованный файл для отладки в Docker.
  static Future<AppServices> production() async {
    final support = await getApplicationSupportDirectory();
    const kind = String.fromEnvironment('YL_VAULT', defaultValue: 'secure');
    final KeyVault vault = kind == 'file' && kDebugMode
        ? FileVault(File('${support.path}/insecure-vault.json'))
        : SecureVault();
    return AppServices(
      store: AccountStore(vault: vault, dir: Directory('${support.path}/identity')),
      bridge: PlatformBridge(),
      pickImage: _pickImage,
    );
  }

  static Future<Uint8List?> _pickImage() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'images',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
          mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
        ),
      ],
    );
    return file?.readAsBytes();
  }
}

/// Клиент YeenLink.
class YeenLinkApp extends StatelessWidget {
  const YeenLinkApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appTitle,
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
      home: AppRoot(services: services),
    );
  }
}

/// Онбординг, если профиля на устройстве нет, иначе — главное окно.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.services});

  final AppServices services;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final OnboardingController _onboarding = OnboardingController(
    store: widget.services.store,
    pickImage: widget.services.pickImage,
  );
  late Future<(LocalAccount, Profile?)?> _account = _load();

  // Фраза в буфере обмена не переживает закрытие приложения. При уходе в фон
  // буфер не трогаем: фразу копируют, чтобы вставить в менеджер паролей.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onDetach: _clearClipboard,
    onExitRequested: () async {
      await widget.services.bridge.clearSensitiveClipboard();
      return AppExitResponse.exit;
    },
  );

  void _clearClipboard() => widget.services.bridge.clearSensitiveClipboard();

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  Future<(LocalAccount, Profile?)?> _load() async {
    final acc = await widget.services.store.load();
    if (acc == null) return null;
    final profile = acc.profile == null ? null : await openProfile(acc.profile!);
    return (acc, profile);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _onboarding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _account,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const YlSurface(child: SizedBox());
        if (snap.hasError) {
          return YlSurface(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(YlSpace.s6),
                child: Text(L10n.of(context).homeLoadFailed('${snap.error}')),
              ),
            ),
          );
        }
        final data = snap.data;
        if (data != null) return HomeStub(account: data.$1, profile: data.$2);
        return OnboardingScreen(
          controller: _onboarding,
          bridge: widget.services.bridge,
          // Не `setState(() => _account = …)`: стрелка возвращает значение
          // присваивания — Future, и в отладочной сборке setState падает на
          // assert, перехода нет (баг фазы 1 на Android). Только тело в скобках.
          onOpenApp: () {
            final next = _load();
            setState(() {
              _account = next;
            });
          },
        );
      },
    );
  }
}
