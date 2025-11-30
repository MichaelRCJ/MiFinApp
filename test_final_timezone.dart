import 'package:flutter/material.dart';
import 'lib/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 Prueba final de timezone forzado...');
  
  // Inicializar servicios
  await notificationService.initialize();
  
  // Probar con una hora 3 minutos en el futuro
  final now = DateTime.now();
  final targetTime = now.add(Duration(minutes: 3));
  final timeString = '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
  
  print('⏰ Hora actual del sistema: $now');
  print('📍 Zona horaria del sistema: ${now.timeZoneName}');
  print('📍 Offset del sistema: ${now.timeZoneOffset}');
  print('📅 Hora objetivo: $targetTime');
  print('⏰ Time string: $timeString');
  
  try {
    await notificationService.scheduleMultipleExpenseReminders([timeString]);
    print('✅ Notificación programada');
    
    // Esperar un momento y verificar
    await Future.delayed(Duration(seconds: 2));
    final pending = await notificationService.getNotificationStatus();
    print('📋 Estado final: $pending');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
