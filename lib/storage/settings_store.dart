import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class SettingsStore {
  static const String _legacyKey = 'settings_v1';
  static const String _fallbackUser = 'guest';

  String _keyFor(String username) => 'settings_${username}_v1';

  Future<void> save({required int reminderDays, List<String>? notificationTimes}) async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _keyFor(username);
    // merge with existing settings
    final existingRaw = prefs.getString(key);
    Map<String, dynamic> map = {};
    if (existingRaw != null) {
      try {
        map = (jsonDecode(existingRaw) as Map).cast<String, dynamic>();
      } catch (_) {
        map = {};
      }
    }
    map['reminderDays'] = reminderDays;
    if (notificationTimes != null) {
      map['notificationTimes'] = notificationTimes;
    }
    await prefs.setString(key, jsonEncode(map));
  }

  Future<int> loadReminderDays() async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _keyFor(username);
    String? raw = prefs.getString(key);
    // Migración desde clave global
    if (raw == null) {
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKey);
        raw = legacy;
      }
    }
    if (raw == null) return 1; // default: 1 notificación al día
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map['reminderDays'] as num?)?.toInt() ?? 1;
  }

  Future<List<String>> loadNotificationTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _keyFor(username);
    final raw = prefs.getString(key);
    if (raw == null) return ['10:00']; // default: una notificación a las 10 AM
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final times = map['notificationTimes'] as List<dynamic>?;
    return times?.map((e) => e.toString()).toList() ?? ['10:00'];
  }

  Future<int> loadThemeSeed() async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _keyFor(username);
    final raw = prefs.getString(key);
    if (raw == null) return 0xFF6B35C3; // default primary purple
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map['themeSeed'] as num?)?.toInt() ?? 0xFF6B35C3;
  }

  Future<void> saveThemeSeed(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _keyFor(username);
    final raw = prefs.getString(key);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    map['themeSeed'] = argb;
    await prefs.setString(key, jsonEncode(map));
  }
}

