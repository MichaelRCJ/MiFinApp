import 'package:flutter/material.dart';

import '../../services/service_locator.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _days = TextEditingController(text: '2');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await settingsStore.loadReminderDays();
    if (mounted) setState(() => _days.text = d.toString());
  }

  Future<void> _save() async {
    final v = int.tryParse(_days.text.trim());
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Días inválidos')));
      return;
    }
    await settingsStore.save(reminderDays: v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recordatorios para registrar gastos', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Frecuencia (días)')),
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: _days,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(onPressed: _save, child: const Text('Guardar')),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Interfaz', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Color principal de la aplicación'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColors.map((c) => _ColorChoice(color: c, selected: themeController.seedColor.value == c.value, onTap: () => themeController.setSeed(c))).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Personalizado:'),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final picked = await showDialog<Color?>(
                              context: context,
                              builder: (ctx) => _SimpleColorPickerDialog(initial: themeController.seedColor),
                            );
                            if (picked != null) {
                              await themeController.setSeed(picked);
                            }
                          },
                          child: const Text('Elegir color'),
                        ),
                      ],
                    )
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


