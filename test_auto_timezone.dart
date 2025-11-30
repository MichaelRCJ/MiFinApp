import 'package:flutter/material.dart';
import 'lib/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 Prueba de detección automática de timezone...');
  
  // Inicializar servicios
  await notificationService.initialize();
  
  // Mostrar información del dispositivo
  final now = DateTime.now();
  print('📍 Hora actual del sistema: $now');
  print('📍 Zona horaria del sistema: ${now.timeZoneName}');
  print('📍 Offset del sistema: ${now.timeZoneOffset}');
  
  // Probar con una hora 3 minutos en el futuro
  final targetTime = now.add(Duration(minutes: 3));
  final timeString = '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
  
  print('📅 Hora objetivo: $targetTime');
  print('⏰ Time string: $timeString');
  
  try {
    await notificationService.scheduleMultipleExpenseReminders([timeString]);
    print('✅ Notificación programada con timezone automático');
    
    // Esperar un momento y verificar
    await Future.delayed(Duration(seconds: 2));
    final pending = await notificationService.getNotificationStatus();
    print('📋 Estado final: $pending');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
