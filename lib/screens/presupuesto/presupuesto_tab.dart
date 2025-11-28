import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget.dart';
import '../../models/budget_rule.dart';
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
  
  // Lista de reglas de presupuesto
  List<BudgetRule> _budgetRules = [];
  
  // Para controlar si se debe mostrar confirmación
  // final Map<BudgetCategory, bool> _pendingExceededConfirmation = {};
  
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
  
  // Inicializar controladores
  void _initializeControllers() {
    // Los controladores ya están inicializados en la declaración
    // Este método existe para mantener consistencia con el código existente
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    
    // Escuchar cambios en gastos
    expenseNotifier.addListener(_onExpensesChanged);
    
    // Escuchar cambios en el presupuesto (cuando se actualiza desde gastos)
    budgetStore.addListener(_onBudgetChanged);
    
    // Inicializar datos después de que los listeners estén configurados
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }
  
  // Inicializar todos los datos necesarios
  Future<void> _initializeData() async {
    try {
      setState(() => _isLoading = true);
      await Future.wait([
        _loadBudget(),
        _loadExpenses(),
        _checkBudgetRules(),
      ]);
    } catch (e) {
      _showError('Error al cargar los datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Verificar reglas del presupuesto
  Future<void> _checkBudgetRules() async {
    final rules = <BudgetRule>[];
    
    try {
      // Cargar gastos del mes actual
      final allExpenses = await expenseStore.loadExpenses();
      final now = DateTime.now();
      final monthExpenses = allExpenses.where((e) => 
        e.fecha.year == now.year && e.fecha.month == now.month
      ).toList();

      final totalAllocated = _totalAllocated;
      final monthlyDeposit = _monthlyDeposit;

      // Regla 1: Validar que el total asignado no exceda el saldo
      if (totalAllocated > monthlyDeposit && monthlyDeposit > 0) {
        rules.add(BudgetRule(
          title: 'Presupuesto excedido',
          description: 'Has asignado \$${totalAllocated.toStringAsFixed(2)} pero solo tienes \$${monthlyDeposit.toStringAsFixed(2)} de saldo',
          severity: RuleSeverity.danger,
          recommendation: 'Reduce las asignaciones o aumenta tu saldo registrando más ingresos.',
        ));
      }

      // Regla 2: Validar categorías sin presupuesto asignado
      for (final category in BudgetCategory.values) {
        final allocated = _parseAmount(_amount[category]!.text);
        if (allocated <= 0) {
          rules.add(BudgetRule(
            title: 'Categoría sin presupuesto',
            description: '${_getBudgetCategoryName(category)} no tiene presupuesto asignado',
            severity: RuleSeverity.warning,
            category: category,
            recommendation: 'Asigna un presupuesto a esta categoría para mejor control.',
          ));
        }
      }

      // Regla 3: Validar distribución equitativa (ninguna categoría > 60% del total)
      if (totalAllocated > 0) {
        for (final category in BudgetCategory.values) {
          final allocated = _parseAmount(_amount[category]!.text);
          final percentage = (allocated / totalAllocated) * 100;
          
          if (percentage > 60) {
            rules.add(BudgetRule(
              title: 'Asignación desbalanceada',
              description: '${_getBudgetCategoryName(category)} representa el ${percentage.toStringAsFixed(0)}% del presupuesto total',
              severity: RuleSeverity.warning,
              category: category,
              recommendation: 'Considera distribuir mejor tu presupuesto entre categorías.',
            ));
          }
        }
      }

      // Regla 4: Validar gastos reales vs asignaciones
      for (final category in BudgetCategory.values) {
        final allocated = _parseAmount(_amount[category]!.text);
        final expenseCategory = _mapToExpenseCategory(category);
        final spent = monthExpenses
            .where((e) => e.categoria == expenseCategory)
            .fold(0.0, (sum, e) => sum + e.monto);
        
        if (allocated > 0 && spent > allocated * 0.8) {
          rules.add(BudgetRule(
            title: 'Categoría casi agotada',
            description: 'Has gastado el ${((spent/allocated)*100).toStringAsFixed(0)}% de ${_getBudgetCategoryName(category)}',
            severity: spent > allocated ? RuleSeverity.danger : RuleSeverity.warning,
            category: category,
            recommendation: spent > allocated 
                ? 'Has excedido esta categoría. Considera reasignar fondos.'
                : 'Cuidado, estás cerca del límite de esta categoría.',
          ));
        }
      }

      if (mounted) {
        setState(() => _budgetRules = rules);
      }
    } catch (e) {
      debugPrint('Error checking budget rules: $e');
    }
  }

  @override
  void dispose() {
    // Limpiar listeners y controladores
    expenseNotifier.removeListener(_onExpensesChanged);
    budgetStore.removeListener(_onBudgetChanged);
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
      
      // Verificar cada categoría y actualizar presupuestos si es necesario
      for (final category in BudgetCategory.values) {
        final expenseCategory = _mapToExpenseCategory(category);
        final gastosCategoria = expenses
            .where((e) => e.categoria == expenseCategory && !e.esPresupuestado)
            .toList();
            
        if (gastosCategoria.isNotEmpty) {
          final totalGastado = gastosCategoria.fold<double>(0, (sum, e) => sum + e.monto);
          final presupuestoActual = _parseAmount(_amount[category]!.text);
          
          // Si hay gastos no presupuestados, actualizar el presupuesto automáticamente
          if (totalGastado > 0 && (presupuestoActual == 0 || totalGastado > presupuestoActual)) {
            _amount[category]!.text = _formatCurrency(totalGastado);
            _presupuestoExtendido[category] = true;
          } else if (totalGastado <= presupuestoActual) {
            _presupuestoExtendido[category] = false;
          }
        }
      }
      
      if (mounted) {
        setState(() {});
        _updateController.add(null);
        // Revisar reglas después de cambios
        await _checkBudgetRules();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al actualizar presupuestos: $e');
      }
    }
  }
  
  // Escuchar cambios en el presupuesto (cuando se actualiza desde gastos)
  Future<void> _onBudgetChanged() async {
    debugPrint('🔄 Budget changed - reloading budget data');
    if (!mounted) return;
    
    try {
      // Recargar la configuración del presupuesto
      await _loadBudget();
      
      if (mounted) {
        setState(() {
          debugPrint('✅ Budget UI updated');
        });
        _updateController.add(null);
        // Revisar reglas después de cambios
        await _checkBudgetRules();
      }
    } catch (e) {
      debugPrint('❌ Error al actualizar presupuesto: $e');
      if (mounted) {
        _showError('Error al actualizar presupuesto: $e');
      }
    }
  }
  
  // Cargar la configuración del presupuesto
  Future<void> _loadBudget() async {
    try {
      final cfg = await budgetStore.loadConfig();
      debugPrint('💰 Budget loaded: ${cfg?.monthlyDeposit}');
      if (!mounted) return;
      
      setState(() {
        _deposit.text = _formatCurrency(cfg?.monthlyDeposit ?? 0.0);
        for (final category in BudgetCategory.values) {
          final amount = cfg?.allocationsAmount[category] ?? 0.0;
          _amount[category]!.text = _formatCurrency(amount);
          debugPrint('📊 Category ${category.name}: $amount');
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading budget: $e');
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
      _showError('El saldo debe ser mayor a cero. Registra ingresos para aumentar tu saldo.');
      return false;
    }
    try {
      final config = BudgetConfig(
        monthlyDeposit: _monthlyDeposit,
        allocationsAmount: {
          for (final category in BudgetCategory.values)
            category: _parseAmount(_amount[category]!.text),
        },
        lastUpdated: DateTime.now(),
      );
      
      await budgetStore.saveConfig(config);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presupuesto guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Revisar reglas después de guardar
        await _checkBudgetRules();
      }
      return true;
    } catch (e) {
      if (mounted) {
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

  // Construir tarjeta de regla de presupuesto
  Widget _buildBudgetRuleCard(BudgetRule rule) {
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
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rule.description,
            style: const TextStyle(fontSize: 11),
          ),
          if (rule.recommendation != null) ...[
            const SizedBox(height: 4),
            Text(
              '💡 ${rule.recommendation}',
              style: const TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
        ],
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
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Presupuesto'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<void>(
              stream: _updateController.stream,
              builder: (context, snapshot) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Saldo disponible
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saldo Disponible',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet, color: Colors.green[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    currencyFormat.format(_monthlyDeposit),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Solo se modifica por ingresos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Para aumentar tu saldo, registra ingresos en la pestaña de Ingresos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      

                      // SECCIÓN DE REGLAS DE PRESUPUESTO
                      if (_budgetRules.isNotEmpty) ...[
                        Card(
                          color: Colors.red[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.rule, color: Colors.red[700]),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Reglas de Presupuesto',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_budgetRules.length} ${_budgetRules.length == 1 ? "alerta" : "alertas"}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._budgetRules.map((rule) => _buildBudgetRuleCard(rule)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      

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
                                'Total asignado: ${currencyFormat.format(_totalAllocated)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isOverBudget ? Colors.red : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      

                      // Botón de guardar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Guardar Presupuesto'),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
        final percentage = presupuesto > 0 ? (totalGastado / presupuesto) * 100 : 0.0;
        
        // Determinar color según estado
        Color cardColor;
        Color borderColor;
        Color statusColor;
        String statusText;
        IconData statusIcon;
        
        if (isOverBudget) {
          // ROJO: Excedido
          cardColor = Colors.red[50]!;
          borderColor = Colors.red[400]!;
          statusColor = Colors.red[700]!;
          statusText = 'EXCEDIDO';
          statusIcon = Icons.dangerous;
        } else if (percentage >= 80) {
          // NARANJA: Cercano al límite
          cardColor = Colors.orange[50]!;
          borderColor = Colors.orange[400]!;
          statusColor = Colors.orange[700]!;
          statusText = 'CASI LÍMITE';
          statusIcon = Icons.warning;
        } else {
          // VERDE: Bien
          cardColor = Colors.green[50]!;
          borderColor = Colors.green[400]!;
          statusColor = Colors.green[700]!;
          statusText = 'OK';
          statusIcon = Icons.check_circle;
        }
        
        // Actualizar el estado de presupuesto extendido
        if (isOverBudget) {
          _presupuestoExtendido[category] = true;
        } else if (restante >= 0 && _presupuestoExtendido[category] == true) {
          _presupuestoExtendido[category] = false;
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con nombre de categoría y estado visual
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _getBudgetCategoryName(category),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Barra de progreso visual
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (percentage / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isOverBudget ? Colors.red[700] : 
                               percentage >= 80 ? Colors.orange[700] : Colors.green[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Información de presupuesto y gastos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Presupuesto: \$${presupuesto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Gastado: \$${totalGastado.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Restante: \$${restante.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget ? Colors.red[700] : statusColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(0)}% usado',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        if (isOverBudget)
                          Text(
                            '+\$${(-restante).toStringAsFixed(2)} excedido',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
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
                    labelText: 'Ajustar presupuesto',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    suffixIcon: Icon(Icons.edit, color: statusColor),
                  ),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (value) {
                    // Actualizar el estado cuando cambia el presupuesto
                    _debouncer.run(() {
                      setState(() {});
                      _checkBudgetRules(); // Revisar reglas después del cambio
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

