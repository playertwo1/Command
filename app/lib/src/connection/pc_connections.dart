import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  SavedPc? _secondaryPc;
  SignalRService? _secondary;
  bool _backgrounded = false;

  SavedPc? get secondaryPc => _secondaryPc;
  SignalRService? get secondary => _secondary;

  /// Conexão de um PC, ou null se ele não está conectado.
  SignalRService? forPc(String pcId) {
    if (pcId == PcStore.currentId) return primary;
    if (pcId == _secondaryPc?.id) return _secondary;
    return null;
  }

  /// Conecta [pc] como segundo PC. Substitui o segundo PC anterior, se houver,
  /// pois o limite é fixo: nunca existem 3 conexões.
  Future<void> connectSecondary(SavedPc pc) async {
    if (pc.id == PcStore.currentId) {
      throw ArgumentError('O PC em foco já está conectado.');
    }
    if (pc.id == _secondaryPc?.id) return;
    await disconnectSecondary();
    final service = _factory();
    _secondaryPc = pc;
    _secondary = service;
    await (await SharedPreferences.getInstance()).setString(
      _secondaryKey,
      pc.id,
    );
    if (!_backgrounded) await service.init(pc.baseUrl, apiKey: pc.apiKey);
  }

  Future<void> disconnectSecondary() async {
    final old = _secondary;
    _secondary = null;
    _secondaryPc = null;
    await (await SharedPreferences.getInstance()).remove(_secondaryKey);
    await old?.dispose();
  }

  /// Reabre o segundo PC salvo (na abertura do app).
  Future<void> restore() async {
    final id = (await SharedPreferences.getInstance()).getString(_secondaryKey);
    if (id == null || id == PcStore.currentId) return;
    for (final pc in await PcStore.load()) {
      if (pc.id == id) return connectSecondary(pc);
    }
    await disconnectSecondary(); // PC removido desde a última abertura.
  }

  /// Chamar depois de o PC em foco mudar de [previous] para o atual: se o novo
  /// foco era o segundo PC, os dois trocam de papel, e nada é desconectado.
  Future<void> onFocusChanged(SavedPc? previous) async {
    if (_secondaryPc?.id != PcStore.currentId) return;
    await disconnectSecondary();
    if (previous != null && previous.id != PcStore.currentId) {
      await connectSecondary(previous);
    }
  }

  /// Chamar quando um PC é removido ou revogado: só a conexão dele cai.
  Future<void> onPcRemoved(String pcId) async {
    if (pcId == _secondaryPc?.id) await disconnectSecondary();
  }

  /// Libera os hubs enquanto o app está em segundo plano; sem polling em background.
  Future<void> suspend() async {
    if (_backgrounded) return;
    _backgrounded = true;
    await primary.dispose();
    await _secondary?.dispose();
  }

  /// Reconecta apenas os dois PCs ativos quando o app volta ao primeiro plano.
  Future<void> resume() async {
    if (!_backgrounded) return;
    _backgrounded = false;
    final current = await PcStore.current();
    if (current != null) {
      await primary.init(current.baseUrl, apiKey: current.apiKey);
    }
    final secondary = _secondaryPc;
    if (secondary != null && _secondary != null) {
      await _secondary!.init(secondary.baseUrl, apiKey: secondary.apiKey);
    }
  }
}
