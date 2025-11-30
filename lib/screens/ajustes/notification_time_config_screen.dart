import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../services/service_locator.dart';

class NotificationTimeConfigScreen extends StatefulWidget {
  final int numberOfNotifications;

  const NotificationTimeConfigScreen({
    super.key,
    required this.numberOfNotifications,
  });

  @override
  State<NotificationTimeConfigScreen> createState() => _NotificationTimeConfigScreenState();
}

class _NotificationTimeConfigScreenState extends State<NotificationTimeConfigScreen> {
  final List<TimeOfDay> _notificationTimes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTimes();
  }

  Future<void> _loadSavedTimes() async {
    try {
      final savedTimes = await settingsStore.loadNotificationTimes();
      
      _notificationTimes.clear();
      
      // Si hay tiempos guardados y coinciden con el número de notificaciones
      if (savedTimes.isNotEmpty && savedTimes.length >= widget.numberOfNotifications) {
        // Cargar los tiempos guardados
        for (int i = 0; i < widget.numberOfNotifications; i++) {
          final timeParts = savedTimes[i].split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          _notificationTimes.add(TimeOfDay(hour: hour, minute: minute));
        }
        debugPrint('✅ Cargadas ${widget.numberOfNotifications} horas guardadas: $savedTimes');
      } else {
        // Si no hay tiempos guardados, usar horas por defecto
        _initializeTimes();
        debugPrint('📅 Usando horas por defecto para ${widget.numberOfNotifications} notificaciones');
      }
      
      setState(() {});
    } catch (e) {
      debugPrint('❌ Error cargando horas guardadas: $e');
      // Si hay error, usar horas por defecto
      _initializeTimes();
      setState(() {});
    }
  }

  void _initializeTimes() {
    // Inicializar con horas por defecto
    _notificationTimes.clear();
    for (int i = 0; i < widget.numberOfNotifications; i++) {
      // Distribuir las horas durante el día
      final hour = 9 + (i * 4); // 9 AM, 1 PM, 5 PM, etc.
      _notificationTimes.add(TimeOfDay(hour: hour % 24, minute: 0));
    }
    debugPrint('📅 Inicializadas horas por defecto: ${_notificationTimes.map((t) => "${t.hour}:${t.minute.toString().padLeft(2, '0')}").toList()}');
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTimes[index],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _notificationTimes[index]) {
      setState(() {
        _notificationTimes[index] = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _testScheduledNotification() async {
    try {
      await notificationService.scheduleTestNotificationInSeconds(10);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.schedule, color: Colors.white),
                SizedBox(width: 8),
                Text('⏰ Notificación programada para 10 segundos'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('❌ Error: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    try {
      await notificationService.showTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('🧪 Notificación de prueba enviada'),
              ],
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('❌ Error: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAndSchedule() async {
    setState(() => _isLoading = true);

    try {
      // Convertir tiempos a strings
      final timeStrings = _notificationTimes.map((time) {
        final hour = time.hour.toString().padLeft(2, '0');
        final minute = time.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }).toList();

      // Guardar configuración
      await settingsStore.save(
        reminderDays: widget.numberOfNotifications,
        notificationTimes: timeStrings,
      );

      // Programar notificaciones
      await notificationService.scheduleMultipleExpenseReminders(timeStrings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('✅ ${widget.numberOfNotifications} notificaciones configuradas'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('❌ Error: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurar ${widget.numberOfNotifications} notificación${widget.numberOfNotifications > 1 ? 'es' : ''}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selecciona la hora para cada notificación diaria',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            Expanded(
              child: ListView.builder(
                itemCount: widget.numberOfNotifications,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        'Notificación ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_notificationTimes[index]),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _selectTime(index),
                            icon: Icon(
                              Icons.access_time,
                              color: Theme.of(context).primaryColor,
                            ),
                            tooltip: 'Cambiar hora',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botón de prueba programada
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _testScheduledNotification,
                icon: const Icon(Icons.schedule),
                label: const Text('Probar notificación en 10 segundos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Botón de prueba inmediata
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _testNotification,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Probar notificación ahora'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveAndSchedule,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Guardando...' : 'Guardar y activar notificaciones'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
