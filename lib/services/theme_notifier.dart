import 'package:flutter/material.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier([super.mode = ThemeMode.dark]);

  void setThemeMode(ThemeMode mode) {
    value = mode;
  }
}

final themeNotifier = ThemeNotifier(ThemeMode.dark);
