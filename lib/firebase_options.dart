import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// TODO: Ejecuta `flutterfire configure` para generar valores reales.
/// Estos valores de marcador permiten compilar mientras se completa la configuración.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Fuchsia no es compatible con Firebase todavía.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAyi7SzAoVsylaEdevTAb9ALCQpI5yrwkU',
    appId: '1:674645563015:web:f0ffe562f32b1ab0d88a22',
    messagingSenderId: '674645563015',
    projectId: 'myfinapp-28865',
    authDomain: 'myfinapp-28865.firebaseapp.com',
    storageBucket: 'myfinapp-28865.firebasestorage.app',
    measurementId: 'G-R8YY690P7V',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCzPx-bjTd3dtGz1jJXMFFek_R3caKjsGU',
    appId: '1:674645563015:android:fa1a6c81edbc1d50d88a22',
    messagingSenderId: '674645563015',
    projectId: 'myfinapp-28865',
    storageBucket: 'myfinapp-28865.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCwDFedDDrsmJ_6J07A-H7Ak8n-5S2GYb8',
    appId: '1:674645563015:ios:8df357aea74b9637d88a22',
    messagingSenderId: '674645563015',
    projectId: 'myfinapp-28865',
    storageBucket: 'myfinapp-28865.firebasestorage.app',
    iosClientId: '674645563015-u01u6jod6q2dr4luj8v1v4ooddbvq2hv.apps.googleusercontent.com',
    iosBundleId: 'com.example.aplicacion1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCwDFedDDrsmJ_6J07A-H7Ak8n-5S2GYb8',
    appId: '1:674645563015:ios:8df357aea74b9637d88a22',
    messagingSenderId: '674645563015',
    projectId: 'myfinapp-28865',
    storageBucket: 'myfinapp-28865.firebasestorage.app',
    iosClientId: '674645563015-u01u6jod6q2dr4luj8v1v4ooddbvq2hv.apps.googleusercontent.com',
    iosBundleId: 'com.example.aplicacion1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAyi7SzAoVsylaEdevTAb9ALCQpI5yrwkU',
    appId: '1:674645563015:web:439dc054b17443cbd88a22',
    messagingSenderId: '674645563015',
    projectId: 'myfinapp-28865',
    authDomain: 'myfinapp-28865.firebaseapp.com',
    storageBucket: 'myfinapp-28865.firebasestorage.app',
    measurementId: 'G-7K140BKM94',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_LINUX_API_KEY',
    appId: 'YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}