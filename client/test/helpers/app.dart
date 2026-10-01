import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/l10n/gen/app_localizations.dart';
import 'package:yeenlink/ui/theme/yl_theme.dart';
import 'package:yeenlink/ui/widgets/widgets.dart';

/// Загружает шрифты приложения: по умолчанию тесты рисуют текст шрифтом Ahem
/// (квадратами), и golden-снимки были бы бесполезны.
Future<void> loadAppFonts() async {
  final families = {
    YlText.sansFamily: ['Regular', 'SemiBold', 'Bold', 'ExtraBold'].map((w) => 'Manrope-$w.ttf'),
    YlText.monoFamily: ['Regular', 'Medium'].map((w) => 'JetBrainsMono-$w.ttf'),
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Обёртка с темой и локализацией, как в приложении.
Widget testApp(Widget child, {Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ylTheme(brightness),
    home: YlSurface(child: child),
  );
}

/// Задаёт размер окна теста и возвращает его к исходному после теста.
void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
