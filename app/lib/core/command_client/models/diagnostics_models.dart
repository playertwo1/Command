/// Modelos de dados para diagnósticos de sistema (Serviços e Top Processos - S3/S5)
class WindowsServiceItem {
  final String name;
  final String displayName;
  final String status;
  final bool isRunning;

  const WindowsServiceItem({
    required this.name,
    required this.displayName,
    required this.status,
    required this.isRunning,
  });

  factory WindowsServiceItem.fromJson(Map<String, dynamic> json) {
    return WindowsServiceItem(
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['DisplayName'] ?? '').toString(),
      status: (json['status'] ?? json['Status'] ?? 'Unknown').toString(),
      isRunning: json['isRunning'] == true || json['IsRunning'] == true,
    );
  }
}

class TopProcessItem {
  final int pid;
  final String name;
  final double memoryMb;
  final double? cpuPercent;

  const TopProcessItem({
    required this.pid,
    required this.name,
    required this.memoryMb,
    this.cpuPercent,
  });

  factory TopProcessItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0;
      return 0;
    }

    double? parseNullableDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return TopProcessItem(
      pid: parseInt(json['pid'] ?? json['Pid']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      memoryMb: parseDouble(json['memoryMB'] ?? json['MemoryMB'] ?? json['memoryMb']),
      cpuPercent: parseNullableDouble(json['cpuPercent'] ?? json['CpuPercent']),
    );
  }
}

class TopProcessesData {
  final List<TopProcessItem> byMemory;
  final List<TopProcessItem> byCpu;

  const TopProcessesData({
    this.byMemory = const [],
    this.byCpu = const [],
  });

  factory TopProcessesData.fromJson(Map<String, dynamic> json) {
    List<TopProcessItem> parseList(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(TopProcessItem.fromJson)
            .toList();
      }
      return const [];
    }

    return TopProcessesData(
      byMemory: parseList(json['byMemory'] ?? json['ByMemory']),
      byCpu: parseList(json['byCpu'] ?? json['ByCpu']),
    );
  }
}

/// Resultado do ping de diagnóstico de rede e latência (S8)
class PingResult {
  final String hostName;
  final String status;
  final DateTime serverTimeUtc;
  final int latencyMs;

  const PingResult({
    required this.hostName,
    required this.status,
    required this.serverTimeUtc,
    required this.latencyMs,
  });

  factory PingResult.fromJson(Map<String, dynamic> json, int latencyMs) {
    return PingResult(
      hostName: (json['hostName'] ?? json['HostName'] ?? '').toString(),
      status: (json['status'] ?? json['Status'] ?? 'ok').toString(),
      serverTimeUtc: DateTime.tryParse(
            (json['serverTimeUtc'] ?? json['ServerTimeUtc'] ?? '').toString(),
          ) ??
          DateTime.now().toUtc(),
      latencyMs: latencyMs,
    );
  }
}

