import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../services/service_locator.dart';
import 'registrar_gasto_screen.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  List<Expense> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await expenseStore.loadExpenses();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _goToRegistrar() async {
    final added = await Navigator.of(context).pushNamed(RegistrarGastoScreen.routeName);
    if (added == true) {
      await _load();
    }
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

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Obtener el ícono para cada categoría
  IconData _getCategoryIcon(ExpenseCategory category) {
    return switch (category) {
      ExpenseCategory.alojamiento => Icons.house_outlined,
      ExpenseCategory.academica => Icons.school_outlined,
      ExpenseCategory.transporte => Icons.directions_bus_outlined,
      ExpenseCategory.comida => Icons.restaurant_outlined,
      ExpenseCategory.otros => Icons.more_horiz,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registros de gastos'),
          actions: [
            TextButton.icon(
              onPressed: _goToRegistrar,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Registrar gastos'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_items.isEmpty
                ? _EmptyState(onAdd: _goToRegistrar)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (_, i) {
                      final e = _items[i];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: e.esPresupuestado 
                              ? BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: e.esPresupuestado 
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                : Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              _getCategoryIcon(e.categoria),
                              color: e.esPresupuestado 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            e.descripcion.isEmpty ? 'Gasto' : e.descripcion,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: e.esPresupuestado 
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_categoryLabel(e.categoria)} • ${_fmtDate(e.fecha)}'),
                              if (e.esPresupuestado) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Presupuestado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Text(
                            '\$${e.monto.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: e.esPresupuestado 
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: _items.length,
                  )),
        bottomNavigationBar: const SizedBox(height: 0),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No hay gastos registrados', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Agrega tu primer gasto para verlo aquí.'),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Registrar gastos')),
          ],
        ),
      ),
    );
  }
}
