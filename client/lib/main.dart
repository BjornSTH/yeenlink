import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/gen/app_localizations.dart';
import 'ui/theme/yl_theme.dart';
import 'ui/widgets/widgets.dart';

void main() => runApp(const YeenLinkApp());

/// Клиент YeenLink. В фазе 0 — только каркас: тема, локализация и пустое
/// окно; экраны появляются с фазы 1 (docs/spec.md).
class YeenLinkApp extends StatelessWidget {
  const YeenLinkApp({super.key});

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
      darkTheme: ylTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: const _Skeleton(),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l10n = L10n.of(context);
    return YlSurface(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(YlSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.appTitle, style: YlText.h1.copyWith(color: c.ink)),
              const SizedBox(height: YlSpace.s2),
              Text(
                l10n.appSkeleton,
                style: YlText.body.copyWith(color: c.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
