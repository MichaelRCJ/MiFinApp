enum BudgetCategory { arriendo, comida, transporte, otros }

class BudgetConfig {
  final double monthlyDeposit;
  final Map<BudgetCategory, double> allocationsAmount; // fixed amount per category

  const BudgetConfig({required this.monthlyDeposit, required this.allocationsAmount});

  double allocationAmount(BudgetCategory c) {
    return allocationsAmount[c] ?? 0;
  }
}


