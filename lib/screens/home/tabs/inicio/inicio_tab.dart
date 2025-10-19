import 'package:flutter/material.dart';
import '../../../../models/budget.dart';
import '../../../../models/expense.dart';
import '../../../../services/service_locator.dart';
import '../../../../services/auth_service.dart';
import '../../../auth/inicio_sesion_screen.dart';

class DashboardTab extends StatelessWidget {
  final ValueChanged<int>? onChangeTab;
  const DashboardTab({super.key, this.onChangeTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: FutureBuilder<Map<String, dynamic>?>(
              future: AuthService.getCurrentUser(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                final name = (data != null ? (data['name'] as String?) : null);
                return FutureBuilder<String?>(
                  future: AuthService.getLastUsername(),
                  builder: (context, snap2) {
                    final username = snap2.data;
                    final display = (name != null && name.trim().isNotEmpty)
                        ? name
                        : (username != null && username.isNotEmpty ? username : '');
                    final text = display.isNotEmpty ? 'Bienvenido $display' : 'Bienvenido';
                    return Text(text);
                  },
                );
              },
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _ProfileScreen()),
                  ),
                  child: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                ),
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickAction(icon: Icons.add_card, label: 'Ingresos', color: theme.colorScheme.primary, onTap: () => onChangeTab?.call(1)),
                      _QuickAction(icon: Icons.ssid_chart, label: 'Análisis', color: theme.colorScheme.secondary, onTap: () => onChangeTab?.call(3)),
                      _QuickAction(icon: Icons.receipt, label: 'Gastos', color: Colors.orange, onTap: () => onChangeTab?.call(2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BudgetProgressCard(),
                  const SizedBox(height: 12),
                  _SectionCard(title: 'Historial de gastos', child: _HistoryList()),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _BudgetProgressCard extends StatefulWidget {
  @override
  State<_BudgetProgressCard> createState() => _BudgetProgressCardState();
}

class _BudgetProgressCardState extends State<_BudgetProgressCard> {
  BudgetConfig? _config;
  Map<String, BudgetCategory> _cats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await budgetStore.loadConfig();
    final cats = await budgetStore.loadTransferCategories();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _cats = cats;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return _SectionCard(
        title: 'Presupuesto mensual',
        child: SizedBox(
          height: 88,
          child: Center(
            child: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configura tu presupuesto en la pestaña Presupuesto'))),
              child: const Text('Configura tu presupuesto en la pestaña Presupuesto'),
            ),
          ),
        ),
      );
    }

    return const _MonthlySpendCard();
  }
}

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, this.onTap});

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = .96),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap?.call();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: 104,
            height: 84,
            decoration: BoxDecoration(color: widget.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: widget.color),
                  const SizedBox(height: 8),
                  Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatefulWidget {
  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  List<Expense> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await expenseStore.loadExpenses();
    list.sort((a, b) => b.fecha.compareTo(a.fecha));
    if (!mounted) return;
    setState(() {
      _items = list.take(5).toList();
      _loading = false;
    });
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

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No hay gastos aún. Registra tus gastos para verlos aquí.'),
      );
    }

    return Column(
      children: _items.map((e) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .15),
            child: const Icon(Icons.shopping_bag, color: Colors.black87),
          ),
          title: Text(e.descripcion.isEmpty ? 'Gasto' : e.descripcion),
          subtitle: Text('${_categoryLabel(e.categoria)} • ${_fmtDate(e.fecha)}'),
          trailing: Text(e.monto.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
        );
      }).toList(),
    );
  }
}

class _MonthlySpendCard extends StatefulWidget {
  const _MonthlySpendCard();

  @override
  State<_MonthlySpendCard> createState() => _MonthlySpendCardState();
}

class _MonthlySpendCardState extends State<_MonthlySpendCard> {
  double _initial = 0;
  double _spent = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await budgetStore.loadConfig();
    final expenses = await expenseStore.loadExpenses();
    final sumSpent = expenses.fold<double>(0, (p, e) => p + e.monto);
    if (!mounted) return;
    setState(() {
      _initial = cfg?.monthlyDeposit ?? 0;
      _spent = sumSpent;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }
    final remaining = (_initial - _spent).clamp(0, double.infinity);
    final ratio = _initial <= 0 ? 0.0 : (_spent / _initial).clamp(0.0, 1.0);
    return _SectionCard(
      title: 'Gasto mensual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dinero inicial', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_fmt(_initial), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Gastos', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_fmt(_spent), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Sobrante', style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_fmt(remaining), style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _bar(ratio),
          const SizedBox(height: 6),
          _bar((ratio * .8).clamp(0.0, 1.0)),
          const SizedBox(height: 6),
          _bar((ratio * 1.1).clamp(0.0, 1.0)),
        ],
      ),
    );
  }

  String _fmt(num v) {
    // Simple formatting without intl
    if (v >= 1000) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(0);
  }

  Widget _bar(double ratio) {
    final int spentFlex = (ratio * 100).round().clamp(0, 100);
    final int remainFlex = 100 - spentFlex;
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        children: [
          Expanded(
            flex: spentFlex,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(6.0),
                  bottomLeft: const Radius.circular(6.0),
                  topRight: Radius.circular(remainFlex == 0 ? 6.0 : 2.0),
                  bottomRight: Radius.circular(remainFlex == 0 ? 6.0 : 2.0),
                ),
              ),
            ),
          ),
          Expanded(
            flex: remainFlex,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                borderRadius: BorderRadius.only(
                  topRight: const Radius.circular(6.0),
                  bottomRight: const Radius.circular(6.0),
                  topLeft: Radius.circular(spentFlex == 0 ? 6.0 : 2.0),
                  bottomLeft: Radius.circular(spentFlex == 0 ? 6.0 : 2.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _originalUsername;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final username = await AuthService.getLastUsername();
    if (username != null) {
      final data = await AuthService.getUser(username);
      if (mounted && data != null) {
        _originalUsername = username;
        _userCtrl.text = username;
        _nameCtrl.text = (data['name'] as String?) ?? '';
        _emailCtrl.text = (data['email'] as String?) ?? '';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _originalUsername == null) return;
    setState(() => _saving = true);
    try {
      await AuthService.updateProfile(
        username: _originalUsername!,
        newUsername: _userCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      Navigator.of(context).pop();
    } on Exception catch (e) {
      final msg = e.toString().contains('ya existe')
          ? 'El nombre de usuario ya existe'
          : 'No se pudo actualizar';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(InicioSesionScreen.routeName, (route) => false);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(value: 'logout', child: Text('Cerrar sesión')),
            ],
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingrese su nombre';
                        if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Ingrese un usuario';
                        if (value.length < 3) return 'Mínimo 3 caracteres';
                        if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(value)) return 'Solo letras, números y . _ -';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Ingrese su correo';
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                        if (!ok) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        await AuthService.logout();
                        if (!mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(InicioSesionScreen.routeName, (route) => false);
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
