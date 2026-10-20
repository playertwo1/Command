import 'package:droiddeck/core/core.dart';
import '../connection/pc_connections.dart';
import '../services/signalr_service.dart';

class AppBinding extends ApplicationBindings {
  @override
  List<Bind<Object>> bindings() => [
        Bind.lazySingleton<DroidDeckClient>((i) => DroidDeckClient(baseUrl: '')),
        Bind.lazySingleton<SignalRService>((i) => SignalRService()),
        Bind.lazySingleton<PcConnections>(
            (i) => PcConnections(Injector.get<SignalRService>())),
      ];
}
