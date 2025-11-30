import 'package:flutter/material.dart';
import 'lib/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 Probando configuración de timezone...');
  
  // Inicializar servicios
  await notificationService.initialize();
  
  // Probar con una hora 3 minutos en el futuro
  final now = DateTime.now();
  final targetTime = now.add(Duration(minutes: 3));
  final timeString = '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
  
  print('⏰ Hora actual: $now');
  print('📅 Hora objetivo: $targetTime');
  print('⏰ Time string: $timeString');
  print('📍 Zona horaria actual: ${now.timeZoneName}');
  print('📍 Offset: ${now.timeZoneOffset}');
  
  try {
    await notificationService.scheduleMultipleExpenseReminders([timeString]);
    print('✅ Notificación programada - revisa los logs para ver detalles');
    
    // Esperar un momento y verificar
    await Future.delayed(Duration(seconds: 2));
    final pending = await notificationService.getNotificationStatus();
    print('📋 Estado: $pending');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
