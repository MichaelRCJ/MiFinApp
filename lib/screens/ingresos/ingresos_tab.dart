import 'package:flutter/material.dart';
import '../../models/budget.dart';
import '../../models/expense.dart';
import '../../services/service_locator.dart';

class IncomeTab extends StatefulWidget {
  const IncomeTab({super.key});

  @override
  State<IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<IncomeTab> {
  BudgetConfig? _config;
  List<Expense> _monthExpenses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await budgetStore.loadConfig();
    final all = await expenseStore.loadExpenses();
    final now = DateTime.now();
    final month = all.where((e) => e.fecha.year == now.year && e.fecha.month == now.month).toList();
    month.sort((a, b) => b.fecha.compareTo(a.fecha));
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _monthExpenses = month;
      _loading = false;
    });
  }

  double get _initial => _config?.monthlyDeposit ?? 0;
  double get _spent => _monthExpenses.fold(0, (p, e) => p + e.monto);
  double get _remaining => (_initial - _spent).clamp(0, double.infinity);

  String _fmt(num v) => v.toStringAsFixed(0);
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _categoryLabel(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.academica:
        return 'Académica';
      case ExpenseCategory.transporte:
        return 'Transporte';
      case ExpenseCategory.alojamiento:
        return 'Alojamiento';
      case ExpenseCategory.otros:
        return 'Otras adicionales';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ingresos')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Información financiera mensual', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Dinero inicial'),
                                      Text(_fmt(_initial), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('Gastos', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                                  Text(_fmt(_spent), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                                ]),
                                const SizedBox(width: 16),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('Sobrante', style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.w700)),
                                  Text(_fmt(_remaining), style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.w700)),
                                ]),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gastos recientes del mes', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_monthExpenses.isEmpty)
                              const Text('No hay gastos registrados este mes')
                            else
                              ..._monthExpenses.take(5).map((e) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
                                    title: Text(e.descripcion.isEmpty ? 'Gasto' : e.descripcion),
                                    subtitle: Text('${_categoryLabel(e.categoria)} • ${_fmtDate(e.fecha)}'),
                                    trailing: Text(e.monto.toStringAsFixed(2)),
                                  )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: const SizedBox(height: 0),
      ),
    );
  }
}


