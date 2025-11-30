import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  BuildContext? _context;

  // Para mostrar diálogos desde el servicio
  void setContext(BuildContext context) {
    _context = context;
  }

  Future<bool> _showPermissionDialog() async {
    if (_context == null) return false;

    final result = await showDialog<bool>(
      context: _context!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blue),
            SizedBox(width: 8),
            Text('Permisos de Notificaciones'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MiFinApp necesita permisos para enviarte notificaciones recordatorios.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Las notificaciones te ayudarán a:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Recordar registrar gastos diarios'),
              ],
            ),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Mantener tu presupuesto bajo control'),
              ],
            ),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Recibir alertas de presupuesto'),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Puedes desactivar las notificaciones en cualquier momento desde los ajustes.',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, gracias'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle),
            label: const Text('Permitir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // Inicializar timezone
    tz.initializeTimeZones();

    // Configuración para Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuración inicial
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Solicitar permisos con confirmación
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      
      if (granted == false) {
        // Mostrar diálogo de confirmación
        final userApproved = await _showPermissionDialog();
        if (userApproved) {
          final requested = await androidPlugin.requestNotificationsPermission();
          if (requested == true) {
            debugPrint('✅ Permisos de notificaciones concedidos');
          } else {
            debugPrint('❌ Permisos de notificaciones denegados');
          }
        } else {
          debugPrint('❌ Usuario denegó permisos de notificaciones');
        }
      } else {
        debugPrint('✅ Permisos de notificaciones ya concedidos');
      }
    }

    _initialized = true;
    debugPrint('✅ Servicio de notificaciones inicializado');
  }

  // Manejar clic en notificación
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notificación tocada: ${response.payload}');
    // Aquí puedes manejar la navegación cuando el usuario toca la notificación
  }

  // Programar recordatorio de gastos
  Future<void> scheduleExpenseReminder(int days) async {
    if (!_initialized) await initialize();

    // Cancelar recordatorios anteriores
    await cancelExpenseReminders();

    debugPrint('📅 Programando recordatorio de gastos cada $days días');

    // Programar notificación recurrente
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expense_reminders',
      'Recordatorios de Gastos',
      channelDescription: 'Notificaciones para registrar gastos pendientes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        'No olvides registrar tus gastos diarios para mantener tu presupuesto bajo control.',
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Programar notificación para mañana y luego repetir cada N días
    final now = tz.TZDateTime.now(tz.local);
    final tomorrow = now.add(Duration(days: 1));
    final scheduledTime = tz.TZDateTime(
      tz.local,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      10, // 10 AM
      0, // 0 minutos
      0, // 0 segundos
    );

    await _notifications.zonedSchedule(
      0, // ID
      '📊 Recordatorio de Gastos',
      '¡Hola! No olvides registrar tus gastos de hoy para mantener tu presupuesto bajo control.',
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repetir diariamente
      payload: 'expense_reminder', // Agregar payload para evitar el error
    );

    debugPrint('✅ Recordatorio programado para: $scheduledTime');
  }

  // Cancelar todos los recordatorios de gastos
  Future<void> cancelExpenseReminders() async {
    if (!_initialized) await initialize();

    await _notifications.cancel(0);
    debugPrint('🗑️ Recordatorios de gastos cancelados');
  }

  // Enviar notificación inmediata (para pruebas)
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test',
      'Test',
      channelDescription: 'Canal de prueba',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      '🧪 Notificación de Prueba',
      'Esta es una notificación de prueba para verificar que todo funciona correctamente.',
      platformDetails,
      payload: 'test_notification', // Agregar payload para evitar el error
    );

    debugPrint('🧪 Notificación de prueba enviada');
  }

  // Verificar permisos
  Future<bool> arePermissionsGranted() async {
    if (!_initialized) await initialize();

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.areNotificationsEnabled() ?? false;
  }

  // Obtener estado de las notificaciones
  Future<String> getNotificationStatus() async {
    if (!_initialized) await initialize();

    final granted = await arePermissionsGranted();
    if (granted) {
      final pending = await _notifications.pendingNotificationRequests();
      return '✅ Activas (${pending.length} pendientes)';
    } else {
      return '❌ Permisos denegados';
    }
  }
}
