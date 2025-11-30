import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../auth/inicio_sesion_screen.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = '/';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0;
  String? _logoTemplate;
  @override
  void initState() {
    super.initState();
    _loadLogoTemplate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _opacity = 1);
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(InicioSesionScreen.routeName);
    });
  }

  Future<void> _loadLogoTemplate() async {
    try {
      final raw = await rootBundle.loadString('assets/images/logo.svg');
      if (mounted) setState(() => _logoTemplate = raw);
    } catch (_) {}
  }

  String _colorToHex(Color c) {
    return '#'
        '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();
  }

  Color _darken(Color c, [double amount = 0.25]) {
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

  // ---- Contrast helpers ----
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
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: _logoTemplate == null
                    ? const SizedBox()
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
              const SizedBox(height: 16),
              Text('MiFinApp', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Controla tus gastos'),
            ],
          ),
        ),
      ),
    );
  }
}


