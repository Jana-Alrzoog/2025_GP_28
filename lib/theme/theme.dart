import 'package:flutter/material.dart';

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color.fromARGB(255, 59, 59, 59),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF6EAEE7),
  onSecondary: Color(0xFFFFFFFF),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  background: Color(0xFFFCFDF6),
  onBackground: Color(0xFF1A1C18),
  shadow: Color(0xFF000000),
  outlineVariant: Color(0xFFC2C8BC),
  surface: Color(0xFFF9FAF3),
  onSurface: Color(0xFF1A1C18),
);

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color.fromARGB(255, 59, 59, 59),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF6EAEE7),
  onSecondary: Color(0xFFFFFFFF),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  background: Color(0xFFFCFDF6),
  onBackground: Color(0xFF1A1C18),
  shadow: Color(0xFF000000),
  outlineVariant: Color(0xFFC2C8BC),
  surface: Color(0xFFF9FAF3),
  onSurface: Color(0xFF1A1C18),
);

ThemeData lightMode = _buildTheme(
  brightness: Brightness.light,
  scheme: lightColorScheme,
);

ThemeData darkMode = _buildTheme(
  brightness: Brightness.dark,
  scheme: darkColorScheme,
);

ThemeData _buildTheme({
  required Brightness brightness,
  required ColorScheme scheme,
}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    // الخط الأساسي يبقى عربيك/Handicrafts مثل ما هو
    fontFamily: 'Handicrafts',
  );

  // نضيف AppLatin كـ fallback لكل أنماط النص — بدون ما نغيّر الخط الأساسي
  final textWithLatin = _withLatinFallback(base.textTheme);
  final primaryTextWithLatin = _withLatinFallback(base.primaryTextTheme);

  return base.copyWith(
    textTheme: textWithLatin,
    primaryTextTheme: primaryTextWithLatin,
    // لو حاب تتأكد في AppBar/Buttons وغيرهم:
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: (base.appBarTheme.titleTextStyle ?? const TextStyle())
          .copyWith(fontFamilyFallback: const ['AppLatin']),
      toolbarTextStyle: (base.appBarTheme.toolbarTextStyle ?? const TextStyle())
          .copyWith(fontFamilyFallback: const ['AppLatin']),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      hintStyle: (base.inputDecorationTheme.hintStyle ?? const TextStyle())
          .copyWith(fontFamilyFallback: const ['AppLatin']),
    ),
  );
}

/// يحقن AppLatin كـ fallback في جميع TextStyles داخل TextTheme.
TextTheme _withLatinFallback(TextTheme t) {
  TextStyle addFallback(TextStyle? s) =>
      (s ?? const TextStyle()).copyWith(fontFamilyFallback: const ['AppLatin', 'Roboto']);

  return TextTheme(
    displayLarge:    addFallback(t.displayLarge),
    displayMedium:   addFallback(t.displayMedium),
    displaySmall:    addFallback(t.displaySmall),
    headlineLarge:   addFallback(t.headlineLarge),
    headlineMedium:  addFallback(t.headlineMedium),
    headlineSmall:   addFallback(t.headlineSmall),
    titleLarge:      addFallback(t.titleLarge),
    titleMedium:     addFallback(t.titleMedium),
    titleSmall:      addFallback(t.titleSmall),
    bodyLarge:       addFallback(t.bodyLarge),
    bodyMedium:      addFallback(t.bodyMedium),
    bodySmall:       addFallback(t.bodySmall),
    labelLarge:      addFallback(t.labelLarge),
    labelMedium:     addFallback(t.labelMedium),
    labelSmall:      addFallback(t.labelSmall),
  );
}
