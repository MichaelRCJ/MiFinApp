import 'package:flutter/material.dart';

import '../../services/service_locator.dart';
import 'notification_time_config_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _days = TextEditingController(text: '2');
  bool _notificationsEnabled = false;
  String _notificationStatus = 'Verificando...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Establecer contexto para el servicio de notificaciones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notificationService.setContext(context);
        _initializeNotifications();
      }
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      await notificationService.initialize();
      await _updateNotificationStatus();
    } catch (e) {
      debugPrint('❌ Error inicializando notificaciones: $e');
      setState(() {
        _notificationStatus = 'Error al inicializar';
      });
    }
  }

  Future<void> _updateNotificationStatus() async {
    final status = await notificationService.getNotificationStatus();
    final granted = await notificationService.arePermissionsGranted();
    setState(() {
      _notificationStatus = status;
      _notificationsEnabled = granted;
    });
  }

  Future<void> _load() async {
    final d = await settingsStore.loadReminderDays();
    if (mounted) setState(() => _days.text = d.toString());
  }

  Future<void> _save() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final v = int.tryParse(_days.text.trim());
      if (v == null || v <= 0 || v > 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Por favor, ingresa un número entre 1 y 3'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!_notificationsEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Por favor, activa las notificaciones primero'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Navegar a la pantalla de configuración de horas
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NotificationTimeConfigScreen(
            numberOfNotifications: v,
          ),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('✅ $v notificación${v > 1 ? 'es' : ''} configurada${v > 1 ? 's' : ''}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error guardando ajustes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar ajustes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermissions() async {
  try {
    await notificationService.initialize();
    await _updateNotificationStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 8),
              Text(_notificationsEnabled ? '✅ Permisos concedidos' : '❌ Permisos denegados'),
            ],
          ),
          backgroundColor: _notificationsEnabled ? Colors.green : Colors.orange,
        ),
      );
    }
  } catch (e) {
    debugPrint('❌ Error solicitando permisos: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Future<void> _testNotification() async {
    if (!_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Habilita las notificaciones primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await notificationService.showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 Notificación de prueba enviada'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error enviando notificación de prueba: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text('Recordatorios para registrar gastos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Recibe recordatorios automáticos para registrar tus gastos. Te notificaremos periódicamente para ayudarte a mantener tu presupuesto bajo control.'),
                    const SizedBox(height: 16),
                    
                    // Estado de notificaciones
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _notificationsEnabled ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _notificationsEnabled ? Colors.green[200]! : Colors.orange[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _notificationsEnabled ? Icons.check_circle : Icons.warning,
                            color: _notificationsEnabled ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Estado: $_notificationStatus',
                              style: TextStyle(
                                color: _notificationsEnabled ? Colors.green[700] : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _updateNotificationStatus,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Actualizar estado',
                          ),
                          if (!_notificationsEnabled)
                            IconButton(
                              onPressed: _requestPermissions,
                              icon: const Icon(Icons.notifications_active),
                              tooltip: 'Solicitar permisos',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Configuración de frecuencia
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: Text('¿Cuántas notificaciones al día quieres?', style: TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _days,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                  ),
                                  hintText: '1',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Elige cuántas notificaciones quieres recibir cada día:',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('• Presiona 1 = una notificación al día (elige la hora)', style: TextStyle(color: Colors.blue[700], fontSize: 11)),
                              Text('• Presiona 2 = dos notificaciones al día (elige las horas)', style: TextStyle(color: Colors.blue[700], fontSize: 11)),
                              Text('• Presiona 3 = tres notificaciones al día (elige las horas)', style: TextStyle(color: Colors.blue[700], fontSize: 11)),
                              const SizedBox(height: 4),
                              Text('⏰ Después de guardar, podrás configurar las horas exactas', style: TextStyle(color: Colors.blue[600], fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _save,
                            icon: _isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                            label: Text(_isLoading ? 'Guardando...' : 'Guardar configuración'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _testNotification,
                          icon: const Icon(Icons.notifications),
                          label: const Text('Probar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Las notificaciones se enviarán todos los días a las 10:00 AM',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text('Interfaz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Personaliza el color principal de la aplicación según tu preferencia.'),
                    const SizedBox(height: 16),
                    
                    // Colores predefinidos
                    const Text('Colores predefinidos:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColors.map((c) => _ColorChoice(
                        color: c, 
                        selected: themeController.seedColor.value == c.value, 
                        onTap: () async {
                          await themeController.setSeed(c);
                          setState(() {}); // Actualizar para reflejar el cambio
                        }
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Selector personalizado
                    Row(
                      children: [
                        const Text('Personalizado:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await showDialog<Color?>(
                                context: context,
                                builder: (ctx) => _SimpleColorPickerDialog(initial: themeController.seedColor),
                              );
                              if (picked != null) {
                                await themeController.setSeed(picked);
                                setState(() {}); // Actualizar para reflejar el cambio
                              }
                            },
                            icon: const Icon(Icons.color_lens),
                            label: const Text('Elegir color'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El color seleccionado se aplicará en toda la aplicación, incluyendo botones, barras y elementos interactivos.',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const SizedBox(height: 0),
      ),
    );
  }
}

final List<Color> _presetColors = [
  const Color(0xFF6B35C3), // purple (default)
  const Color(0xFF0D9488), // teal
  const Color(0xFF2563EB), // blue
  const Color(0xFFF97316), // orange
  const Color(0xFF16A34A), // green
  const Color(0xFFE11D48), // rose
];

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorChoice({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.black : Colors.white, width: selected ? 2 : 1),
        ),
      ),
    );
  }
}

class _SimpleColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _SimpleColorPickerDialog({required this.initial});

  @override
  State<_SimpleColorPickerDialog> createState() => _SimpleColorPickerDialogState();
}

class _SimpleColorPickerDialogState extends State<_SimpleColorPickerDialog> {
  double _h = 270; // hue
  double _s = .6;  // saturation
  double _l = .5;  // lightness

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initial);
    _h = hsl.hue;
    _s = hsl.saturation;
    _l = hsl.lightness;
  }

  Color get _color => HSLColor.fromAHSL(1, _h, _s, _l).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [const Text('Matiz'), Expanded(child: Slider(min: 0, max: 360, value: _h, onChanged: (v) => setState(() => _h = v)))]),
          Row(children: [const Text('Saturación'), Expanded(child: Slider(min: 0, max: 1, value: _s, onChanged: (v) => setState(() => _s = v)))]),
          Row(children: [const Text('Luz'), Expanded(child: Slider(min: 0, max: 1, value: _l, onChanged: (v) => setState(() => _l = v)))]),
          const SizedBox(height: 12),
          Container(width: double.infinity, height: 36, decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(6))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_color), child: const Text('Usar color')),
      ],
    );
  }
}


