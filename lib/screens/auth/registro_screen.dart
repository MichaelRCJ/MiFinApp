import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'inicio_sesion_screen.dart';

class RegistroScreen extends StatefulWidget {
  static const String routeName = '/registro';
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.register(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso. Ahora inicia sesión.')),
      );
      Navigator.of(context).pushReplacementNamed(InicioSesionScreen.routeName);
    } on Exception catch (e) {
      final msg = e.toString().contains('ya existe')
          ? 'El usuario ya existe, elija otro.'
          : 'No se pudo registrar. Inténtalo de nuevo.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Juan',
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingrese su nombre';
                    if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _surnameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Apellidos',
                    hintText: 'Ej: Pérez García',
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingrese sus apellidos';
                    if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _userCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    hintText: 'Ej: juanperez',
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Ingrese un nombre de usuario';
                    if (value.length < 3) return 'Mínimo 3 caracteres';
                    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(value)) {
                      return 'Solo letras, números y . _ -';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'Ej: juan@email.com',
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingrese su correo';
                    final email = v.trim();
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                    if (!ok) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'La contraseña debe tener caracteres especiales.',
                    style: TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Mínimo 6 caracteres',
                    border: const OutlineInputBorder(),
                    hintStyle: const TextStyle(color: Colors.black54),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingrese una contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    hintText: 'Repite la contraseña',
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  onFieldSubmitted: (_) => _onRegister(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Repita la contraseña';
                    if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _onRegister,
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Registrarme'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pushReplacementNamed(InicioSesionScreen.routeName),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
