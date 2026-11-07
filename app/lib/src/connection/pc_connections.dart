import 'package:command/src/connection/pc_store.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Conexões simultâneas com PCs (Command v1.5 M0).
///
/// O PC em foco usa o [SignalRService] global, que o resto do app já lê. Um
/// segundo PC pode ficar conectado em paralelo com a própria instância, de
/// modo que cada conexão tem ciclo de vida, estado e métricas independentes.
class PcConnections {
  /// D-v1.5-01: limite fixo de 2 PCs conectados ao mesmo tempo.
  static const maxConnections = 2;
  static const _secondaryKey = 'pc_secondary';

  PcConnections(this.primary, {SignalRService Function()? factory})
    : _factory = factory ?? SignalRService.new;

  final SignalRService primary;
  final SignalRService Function() _factory;

  final _secondaryState = signal<({SavedPc pc, SignalRService service})?>(null);
  bool _backgrounded = false;

  SavedPc? get secondaryPc => _secondaryState.value?.pc;
  SignalRService? get secondary => _secondaryState.value?.service;

  /// Conexão de um PC, ou null se ele não está conectado.
  SignalRService? forPc(String pcId) {
    if (pcId == PcStore.currentId) return primary;
    if (pcId == secondaryPc?.id) return secondary;
    return null;
  }

  /// Conecta [pc] como segundo PC. Substitui o segundo PC anterior, se houver,
  /// pois o limite é fixo: nunca existem 3 conexões.
  Future<void> connectSecondary(SavedPc pc) async {
    if (pc.id == PcStore.currentId) {
      throw ArgumentError('O PC em foco já está conectado.');
    }
    if (pc.id == secondaryPc?.id) return;
    await disconnectSecondary();
    final service = _factory();
    _secondaryState.value = (pc: pc, service: service);
    await (await SharedPreferences.getInstance()).setString(
      _secondaryKey,
      pc.id,
    );
    if (!_backgrounded) await service.init(pc.baseUrl, apiKey: pc.apiKey);
  }

  Future<void> disconnectSecondary() async {
    final old = secondary;
    _secondaryState.value = null;
    // Vazio distingue desconexão explícita de uma instalação sem preferência.
    await (await SharedPreferences.getInstance()).setString(_secondaryKey, '');
    await old?.dispose();
  }

  /// Reabre o paralelo salvo. Na migração, dois perfis já pareados dispensam
  /// uma opção manual adicional; uma desconexão explícita continua respeitada.
  Future<void> restore() async {
    final id = (await SharedPreferences.getInstance()).getString(_secondaryKey);
    if (id == '') return;
    final pcs = await PcStore.load();
    if (id == null || id == PcStore.currentId) {
      if (pcs.length == maxConnections) {
        for (final pc in pcs) {
          if (pc.id != PcStore.currentId) return connectSecondary(pc);
        }
      }
      return;
    }
    for (final pc in pcs) {
      if (pc.id == id) return connectSecondary(pc);
    }
    await disconnectSecondary(); // PC removido desde a última abertura.
  }

  /// Após trocar o foco, reabre o PC anterior em paralelo, inclusive quando
  /// ainda não havia um segundo hub. Preserva um paralelo diferente do novo foco.
  Future<void> onFocusChanged(SavedPc? previous) async {
    if (previous == null || previous.id == PcStore.currentId) return;
    if (secondaryPc != null && secondaryPc?.id != PcStore.currentId) return;
    if (secondaryPc == null) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_secondaryKey) == '') return;
    }
    await connectSecondary(previous);
  }

  /// Chamar quando um PC é removido ou revogado: só a conexão dele cai.
  Future<void> onPcRemoved(String pcId) async {
    if (pcId == secondaryPc?.id) await disconnectSecondary();
  }

  /// Libera os hubs enquanto o app está em segundo plano; sem polling em background.
  Future<void> suspend() async {
    if (_backgrounded) return;
    _backgrounded = true;
    await primary.dispose();
    await secondary?.dispose();
  }

  /// Reconecta apenas os dois PCs ativos quando o app volta ao primeiro plano.
  Future<void> resume() async {
    if (!_backgrounded) return;
    _backgrounded = false;
    final current = await PcStore.current();
    if (current != null) {
      await primary.init(current.baseUrl, apiKey: current.apiKey);
    }
    final pc = secondaryPc;
    final service = secondary;
    if (pc != null && service != null) {
      await service.init(pc.baseUrl, apiKey: pc.apiKey);
    }
  }
}
