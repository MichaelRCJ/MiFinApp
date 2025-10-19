import '../storage/budget_store.dart';
import '../storage/settings_store.dart';
import '../storage/expense_store.dart';
import 'theme_controller.dart';

final budgetStore = BudgetStore();
final settingsStore = SettingsStore();
final expenseStore = ExpenseStore();
final themeController = ThemeController(settingsStore);


