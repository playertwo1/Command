import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signalr_service.dart';

enum AlertSeverity { warning, critical }

class HealthAlert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;

  HealthAlert({
    required this.id,
    required this.title,
    required this.message,
    this.severity = AlertSeverity.warning,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class HealthThresholds {
  double cpuPercent;
  double ramPercent;
  double tempC;
  double diskPercent;
  int batteryLowPercent;
  int cooldownSeconds;

  HealthThresholds({
    this.cpuPercent = 90.0,
    this.ramPercent = 90.0,
    this.tempC = 85.0,
    this.diskPercent = 95.0,
    this.batteryLowPercent = 15,
    this.cooldownSeconds = 60,
  });

  factory HealthThresholds.defaults() => HealthThresholds();
}

/// Motor de Alertas de Saúde e Cooldown de Recursos (Command v0.2 - S6).
class HealthAlertService extends ChangeNotifier {
  static final HealthAlertService instance = HealthAlertService();

  HealthThresholds thresholds = HealthThresholds.defaults();
  final List<HealthAlert> _activeAlerts = [];
  final Map<String, DateTime> _cooldowns = {};

  List<HealthAlert> get activeAlerts => List.unmodifiable(_activeAlerts);

  Future<void> loadThresholds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      thresholds.cpuPercent = prefs.getDouble('alert_cpu_threshold') ?? 90.0;
      thresholds.ramPercent = prefs.getDouble('alert_ram_threshold') ?? 90.0;
      thresholds.tempC = prefs.getDouble('alert_temp_threshold') ?? 85.0;
      thresholds.diskPercent = prefs.getDouble('alert_disk_threshold') ?? 95.0;
      thresholds.batteryLowPercent = prefs.getInt('alert_battery_low_threshold') ?? 15;
      thresholds.cooldownSeconds = prefs.getInt('alert_cooldown_seconds') ?? 60;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveThresholds(HealthThresholds newThresholds) async {
    thresholds = newThresholds;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('alert_cpu_threshold', thresholds.cpuPercent);
      await prefs.setDouble('alert_ram_threshold', thresholds.ramPercent);
      await prefs.setDouble('alert_temp_threshold', thresholds.tempC);
      await prefs.setDouble('alert_disk_threshold', thresholds.diskPercent);
      await prefs.setInt('alert_battery_low_threshold', thresholds.batteryLowPercent);
      await prefs.setInt('alert_cooldown_seconds', thresholds.cooldownSeconds);
    } catch (_) {}
    notifyListeners();
  }

  /// Avalia as métricas recebidas contra os limiares configurados.
  void evaluate(SystemStats stats) {
    final now = DateTime.now();
    bool changed = false;

    bool isCoolingDown(String id) {
      final last = _cooldowns[id];
      if (last == null) return false;
      return now.difference(last).inSeconds < thresholds.cooldownSeconds;
    }

    void trigger(String id, String title, String message, AlertSeverity severity) {
      if (isCoolingDown(id)) return;
      _cooldowns[id] = now;
      _activeAlerts.removeWhere((a) => a.id == id);
      _activeAlerts.add(HealthAlert(id: id, title: title, message: message, severity: severity));
      changed = true;
    }

    void clear(String id) {
      final initialCount = _activeAlerts.length;
      _activeAlerts.removeWhere((a) => a.id == id);
      if (_activeAlerts.length != initialCount) changed = true;
    }

    // 1. CPU
    if (stats.cpuUsage >= thresholds.cpuPercent) {
      trigger(
        'cpu',
        'CPU Crítica',
        'Uso de CPU atingiu ${stats.cpuUsage.toStringAsFixed(1)}% (limiar: ${thresholds.cpuPercent.toStringAsFixed(0)}%)',
        AlertSeverity.critical,
      );
    } else {
      clear('cpu');
    }

    // 2. RAM
    if (stats.ramUsedPercent >= thresholds.ramPercent) {
      trigger(
        'ram',
        'RAM Elevada',
        'Uso de memória RAM atingiu ${stats.ramUsedPercent.toStringAsFixed(1)}% (limiar: ${thresholds.ramPercent.toStringAsFixed(0)}%)',
        AlertSeverity.warning,
      );
    } else {
      clear('ram');
    }

    // 3. Temperatura
    final temps = <double>[
      if (stats.cpuTempC != null) stats.cpuTempC!,
      if (stats.gpuTempC != null) stats.gpuTempC!,
    ];
    final double maxTemp = temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : 0.0;
    if (maxTemp >= thresholds.tempC) {
      trigger(
        'temp',
        'Superaquecimento',
        'Temperatura de hardware atingiu ${maxTemp.toStringAsFixed(0)}°C (limiar: ${thresholds.tempC.toStringAsFixed(0)}°C)',
        AlertSeverity.critical,
      );
    } else {
      clear('temp');
    }

    // 4. Disco
    double maxDisk = stats.diskUsage;
    for (final d in stats.disks) {
      if (d.usagePercent > maxDisk) maxDisk = d.usagePercent;
    }
    if (maxDisk >= thresholds.diskPercent) {
      trigger(
        'disk',
        'Disco Quase Cheio',
        'Armazenamento atingiu ${maxDisk.toStringAsFixed(1)}% (limiar: ${thresholds.diskPercent.toStringAsFixed(0)}%)',
        AlertSeverity.warning,
      );
    } else {
      clear('disk');
    }

    // 5. Bateria do PC
    if (stats.hasBattery && stats.isCharging != true && stats.batteryPercent != null) {
      if (stats.batteryPercent! <= thresholds.batteryLowPercent) {
        trigger(
          'battery',
          'Bateria Baixa no PC',
          'Bateria restante do PC está em ${stats.batteryPercent}% (limiar: ${thresholds.batteryLowPercent}%)',
          AlertSeverity.warning,
        );
      } else {
        clear('battery');
      }
    } else {
      clear('battery');
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Silencia/dispensa um alerta ativo e inicia janela de cooldown.
  void dismissAlert(String id) {
    _cooldowns[id] = DateTime.now();
    final initialCount = _activeAlerts.length;
    _activeAlerts.removeWhere((a) => a.id == id);
    if (_activeAlerts.length != initialCount) {
      notifyListeners();
    }
  }

  /// Limpa todos os alertas e histórico de cooldown.
  void clearAll() {
    _activeAlerts.clear();
    _cooldowns.clear();
    notifyListeners();
  }
}
