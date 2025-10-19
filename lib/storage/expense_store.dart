import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../services/auth_service.dart';

class ExpenseStore {
  static const String _fallbackUser = 'guest';
  static const String _legacyKey = 'expenses_v1';

  String _keyForUser(String username) => 'expenses_${username}_v1';

  Future<List<Expense>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _keyForUser(username);
    String? raw = prefs.getString(key);

    // Migración automática desde clave global (pre-perfil) a clave por usuario
    if (raw == null) {
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKey);
        raw = legacy;
      }
    }

    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Expense.fromJson).toList();
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final data = expenses.map((e) => e.toJson()).toList();
    final username = await AuthService.getLastUsername() ?? _fallbackUser;
    final key = _keyForUser(username);
    await prefs.setString(key, jsonEncode(data));
  }

  Future<void> addExpense(Expense expense) async {
    final items = await loadExpenses();
    items.add(expense);
    await saveExpenses(items);
  }

  Future<void> removeExpense(String id) async {
    final items = await loadExpenses();
    items.removeWhere((e) => e.id == id);
    await saveExpenses(items);
  }
}

