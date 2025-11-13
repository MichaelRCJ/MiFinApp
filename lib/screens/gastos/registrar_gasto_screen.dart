import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/service_locator.dart';

class RegistrarGastoScreen extends StatefulWidget {
  static const String routeName = '/registrar-gasto';
  final ExpenseCategory? initialCategory;

  const RegistrarGastoScreen({super.key, this.initialCategory});

  @override
  State<RegistrarGastoScreen> createState() => _RegistrarGastoScreenState();
}

class _RegistrarGastoScreenState extends State<RegistrarGastoScreen> {
  @override
  void initState() {
    super.initState();
    _categoria = widget.initialCategory ?? ExpenseCategory.academica;
  }

  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  late ExpenseCategory _categoria;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0;

    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      descripcion: _descripcionCtrl.text.trim(),
      monto: monto,
      fecha: _fecha,
      categoria: _categoria,
    );
    await expenseStore.addExpense(expense);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Registrar gastos')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: '¿En qué lo usó? (Descripción)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto total (USD)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (double.tryParse((v ?? '').trim()) == null) ? 'Ingrese un número válido' : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickFecha,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}'),
                        const Icon(Icons.calendar_today_outlined),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ExpenseCategory>(
                      value: _categoria,
                      items: const [
                        DropdownMenuItem(value: ExpenseCategory.academica, child: Text('Académica')),
                        DropdownMenuItem(value: ExpenseCategory.transporte, child: Text('Transporte')),
                        DropdownMenuItem(value: ExpenseCategory.alojamiento, child: Text('Alojamiento')),
                        DropdownMenuItem(value: ExpenseCategory.comida, child: Text('Comida')),
                        DropdownMenuItem(value: ExpenseCategory.otros, child: Text('Otras adicionales')),
                      ],
                      onChanged: (v) => setState(() => _categoria = v ?? ExpenseCategory.academica),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _guardar,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
