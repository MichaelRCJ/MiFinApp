# MiFinApp - Gestor de Finanzas Personales

[![Flutter](https://img.shields.io/badge/Flutter-3.16.0-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.9.2-blue.svg)](https://dart.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Aplicación de gestión financiera personal desarrollada con Flutter, compatible con Android, iOS, Web y Windows. Incluye un sistema completo para el seguimiento de gastos, presupuestos, ingresos y análisis financiero.

## 📋 Tabla de Contenidos

- [Características Principales](#-características-principales)
- [Requisitos](#-requisitos)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Configuración Inicial](#-configuración-inicial)
- [Ejecución del Proyecto](#-cómo-ejecutar)
- [Construcción para Producción](#-builds-de-producción)
- [Personalización](#-personalización)
- [Solución de Problemas](#-problemas-comunes)
- [Contribución](#-contribución)
- [Licencia](#-licencia)

## ✨ Características Principales

- **Autenticación de Usuarios**
  - Registro e inicio de sesión seguros
  - Recuperación de contraseña mediante correo electrónico
  - Personalización de perfil

- **Gestión Financiera**
  - Registro de gastos e ingresos
  - Categorización de transacciones
  - Seguimiento de presupuestos
  - Análisis de gastos con gráficos

- **Plataformas Soportadas**
  - 📱 Android
  - 🍎 iOS
  - 🌐 Web
  - 🖥️ Windows
  - 🐧 Linux
  - 🍏 macOS

- **Características Adicionales**
  - Interfaz intuitiva y moderna
  - Modo oscuro/claro
  - Sincronización entre dispositivos (próximamente)
  - Exportación de datos (próximamente)

## 🛠 Requisitos

Usa esta guía paso a paso para instalar requisitos, preparar el entorno y ejecutar sin problemas.

## 🛠 Requisitos

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

## 🔄 Flujo de Recuperación de Contraseña

### 📱 Pantalla de Recuperación
La pantalla de "Olvidé mi Contraseña" permite a los usuarios recuperar el acceso a sus cuentas de manera segura a través de su correo electrónico registrado.

### 🔑 Componentes Utilizados
- **Campo de Texto (TextField)**: Para ingresar el correo electrónico registrado
- **Botón de Acción (ElevatedButton)**: Para enviar el enlace de recuperación
- **Firebase Authentication**: Gestiona el envío de correos de recuperación
- **Indicador de Carga (CircularProgressIndicator)**: Muestra el estado de carga durante el proceso
- **Mensajes de Retroalimentación (SnackBar)**: Informa al usuario sobre el resultado de la operación

### 🔄 Flujo de Uso
1. El usuario selecciona "¿Olvidaste tu contraseña?" en la pantalla de inicio de sesión
2. Ingresa su correo electrónico registrado
3. Presiona el botón "Enviar enlace de recuperación"
4. El sistema procesa la solicitud y muestra un indicador de carga
5. Se envía un correo electrónico con el enlace de restablecimiento
6. El usuario recibe una notificación visual del estado de la operación

### ✅ Validaciones Implementadas
- Verificación de formato de correo electrónico
- Validación de campos obligatorios
- Manejo de errores de Firebase Auth
- Retroalimentación visual durante el proceso de recuperación
- Mensajes claros de éxito o error para el usuario

## 📁 Estructura del Proyecto

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

## ⚙️ Configuración Inicial

1. Clona el repositorio.
2. En la raíz del proyecto, instala dependencias:
   - `flutter pub get`
3. Verifica que las plataformas estén listas:
   - `flutter doctor -v`
4. Revisa que los assets declarados en `pubspec.yaml` existan:
   - Directorios: `assets/images/` y `assets/config/`.

Si quieres trabajar con la app dentro de `aplicacion1/`, entra a esa carpeta y repite los pasos 2–3 allí.

## 🚀 Cómo ejecutar

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

## 📦 Builds de Producción

- Android (APK):
  - `flutter build apk --release`
- Web:
  - `flutter build web`
- Windows:
  - `flutter build windows`

Consulta la documentación oficial para iOS (requiere macOS y configuración de certificados):
https://docs.flutter.dev/deployment/ios

## 🎨 Personalización

### Íconos de la Aplicación

La app raíz usa `flutter_launcher_icons` para generar íconos (ver `pubspec.yaml`).

1. Asegúrate de tener la imagen base en `assets/images/logo.png` (según configuración actual).
2. Ejecuta:
   - `dart run flutter_launcher_icons`

## 🐛 Problemas Comunes

- Dependencias no se instalan:
  - Ejecuta `flutter pub get -v` y revisa conexión a internet y `pubspec.yaml`.
- Dispositivo/emulador no aparece:
  - `flutter devices`; en Android, abre Android Studio > Device Manager y crea/inicia un emulador. En iOS, abre Xcode > simuladores.
- Error de versión de Dart/Flutter:
  - Actualiza Flutter a una versión que incluya Dart `>= 3.9.2`.
- Windows Desktop falla al compilar:
  - Instala Visual Studio con la carga de trabajo C++ y reinicia la terminal. Luego `flutter doctor -v`.

## 💻 Comandos Útiles

- Listar dispositivos: `flutter devices`
- Limpiar cachés: `flutter clean && flutter pub get`
- Actualizar dependencias: `flutter pub upgrade --major-versions`

## 🌐 Recursos

- [Documentación Oficial de Flutter](https://docs.flutter.dev/)
- [Cookbook de Ejemplos](https://docs.flutter.dev/cookbook)
- [Paquetes de Flutter](https://pub.dev/)
- [Comunidad Flutter en Español](https://esflutter.dev/)

## 🤝 Contribución

¡Las contribuciones son bienvenidas! Por favor, lee nuestra [guía de contribución](CONTRIBUTING.md) antes de enviar un pull request.

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más información.

---

Desarrollado con ❤️ por [Tu Nombre o Equipo]
