import 'dart:async';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/services/mdns_discovery_service.dart';
import 'package:http/http.dart' as http;

/// Serviço de resolução e ordem de fallback de conexão (D0.3).
///
/// Ordem de prioridade estrita:
/// 1. LAN mDNS descoberto recentemente com identidade/certificado validado
/// 2. LAN IP configurado no perfil
/// 3. Tailscale IP (faixa CGNAT 100.64.0.0/10 ou configurado)
/// 4. Último endereço conhecido com sucesso
///
/// Deduplica candidatos preservando a prioridade, sem repetir tentativas.
class ReconnectionFallbackService {
  final MdnsDiscoveryService _discoveryService;
  final http.Client _httpClient;

  ReconnectionFallbackService({
    MdnsDiscoveryService? discoveryService,
    http.Client? httpClient,
  })  : _discoveryService = discoveryService ?? MdnsDiscoveryService(),
        _httpClient = httpClient ?? http.Client();

  /// Identifica se um determinado IP pertence à rede Tailscale (CGNAT 100.64.0.0/10).
  static bool isTailscaleIp(String ip) {
    if (ip.isEmpty) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    if (first == 100 && second != null && second >= 64 && second <= 127) {
      return true;
    }
    return false;
  }

  /// Gera a lista deduplicada de candidatos ordenados por prioridade para [pc].
  Future<List<String>> getCandidates(SavedPc pc, {List<DiscoveredCommandDevice>? discoveredDevices}) async {
    final candidates = <String>[];

    void addCandidate(String? ip) {
      if (ip == null || ip.trim().isEmpty) return;
      final clean = ip.trim();
      if (!candidates.contains(clean)) {
        candidates.add(clean);
      }
    }

    // 1. LAN mDNS descoberto com correspondência de certificado
    final discovered = discoveredDevices ??
        await _discoveryService.discoverDevices(timeout: const Duration(milliseconds: 1500));

    for (final dev in discovered) {
      if (pc.controlCertificatePin != null &&
          dev.certPin != null &&
          pc.controlCertificatePin!.toLowerCase() == dev.certPin!.toLowerCase()) {
        addCandidate(dev.ip);
        break;
      }
    }

    // 2. LAN IP atual do perfil (se não for Tailscale)
    if (!isTailscaleIp(pc.ip)) {
      addCandidate(pc.ip);
    }

    // 3. Tailscale (se o IP atual for Tailscale ou se houver rota configurada)
    if (isTailscaleIp(pc.ip)) {
      addCandidate(pc.ip);
    }

    // 4. Fallback final: último endereço conhecido
    addCandidate(pc.ip);

    return candidates;
  }

  /// Tenta conectar nos candidatos em ordem de prioridade.
  /// Retorna o primeiro endereço que responder com sucesso, ou null se todos falharem.
  Future<String?> resolveWorkingAddress(
    SavedPc pc, {
    Duration probeTimeout = const Duration(milliseconds: 1200),
    List<DiscoveredCommandDevice>? discoveredDevices,
  }) async {
    final candidateList = await getCandidates(pc, discoveredDevices: discoveredDevices);

    for (final ip in candidateList) {
      final success = await probeAddress(ip, pc.port, apiKey: pc.apiKey, timeout: probeTimeout);
      if (success) {
        // Se o IP funcional for diferente do salvo, atualiza o PcStore se a identidade bater
        if (ip != pc.ip) {
          if (pc.controlCertificatePin != null) {
            await PcStore.updateIpIfIdentityMatches(
              pcId: pc.id,
              newIp: ip,
              certPin: pc.controlCertificatePin,
            );
          }
        }
        return ip;
      }
    }

    return null;
  }

  /// Testa rapidamente se o endpoint HTTP do PC responde na porta indicada.
  Future<bool> probeAddress(
    String ip,
    String port, {
    String? apiKey,
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    try {
      final cleanIp = ip.replaceAll(RegExp(r'^https?://'), '').replaceAll('/', '');
      final uri = Uri.parse('http://$cleanIp:$port/api/system/health');
      final request = http.Request('GET', uri);
      if (apiKey != null && apiKey.isNotEmpty) {
        request.headers['X-API-KEY'] = apiKey;
      }

      final streamedResponse = await _httpClient.send(request).timeout(timeout);
      return streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
