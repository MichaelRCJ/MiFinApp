import 'package:flutter/material.dart';
import '../../../models/expense.dart';
import '../../../services/service_locator.dart';
import '../registrar_gasto_screen.dart';

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
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
                        title: Text(e.descripcion.isEmpty ? 'Gasto' : e.descripcion),
                        subtitle: Text('${_categoryLabel(e.categoria)} • ${_fmtDate(e.fecha)}'),
                        trailing: Text(e.monto.toStringAsFixed(2)),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Registrar gasto')),
          ],
        ),
      ),
    );
  }
}


