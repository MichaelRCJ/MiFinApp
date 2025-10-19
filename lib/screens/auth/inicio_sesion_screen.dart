import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/auth_service.dart';
import 'olvide_contrasena_screen.dart';
import 'registro_screen.dart';
import '../home/home_screen.dart';

class InicioSesionScreen extends StatefulWidget {
  static const String routeName = '/inicio-sesion';
  const InicioSesionScreen({super.key});

  @override
  State<InicioSesionScreen> createState() => _InicioSesionScreenState();
}

class _InicioSesionScreenState extends State<InicioSesionScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _obscure = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _logoTemplate; // raw SVG content loaded once

  @override
  void initState() {
    super.initState();
    _loadLogoTemplate();
    AuthService.getLastUsername().then((value) {
      if (!mounted) return;
      if (value != null && value.isNotEmpty) {
        _userController.text = value;
      }
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = _userController.text.trim();
      final pass = _passController.text;
      final ok = await AuthService.login(username: user, password: pass);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario o contraseña inválidos')),
        );
        return;
      }
      _goHome();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLogoTemplate() async {
    try {
      final raw = await rootBundle.loadString('assets/images/logo.svg');
      if (mounted) setState(() => _logoTemplate = raw);
    } catch (_) {
      // Silently ignore; placeholder will show
    }
  }

  String _colorToHex(Color c) {
    return '#'
        '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();
  }

  Color _darken(Color c, [double amount = 0.2]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      c.alpha,
      (c.red * f).round(),
      (c.green * f).round(),
      (c.blue * f).round(),
    );
  }

  String _colorizeSvg(String template, {required Color primary, required Color secondary}) {
    final primaryHex = _colorToHex(primary);
    final primaryStrokeHex = _colorToHex(_darken(primary, 0.25));
    final secondaryHex = _colorToHex(secondary);

    return template
        .replaceAll('#8B3A9F', primaryHex)
        .replaceAll('#6B2A7F', primaryStrokeHex)
        .replaceAll('#F4B840', secondaryHex);
  }

  double _relativeLuminance(Color c) {
    double f(int channel) {
      final v = channel / 255.0;
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }
    final r = f(c.red);
    final g = f(c.green);
    final b = f(c.blue);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  double _contrastRatio(Color a, Color b) {
    final l1 = _relativeLuminance(a);
    final l2 = _relativeLuminance(b);
    final top = l1 > l2 ? l1 : l2;
    final bottom = l1 > l2 ? l2 : l1;
    return (top + 0.05) / (bottom + 0.05);
  }

  Color _highContrastOn(Color base) {
    return ThemeData.estimateBrightnessForColor(base) == Brightness.light
        ? Colors.black
        : Colors.white;
  }

  Color _ensureContrast(Color primary, Color? secondary, {double minRatio = 3.0}) {
    final sec = secondary ?? _highContrastOn(primary);
    if (_contrastRatio(primary, sec) < minRatio) {
      return _highContrastOn(primary);
    }
    return sec;
  }

  bool _isBrandMorado(Color c) {
    const brand = Color(0xFF8B3A9F);
    int dr = c.red - brand.red;
    int dg = c.green - brand.green;
    int db = c.blue - brand.blue;
    final distSq = dr * dr + dg * dg + db * db;
    return distSq < 2000;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _logoTemplate == null
                        ? Container(
                            color: theme.colorScheme.primary.withOpacity(.08),
                            child: const SizedBox(),
                          )
                        : (_isBrandMorado(theme.colorScheme.primary)
                            ? SvgPicture.asset(
                                'assets/images/logo.svg',
                                fit: BoxFit.cover,
                              )
                            : SvgPicture.string(
                                _colorizeSvg(
                                  _logoTemplate!,
                                  primary: theme.colorScheme.primary,
                                  secondary: _ensureContrast(
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ),
                                ),
                                fit: BoxFit.cover,
                              )),
                  ),
                ),
                const SizedBox(height: 24),
                Text('MiFinApp', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _userController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingrese el usuario';
                    if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  onFieldSubmitted: (_) => _onLogin(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingrese la contraseña';
                    if (v.length < 4) return 'Mínimo 4 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(OlvideContrasenaScreen.routeName),
                        child: const Text('Olvidé mi contraseña'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(RegistroScreen.routeName),
                        child: const Text('Crear cuenta'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _onLogin,
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Login con Google no implementado'))),
                      icon: const Icon(Icons.g_mobiledata, size: 32),
                    ),
                    IconButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Login con Facebook no implementado'))),
                      icon: const Icon(Icons.facebook, size: 24),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
