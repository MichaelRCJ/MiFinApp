# MiFinApp — Guía para correr el proyecto

Este repositorio contiene una aplicación Flutter lista para ejecutarse en Android, iOS, Web y Windows. Además, incluye una segunda app de ejemplo dentro de `aplicacion1/`.

Usa esta guía paso a paso para instalar requisitos, preparar el entorno y ejecutar sin problemas.

## Requisitos

- **Flutter** instalado y en el `PATH`.
  - Debes usar una versión de Flutter que incluya **Dart >= 3.9.2** (ver `environment.sdk` en `pubspec.yaml`).
  - Verifica tu versión: `flutter --version`.
- **Android**: Android Studio, Android SDK, un emulador o dispositivo físico con Depuración USB.
- **iOS** (solo macOS): Xcode y un simulador o dispositivo físico.
- **Web**: Google Chrome o Edge.
- **Windows Desktop**: Visual Studio (carga de trabajo "Desarrollo de escritorio con C++").

Sugerencias de configuración Flutter:

- Habilitar plataformas opcionales:
  - Windows: `flutter config --enable-windows-desktop`
  - Web: `flutter config --enable-web`
- Diagnóstico del entorno: `flutter doctor -v`

## Estructura del repositorio

- **App principal (raíz)**: archivos como `pubspec.yaml`, `lib/`, `android/`, `ios/`, `web/`, `windows/` se encuentran en la raíz del repo.
- **App secundaria (`aplicacion1/`)**: contiene otra app Flutter de plantilla dentro de `aplicacion1/` con su propio `pubspec.yaml`.

Puedes ejecutar cualquiera de las dos. Si no se indica lo contrario, las instrucciones se refieren a la app de la **raíz**.

## Estructura del proyecto (detalle)

```text
MiFinApp/
├─ pubspec.yaml                 # Configuración de dependencias, assets y entorno (Dart >= 3.9.2)
├─ lib/                         # Código fuente principal de la app
│  ├─ main.dart                 # Punto de entrada de la aplicación Flutter
│  ├─ models/                   # Modelos de dominio
│  │  ├─ bank_account.dart
│  │  ├─ bank_transfer.dart
│  │  ├─ budget.dart
│  │  └─ expense.dart
│  ├─ screens/                  # Pantallas (ventanas) y tabs de la UI
│  │  ├─ auth/                  # Flujo de autenticación
│  │  │  ├─ inicio_sesion_screen.dart
│  │  │  ├─ olvide_contrasena_screen.dart
│  │  │  └─ registro_screen.dart
│  │  ├─ home/                  # Pantalla Home y tabs
│  │  │  ├─ home_screen.dart
│  │  │  ├─ registrar_gasto_screen.dart
│  │  │  └─ tabs/
│  │  │     └─ gastos_tab.dart
│  │  ├─ gastos/
│  │  │  ├─ gastos_tab.dart
│  │  │  └─ registrar_gasto_screen.dart
│  │  ├─ ingresos/
│  │  │  └─ ingresos_tab.dart
│  │  ├─ presupuesto/
│  │  │  └─ presupuesto_tab.dart
│  │  ├─ analisis/
│  │  │  └─ analisis_tab.dart
│  │  ├─ ajustes/
│  │  │  └─ ajustes_tab.dart
│  │  ├─ onboarding/
│  │  │  └─ splash_screen.dart
│  │  └─ common/
│  │     └─ particle_background.dart
│  ├─ services/                 # Servicios y lógica de negocio/transversal
│  │  ├─ auth_service.dart
│  │  ├─ email_service.dart
│  │  ├─ service_locator.dart   # Registro/inyector de dependencias
│  │  └─ theme_controller.dart  # Control de tema (oscuro/claro)
│  └─ storage/                  # Persistencia local (stores)
│     ├─ budget_store.dart
│     ├─ expense_store.dart
│     └─ settings_store.dart
├─ assets/
│  ├─ images/                   # Imágenes e íconos (incluye logo para launcher)
│  └─ config/                   # Archivos de configuración
├─ android/                     # Proyecto Android (Gradle)
├─ ios/                         # Proyecto iOS (Xcode)
├─ web/                         # Configuración y assets para Web
├─ windows/                     # Proyecto Windows Desktop (MSVC)
├─ linux/                       # Proyecto Linux Desktop
├─ macos/                       # Proyecto macOS Desktop
├─ test/                        # Pruebas unitarias/widget tests
└─ aplicacion1/                 # Segunda app Flutter (plantilla) con su propio `lib/` y `pubspec.yaml`
```

