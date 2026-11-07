import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:command/src/connection/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um PC pareado com este celular (Perfil de PC - Command v0.2 Fase S7).
class SavedPc {
  final String id;
  final String name;
  final String ip;
  final String port;
  final String? apiKey;
  final String? controlDeviceId;
  final String? controlCertificatePin;
  final String? controlCredential;
  final DateTime? lastConnectedAt;

  const SavedPc({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    this.apiKey,
    this.controlDeviceId,
    this.controlCertificatePin,
    this.controlCredential,
    this.lastConnectedAt,
  });

  String get host => ip;
  String get baseUrl => 'http://$ip:$port';

  SavedPc copyWith({
    String? name,
    String? ip,
    String? port,
    String? apiKey,
    String? controlDeviceId,
    String? controlCertificatePin,
    String? controlCredential,
    DateTime? lastConnectedAt,
  }) => SavedPc(
    id: id,
    name: name ?? this.name,
    ip: ip ?? this.ip,
    port: port ?? this.port,
    apiKey: apiKey ?? this.apiKey,
    controlDeviceId: controlDeviceId ?? this.controlDeviceId,
    controlCertificatePin: controlCertificatePin ?? this.controlCertificatePin,
    controlCredential: controlCredential ?? this.controlCredential,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'port': port,
    'apiKey': apiKey,
    if (controlDeviceId != null) 'controlDeviceId': controlDeviceId,
    if (controlCertificatePin != null)
      'controlCertificatePin': controlCertificatePin,
    if (lastConnectedAt != null)
      'lastConnectedAt': lastConnectedAt!.toIso8601String(),
  };

  factory SavedPc.fromJson(Map<String, dynamic> j) => SavedPc(
    id: '${j['id']}',
    name: '${j['name'] ?? 'PC'}',
    ip: '${j['ip']}',
    port: '${j['port'] ?? Constants.defaultPort}',
    apiKey: j['apiKey'] as String?,
    controlDeviceId: j['controlDeviceId'] as String?,
    controlCertificatePin: j['controlCertificatePin'] as String?,
    lastConnectedAt: j['lastConnectedAt'] != null
        ? DateTime.tryParse('${j['lastConnectedAt']}')
        : null,
  );
}

/// Alias oficial de Perfil de PC (Command v0.2 - S7).
typedef PcProfile = SavedPc;

/// PCs pareados e qual está em uso. O PC atual também fica nas chaves antigas
/// (IP, porta, chave), que o resto do app lê; o cache do deck é separado por PC.
class PcStore {
  static const _listKey = 'pcs';
  static const _currentKey = 'pc_current';
  static const _secureStorage = FlutterSecureStorage();
  static String _controlCredentialKey(String pcId) =>
      'command_control_credential_$pcId';

  /// Id do PC em uso, carregado na abertura do app ([load]).
  static String? currentId;

  static Future<List<SavedPc>> load() async {
    final prefs = await SharedPreferences.getInstance();
    var list = _decode(prefs.getString(_listKey));
    if (list.isEmpty) {
      // Versões antigas guardavam um PC só, direto nas chaves de conexão.
      final ip = prefs.getString(Constants.ipAddrKey);
      if (ip != null && ip.isNotEmpty) {
        final pc = SavedPc(
          id: _newId(),
          name: 'PC',
          ip: ip.contains(':') ? ip.substring(0, ip.indexOf(':')) : ip,
          port: prefs.getString(Constants.portKey) ?? Constants.defaultPort,
          apiKey: prefs.getString(Constants.apiKeyKey),
          lastConnectedAt: DateTime.now(),
        );
        list = [pc];
        await prefs.setString(_listKey, _encode(list));
        await prefs.setString(_currentKey, pc.id);
        // O deck guardado passa a ser o deste PC.
        for (final key in ['deck_cache', 'deck_last_profile']) {
          final v = prefs.getString(key);
          if (v != null) await prefs.setString(scoped(key, pc.id), v);
        }
      }
    }
    currentId =
        prefs.getString(_currentKey) ??
        (list.isNotEmpty ? list.first.id : null);
    return [
      for (final pc in list)
        pc.copyWith(
          controlCredential: await _secureStorage.read(
            key: _controlCredentialKey(pc.id),
          ),
        ),
    ];
  }

  static Future<SavedPc?> current() async {
    final list = await load();
    for (final pc in list) {
      if (pc.id == currentId) return pc;
    }
    return list.isEmpty ? null : list.first;
  }

