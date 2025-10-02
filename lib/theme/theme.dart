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

ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: lightColorScheme,

  // 👇 هنا حطينا الخط الافتراضي
  fontFamily: 'Handicrafts',
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      fontFamily: 'Handicrafts',
      fontFamilyFallback: ['Tajawal'],
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Handicrafts',
      fontFamilyFallback: ['Tajawal'],
    ),
    bodySmall: TextStyle(
      fontFamily: 'Handicrafts',
      fontFamilyFallback: ['Tajawal'],
    ),
  ),
);

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: darkColorScheme,

  // 👇 نفس الشي للوضع الليلي
  fontFamily: 'Handicrafts',
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      fontFamily: 'Handicrafts',
      fontFamilyFallback: ['Tajawal'],
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Handicrafts',
      fontFamilyFallback: ['Tajawal'],
    ),
    bodySmall: TextStyle(
      fontFamily: 'Handicrafts',
      fontFamilyFallback: ['Tajawal'],
    ),
  ),
);
