import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_controller.dart';

/// Açık/koyu tema arasında geçiş yapan AppBar butonu.
///
/// İkon o an ekranda görünen parlaklığa göre değişir: koyu moddayken güneş
/// (aydınlığa geç), açık moddayken ay (karanlığa geç).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.read<ThemeController>();

    return IconButton(
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      tooltip: isDark ? 'Açık temaya geç' : 'Koyu temaya geç',
      onPressed: () => controller.toggle(isCurrentlyDark: isDark),
    );
  }
}
