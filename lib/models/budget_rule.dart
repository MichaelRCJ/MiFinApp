import 'budget.dart';

enum RuleSeverity {
  info,
  warning,
  danger,
}

class BudgetRule {
  final String title;
  final String description;
  final RuleSeverity severity;
  final BudgetCategory? category;
  final String? recommendation;

  BudgetRule({
    required this.title,
    required this.description,
    required this.severity,
    this.category,
    this.recommendation,
  });
}
