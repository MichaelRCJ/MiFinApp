import 'package:flutter/material.dart';

import '../storage/settings_store.dart';

class ThemeController {
  final SettingsStore _settings;
  final ValueNotifier<int> seedArgb;

  ThemeController(this._settings, {int initialSeed = 0xFF6B35C3}) : seedArgb = ValueNotifier<int>(initialSeed);

  Future<void> load() async {
    final seed = await _settings.loadThemeSeed();
    seedArgb.value = seed;
  }

  Future<void> setSeed(Color color) async {
    final argb = color.value;
    seedArgb.value = argb;
    await _settings.saveThemeSeed(argb);
  }

  Color get seedColor => Color(seedArgb.value);
}
