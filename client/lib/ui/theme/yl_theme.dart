import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

/// Тема приложения: токены в виде ThemeExtension плюс настройки Material,
/// чтобы служебные части фреймворка (выделение текста, курсор) не выбивались
/// из палитры. Акцент из настроек меняет только `accent` (README дизайн-системы).
ThemeData ylTheme(Brightness brightness, {Color? accent}) {
  final base = brightness == Brightness.dark ? YlColors.dark : YlColors.light;
  final c = accent == null ? base : base.copyWith(accent: accent);
  final shadows = brightness == Brightness.dark ? YlShadows.dark : YlShadows.light;

  TextStyle ink(TextStyle s) => s.copyWith(color: c.ink);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: YlText.sansFamily,
    scaffoldBackgroundColor: c.bg100,
    canvasColor: c.bg100,
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.bg400,
    hoverColor: c.bg400,
    focusColor: c.bg400,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.onDanger,
      surface: c.bg100,
      onSurface: c.ink,
      outline: c.border,
      scrim: c.scrim,
    ),
    textTheme: TextTheme(
      displayLarge: ink(YlText.display),
      headlineLarge: ink(YlText.h1),
      headlineMedium: ink(YlText.h2),
      titleLarge: ink(YlText.title),
      bodyLarge: ink(YlText.bodyLg),
      bodyMedium: ink(YlText.body),
      labelLarge: ink(YlText.label),
      bodySmall: YlText.caption.copyWith(color: c.muted),
      labelSmall: YlText.overline.copyWith(color: c.subtle),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.35),
      selectionHandleColor: c.accent,
    ),
    extensions: [c, shadows],
  );
}
