import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  // Obtener la zona horaria del dispositivo
  Future<String?> _getDeviceTimezone() async {
    if (Platform.isAndroid) {
      // Para Android, intentar obtener la zona horaria del sistema
      try {
        // Usar la zona horaria actual del dispositivo
        final now = DateTime.now();
        final timezoneName = now.timeZoneName;
        
        // Mapeo común de zonas horarias de América Latina
        final timezoneMap = {
          'ART': 'America/Argentina/Buenos_Aires',
          'BOT': 'America/La_Paz',
          'CLT': 'America/Santiago',
          'COT': 'America/Bogota',
          'ECT': 'America/Guayaquil',
          'EST': 'America/New_York',
          'CST': 'America/Chicago',
          'MST': 'America/Denver',
          'PST': 'America/Los_Angeles',
          'GMT': 'Europe/London',
          'CET': 'Europe/Paris',
          'EET': 'Europe/Athens',
          'UTC': 'UTC', // Agregado para UTC
          'BRT': 'America/Sao_Paulo',
          'UYT': 'America/Montevideo',
          'PYT': 'America/Asuncion',
          'VET': 'America/Caracas',
          'PET': 'America/Lima',
          'GFT': 'America/Cayenne',
          'SRT': 'America/Paramaribo',
          'AST': 'America/Halifax',
          'NST': 'America/St_Johns',
          'AKST': 'America/Anchorage',
          'HST': 'Pacific/Honolulu',
          'MEX': 'America/Mexico_City', // General para México
          'CST6CDT': 'America/Chicago',
          'MST7MDT': 'America/Denver',
          'PST8PDT': 'America/Los_Angeles',
        };
        
        // Intentar detectar por offset si el nombre no coincide
        final offset = now.timeZoneOffset;
        final hours = offset.inHours;
        debugPrint('📍 Offset detectado: $hours horas');
        
        // Zonas horarias comunes por offset
        String? timezoneByOffset;
        if (hours == -5) {
          timezoneByOffset = 'America/Bogota'; // Colombia, Ecuador, Perú
        } else if (hours == -6) {
          timezoneByOffset = 'America/Mexico_City'; // México, Centroamérica
        } else if (hours == -3) {
          timezoneByOffset = 'America/Argentina/Buenos_Aires'; // Argentina, Brasil
        } else if (hours == -4) {
          timezoneByOffset = 'America/Caracas'; // Venezuela, Bolivia
        }
        
        return timezoneMap[timezoneName] ?? timezoneByOffset ?? 'America/Mexico_City';
      } catch (e) {
        debugPrint('⚠️ Error obteniendo timezone de Android: $e');
      }
    } else if (Platform.isIOS) {
      // Para iOS, usar la zona horaria actual
      return 'America/Mexico_City'; // Asumimos México como fallback principal
    }
    
    return 'America/Mexico_City'; // Fallback general
  }

  // Para mostrar diálogos desde el servicio
  void setContext(BuildContext context) {
    _context = context;
  }

  // Diálogo para solicitar permisos
  Future<bool> _showPermissionDialog() async {
    if (_context == null) return false;
    
    return await showDialog<bool>(
      context: _context!,
      builder: (context) => AlertDialog(
        title: const Text('Permisos de Notificaciones'),
        content: const Text(
          'Para recibir recordatorios de gastos, necesitamos tu permiso para enviar notificaciones. ¿Te gustaría habilitarlas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // Inicializar timezone
    tz.initializeTimeZones();
    
    // OBTENER AUTOMÁTICAMENTE LA ZONA HORARIA DEL DISPOSITIVO
    try {
      // Obtener la zona horaria del sistema del dispositivo
      final deviceTimezone = await _getDeviceTimezone();
      if (deviceTimezone != null) {
        tz.setLocalLocation(tz.getLocation(deviceTimezone));
        debugPrint('✅ Zona horaria automática detectada: $deviceTimezone');
      } else {
        // Fallback: detectar por el offset del dispositivo
        final now = DateTime.now();
        final offset = now.timeZoneOffset;
        final hours = offset.inHours;
        
        debugPrint('📍 Offset del dispositivo: $hours horas');
        debugPrint('📍 Zona horaria del sistema: ${now.timeZoneName}');
        
        // Buscar zona horaria por offset
        for (final location in tz.timeZoneDatabase.locations.keys) {
          final tzLocation = tz.getLocation(location);
          final tzNow = tz.TZDateTime.now(tzLocation);
          final tzOffset = tzNow.timeZoneOffset;
          
          if (tzOffset.inHours == hours && tzOffset.inMinutes % 60 == offset.inMinutes % 60) {
            tz.setLocalLocation(tzLocation);
            debugPrint('✅ Zona horaria por offset: $location (UTC$hours:${offset.inMinutes % 60})');
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error detectando zona horaria automática: $e');
      debugPrint('⚠️ Usando UTC como fallback');
    }

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
      
      // Solicitar permiso de alarmas exactas para Android 12+
      final exactAlarmGranted = await androidPlugin.canScheduleExactNotifications();
      if (exactAlarmGranted == false) {
        debugPrint('⚠️ Solicitando permiso de alarmas exactas...');
        await androidPlugin.requestExactAlarmsPermission();
        final nowGranted = await androidPlugin.canScheduleExactNotifications();
        if (nowGranted == true) {
          debugPrint('✅ Permiso de alarmas exactas concedido');
        } else {
          debugPrint('❌ Permiso de alarmas exactas denegado - usando alarmas aproximadas');
        }
      } else {
        debugPrint('✅ Permiso de alarmas exactas ya concedido');
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

  // Programar múltiples notificaciones diarias (versión mejorada)
  Future<void> scheduleMultipleExpenseReminders(List<String> times) async {
    if (!_initialized) await initialize();

    debugPrint('🔧 Iniciando programación de notificaciones...');
    debugPrint('📅 Times recibidos: $times');

    // Verificar si estamos en web
    if (kIsWeb) {
      debugPrint('⚠️ Las notificaciones programadas no funcionan en navegador web');
      debugPrint('⚠️ Solo notificaciones inmediatas están disponibles en web');
      
      // En web, mostrar un diálogo informando al usuario
      if (_context != null) {
        showDialog(
          context: _context!,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Limitación del Navegador'),
            content: const Text(
              'Las notificaciones programadas para hora específica no funcionan en el navegador. '
              'Para usar esta función, instala la app en un dispositivo móvil (Android/iOS).\n\n'
              'Las notificaciones inmediatas (pruebas) sí funcionarán si concedes permisos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Cancelar notificaciones existentes
    await cancelExpenseReminders();

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    
    if (androidPlugin != null) {
      final canUseExactAlarms = await androidPlugin.canScheduleExactNotifications();
      debugPrint('🔔 ¿Puede usar alarmas exactas? $canUseExactAlarms');
      
      if (canUseExactAlarms != true) {
        debugPrint('⚠️ Usando alarmas aproximadas (permiso exact alarm no concedido)');
        scheduleMode = AndroidScheduleMode.inexact;
        
        // Intentar solicitar permiso de alarmas exactas
        debugPrint('🔔 Solicitando permiso de alarmas exactas...');
        await androidPlugin.requestExactAlarmsPermission();
        final nowGranted = await androidPlugin.canScheduleExactNotifications();
        if (nowGranted == true) {
          debugPrint('✅ Permiso de alarmas exactas concedido después de solicitar');
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        } else {
          debugPrint('❌ Permiso de alarmas exactas denegado - usando alarmas aproximadas');
        }
      }
    }

    // Programar cada notificación
    for (int i = 0; i < times.length; i++) {
      final timeParts = times[i].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      debugPrint('⏰ Programando notificación $i: $hour:$minute');
      debugPrint('📅 Hora seleccionada (24h): $hour:$minute');

      // Obtener hora actual del dispositivo con timezone local
      final now = tz.TZDateTime.now(tz.local);
      debugPrint('📍 Hora actual del dispositivo: $now');
      debugPrint('📍 Timezone actual: ${tz.local}');
      debugPrint('📍 Hora actual (formato 24h): ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      
      // Crear tiempo objetivo para hoy usando timezone local
      tz.TZDateTime targetTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
        0,
      );
      
      debugPrint('📅 Target time inicial: $targetTime');
      debugPrint('📅 ¿Target time < current time? ${targetTime.isBefore(now)}');
      debugPrint('📅 Diferencia en minutos: ${targetTime.difference(now).inMinutes}');
      
      // Si la hora ya pasó, programar para mañana
      if (targetTime.isBefore(now)) {
        // Pero primero verificar si realmente es necesario programar para mañana
        // o si podemos programar para hoy en unos minutos más
        final minutesUntilTarget = targetTime.difference(now).inMinutes;
        
        if (minutesUntilTarget > -5) {
          // Si la hora pasó hace menos de 5 minutos, programar para mañana a la misma hora
          targetTime = targetTime.add(Duration(days: 1));
          debugPrint('📅 Hora ya pasó, programando para mañana: $targetTime');
          debugPrint('📅 Nueva diferencia: ${targetTime.difference(now).inMinutes} minutos');
        } else {
          // Si la hora pasó hace mucho tiempo, programar para mañana
          targetTime = targetTime.add(Duration(days: 1));
          debugPrint('📅 Hora ya pasó hace mucho tiempo, programando para mañana: $targetTime');
          debugPrint('📅 Nueva diferencia: ${targetTime.difference(now).inMinutes} minutos');
        }
      } else {
        debugPrint('📅 Programando para hoy: $targetTime');
        debugPrint('📅 Minutos restantes: ${targetTime.difference(now).inMinutes}');
      }

      debugPrint('📅 Tiempo programado final: $targetTime');
      debugPrint('📅 ScheduleMode: $scheduleMode');

      try {
        debugPrint('🔔 Intentando programar notificación con ID: $i');
        debugPrint('🔔 Tiempo objetivo: $targetTime');
        debugPrint('🔔 ScheduleMode: $scheduleMode');
        debugPrint('🔔 DateTimeComponents: ${DateTimeComponents.time}');
        
        await _notifications.zonedSchedule(
          i, // ID único para cada notificación
          '📊 Recordatorio de Gastos',
          '¡Hola! No olvides registrar tus gastos para mantener tu presupuesto bajo control.',
          targetTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expense_reminder_channel',
              'Recordatorios de Gastos',
              channelDescription: 'Notificaciones para registrar gastos',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time, // Repetir diariamente
          payload: 'expense_reminder_$i',
        );

        debugPrint('✅ Recordatorio $i programado exitosamente para: $targetTime (${times[i]})');
        debugPrint('📊 Tiempo restante: ${targetTime.difference(now).inMinutes} minutos');
        
        // Verificar inmediatamente si quedó programada
        final pendingAfter = await _notifications.pendingNotificationRequests();
        debugPrint('📋 Notificaciones pendientes después de programar $i: ${pendingAfter.length}');
        final found = pendingAfter.where((n) => n.id == i);
        debugPrint('📋 Notificación $i encontrada en pendientes: ${found.isNotEmpty}');
        if (found.isNotEmpty) {
          debugPrint('📋 Detalles: ${found.first.title}');
        }
      } catch (e) {
        debugPrint('❌ Error programando notificación $i: $e');
        debugPrint('❌ Stack trace: ${StackTrace.current}');
      }
    }

    // Verificar notificaciones pendientes
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    debugPrint('📋 Notificaciones pendientes: ${pendingNotifications.length}');
    for (final notification in pendingNotifications) {
      debugPrint('📋 - ID: ${notification.id}, Título: ${notification.title}');
    }

    debugPrint('✅ ${times.length} recordatorios programados para las horas: ${times.join(', ')}');
  }

  // Mantener compatibilidad con el método antiguo
  Future<void> scheduleExpenseReminder(int days) async {
    // Para compatibilidad, crear una notificación por defecto a las 10 AM
    await scheduleMultipleExpenseReminders(['10:00']);
  }

  // Cancelar todos los recordatorios de gastos
  Future<void> cancelExpenseReminders() async {
    if (!_initialized) await initialize();

    // Cancelar múltiples notificaciones (IDs 0, 1, 2, etc.)
    for (int i = 0; i < 10; i++) { // Asumimos máximo 10 notificaciones
      await _notifications.cancel(i);
    }
    debugPrint('🗑️ Todos los recordatorios de gastos cancelados');
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
      icon: '@mipmap/ic_launcher',
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

    await _notifications.show(
      999,
      '🧪 Notificación de Prueba',
      'Esta es una notificación de prueba para verificar que todo funciona correctamente.',
      platformDetails,
      payload: 'test_notification', // Agregar payload para evitar el error
    );

    debugPrint('🧪 Notificación de prueba enviada');
  }

  // Programar notificación para X segundos en el futuro (para pruebas)
  Future<void> scheduleTestNotificationInSeconds(int seconds) async {
    if (!_initialized) await initialize();

    debugPrint('⏰ Programando notificación de prueba para $seconds segundos en el futuro...');

    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(Duration(seconds: seconds));

    try {
      await _notifications.zonedSchedule(
        998, // ID único para prueba
        '⏰ Recordatorio de Prueba',
        'Esta es una notificación programada para $seconds segundos después de guardar.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Pruebas',
            channelDescription: 'Canal para pruebas de programación',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'test_scheduled',
      );

      debugPrint('✅ Notificación de prueba programada para: $scheduledTime');
      
      // Verificar que esté programada
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('📋 Notificaciones pendientes después de programar: ${pending.length}');
      for (final notification in pending) {
        debugPrint('📋 - ID: ${notification.id}, Título: ${notification.title}');
      }
    } catch (e) {
      debugPrint('❌ Error programando notificación de prueba: $e');
    }
  }

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

final notificationService = NotificationService();