- **Pantallas/Ventanas**: se encuentran bajo `lib/screens/` agrupadas por funcionalidad (por ejemplo, `auth/`, `home/`, `gastos/`).
- **Modelos**: en `lib/models/` (`budget.dart`, `expense.dart`, etc.).
- **Servicios**: en `lib/services/` (`auth_service.dart`, `email_service.dart`, `service_locator.dart`, `theme_controller.dart`).
- **Persistencia**: en `lib/storage/` (`budget_store.dart`, `expense_store.dart`, `settings_store.dart`).
- **Recursos estáticos**: en `assets/images/` y `assets/config/` (declarados en `pubspec.yaml`).

## Preparación (una vez por clonación)

1. Clona el repositorio.
2. En la raíz del proyecto, instala dependencias:
   - `flutter pub get`
3. Verifica que las plataformas estén listas:
   - `flutter doctor -v`
4. Revisa que los assets declarados en `pubspec.yaml` existan:
   - Directorios: `assets/images/` y `assets/config/`.

Si quieres trabajar con la app dentro de `aplicacion1/`, entra a esa carpeta y repite los pasos 2–3 allí.

## Cómo ejecutar

Desde la raíz del proyecto:

- Android (emulador/dispositivo):
  - `flutter run -d emulator-5554` (usa el ID de tu dispositivo con `flutter devices`), o simplemente `flutter run` si hay un único destino disponible.
- iOS (macOS):
  - `flutter run -d ios`
- Web (Chrome):
  - `flutter run -d chrome`
- Windows Desktop:
  - `flutter run -d windows`

Para la app secundaria en `aplicacion1/`, ejecuta los mismos comandos pero dentro de esa carpeta.

## Builds de producción (básico)

- Android (APK):
  - `flutter build apk --release`
- Web:
  - `flutter build web`
- Windows:
  - `flutter build windows`

Consulta la documentación oficial para iOS (requiere macOS y configuración de certificados):
https://docs.flutter.dev/deployment/ios

## Íconos de la app

La app raíz usa `flutter_launcher_icons` para generar íconos (ver `pubspec.yaml`).

1. Asegúrate de tener la imagen base en `assets/images/logo.png` (según configuración actual).
2. Ejecuta:
   - `dart run flutter_launcher_icons`

## Problemas comunes

- Dependencias no se instalan:
  - Ejecuta `flutter pub get -v` y revisa conexión a internet y `pubspec.yaml`.
- Dispositivo/emulador no aparece:
  - `flutter devices`; en Android, abre Android Studio > Device Manager y crea/inicia un emulador. En iOS, abre Xcode > simuladores.
- Error de versión de Dart/Flutter:
  - Actualiza Flutter a una versión que incluya Dart `>= 3.9.2`.
- Windows Desktop falla al compilar:
  - Instala Visual Studio con la carga de trabajo C++ y reinicia la terminal. Luego `flutter doctor -v`.

## Comandos útiles

- Listar dispositivos: `flutter devices`
- Limpiar cachés: `flutter clean && flutter pub get`
- Actualizar dependencias: `flutter pub upgrade --major-versions`

## Recursos

- Documentación Flutter: https://docs.flutter.dev/
- Cookbook de ejemplos: https://docs.flutter.dev/cookbook

