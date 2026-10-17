import 'package:flutter/material.dart';
import '../../core/i18n/i18n.dart';
import '../services/health_alert_service.dart';

/// Tela de Configuração dos Limiares de Alerta de Recursos (Command v0.2 - S6)
class HealthAlertSettingsPage extends StatefulWidget {
  final HealthAlertService? service;

  const HealthAlertSettingsPage({super.key, this.service});

  @override
  State<HealthAlertSettingsPage> createState() => _HealthAlertSettingsPageState();
}

class _HealthAlertSettingsPageState extends State<HealthAlertSettingsPage> {
  late HealthAlertService _service;
  late double _cpu;
  late double _ram;
  late double _temp;
  late double _disk;
  late int _battery;
  late int _cooldown;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HealthAlertService.instance;
    _cpu = _service.thresholds.cpuPercent;
    _ram = _service.thresholds.ramPercent;
    _temp = _service.thresholds.tempC;
    _disk = _service.thresholds.diskPercent;
    _battery = _service.thresholds.batteryLowPercent;
    _cooldown = _service.thresholds.cooldownSeconds;
  }

  void _restoreDefaults() {
    final def = HealthThresholds.defaults();
    setState(() {
      _cpu = def.cpuPercent;
      _ram = def.ramPercent;
      _temp = def.tempC;
      _disk = def.diskPercent;
      _battery = def.batteryLowPercent;
      _cooldown = def.cooldownSeconds;
    });
  }

  Future<void> _save() async {
    final newThresholds = HealthThresholds(
      cpuPercent: _cpu,
      ramPercent: _ram,
      tempC: _temp,
      diskPercent: _disk,
      batteryLowPercent: _battery,
      cooldownSeconds: _cooldown,
    );
    await _service.saveThresholds(newThresholds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Limiares de alerta salvos com sucesso!')),
          backgroundColor: const Color(0xFF34D5A0),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Limiares de Alerta')),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: tr('Restaurar padrões'),
            onPressed: _restoreDefaults,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr('Configure os limites para disparo de alertas visuais no painel móvel.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // CPU
          _buildSliderSection(
            title: 'Uso de CPU',
            valueText: '${_cpu.toStringAsFixed(0)}%',
            value: _cpu,
            min: 50,
            max: 100,
            divisions: 50,
            icon: Icons.memory,
            activeColor: const Color(0xFFA78BFA),
            onChanged: (v) => setState(() => _cpu = v),
          ),
          const Divider(),

          // RAM
          _buildSliderSection(
            title: 'Uso de Memória RAM',
            valueText: '${_ram.toStringAsFixed(0)}%',
            value: _ram,
            min: 50,
            max: 100,
            divisions: 50,
            icon: Icons.storage,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (v) => setState(() => _ram = v),
          ),
          const Divider(),

          // Temperatura
          _buildSliderSection(
            title: 'Temperatura Máxima (CPU/GPU)',
            valueText: '${_temp.toStringAsFixed(0)}°C',
            value: _temp,
            min: 60,
            max: 105,
            divisions: 45,
            icon: Icons.thermostat,
            activeColor: const Color(0xFFF59E0B),
            onChanged: (v) => setState(() => _temp = v),
          ),
          const Divider(),

          // Disco
          _buildSliderSection(
            title: 'Uso de Armazenamento',
            valueText: '${_disk.toStringAsFixed(0)}%',
            value: _disk,
            min: 70,
            max: 99,
            divisions: 29,
            icon: Icons.disc_full_outlined,
            activeColor: const Color(0xFFEF4444),
            onChanged: (v) => setState(() => _disk = v),
          ),
          const Divider(),

          // Bateria
          _buildSliderSection(
            title: 'Bateria Restante Baixa',
            valueText: '$_battery%',
            value: _battery.toDouble(),
            min: 5,
            max: 30,
            divisions: 25,
            icon: Icons.battery_alert,
            activeColor: const Color(0xFFF87171),
            onChanged: (v) => setState(() => _battery = v.toInt()),
          ),
          const Divider(),

          // Cooldown
          _buildSliderSection(
            title: 'Tempo de Cooldown',
            valueText: '$_cooldown s',
            value: _cooldown.toDouble(),
            min: 15,
            max: 300,
            divisions: 19,
            icon: Icons.timer_outlined,
            activeColor: theme.colorScheme.primary,
            onChanged: (v) => setState(() => _cooldown = v.toInt()),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(tr('Salvar Limiares')),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection({
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required IconData icon,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: activeColor),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            Text(
              valueText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: activeColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
