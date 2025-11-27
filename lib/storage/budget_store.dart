import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';
import '../services/auth_service.dart';

class BudgetStore extends ChangeNotifier {
  static const String _legacyConfigKey = 'budget_config_v1';
  static const String _legacyTransferCatsKey = 'transfer_categories_v1';
  static const String _fallbackUser = 'guest';

  String _configKeyFor(String username) => 'budget_config_${username}_v1';
  String _transferKeyFor(String username) => 'transfer_categories_${username}_v1';

  Future<void> saveConfig(BudgetConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _configKeyFor(username);
    final data = {
      'monthlyDeposit': config.monthlyDeposit,
      // Persist as fixed amounts
      'allocationsAmount': config.allocationsAmount.map((k, v) => MapEntry(k.name, v)),
      'lastUpdated': config.lastUpdated.toIso8601String(),
    };
    await prefs.setString(key, jsonEncode(data));
    notifyListeners();
  }

  Future<BudgetConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _configKeyFor(username);
    String? raw = prefs.getString(key);
    // Migración desde clave global
    if (raw == null) {
      final legacy = prefs.getString(_legacyConfigKey);
      if (legacy != null) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyConfigKey);
        raw = legacy;
      }
    }
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final deposit = (map['monthlyDeposit'] as num).toDouble();
    final alloc = <BudgetCategory, double>{};

    if (map.containsKey('allocationsAmount')) {
      // New schema: fixed amounts
      final allocMap = map['allocationsAmount'] as Map<String, dynamic>;
      for (final entry in allocMap.entries) {
        final cat = BudgetCategory.values.firstWhere(
          (c) => c.name == entry.key,
          orElse: () => BudgetCategory.otros,
        );
        alloc[cat] = (entry.value as num).toDouble();
      }
    } else {
      // Legacy schema: percentages
      final percentages = map['allocations'] as Map<String, dynamic>?;
      if (percentages != null) {
        for (final entry in percentages.entries) {
          final cat = BudgetCategory.values.firstWhere(
            (c) => c.name == entry.key,
            orElse: () => BudgetCategory.otros,
          );
          alloc[cat] = deposit * ((entry.value as num).toDouble() / 100);
        }
      }
    }

    // Parse lastUpdated, default to now if not present
    DateTime lastUpdated;
    if (map.containsKey('lastUpdated')) {
      lastUpdated = DateTime.parse(map['lastUpdated'] as String);
    } else {
      lastUpdated = DateTime.now();
    }

    return BudgetConfig(
      monthlyDeposit: deposit,
      allocationsAmount: alloc,
      lastUpdated: lastUpdated,
    );
  }

  Future<void> setTransferCategory(String transferId, BudgetCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _transferKeyFor(username);
    String? raw = prefs.getString(key);
    // Migración desde clave global
    if (raw == null) {
      final legacy = prefs.getString(_legacyTransferCatsKey);
      if (legacy != null) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyTransferCatsKey);
        raw = legacy;
      }
    }
    final map = raw != null ? (jsonDecode(raw) as Map<String, dynamic>) : <String, dynamic>{};
    map[transferId] = category.name;
    await prefs.setString(key, jsonEncode(map));
    notifyListeners();
  }

  Future<Map<String, BudgetCategory>> loadTransferCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _transferKeyFor(username);
    String? raw = prefs.getString(key);
    // Migración desde clave global
    if (raw == null) {
      final legacy = prefs.getString(_legacyTransferCatsKey);
      if (legacy != null) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyTransferCatsKey);
        raw = legacy;
      }
    }
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, BudgetCategory.values.firstWhere((e) => e.name == v)));
  }
}


