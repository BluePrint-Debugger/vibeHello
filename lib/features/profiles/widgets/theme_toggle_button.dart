import 'package:flutter/material.dart';

import '../../../core/theme_controller.dart';
import '../../../core/app_theme.dart';

/// A compact 3-way theme picker (light / dark / system). Self-contained so
/// it can be dropped into any screen without that screen needing to be
/// fully theme-migrated itself.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return PopupMenuButton<ThemeMode>(
          tooltip: 'Theme',
          initialValue: mode,
          color: context.appColors.surfaceVariant,
          icon: Icon(_iconFor(mode), color: Colors.white70),
          onSelected: (selected) {
            ThemeController.instance.setThemeMode(selected);
          },
          itemBuilder: (context) => [
            _item(ThemeMode.light, Icons.light_mode, 'Light', mode),
            _item(ThemeMode.dark, Icons.dark_mode, 'Dark', mode),
            _item(ThemeMode.system, Icons.brightness_auto, 'System', mode),
          ],
        );
      },
    );
  }

  IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  PopupMenuItem<ThemeMode> _item(
    ThemeMode value,
    IconData icon,
    String label,
    ThemeMode current,
  ) {
    final selected = value == current;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? const Color(0xFF6C63FF) : Colors.white70,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (selected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 16, color: Color(0xFF6C63FF)),
          ],
        ],
      ),
    );
  }
}
