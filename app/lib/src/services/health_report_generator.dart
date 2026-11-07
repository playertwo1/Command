import 'dart:convert';
import 'package:command/core/core.dart';
import '../connection/pc_store.dart';
import 'signalr_service.dart';

/// Dados de entrada para geração do relatório de saúde e diagnósticos (S9)
class HealthReportInput {
  final SavedPc? pc;
  final SystemStats? stats;
  final List<WindowsServiceItem> services;
  final TopProcessesData? topProcesses;
  final int? latencyMs;
  final int? jitterMs;
  final DateTime generatedAt;
  final bool sanitize;

  HealthReportInput({
    this.pc,
    this.stats,
    this.services = const [],
    this.topProcesses,
    this.latencyMs,
    this.jitterMs,
    DateTime? generatedAt,
    this.sanitize = true,
  }) : generatedAt = generatedAt ?? DateTime.now().toUtc();
}

/// Gerador de relatório técnico estruturado em Markdown e JSON com sanitização de segurança (S9)
class HealthReportGenerator {
  /// Mascara endereço IP para proteção de privacidade na rede local
  static String maskIp(String? ip) {
    if (ip == null || ip.isEmpty) return 'N/A';
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.*.***';
    }
    return '***.***.***.***';
  }

  /// Gera representação estruturada em Map pronto para exportação JSON
  static Map<String, dynamic> generateJsonMap(HealthReportInput input) {
    final pc = input.pc;
    final stats = input.stats;
    final sanitize = input.sanitize;

    final pcHost = sanitize ? maskIp(pc?.ip) : (pc?.ip ?? 'N/A');

    return {
      'version': '0.2.0',
      'generatedAt': input.generatedAt.toIso8601String(),
      'sanitized': sanitize,
      'pc': {
        'name': pc?.name ?? 'Desconhecido',
        'host': pcHost,
        'port': pc?.port ?? 'N/A',
        'latencyMs': input.latencyMs,
        if (input.jitterMs != null) 'jitterMs': input.jitterMs,
      },
      'telemetry': {
        'cpuUsagePercent': stats?.cpuUsage,
        'cpuTempC': stats?.cpuTempC,
        'ramUsagePercent': stats?.ramUsage,
        'ramTotalMb': stats?.ramTotal,
        'ramAvailableMb': stats?.ramAvailable,
        'ramUsedGb': stats?.ramUsedGb,
        'ramTotalGb': stats?.ramTotalGb,
        'gpuUsagePercent': stats?.gpuUsage,
        'gpuTempC': stats?.gpuTempC,
        'batteryPercent': stats?.batteryPercent,
        'isCharging': stats?.isCharging,
        'uptime': stats?.formattedUptime,
        'uptimeSeconds': stats?.uptimeSeconds,
        'netUpKbps': stats?.netUp,
        'netDownKbps': stats?.netDown,
      },
      'disks': stats?.disks
              .map((d) => {
                    'name': d.name,
                    'label': d.label,
                    'totalGb': d.totalGb,
                    'availableGb': d.availableGb,
                    'usagePercent': d.usagePercent,
                  })
              .toList() ??
          [],
      'services': input.services
          .map((s) => {
                'name': s.name,
                'displayName': s.displayName,
                'status': s.status,
                'isRunning': s.isRunning,
              })
          .toList(),
      'topProcesses': {
        'byMemory': input.topProcesses?.byMemory
                .map((p) => {
                      'pid': p.pid,
                      'name': p.name,
                      'memoryMb': p.memoryMb,
                      'cpuPercent': p.cpuPercent,
                    })
                .toList() ??
            [],
        'byCpu': input.topProcesses?.byCpu
                .map((p) => {
                      'pid': p.pid,
                      'name': p.name,
                      'memoryMb': p.memoryMb,
                      'cpuPercent': p.cpuPercent,
                    })
                .toList() ??
            [],
      },
    };
  }

  /// Gera string JSON formatada com indentação
  static String generateJson(HealthReportInput input) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(generateJsonMap(input));
  }

  /// Gera relatório legível formatado em Markdown
  static String generateMarkdown(HealthReportInput input) {
    final pc = input.pc;
    final stats = input.stats;
    final sanitize = input.sanitize;
    final pcHost = sanitize ? maskIp(pc?.ip) : (pc?.ip ?? 'N/A');

    final sb = StringBuffer();
    sb.writeln('# Relatório de Saúde do Sistema — Command');
    sb.writeln();
    sb.writeln('- **Gerado em:** ${input.generatedAt.toIso8601String()}');
    sb.writeln('- **Computador:** ${pc?.name ?? "Desconhecido"}');
    sb.writeln('- **Endereço:** $pcHost:${pc?.port ?? "N/A"}');
    if (input.latencyMs != null) {
      final jitterStr = input.jitterMs != null ? ' (±${input.jitterMs} ms)' : '';
      sb.writeln('- **Latência RTT:** ${input.latencyMs} ms$jitterStr');
    }
    sb.writeln('- **Modo:** ${sanitize ? "Sanitizado (Sem credenciais/IPs privados)" : "Completo"}');
    sb.writeln();

    sb.writeln('## 1. Telemetria de Hardware');
    sb.writeln();
    sb.writeln('| Métrica | Valor |');
    sb.writeln('| :--- | :--- |');
    sb.writeln('| **CPU Uso** | ${stats != null ? "${stats.cpuUsage.toStringAsFixed(1)}%" : "N/A"} |');
    sb.writeln('| **CPU Temp** | ${stats?.cpuTempC != null ? "${stats!.cpuTempC!.toStringAsFixed(1)} °C" : "N/A"} |');
    sb.writeln('| **RAM Uso** | ${stats != null ? "${stats.ramUsedPercent.toStringAsFixed(1)}% (${stats.ramUsedGb.toStringAsFixed(1)} GB / ${stats.ramTotalGb.toStringAsFixed(1)} GB)" : "N/A"} |');
    sb.writeln('| **GPU Uso** | ${stats != null ? "${stats.gpuUsage.toStringAsFixed(1)}%" : "N/A"} |');
    sb.writeln('| **GPU Temp** | ${stats?.gpuTempC != null ? "${stats!.gpuTempC!.toStringAsFixed(1)} °C" : "N/A"} |');
    if (stats != null && stats.hasBattery) {
      sb.writeln('| **Bateria** | ${stats.batteryPercent ?? "N/A"}% (${stats.isCharging == true ? "Carregando" : "Bateria"}) |');
    }
    sb.writeln('| **Uptime** | ${stats?.formattedUptime ?? "N/A"} |');
    sb.writeln();

    sb.writeln('## 2. Armazenamento & Volumes');
    sb.writeln();
    if (stats != null && stats.disks.isNotEmpty) {
      sb.writeln('| Unidade | Nome | Total (GB) | Disponível (GB) | Uso (%) |');
      sb.writeln('| :--- | :--- | :--- | :--- | :--- |');
      for (final disk in stats.disks) {
        sb.writeln('| `${disk.name}` | ${disk.label.isNotEmpty ? disk.label : "-"} | ${disk.totalGb.toStringAsFixed(1)} | ${disk.availableGb.toStringAsFixed(1)} | ${disk.usagePercent.toStringAsFixed(1)}% |');
      }
    } else {
      sb.writeln('_Nenhum disco detectado ou telemetria indisponível._');
    }
    sb.writeln();

    sb.writeln('## 3. Serviços do Windows');
    sb.writeln();
    if (input.services.isNotEmpty) {
      sb.writeln('| Serviço | Nome de Exibição | Estado |');
      sb.writeln('| :--- | :--- | :--- |');
      for (final s in input.services) {
        sb.writeln('| `${s.name}` | ${s.displayName} | **${s.status}** |');
      }
    } else {
      sb.writeln('_Nenhum serviço monitorado na allowlist._');
    }
    sb.writeln();

    sb.writeln('## 4. Top Processos em Execução');
    sb.writeln();
    final topMemory = input.topProcesses?.byMemory ?? [];
    if (topMemory.isNotEmpty) {
      sb.writeln('### Por Memória (RAM)');
      sb.writeln('| PID | Processo | Memória (MB) | CPU (%) |');
      sb.writeln('| :--- | :--- | :--- | :--- |');
      for (final p in topMemory) {
        final cpuStr = p.cpuPercent != null ? '${p.cpuPercent!.toStringAsFixed(1)}%' : '-';
        sb.writeln('| `${p.pid}` | `${p.name}` | ${p.memoryMb.toStringAsFixed(1)} | $cpuStr |');
      }
      sb.writeln();
    }

    final topCpu = input.topProcesses?.byCpu ?? [];
    if (topCpu.isNotEmpty) {
      sb.writeln('### Por Processador (CPU)');
      sb.writeln('| PID | Processo | Memória (MB) | CPU (%) |');
      sb.writeln('| :--- | :--- | :--- | :--- |');
      for (final p in topCpu) {
        final cpuStr = p.cpuPercent != null ? '${p.cpuPercent!.toStringAsFixed(1)}%' : '-';
        sb.writeln('| `${p.pid}` | `${p.name}` | ${p.memoryMb.toStringAsFixed(1)} | $cpuStr |');
      }
      sb.writeln();
    }

    sb.writeln('---');
    sb.writeln('_Relatório gerado pelo Command Mobile v0.2.0 · 100% IA-Independente_');

    return sb.toString();
  }
}
