import 'package:droiddeck/core/core.dart';
import '../services/signalr_service.dart';

class AppBinding extends ApplicationBindings {
  @override
  List<Bind<Object>> bindings() => [
        Bind.lazySingleton<DroidDeckClient>((i) => DroidDeckClient(baseUrl: '')),
        Bind.lazySingleton<SignalRService>((i) => SignalRService()),
      ];
}
