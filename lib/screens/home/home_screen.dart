import 'package:flutter/material.dart';
import 'tabs/inicio/inicio_tab.dart';
import '../gastos/gastos_tab.dart';
import '../ingresos/ingresos_tab.dart';
import '../analisis/analisis_tab.dart';
import '../presupuesto/presupuesto_tab.dart';
import '../ajustes/ajustes_tab.dart';
import '../../services/service_locator.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';
  final int initialIndex;
  
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    debugPrint('🏠 HomeScreen: Inicializando con índice ${widget.initialIndex}');
    
    // Inicializar notificaciones después de que la UI está lista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeNotifications();
      }
    });
  }
  
  Future<void> _initializeNotifications() async {
    try {
      // Establecer contexto para el servicio de notificaciones
      notificationService.setContext(context);
      await notificationService.initialize();
      debugPrint('✅ Notificaciones inicializadas en HomeScreen');
    } catch (e) {
      debugPrint('❌ Error inicializando notificaciones: $e');
    }
  }

  List<Widget> get _tabs => [
    DashboardTab(onChangeTab: (i) => setState(() => _index = i)),
    const IncomeTab(),
    const ExpensesTab(),
    const AnalysisTab(),
    const BudgetTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 HomeScreen build: índice actual = $_index');
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _tabs[_index],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() {
          debugPrint('🏠 Cambiando a índice: $i');
          _index = i;
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money_rounded), label: 'Ingresos'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Gastos'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Análisis'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Presupuesto'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}


