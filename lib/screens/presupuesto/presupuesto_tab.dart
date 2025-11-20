import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget.dart';
import '../../models/expense.dart';
import '../../services/service_locator.dart';
import '../../storage/expense_store.dart';
import '../../utils/debouncer.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  // Controladores y estado
  final TextEditingController _deposit = TextEditingController();
  final Map<BudgetCategory, TextEditingController> _amount = {
    for (final c in BudgetCategory.values) c: TextEditingController()
  };
  final Map<BudgetCategory, FocusNode> _focusNodes = {};
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final Debouncer _debouncer = Debouncer();
  
  // Estado de la aplicación
  bool _isLoading = true;
  
  // Rastrear categorías con presupuesto extendido
  final Map<BudgetCategory, bool> _presupuestoExtendido = {
    for (final c in BudgetCategory.values) c: false
  };
  
  // Stream para actualizaciones en tiempo real
  final StreamController<void> _updateController = StreamController<void>.broadcast();
  
  // Parsear cantidad de texto a double
  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }
  
  // Obtener el total asignado a las categorías
  double get _totalAllocated {
    double total = 0;
    for (final c in BudgetCategory.values) {
      total += _parseAmount(_amount[c]!.text);
    }
    return total;
  }
  
  // Obtener el depósito mensual
  double get _monthlyDeposit => _parseAmount(_deposit.text);
  
  // Verificar si se ha excedido el presupuesto
  bool get _isOverBudget => _totalAllocated > _monthlyDeposit;
  
  // Método para obtener o crear un FocusNode
  FocusNode _getOrCreateFocusNode(BudgetCategory category) {
    return _focusNodes.putIfAbsent(category, () => FocusNode());
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Escuchar cambios en los gastos
    expenseNotifier.addListener(_onExpensesChanged);
  }
  
  // Inicializar todos los datos necesarios
  Future<void> _initializeData() async {
    try {
      setState(() => _isLoading = true);
      await Future.wait([
        _loadBudget(),
        _loadExpenses(),
      ]);
    } catch (e) {
      _showError('Error al cargar los datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    // Limpiar listeners y controladores
    expenseNotifier.removeListener(_onExpensesChanged);
    _deposit.dispose();
    _debouncer.dispose();
    _updateController.close();
    
    for (final c in BudgetCategory.values) {
      _amount[c]!.dispose();
      _focusNodes[c]?.dispose();
    }
    
    super.dispose();
  }

  Future<void> _onExpensesChanged() async {
    if (!mounted) return;
    
    try {
      // Cargar todos los gastos
      final expenses = await expenseStore.loadExpenses();
      
      // Verificar cada categoría
      for (final category in BudgetCategory.values) {
        final expenseCategory = _mapToExpenseCategory(category);
        final gastosCategoria = expenses
            .where((e) => e.categoria == expenseCategory && !e.esPresupuestado)
            .toList();
            
        if (gastosCategoria.isNotEmpty) {
          final totalGastado = gastosCategoria.fold<double>(0, (sum, e) => sum + e.monto);
          final presupuestoActual = _parseAmount(_amount[category]!.text);
          
          // Si el presupuesto actual es menor al gasto total
          if (totalGastado > 0) {
            if (totalGastado > presupuestoActual) {
              // Mostrar mensaje de advertencia
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('¡Atención! Se ha excedido el presupuesto en ${_getBudgetCategoryName(category)}'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              
              // Actualizar el presupuesto automáticamente
              _amount[category]!.text = _formatCurrency(totalGastado);
              _presupuestoExtendido[category] = true;
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {});
        _updateController.add(null);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al actualizar presupuestos: $e');
      }
    }
  }
  
  // Cargar la configuración del presupuesto
  Future<void> _loadBudget() async {
    try {
      final cfg = await budgetStore.loadConfig();
      if (!mounted) return;
      
      setState(() {
        _deposit.text = _formatCurrency(cfg?.monthlyDeposit ?? 0.0);
        for (final category in BudgetCategory.values) {
          _amount[category]!.text = _formatCurrency(cfg?.allocationsAmount[category] ?? 0.0);
        }
      });
    } catch (e) {
      if (mounted) {
        _showError('Error al cargar el presupuesto: $e');
      }
    }
  }
  
  // Cargar gastos y actualizar la interfaz
  Future<void> _loadExpenses() async {
    if (!mounted) return;
    
    try {
      // Cargar todos los gastos
      final expenses = await expenseStore.loadExpenses();
      
      if (!mounted) return;
      
      // Verificar cada categoría y actualizar presupuestos si es necesario
      for (final category in BudgetCategory.values) {
        final expenseCategory = _mapToExpenseCategory(category);
        final gastosCategoria = expenses
            .where((e) => e.categoria == expenseCategory && !e.esPresupuestado)
            .toList();
            
        if (gastosCategoria.isNotEmpty) {
          final totalGastado = gastosCategoria.fold<double>(0, (sum, e) => sum + e.monto);
          final presupuestoActual = _parseAmount(_amount[category]!.text);
          
          // Si hay gastos no presupuestados, actualizar el presupuesto
          if (totalGastado > 0 && (presupuestoActual == 0 || totalGastado > presupuestoActual)) {
            _amount[category]!.text = _formatCurrency(totalGastado);
          }
        }
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al cargar los gastos: $e');
      }
    }
  }

  // Formatear número como moneda
  String _formatCurrency(double value) {
    return value.toStringAsFixed(2);
  }
  
  // Mapea las categorías de presupuesto a descripciones amigables
  String _getBudgetCategoryName(BudgetCategory category) {
    return switch (category) {
      BudgetCategory.arriendo => 'Pago de arriendo',
      BudgetCategory.comida => 'Presupuesto de comida',
      BudgetCategory.transporte => 'Gastos de transporte',
      BudgetCategory.academicos => 'Gastos académicos',
      BudgetCategory.otros => 'Otros gastos presupuestados',
    };
  }

  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) return false;
    
    if (_monthlyDeposit <= 0) {
      _showError('El depósito mensual debe ser mayor a cero');
      return false;
    }

    if (_isOverBudget) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Presupuesto excedido'),
          content: const Text(
              'El total asignado supera el depósito mensual. ¿Desea continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        return false;
      }
    }

    try {
      final alloc = <BudgetCategory, double>{};
      bool hasChanges = false;
      
      // Validar y preparar los datos
      for (final c in BudgetCategory.values) {
        final v = double.tryParse(_amount[c]!.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        alloc[c] = v;
        
        // Verificar si hay cambios
        final currentBudget = await budgetStore.loadConfig();
        final currentAmount = currentBudget?.allocationsAmount[c] ?? 0;
        if ((v - currentAmount).abs() > 0.01) { // Usar una pequeña tolerancia para comparación de decimales
          hasChanges = true;
        }
      }
      
      // Verificar si hay cambios para guardar
      if (!hasChanges && _parseAmount(_deposit.text) == (await budgetStore.loadConfig())?.monthlyDeposit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay cambios para guardar'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return true;
      }
      
      // Mostrar diálogo de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }
      
      // Guardar solo la configuración del presupuesto (sin crear gastos)
      await budgetStore.saveConfig(
        BudgetConfig(
          monthlyDeposit: _parseAmount(_deposit.text),
          allocationsAmount: alloc,
        ),
      );
      
      if (!mounted) return true;
      
      // Cerrar el diálogo de carga
      Navigator.of(context).pop();
      
      // Actualizar la interfaz
      await _loadBudget();
      
      if (mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presupuesto guardado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      return true;
    } catch (e) {
      if (mounted) {
        // Cerrar el diálogo de carga si hay un error
        Navigator.of(context).pop();
        _showError('Error al guardar el presupuesto: $e');
      }
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Mapea las categorías de presupuesto a categorías de gasto
  ExpenseCategory _mapToExpenseCategory(BudgetCategory category) {
    return switch (category) {
      BudgetCategory.arriendo => ExpenseCategory.alojamiento,
      BudgetCategory.comida => ExpenseCategory.comida,
      BudgetCategory.transporte => ExpenseCategory.transporte,
      BudgetCategory.academicos => ExpenseCategory.academica,
      BudgetCategory.otros => ExpenseCategory.otros,
    };
  }


  Future<void> _eliminarGasto(String id, BudgetCategory category) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar gasto'),
          content: const Text('¿Estás seguro de que quieres eliminar este gasto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Mostrar indicador de carga
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
        }

        // Eliminar el gasto
        await expenseStore.removeExpense(id);
        
        // Actualizar la interfaz
        if (mounted) {
          Navigator.of(context).pop(); // Cerrar el diálogo de carga
          
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gasto eliminado correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Actualizar la interfaz
          setState(() {});
          _updateController.add(null);
          
          // Actualizar los gastos
          await _loadExpenses();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar el diálogo de carga si está abierto
        _showError('Error al eliminar el gasto: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalAllocated = _totalAllocated;
    final double remaining = _monthlyDeposit - totalAllocated;
    final double progress = _monthlyDeposit > 0 ? (totalAllocated / _monthlyDeposit).toDouble() : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuesto Mensual'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Guardar presupuesto',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resumen del presupuesto
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumen del Presupuesto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBudgetSummary(remaining, progress),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress > 1 ? 1 : progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isOverBudget ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Depósito mensual
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Depósito Mensual',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _deposit,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          border: const OutlineInputBorder(),
                          hintText: '0.00',
                          suffixIcon: _deposit.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _deposit.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingrese un monto';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount < 0) {
                            return 'Monto inválido';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Asignación por categoría
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Asignación por Categoría',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...BudgetCategory.values.map((category) => _buildCategoryRow(category)),
                      const SizedBox(height: 16),
                      Text(
                        'Total asignado: ${_currencyFormat.format(totalAllocated)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isOverBudget ? Colors.red : null,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save),
        label: const Text('Guardar Presupuesto'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Método para construir el resumen del presupuesto
  Widget _buildBudgetSummary(double remaining, double progress) {
    final totalAllocated = _totalAllocated;
    final isOver = _isOverBudget;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del Presupuesto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildSummaryRow('Presupuesto total:', _currencyFormat.format(_monthlyDeposit)),
            _buildSummaryRow(
              'Total asignado:',
              _currencyFormat.format(totalAllocated),
              isOver ? Colors.red : null,
            ),
            _buildSummaryRow(
              isOver ? 'Excedente:' : 'Restante:',
              _currencyFormat.format(remaining.abs()),
              isOver ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress > 1.0 ? 1.0 : progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? Colors.red : Theme.of(context).primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  // Método para construir una fila de resumen
  Widget _buildSummaryRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryRow(BudgetCategory category) {
    final expenseCategory = _mapToExpenseCategory(category);
    
    return FutureBuilder<List<Expense>>(
      future: expenseStore.getExpensesByCategory(expenseCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final expenses = snapshot.data ?? [];
        // Filtrar solo gastos no presupuestados para el cálculo
        final gastosReales = expenses.where((e) => !e.esPresupuestado).toList();
        final totalGastado = gastosReales.fold<double>(0, (sum, e) => sum + e.monto);
        
        // Obtener el presupuesto del controlador de texto
        final presupuesto = double.tryParse(
          _amount[category]?.text.replaceAll(RegExp(r'[^\d.]'), '') ?? '0'
        ) ?? 0.0;
        
        final restante = presupuesto - totalGastado;
        final isOverBudget = restante < 0;
        
        // Actualizar el estado de presupuesto extendido
        if (isOverBudget) {
          _presupuestoExtendido[category] = true;
        } else if (restante >= 0 && _presupuestoExtendido[category] == true) {
          _presupuestoExtendido[category] = false;
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con nombre de categoría y estado de presupuesto
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getBudgetCategoryName(category),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_presupuestoExtendido[category] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'PRESUPUESTO EXTENDIDO',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Campo de entrada de presupuesto
                TextFormField(
                  controller: _amount[category],
                  focusNode: _getOrCreateFocusNode(category),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Presupuesto asignado',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorText: isOverBudget ? '¡Presupuesto excedido!' : null,
                    suffixIcon: isOverBudget
                        ? const Tooltip(
                            message: 'El gasto ha superado el presupuesto asignado',
                            child: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          )
                        : null,
                  ),
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : null,
                    fontWeight: isOverBudget ? FontWeight.bold : null,
                  ),
                  onChanged: (value) {
                    // Actualizar el estado cuando cambia el presupuesto
                    final newValue = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
                    if (newValue >= totalGastado) {
                      setState(() {
                        _presupuestoExtendido[category] = false;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Resumen de gastos
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      // Línea de total gastado
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total gastado:', style: TextStyle(fontSize: 14)),
                            Text(
                              _currencyFormat.format(totalGastado),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      
                      // Línea de presupuesto asignado
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Presupuesto asignado:', style: TextStyle(fontSize: 14)),
                            Text(
                              _currencyFormat.format(presupuesto),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      
                      // Línea de diferencia
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isOverBudget ? 'Excedente:' : 'Restante:',
                              style: TextStyle(
                                color: isOverBudget ? Colors.red : Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(restante.abs()),
                              style: TextStyle(
                                color: isOverBudget ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Barra de progreso
                      if (presupuesto > 0) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: totalGastado / (presupuesto > 0 ? presupuesto : 1),
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverBudget ? Colors.red : Colors.green,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(totalGastado / (presupuesto > 0 ? presupuesto : 1) * 100).toStringAsFixed(1)}% del presupuesto utilizado',
                          style: TextStyle(
                            color: isOverBudget ? Colors.red : Colors.grey[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Lista de gastos recientes
                if (expenses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Gastos recientes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ...expenses.take(3).map((e) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(
                        e.descripcion,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${e.fecha.toString().substring(0, 10)} • ${_currencyFormat.format(e.monto)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _eliminarGasto(e.id, category),
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

