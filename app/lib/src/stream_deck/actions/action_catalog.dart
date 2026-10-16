import 'package:companion/core/core.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:companion/src/stream_deck/actions/action_schema.dart';

/// Tipos de ação que o PC conectado aceita. Carregado uma vez por sessão do PC;
/// enquanto não chega (ou se o PC é antigo), vale o catálogo embutido.
class ActionCatalog {
  ActionCatalog._();
  static final instance = ActionCatalog._();

  final schemas = signal<List<ActionSchema>>(fallbackActionCatalog);
  Future<void>? _loading;

  /// Busca o catálogo no PC. Chamadas repetidas reaproveitam a primeira.
  Future<void> load({bool force = false}) {
    if (force) _loading = null;
    return _loading ??= _fetch();
  }

  Future<void> _fetch() async {
    try {
      final raw = await Injector.get<DroidDeckClient>().getActionSchema();
      final list = raw.map(ActionSchema.fromJson).where((s) => s.type.isNotEmpty).toList();
      if (list.isEmpty) return;
      schemas.value = list;

      // Estados ao vivo dos provedores (timers etc.) passam a ser ouvidos.
      final signalR = Injector.get<SignalRService>();
      final client = Injector.get<DroidDeckClient>();
      for (final s in list) {
        if (s.stateEvent == null) continue;
        signalR.listenState(s.stateEvent!);
        // O PC manda o estado ao conectar, antes de o handler existir: busca uma vez.
        if (signalR.stateOf(s.stateEvent!).isEmpty) {
          client.getActionState(s.type).then((state) {
            if (state != null) signalR.seedState(s.stateEvent!, state);
          }).catchError((_) {});
        }
      }
    } catch (_) {
      // PC sem /api/actions/schema (anterior à 1.8): fica o catálogo embutido.
      _loading = null;
    }
  }

  ActionSchema? find(String? type) {
    if (type == null) return null;
    final t = type.toLowerCase();
    for (final s in schemas.value) {
      if (s.type.toLowerCase() == t) return s;
    }
    // Apelidos antigos gravados em perfis.
    if (t == 'launchapp') return find('launch_app');
    return null;
  }
}