  /// Guarda um PC (o mesmo IP e porta atualiza o existente) e o deixa em uso.
  static Future<SavedPc> upsert({
    required String ip,
    required String port,
    String? apiKey,
    String? name,
  }) async {
    final list = await load();
    final index = list.indexWhere((p) => p.ip == ip && p.port == port);
    final SavedPc pc;
    if (index >= 0) {
      pc = SavedPc(
        id: list[index].id,
        name: name ?? list[index].name,
        ip: ip,
        port: port,
        apiKey: apiKey ?? list[index].apiKey,
        controlDeviceId: list[index].controlDeviceId,
        controlCertificatePin: list[index].controlCertificatePin,
        controlCredential: list[index].controlCredential,
        lastConnectedAt: DateTime.now(),
      );
      list[index] = pc;
    } else {
      pc = SavedPc(
        id: _newId(),
        name: name ?? ip,
        ip: ip,
        port: port,
        apiKey: apiKey,
        lastConnectedAt: DateTime.now(),
      );
      list.add(pc);
    }
    await _save(list);
    await select(pc);
    return pc;
  }

  static Future<void> rename(String id, String name) async {
    final list = await load();
    await _save([
      for (final p in list) p.id == id ? p.copyWith(name: name) : p,
    ]);
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (await load()).where((p) => p.id != id).toList();
    final credentialKey = _controlCredentialKey(id);
    final credential = await _secureStorage.read(key: credentialKey);
    await _secureStorage.delete(key: credentialKey);
    try {
      await _save(list);
    } catch (_) {
      if (credential != null) {
        await _secureStorage.write(key: credentialKey, value: credential);
      }
      rethrow;
    }
    await prefs.remove(scoped('deck_cache', id));
    await prefs.remove(scoped('deck_last_profile', id));
    if (currentId == id) {
      if (list.isNotEmpty) {
        await select(list.first);
      } else {
        currentId = null;
        await prefs.remove(_currentKey);
        await prefs.remove(Constants.ipAddrKey);
        await prefs.remove(Constants.apiKeyKey);
      }
    }
  }

  /// Stores the control credential only in Android/system secure storage.
  static Future<bool> setControlCredential({
    required String pcId,
    required String deviceId,
    required String certificatePin,
    required String credential,
  }) async {
    final list = await load();
    final index = list.indexWhere((pc) => pc.id == pcId);
    if (index < 0) return false;

    final key = _controlCredentialKey(pcId);
    final previous = await _secureStorage.read(key: key);
    await _secureStorage.write(key: key, value: credential);
    list[index] = list[index].copyWith(
      controlDeviceId: deviceId,
      controlCertificatePin: certificatePin,
      controlCredential: credential,
    );
    try {
      await _save(list);
    } catch (_) {
      if (previous == null) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: previous);
      }
      rethrow;
    }
    return true;
  }

  /// Atualiza o endereço IP de um PC pareado quando o DHCP altera o IP na rede local (D0.2).
  /// Exige validação estrita de identidade: o [certPin] do anúncio deve coincidir com
  /// [controlCertificatePin] do perfil salvo; se o perfil não tiver pin (pareamento antigo)
  /// ou o pin divergir, a alteração é sumariamente rejeitada para impedir sequestro de perfil.
  static Future<bool> updateIpIfIdentityMatches({
    required String pcId,
    required String newIp,
    required String? certPin,
  }) async {
    if (newIp.isEmpty || certPin == null || certPin.isEmpty) return false;

    final list = await load();
    final index = list.indexWhere((pc) => pc.id == pcId);
    if (index < 0) return false;

    final targetPc = list[index];

    // Validação estrita: exige correspondência criptográfica da identidade
    if (targetPc.controlCertificatePin == null ||
        targetPc.controlCertificatePin!.toLowerCase() != certPin.toLowerCase()) {
      return false;
    }

    if (targetPc.ip == newIp) return true; // já está atualizado

    list[index] = targetPc.copyWith(ip: newIp);
    await _save(list);

    final prefs = await SharedPreferences.getInstance();
    if (currentId == pcId) {
      await prefs.setString(Constants.ipAddrKey, newIp);
    }

    return true;
  }

  /// Passa a usar este PC: grava nas chaves de conexão que o app lê ao abrir.
  static Future<void> select(SavedPc pc) async {
    final prefs = await SharedPreferences.getInstance();
    currentId = pc.id;
    await prefs.setString(_currentKey, pc.id);
    await prefs.setString(Constants.ipAddrKey, pc.ip);
    await prefs.setString(Constants.portKey, pc.port);
    if (pc.apiKey != null) {
      await prefs.setString(Constants.apiKeyKey, pc.apiKey!);
    } else {
      await prefs.remove(Constants.apiKeyKey);
    }

    final rawList = _decode(prefs.getString(_listKey));
    final now = DateTime.now();
    final updated = [
      for (final p in rawList)
        p.id == pc.id ? p.copyWith(lastConnectedAt: now) : p,
    ];
    await _save(updated);
  }

  /// Chave de preferência separada por PC (cache do deck, último perfil).
  static String scoped(String key, [String? pcId]) {
    final id = pcId ?? currentId;
    return id == null ? key : '${key}_$id';
  }

  static Future<void> _save(List<SavedPc> list) async =>
      (await SharedPreferences.getInstance()).setString(
        _listKey,
        _encode(list),
      );

  static String _encode(List<SavedPc> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  static List<SavedPc> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SavedPc.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int _seq = 0;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';
}
