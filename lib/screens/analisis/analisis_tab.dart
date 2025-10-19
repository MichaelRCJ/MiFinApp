import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../services/service_locator.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  List<Expense> _monthExpenses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await expenseStore.loadExpenses();
    final now = DateTime.now();
    final month = all.where((e) => e.fecha.year == now.year && e.fecha.month == now.month).toList();
    if (!mounted) return;
    setState(() {
      _monthExpenses = month;
      _loading = false;
    });
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
      case ExpenseCategory.otros:
        return 'Otras adicionales';
    }
  }

  String _pct(double part, double total) => total <= 0 ? '0%' : '${((part / total) * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Análisis mensual')),
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
                            const Text('Resumen del mes', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('Gasto total: ${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text('Registros: ${_monthExpenses.length}'),
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
                            const Text('Distribución por categoría', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_monthExpenses.isEmpty)
                              const Text('No hay gastos este mes')
                            else
                              ..._byCat.entries.map((e) {
                                final cat = e.key;
                                final val = e.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(_categoryLabel(cat))),
                                      Expanded(
                                        flex: 3,
                                        child: LinearProgressIndicator(
                                          value: _total <= 0 ? 0 : (val / _total).clamp(0.0, 1.0),
                                          minHeight: 10,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('${val.toStringAsFixed(2)} • ${_pct(val, _total)}'),
                                    ],
                                  ),
                                );
                              }).toList(),
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
                            const Text('Gastos más recientes', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_monthExpenses.isEmpty)
                              const Text('No hay datos')
                            else
                              ..._monthExpenses.take(5).map((x) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(child: Icon(Icons.receipt_long_rounded)),
                                    title: Text(x.descripcion.isEmpty ? 'Gasto' : x.descripcion),
                                    subtitle: Text(_categoryLabel(x.categoria)),
                                    trailing: Text(x.monto.toStringAsFixed(2)),
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


