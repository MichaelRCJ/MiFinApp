import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../models/budget.dart';
import '../../models/budget_rule.dart';
import '../../services/service_locator.dart';
import '../../storage/budget_store.dart';
import '../../services/auth_service.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  List<Expense> _monthExpenses = const [];
  bool _loading = true;
  BudgetConfig? _budgetConfig;
  List<BudgetRule> _violatedRules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await expenseStore.loadExpenses();
      final now = DateTime.now();
      final month = all.where((e) => e.fecha.year == now.year && e.fecha.month == now.month).toList();
      
      // Cargar configuración de presupuesto
      final username = await AuthService.getLastUsername() ?? 'default';
      final budgetConfig = await budgetStore.loadConfig();
      
      if (!mounted) return;
      setState(() {
        _monthExpenses = month;
        _budgetConfig = budgetConfig;
        _violatedRules = _checkBudgetRules();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Verificar reglas del presupuesto
  List<BudgetRule> _checkBudgetRules() {
    final rules = <BudgetRule>[];
    if (_budgetConfig == null) return rules;

    final totalExpenses = _total;
    final totalAllocated = _budgetConfig!.allocationsAmount.values.fold(0.0, (sum, val) => sum + val);
    final monthlyDeposit = _budgetConfig!.monthlyDeposit;

    // Regla 1: No gastar más del 80% del presupuesto en una sola categoría
    for (final entry in _budgetConfig!.allocationsAmount.entries) {
      final category = entry.key;
      final allocated = entry.value;
      final spent = _getSpentByCategory(category);
      
      if (allocated > 0 && spent > allocated * 0.8) {
        rules.add(BudgetRule(
          title: 'Límite de categoría cercano',
          description: 'Has gastado el ${((spent/allocated)*100).toStringAsFixed(0)}% en ${_getBudgetCategoryName(category)}',
          severity: spent > allocated ? RuleSeverity.danger : RuleSeverity.warning,
          category: category,
          recommendation: spent > allocated 
              ? 'Considera reducir gastos en esta categoría o reasignar presupuesto'
              : 'Cuidado, estás cerca del límite de esta categoría',
        ));
      }
    }

    // Regla 2: No gastar más del 90% del saldo total
    if (monthlyDeposit > 0 && totalExpenses > monthlyDeposit * 0.9) {
      rules.add(BudgetRule(
        title: 'Saldo casi agotado',
        description: 'Has gastado el ${((totalExpenses/monthlyDeposit)*100).toStringAsFixed(0)}% de tu saldo',
        severity: totalExpenses > monthlyDeposit ? RuleSeverity.danger : RuleSeverity.warning,
        recommendation: totalExpenses > monthlyDeposit
            ? 'Has excedido tu saldo. Registra más ingresos o reduce gastos.'
            : 'Te queda poco saldo. Controla tus gastos.',
      ));
    }

    // Regla 3: Gastos diarios promedio no deben superar el 10% del saldo mensual
    final daysInMonth = DateTime.now().day;
    final dailyAverage = totalExpenses / daysInMonth;
    final dailyLimit = monthlyDeposit * 0.10 / 30; // 10% del saldo mensual dividido en 30 días
    
    if (dailyAverage > dailyLimit && dailyLimit > 0) {
      rules.add(BudgetRule(
        title: 'Gasto diario elevado',
        description: 'Tu promedio diario es \$${dailyAverage.toStringAsFixed(2)} (límite: \$${dailyLimit.toStringAsFixed(2)})',
        severity: RuleSeverity.warning,
        recommendation: 'Tu ritmo de gasto diario es alto. Considera espaciar tus gastos.',
      ));
    }

    // Regla 4: Categoría con mayor gasto no debe superar el 50% del total
    final byCat = _byCat;
    if (byCat.isNotEmpty && totalExpenses > 0) {
      final maxCategory = byCat.entries.reduce((a, b) => a.value > b.value ? a : b);
      final maxPercentage = (maxCategory.value / totalExpenses) * 100;
      
      if (maxPercentage > 50) {
        rules.add(BudgetRule(
          title: 'Concentración de gastos',
          description: '${_categoryLabel(maxCategory.key)} representa el ${maxPercentage.toStringAsFixed(0)}% de tus gastos',
          severity: RuleSeverity.warning,
          recommendation: 'Diversifica tus gastos para no depender tanto de una categoría.',
        ));
      }
    }

    // Regla 5: Alerta si hay más de 10 gastos en "Otros"
    final otrosCount = _monthExpenses.where((e) => e.categoria == ExpenseCategory.otros).length;
    if (otrosCount > 10) {
      rules.add(BudgetRule(
        title: 'Muchos gastos "Otros"',
        description: 'Tienes $otrosCount gastos sin categorizar. Considera agruparlos',
        severity: RuleSeverity.info,
        recommendation: 'Crea categorías específicas para mejor control de tus gastos.',
      ));
    }

    // Regla 6: Proyección mensual vs saldo disponible
    final projectedMonthly = dailyAverage * 30;
    if (projectedMonthly > monthlyDeposit && monthlyDeposit > 0) {
      rules.add(BudgetRule(
        title: 'Proyección de sobre-gasto',
        description: 'Si continúas este ritmo, gastarás \$${projectedMonthly.toStringAsFixed(2)} este mes',
        severity: RuleSeverity.danger,
        recommendation: 'Reduce tu ritmo de gasto diario para no exceder tu saldo.',
      ));
    }

    return rules;
  }

  double _getSpentByCategory(BudgetCategory budgetCategory) {
    final expenseCategory = _mapBudgetToExpense(budgetCategory);
    return _monthExpenses
        .where((e) => e.categoria == expenseCategory)
        .fold(0.0, (sum, e) => sum + e.monto);
  }

  ExpenseCategory _mapBudgetToExpense(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.arriendo:
        return ExpenseCategory.alojamiento;
      case BudgetCategory.comida:
        return ExpenseCategory.comida;
      case BudgetCategory.transporte:
        return ExpenseCategory.transporte;
      case BudgetCategory.academicos:
        return ExpenseCategory.academica;
      case BudgetCategory.otros:
        return ExpenseCategory.otros;
    }
  }

  String _getBudgetCategoryName(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.arriendo:
        return 'Alojamiento';
      case BudgetCategory.comida:
        return 'Comida';
      case BudgetCategory.transporte:
        return 'Transporte';
      case BudgetCategory.academicos:
        return 'Académicos';
      case BudgetCategory.otros:
        return 'Otros';
    }
  }

  double get _total => _monthExpenses.fold(0, (p, e) => p + e.monto);

  Map<ExpenseCategory, double> get _byCat {
    final map = <ExpenseCategory, double>{};
    for (final e in _monthExpenses) {
      map[e.categoria] = (map[e.categoria] ?? 0) + e.monto;
    }
    return map;
  }

  String _categoryLabel(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.academica:
        return 'Académica';
      case ExpenseCategory.transporte:
        return 'Transporte';
      case ExpenseCategory.alojamiento:
        return 'Alojamiento';
      case ExpenseCategory.comida:
        return 'Comida';
      case ExpenseCategory.otros:
        return 'Otras adicionales';
    }
  }

  String _pct(double part, double total) => total <= 0 ? '0%' : '${((part / total) * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Análisis y Reglas')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    // SECCIÓN DE REGLAS
                    if (_violatedRules.isNotEmpty) ...[
                      Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.red[700]),
                                  const SizedBox(width: 8),
                                  const Text('Reglas de Presupuesto', 
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._violatedRules.map((rule) => _buildRuleCard(rule)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // RESUMEN DEL MES
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Resumen del mes', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('Gasto total: ${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            if (_budgetConfig != null) ...[
                              Text('Saldo disponible: ${_budgetConfig!.monthlyDeposit.toStringAsFixed(2)}'),
                              Text('Restante: ${(_budgetConfig!.monthlyDeposit - _total).toStringAsFixed(2)}'),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _budgetConfig!.monthlyDeposit > 0 
                                    ? (_total / _budgetConfig!.monthlyDeposit).clamp(0.0, 1.0)
                                    : 0.0,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    _total > _budgetConfig!.monthlyDeposit ? Colors.red : Colors.green),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text('Registros: ${_monthExpenses.length}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // DISTRIBUCIÓN POR CATEGORÍA
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Distribución por categoría', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_monthExpenses.isEmpty)
                              const Text('No hay gastos este mes')
                            else
                              ..._byCat.entries.map((e) {
                                final cat = e.key;
                                final val = e.value;
                                final percentage = _pct(val, _total);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(_getCategoryIcon(cat), size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_categoryLabel(cat))),
                                      Text('\$${val.toStringAsFixed(2)}'),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getPercentageColor(percentage),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          percentage,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ANÁLISIS ADICIONAL
                    _buildAdditionalAnalysis(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRuleCard(BudgetRule rule) {
    Color cardColor;
    Color iconColor;
    IconData icon;

    switch (rule.severity) {
      case RuleSeverity.danger:
        cardColor = Colors.red[100]!;
        iconColor = Colors.red[700]!;
        icon = Icons.dangerous;
        break;
      case RuleSeverity.warning:
        cardColor = Colors.orange[100]!;
        iconColor = Colors.orange[700]!;
        icon = Icons.warning;
        break;
      case RuleSeverity.info:
        cardColor = Colors.blue[100]!;
        iconColor = Colors.blue[700]!;
        icon = Icons.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(rule.title, style: TextStyle(fontWeight: FontWeight.w600, color: iconColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(rule.description, style: const TextStyle(fontSize: 12)),
          if (rule.recommendation != null) ...[
            const SizedBox(height: 4),
            Text(
              '💡 ${rule.recommendation}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalAnalysis() {
    final daysInMonth = DateTime.now().day;
    final dailyAverage = _total / daysInMonth;
    final projectedMonthly = dailyAverage * 30;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Análisis Avanzado', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _buildAnalysisRow('Promedio diario', '\$${dailyAverage.toStringAsFixed(2)}'),
            _buildAnalysisRow('Proyección mensual', '\$${projectedMonthly.toStringAsFixed(2)}'),
            _buildAnalysisRow('Gastos por día', '${(_monthExpenses.length / daysInMonth).toStringAsFixed(1)}'),
            if (_budgetConfig != null) ...[
              _buildAnalysisRow('Uso del saldo', '${((_total / _budgetConfig!.monthlyDeposit) * 100).toStringAsFixed(0)}%'),
              if (_total > _budgetConfig!.monthlyDeposit)
                _buildAnalysisRow('Excedente', '\$${(_total - _budgetConfig!.monthlyDeposit).toStringAsFixed(2)}', 
                                  isNegative: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isNegative ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPercentageColor(String percentage) {
    final value = double.tryParse(percentage.replaceAll('%', '')) ?? 0;
    if (value > 50) return Colors.red;
    if (value > 30) return Colors.orange;
    return Colors.green;
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.academica:
        return Icons.school;
      case ExpenseCategory.transporte:
        return Icons.directions_bus;
      case ExpenseCategory.alojamiento:
        return Icons.home;
      case ExpenseCategory.comida:
        return Icons.restaurant;
      case ExpenseCategory.otros:
        return Icons.more_horiz;
    }
  }
}


