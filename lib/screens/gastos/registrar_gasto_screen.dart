import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../models/budget.dart';
import '../../services/service_locator.dart';
import '../../services/auth_service.dart';
import '../../storage/expense_store.dart';
import '../../storage/budget_store.dart';

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

    // PRIMERO: Verificar si hay saldo total disponible
    final totalBalanceCheck = await _checkTotalBalance(monto);
    if (totalBalanceCheck != null) {
      final shouldContinue = await _showInsufficientBalanceDialog(totalBalanceCheck);
      if (shouldContinue != true) {
        return; // Usuario canceló, no guardar el gasto
      }
    }

    // SEGUNDO: Verificar si excede el presupuesto de la categoría
    final budgetExceeded = await _checkBudgetExceeded(_categoria, monto);

    // Si excede el presupuesto, mostrar diálogo de confirmación
    if (budgetExceeded != null) {
      final shouldContinue = await _showBudgetExceededDialog(budgetExceeded);
      if (shouldContinue != true) {
        return; // Usuario canceló, no guardar el gasto
      }
      
      // Si el usuario confirmó, actualizar automáticamente el presupuesto
      await _updateBudgetAutomatically(_categoria, monto);
    }

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

  // Verificar si hay saldo total disponible para todos los gastos
  Future<Map<String, dynamic>?> _checkTotalBalance(double monto) async {
    try {
      debugPrint('🔍 Checking total balance for amount: $monto');
      
      final budgetConfig = await budgetStore.loadConfig();
      
      if (budgetConfig == null) {
        debugPrint('❌ No budget config found');
        return null;
      }

      final totalBalance = budgetConfig.monthlyDeposit;
      debugPrint('💰 Total monthly balance: $totalBalance');

      // Obtener todos los gastos del mes actual
      final allExpenses = await expenseStore.loadExpenses();
      final now = DateTime.now();
      final monthExpenses = allExpenses.where((e) => 
        !e.esPresupuestado &&
        e.fecha.year == now.year && 
        e.fecha.month == now.month
      ).toList();
      
      debugPrint('📋 Found ${monthExpenses.length} expenses this month');
      
      final currentSpent = monthExpenses.fold<double>(0, (sum, e) => sum + e.monto);
      final newTotal = currentSpent + monto;
      
      debugPrint('💸 Current spent: $currentSpent, New total: $newTotal, Balance: $totalBalance');

      if (newTotal > totalBalance) {
        debugPrint('⚠️ INSUFFICIENT BALANCE! Showing dialog...');
        return {
          'balance': totalBalance,
          'current': currentSpent,
          'newExpense': monto,
          'total': newTotal,
          'shortfall': newTotal - totalBalance,
        };
      }

      debugPrint('✅ Sufficient balance available');
      return null;
    } catch (e) {
      debugPrint('❌ Error checking balance: $e');
      return null;
    }
  }

  // Mostrar diálogo de saldo insuficiente
  Future<bool?> _showInsufficientBalanceDialog(Map<String, dynamic> balanceInfo) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('¡Saldo Insuficiente!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No tienes suficiente saldo para registrar este gasto',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saldo disponible:'),
                      Text('\$${balanceInfo['balance'].toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gastado actualmente:'),
                      Text('\$${balanceInfo['current'].toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Este gasto:'),
                      Text('\$${balanceInfo['newExpense'].toStringAsFixed(2)}', 
                           style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total después del gasto:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '\$${balanceInfo['total'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Faltante:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '-\$${balanceInfo['shortfall'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Por favor ingresa nuevos ingresos para aumentar tu saldo disponible',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar gasto'),
          ),
        ],
      ),
    );
  }

  // Verificar si el gasto excede el presupuesto
  Future<Map<String, dynamic>?> _checkBudgetExceeded(ExpenseCategory category, double monto) async {
    try {
      debugPrint('🔍 Checking budget exceeded for category: $category, amount: $monto');
      
      final username = await AuthService.getLastUsername() ?? 'default';
      final budgetConfig = await budgetStore.loadConfig();
      
      debugPrint('💰 Budget config loaded: ${budgetConfig?.monthlyDeposit}');
      
      if (budgetConfig == null) {
        debugPrint('❌ No budget config found');
        return null;
      }

      // Mapear categoría de gasto a categoría de presupuesto
      BudgetCategory budgetCategory;
      switch (category) {
        case ExpenseCategory.alojamiento:
          budgetCategory = BudgetCategory.arriendo;
          break;
        case ExpenseCategory.comida:
          budgetCategory = BudgetCategory.comida;
          break;
        case ExpenseCategory.transporte:
          budgetCategory = BudgetCategory.transporte;
          break;
        case ExpenseCategory.academica:
          budgetCategory = BudgetCategory.academicos;
          break;
        case ExpenseCategory.otros:
          budgetCategory = BudgetCategory.otros;
          break;
      }

      final allocatedBudget = budgetConfig.allocationsAmount[budgetCategory] ?? 0.0;
      debugPrint('📊 Allocated budget for $budgetCategory: $allocatedBudget');
      
      // Obtener gastos existentes de esta categoría en el mes actual
      final allExpenses = await expenseStore.loadExpenses();
      final now = DateTime.now();
      final monthExpenses = allExpenses.where((e) => 
        e.categoria == category && 
        !e.esPresupuestado &&
        e.fecha.year == now.year && 
        e.fecha.month == now.month
      ).toList();
      
      debugPrint('📋 Found ${monthExpenses.length} expenses for this category this month');
      
      final currentSpent = monthExpenses.fold<double>(0, (sum, e) => sum + e.monto);
      final newTotal = currentSpent + monto;
      
      debugPrint('💸 Current spent: $currentSpent, New total: $newTotal, Allocated: $allocatedBudget');

      if (allocatedBudget > 0 && newTotal > allocatedBudget) {
        debugPrint('⚠️ BUDGET EXCEEDED! Showing dialog...');
        return {
          'category': _getBudgetCategoryName(budgetCategory),
          'allocated': allocatedBudget,
          'current': currentSpent,
          'newExpense': monto,
          'total': newTotal,
          'exceeded': newTotal - allocatedBudget,
        };
      }

      debugPrint('✅ Budget not exceeded');
      return null;
    } catch (e) {
      debugPrint('❌ Error checking budget: $e');
      return null;
    }
  }

  // Mostrar diálogo de presupuesto excedido
  Future<bool?> _showBudgetExceededDialog(Map<String, dynamic> budgetInfo) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('¡Presupuesto de Categoría Excedido!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Este gasto excede tu presupuesto asignado en ${budgetInfo['category']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Presupuesto de categoría:'),
                      Text('\$${budgetInfo['allocated'].toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gastado actualmente:'),
                      Text('\$${budgetInfo['current'].toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Este gasto:'),
                      Text('\$${budgetInfo['newExpense'].toStringAsFixed(2)}', 
                           style: const TextStyle(color: Colors.orange)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total después del gasto:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '\$${budgetInfo['total'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Excedente:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '+\$${budgetInfo['exceeded'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'El presupuesto de esta categoría se actualizará automáticamente si continúas',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('¿Deseas continuar de todas formas con este gasto?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar gasto'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, registrar gasto'),
          ),
        ],
      ),
    );
  }

  // Actualizar automáticamente el presupuesto cuando se excede
  Future<void> _updateBudgetAutomatically(ExpenseCategory category, double newExpenseAmount) async {
    try {
      final budgetConfig = await budgetStore.loadConfig();
      if (budgetConfig == null) return;

      // Mapear categoría de gasto a categoría de presupuesto
      BudgetCategory budgetCategory;
      switch (category) {
        case ExpenseCategory.alojamiento:
          budgetCategory = BudgetCategory.arriendo;
          break;
        case ExpenseCategory.comida:
          budgetCategory = BudgetCategory.comida;
          break;
        case ExpenseCategory.transporte:
          budgetCategory = BudgetCategory.transporte;
          break;
        case ExpenseCategory.academica:
          budgetCategory = BudgetCategory.academicos;
          break;
        case ExpenseCategory.otros:
          budgetCategory = BudgetCategory.otros;
          break;
      }

      // Obtener gastos existentes de esta categoría en el mes actual
      final allExpenses = await expenseStore.loadExpenses();
      final now = DateTime.now();
      final monthExpenses = allExpenses.where((e) => 
        e.categoria == category && 
        !e.esPresupuestado &&
        e.fecha.year == now.year && 
        e.fecha.month == now.month
      ).toList();
      
      final currentSpent = monthExpenses.fold<double>(0, (sum, e) => sum + e.monto);
      final newTotal = currentSpent + newExpenseAmount;

      // Actualizar el presupuesto asignado para esta categoría
      final updatedAllocations = Map<BudgetCategory, double>.from(budgetConfig.allocationsAmount);
      updatedAllocations[budgetCategory] = newTotal;

      // Guardar la configuración actualizada
      final updatedConfig = BudgetConfig(
        monthlyDeposit: budgetConfig.monthlyDeposit,
        allocationsAmount: updatedAllocations,
        lastUpdated: DateTime.now(),
      );

      await budgetStore.saveConfig(updatedConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Presupuesto de ${_getBudgetCategoryName(budgetCategory)} actualizado automáticamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating budget: $e');
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
