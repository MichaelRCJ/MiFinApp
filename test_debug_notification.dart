import 'package:flutter/material.dart';
import 'lib/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios
  await notificationService.initialize();
  
  print('🧪 Prueba de depuración de notificaciones...');
  
  // Probar con una hora específica (2 minutos en el futuro)
  final now = DateTime.now();
  final targetTime = now.add(Duration(minutes: 2));
  final timeString = '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
  
  print('⏰ Hora actual: $now');
  print('📅 Hora objetivo: $targetTime');
  print('⏰ Time string: $timeString');
  
  try {
    await notificationService.scheduleMultipleExpenseReminders([timeString]);
    print('✅ Notificación programada - revisa los logs en Flutter para ver detalles');
    
    // Esperar un momento y verificar
    await Future.delayed(Duration(seconds: 2));
    final pending = await notificationService.getNotificationStatus();
    print('📋 Estado: $pending');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
