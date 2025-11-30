import 'package:firebase_auth/firebase_auth.dart';
import '../storage/expense_store.dart';
import '../storage/budget_store.dart';
import '../storage/settings_store.dart';
import '../services/notification_service.dart';
import '../services/theme_controller.dart';

final FirebaseAuth auth = FirebaseAuth.instance;
final ExpenseStore expenseStore = ExpenseStore();
final BudgetStore budgetStore = BudgetStore();
final SettingsStore settingsStore = SettingsStore();
final NotificationService notificationService = NotificationService();
final ThemeController themeController = ThemeController(settingsStore);
