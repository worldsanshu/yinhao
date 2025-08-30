import 'package:flutter/material.dart';

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00F5A0),
    secondary: Color(0xFF00D9F5),
    surface: Color(0xFF0B0F14),
    background: Color(0xFF0B0F14),
  ),
  scaffoldBackgroundColor: const Color(0xFF0B0F14),
  cardTheme: CardThemeData(
    color: const Color(0xFF121821),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 4,
    margin: const EdgeInsets.all(12),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF121821),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x2233FFCC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF00F5A0), width: 2),
    ),
    hintStyle: const TextStyle(color: Color(0xFF6D7A8A)),
    labelStyle: const TextStyle(color: Color(0xFF8EA0B2)),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFB8C1CC)),
  ),
);
