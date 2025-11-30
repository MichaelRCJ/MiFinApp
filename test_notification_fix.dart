import 'package:flutter/material.dart';
import 'lib/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios
  await notificationService.initialize();
  
  print('🧪 Probando notificación programada a hora específica...');
  
  // Programar una notificación para 1 minuto en el futuro
  final now = DateTime.now();
  final targetTime = now.add(Duration(minutes: 1));
  final timeString = '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
  
  print('⏰ Hora actual: $now');
  print('📅 Hora objetivo: $targetTime');
  print('⏰ Time string: $timeString');
  
  try {
    await notificationService.scheduleMultipleExpenseReminders([timeString]);
    print('✅ Notificación programada exitosamente');
    
    // Verificar notificaciones pendientes
    final pendingNotifications = await notificationService.getPendingNotifications();
    print('📋 Notificaciones pendientes: ${pendingNotifications.length}');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
