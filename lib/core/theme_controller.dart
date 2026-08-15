import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode controller. `main.dart` wraps MaterialApp in a
/// ValueListenableBuilder listening to [themeMode]; any screen can flip it
/// via `ThemeController.instance.setThemeMode(...)`.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'theme_mode';

  /// Defaults to dark since that's what this app looked like before
  /// theming existed - flipping the default to light would silently
  /// change the app for everyone already using it.
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    themeMode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
