import 'package:flutter/material.dart';

/// Vizualna tema appky. Zmenou 'seedColor' sa prefarbi cela aplikacia -
/// Material 3 z tejto jednej farby automaticky odvodi cely tonalny system
/// (AppBar, tlacidla, zvyraznenia, atd.).
class AppTheme {
  static const Color seedColor = Color(0xFF6699CC); // jemna modra

  static ThemeData get themeData => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      );
}
