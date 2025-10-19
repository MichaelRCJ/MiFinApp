import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';

class OlvideContrasenaScreen extends StatefulWidget {
  static const String routeName = '/olvide-contrasena';
  const OlvideContrasenaScreen({super.key});

  @override
  State<OlvideContrasenaScreen> createState() => _OlvideContrasenaScreenState();
}

class _OlvideContrasenaScreenState extends State<OlvideContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSendTemp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final name = _nameCtrl.text.trim();
      final surname = _surnameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final result = await AuthService.requestTemporaryPasswordByNameSurnameEmail(
        name: name,
        surname: surname,
        email: email,
        durationMinutes: 10,
      );
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La información no coincide con ningún usuario. Por favor verifique nombre, apellidos y correo.')),
        );
        return;
      }
      try {
        await EmailService.sendTemporaryPasswordEmail(
          toEmail: result.email,
          username: result.username,
          temp: result.temp,
          expiresAt: result.expiresAt,
        );
      } catch (e) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Contraseña temporal'),
            content: Text(
              'No se pudo enviar el correo automáticamente.\n\n'
              'Detalle: $e\n\n'
              'Código: ${result.temp}\nEnviado a: ${result.email}\nVence: ${result.expiresAt}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hemos enviado un correo a ${result.email} con tu contraseña temporal.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar la contraseña temporal')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Olvidé mi contraseña')),
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
                    child: const Icon(Icons.lock_clock_rounded, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ingrese su nombre, apellidos y correo electrónico. Si coinciden con un usuario registrado, enviaremos una contraseña temporal (válida por 10 minutos) al correo.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Juan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingrese su nombre';
                    if (v.trim().length < 2) return 'Nombre demasiado corto';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _surnameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Apellidos',
                    hintText: 'Ej: Pérez García',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingrese sus apellidos';
                    if (v.trim().length < 2) return 'Apellidos demasiado cortos';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) => _onSendTemp(),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Ingrese su correo electrónico';
                    final ok = value.contains('@') && value.contains('.') && !value.contains(' ');
                    if (!ok) return 'Correo electrónico no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _onSendTemp,
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Enviar contraseña temporal'),
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
