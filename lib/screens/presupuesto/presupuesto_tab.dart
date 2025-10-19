import 'package:flutter/material.dart';

import '../../models/budget.dart';
import '../../services/service_locator.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  final TextEditingController _deposit = TextEditingController();
  final Map<BudgetCategory, TextEditingController> _amount = {
    for (final c in BudgetCategory.values) c: TextEditingController()
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await budgetStore.loadConfig();
    if (cfg != null) {
      _deposit.text = cfg.monthlyDeposit.toStringAsFixed(2);
      for (final c in BudgetCategory.values) {
        _amount[c]!.text = (cfg.allocationsAmount[c] ?? 0).toStringAsFixed(2);
      }
    } else {
      for (final c in BudgetCategory.values) {
        _amount[c]!.text = '0.00';
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final deposit = double.tryParse(_deposit.text.trim()) ?? 0;
    final alloc = <BudgetCategory, double>{};
    for (final c in BudgetCategory.values) {
      final v = double.tryParse(_amount[c]!.text.trim()) ?? 0;
      alloc[c] = v;
    }
    await budgetStore.saveConfig(BudgetConfig(monthlyDeposit: deposit, allocationsAmount: alloc));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presupuesto guardado')));
  }

  @override
  void dispose() {
    _deposit.dispose();
    for (final c in BudgetCategory.values) {
      _amount[c]!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Presupuesto')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Depósito mensual', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deposit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'USD'),
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
                    const Text('Asignación por categoría (monto)', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _row(BudgetCategory.arriendo, 'Arriendo'),
                    const SizedBox(height: 8),
                    _row(BudgetCategory.comida, 'Comida'),
                    const SizedBox(height: 8),
                    _row(BudgetCategory.transporte, 'Transporte'),
                    const SizedBox(height: 8),
                    _row(BudgetCategory.otros, 'Otros'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(onPressed: _save, child: const Text('Guardar')),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const SizedBox(height: 0),
      ),
    );
  }

  Widget _row(BudgetCategory c, String label) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _amount[c]!,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }
}


