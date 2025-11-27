import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../models/budget.dart';
import '../../services/service_locator.dart';

class IncomeTab extends StatefulWidget {
  const IncomeTab({super.key});

  @override
  State<IncomeTab> createState() => _IncomeTabState();
}

class IncomeRecord {
  final String id;
  final String description;
  final double amount;
  final DateTime date;

  IncomeRecord({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
  };

  factory IncomeRecord.fromJson(Map<String, dynamic> json) => IncomeRecord(
    id: json['id'] as String,
    description: json['description'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
  );
}

class _IncomeTabState extends State<IncomeTab> {
  double _totalIncome = 0;
  List<IncomeRecord> _incomes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Inicializar el formato de fechas para el idioma español
    initializeDateFormatting('es').then((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = await AuthService.getLastUsername() ?? 'default';
      final incomesKey = 'incomes_$username';
      
      final incomesJson = prefs.getStringList(incomesKey) ?? [];
      final loadedIncomes = incomesJson
          .map((json) => IncomeRecord.fromJson(jsonDecode(json)))
          .toList();
      
      // Ordenar por fecha más reciente primero
      loadedIncomes.sort((a, b) => b.date.compareTo(a.date));
      
      if (mounted) {
        setState(() {
          _incomes = loadedIncomes;
          _totalIncome = _incomes.fold(0, (sum, income) => sum + income.amount);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      debugPrint('Error loading incomes: $e');
    }
  }

  String _fmt(num v) => '\$${v.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
      
  Widget _buildInfoRow(String label, String value, IconData icon, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildIncomeItem(IncomeRecord income) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.green[50],
          child: Icon(Icons.arrow_downward, color: Colors.green[700]),
        ),
        title: Text(
          income.description.isEmpty ? 'Ingreso' : income.description,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _fmtDate(income.date),
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Text(
          _fmt(income.amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
  String _fmtDate(DateTime d) {
    try {
      return DateFormat('dd MMM yyyy', 'es').format(d);
    } catch (e) {
      // En caso de error, devolver un formato simple
      return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    }
  }
  Future<bool> _saveNewIncome(IncomeRecord newIncome, [bool addToBudget = true]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = await AuthService.getLastUsername() ?? 'default';
      final incomesKey = 'incomes_$username';
      
      // Obtener ingresos existentes
      final incomesJson = prefs.getStringList(incomesKey) ?? [];
      final incomes = incomesJson
          .map((json) => IncomeRecord.fromJson(jsonDecode(json)))
          .toList();
      
      // Agregar nuevo ingreso
      incomes.add(newIncome);
      
      // Guardar de vuelta
      await prefs.setStringList(
        incomesKey,
        incomes.map((income) => jsonEncode(income.toJson())).toList(),
      );
      
      // ACTUALIZAR DEPÓSITO MENSUAL EN PRESUPUESTO (si el usuario lo desea)
      if (addToBudget) {
        await _updateMonthlyDeposit(newIncome.amount);
      }
      
      // Actualizar UI
      if (mounted) {
        setState(() {
          _incomes.insert(0, newIncome); // Agregar al inicio de la lista
          _totalIncome += newIncome.amount;
        });
      }
      
      return true;
    } catch (e) {
      debugPrint('Error saving income: $e');
      return false;
    }
  }

  // Actualizar saldo en presupuesto
  Future<void> _updateMonthlyDeposit(double incomeAmount) async {
    try {
      // Cargar configuración actual del presupuesto
      final currentConfig = await budgetStore.loadConfig();
      
      // Calcular nuevo saldo
      final currentBalance = currentConfig?.monthlyDeposit ?? 0.0;
      final newBalance = currentBalance + incomeAmount;
      
      // Crear nueva configuración con el saldo actualizado
      final updatedConfig = BudgetConfig(
        monthlyDeposit: newBalance,
        allocationsAmount: currentConfig?.allocationsAmount ?? 
            {for (final category in BudgetCategory.values) category: 0.0},
        lastUpdated: DateTime.now(),
      );
      
      // Guardar usando BudgetStore para que notifique a los listeners
      await budgetStore.saveConfig(updatedConfig);
      
      debugPrint('✅ Saldo actualizado correctamente: \$${newBalance.toStringAsFixed(2)}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saldo actualizado: \$${newBalance.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating balance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar saldo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddIncomeDialog() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    bool addToBudget = true; // Opción por defecto
    
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar Ingreso', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Pago de nómina',
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese una descripción';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      hintText: '0.00',
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese un monto';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Ingrese un monto válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.blue),
                    title: const Text('Fecha del ingreso'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Añadir al saldo'),
                    subtitle: const Text('Actualizará automáticamente tu saldo disponible'),
                    value: addToBudget,
                    onChanged: (value) {
                      setState(() => addToBudget = value);
                    },
                    secondary: Icon(Icons.account_balance_wallet, 
                        color: addToBudget ? Colors.green : Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(amountController.text);
                  final description = descriptionController.text.trim();
                  
                  // Crear nuevo ingreso
                  final newIncome = IncomeRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    description: description,
                    amount: amount,
                    date: selectedDate,
                  );
                  
                  // Guardar el ingreso
                  final success = await _saveNewIncome(newIncome, addToBudget);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    
                    if (success) {
                      // Mostrar notificación de éxito
                      String message = addToBudget 
                          ? '¡Ingreso de \$${amount.toStringAsFixed(2)} registrado y añadido a tu saldo!'
                          : '¡Ingreso de \$${amount.toStringAsFixed(2)} registrado!';
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      // Mostrar mensaje de error
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al guardar el ingreso'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('GUARDAR INGRESO'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ingresos')),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddIncomeDialog,
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    // Tarjeta de resumen de ingresos
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Resumen de Ingresos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Icon(Icons.account_balance_wallet, color: Theme.of(context).primaryColor),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildInfoRow('Total de ingresos', _fmt(_totalIncome), Icons.attach_money, Colors.green, isBold: true),
                            const Divider(height: 30),
                            _buildInfoRow('Ingresos este mes', _fmt(_totalIncome), Icons.calendar_today, Colors.blue),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: 1.0, // Siempre lleno ya que solo mostramos ingresos
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Historial de ingresos
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Historial de Ingresos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Icon(Icons.history, color: Theme.of(context).primaryColor),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_incomes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long, size: 50, color: Colors.grey[400]),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No hay ingresos registrados',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._incomes.take(5).map((income) => _buildIncomeItem(income)),
                            if (_incomes.isEmpty)
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    // TODO: Navegar a pantalla completa de historial
                                  },
                                  child: const Text('Ver todo el historial'),
                                ),
                              ),
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


