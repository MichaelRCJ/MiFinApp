import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/auth/inicio_sesion_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/registro_screen.dart';
import 'screens/auth/olvide_contrasena_screen.dart';
import 'screens/gastos/registrar_gasto_screen.dart';
import 'screens/common/particle_background.dart';
import 'services/service_locator.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ShinyApp());
}

class ShinyApp extends StatefulWidget {
  const ShinyApp({super.key});

  @override
  State<ShinyApp> createState() => _ShinyAppState();
}

class _ShinyAppState extends State<ShinyApp> {
  @override
  void initState() {
    super.initState();
    // Cargar el color del tema guardado por usuario
    themeController.load();
  }

  ThemeData _buildTheme(Color seed) {
    final primary = seed;
    final secondary = HSLColor.fromColor(seed).withHue((HSLColor.fromColor(seed).hue + 30) % 360).toColor();
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      // Hacemos transparente para permitir que el fondo y partículas globales sean visibles
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(centerTitle: true),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeController.seedArgb,
      builder: (context, seed, _) {
        final seedColor = Color(seed);
        // Derivar colores de fondo y partículas a partir del color elegido
        Color _lightBg(Color c) {
          final hsl = HSLColor.fromColor(c);
          final light = hsl.withSaturation((hsl.saturation * .5).clamp(0.0, 1.0)).withLightness(.96);
          return light.toColor();
        }
        Color _particleShade(Color c) {
          final hsl = HSLColor.fromColor(c);
          final mid = hsl.withSaturation((hsl.saturation * .9).clamp(0.0, 1.0)).withLightness(.55);
          return mid.toColor();
        }
        final bgColor = _lightBg(seedColor);
        final particleColor = _particleShade(seedColor);
        return MaterialApp(
          title: 'MiFinApp',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(seedColor),
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Capa de color de fondo claro según el tema
                Container(color: bgColor),
                // Capa de partículas en un tono medio del color elegido
                IgnorePointer(child: ParticleBackground(particleCount: 42, color: particleColor)),
                if (child != null) child,
              ],
            );
          },
          initialRoute: SplashScreen.routeName,
          routes: {
            SplashScreen.routeName: (_) => const SplashScreen(),
            InicioSesionScreen.routeName: (_) => const InicioSesionScreen(),
            HomeScreen.routeName: (_) => const HomeScreen(),
            '/incomes': (_) => const HomeScreen(initialIndex: 1), // Directo a ingresos
            RegistroScreen.routeName: (_) => const RegistroScreen(),
            OlvideContrasenaScreen.routeName: (_) => const OlvideContrasenaScreen(),
            RegistrarGastoScreen.routeName: (_) => const RegistrarGastoScreen(),
          },
        );
      },
    );
  }
}
