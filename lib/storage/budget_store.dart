import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';
import '../services/auth_service.dart';

class BudgetStore {
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
    };
    await prefs.setString(key, jsonEncode(data));
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
      final m = (map['allocationsAmount'] as Map);
      m.forEach((k, v) {
        alloc[BudgetCategory.values.firstWhere((e) => e.name == k)] = (v as num).toDouble();
      });
    } else if (map.containsKey('allocations')) {
      // Legacy schema: percents, convert to amounts
      final m = (map['allocations'] as Map);
      m.forEach((k, v) {
        final pct = (v as num).toDouble();
        final amount = deposit * (pct / 100.0);
        alloc[BudgetCategory.values.firstWhere((e) => e.name == k)] = amount;
      });
      // Persist back in new format to avoid repeated conversion
      final newData = {
        'monthlyDeposit': deposit,
        'allocationsAmount': alloc.map((k, v) => MapEntry(k.name, v)),
      };
      await prefs.setString(key, jsonEncode(newData));
    }

    return BudgetConfig(monthlyDeposit: deposit, allocationsAmount: alloc);
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


