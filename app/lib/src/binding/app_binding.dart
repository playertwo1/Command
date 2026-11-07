import 'package:command/core/core.dart';
import '../connection/pc_connections.dart';
import '../services/signalr_service.dart';

class AppBinding extends ApplicationBindings {
  @override
  List<Bind<Object>> bindings() => [
        Bind.lazySingleton<CommandClient>((i) => CommandClient(baseUrl: '')),
        Bind.lazySingleton<SignalRService>((i) => SignalRService()),
        Bind.lazySingleton<PcConnections>(
            (i) => PcConnections(Injector.get<SignalRService>())),
      ];
}
