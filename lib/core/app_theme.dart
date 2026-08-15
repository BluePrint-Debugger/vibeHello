import 'package:flutter/material.dart';

/// Semantic colors used throughout the app's custom-painted screens
/// (most screens here use raw Container/BoxDecoration rather than
/// Material widgets that pick up ColorScheme automatically). Screens
/// migrated to support light/dark should pull colors from here via
/// `context.appColors.xxx` instead of hardcoding `Color(0xFF...)`.
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentSecondary;
  final Color border;

  const AppColorsExt({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSecondary,
    required this.border,
  });

  @override
  AppColorsExt copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentSecondary,
    Color? border,
  }) {
    return AppColorsExt(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      border: border ?? this.border,
    );
  }

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColorsExt get appColors =>
      Theme.of(this).extension<AppColorsExt>() ?? AppTheme.darkColors;
}

class AppTheme {
  static const darkColors = AppColorsExt(
    background: Color(0xFF0B1020),
    surface: Color(0xFF11182E),
    surfaceVariant: Color(0xFF141B34),
    textPrimary: Colors.white,
    textSecondary: Colors.white54,
    accent: Color(0xFF6C63FF),
    accentSecondary: Color(0xFF00D1FF),
    border: Colors.white10,
  );

  static const lightColors = AppColorsExt(
    background: Color(0xFFF5F6FB),
    surface: Colors.white,
    surfaceVariant: Color(0xFFEFF1F8),
    textPrimary: Color(0xFF14162B),
    textSecondary: Color(0xFF5C5F73),
    accent: Color(0xFF6C63FF),
    accentSecondary: Color(0xFF0090C4),
    border: Color(0xFFE1E3EE),
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkColors.accent,
        brightness: Brightness.dark,
        surface: darkColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkColors.background,
        foregroundColor: darkColors.textPrimary,
        elevation: 0,
      ),
      extensions: [darkColors],
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightColors.accent,
        brightness: Brightness.light,
        surface: lightColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightColors.background,
        foregroundColor: lightColors.textPrimary,
        elevation: 0,
      ),
      extensions: [lightColors],
    );
  }
}
