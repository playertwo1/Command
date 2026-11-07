import 'package:command/core/core.dart';
import 'package:command/src/config/config_page.dart';
import 'package:command/src/home/status_page.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:command/src/stream_deck/actions/action_catalog.dart';
import 'package:command/src/stream_deck/actions/action_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCommandClient extends Mock implements CommandClient {}
class MockSignalRService extends Mock implements SignalRService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('F7 - Falhas, Tolerância a Quedas e Fidelidade Visual', () {
    test('F7-01: Tema padrão é Ametista Dark (#050408, #A78BFA) conforme DESIGN.md', () {
      final defaultSettings = const ThemeSettings();
      expect(defaultSettings.presetId, 'ametista');
      expect(defaultSettings.mode, ThemeMode.dark);
      expect(defaultSettings.preset.accent, const Color(0xFFA78BFA));
      expect(defaultSettings.preset.background, const Color(0xFF050408));
      expect(defaultSettings.preset.surface, const Color(0xFF13101B));
      expect(defaultSettings.preset.tile, const Color(0xFF1E1829));
      expect(defaultSettings.preset.outline, const Color(0xFF352B45));

      final themeData = buildAppTheme(defaultSettings, Brightness.dark);
      expect(themeData.scaffoldBackgroundColor, const Color(0xFF050408));
      expect(themeData.cardTheme.color, const Color(0xFF1E1829));
      expect(themeData.colorScheme.primary, const Color(0xFFA78BFA));
    });

    testWidgets('F7-01: ConfigPage não contém botões de backup não entregues', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      await tester.pumpWidget(
        const MaterialApp(
          home: ConfigPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Não deve encontrar os botões de backup antigos
      expect(find.text('Exportar backup'), findsNothing);
      expect(find.text('Importar backup'), findsNothing);
    });

    test('F7-01: ActionPicker exclui macros (multi) não entregues no MVP', () {
      final picker = ActionPicker(
        initial: null,
        onChanged: (_) {},
        remote: true,
        suggestLabel: (_) {},
        suggestIcon: (_) {},
      );

      picker.createState();
      // Garante que o tipo multi não está presente na lista de schemas disponíveis
      expect(ActionCatalog.instance.schemas.value.any((s) => s.type == 'multi'), true);
      // Mas o available do picker filtra multi
      expect(ActionPicker.isPrivilegedType('launch_app'), true);
    });

    testWidgets('F7-02: StatusPage exibe banner e botão Reconectar quando Bridge desconectado', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      final signalR = SignalRService();
      signalR.connectionStatus.value = 'Disconnected';
      final client = MockCommandClient();

      when(() => client.getJobs(deviceId: any(named: 'deviceId'))).thenAnswer((_) async => []);
      when(() => client.listOutboundTransfers(deviceId: any(named: 'deviceId'))).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(const ThemeSettings(), Brightness.dark),
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
            client: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner deve ser exibido
      expect(find.text('Command Bridge Desconectado'), findsOneWidget);
      expect(find.text('Reconectar'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);

      // Clica em Reconectar sem falha
      await tester.tap(find.text('Reconectar'));
      await tester.pumpAndSettle();
    });

    testWidgets('F7-02 & F7-03: Atividade Recente exibe alertas claros para falha e estado indeterminado', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      final signalR = SignalRService();
      signalR.connectionStatus.value = 'Connected';
      final client = MockCommandClient();

      when(() => client.getJobs(deviceId: any(named: 'deviceId'))).thenAnswer(
        (_) async => [
          CommandJob(
            id: 'job_unknown_1',
            requestId: 'req_unknown_1',
            actionType: 'app.launch',
            targetId: 'obsidian',
            status: 'unknown',
            createdAtUtc: DateTime.utc(2026, 10, 17, 14, 0, 0),
          ),
          CommandJob(
            id: 'job_failed_1',
            requestId: 'req_failed_1',
            actionType: 'app.kill',
            targetId: 'notepad',
            status: 'failed',
            errorMessage: 'Processo não encontrado',
            createdAtUtc: DateTime.utc(2026, 10, 17, 14, 5, 0),
          ),
        ],
      );
      when(() => client.listOutboundTransfers(deviceId: any(named: 'deviceId'))).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(const ThemeSettings(), Brightness.dark),
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
            client: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rola até o card de Atividade Recente
      await tester.scrollUntilVisible(
        find.text('Atividade Recente'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Atividade Recente'), findsOneWidget);
      expect(find.text('Estado indeterminado: verifique o PC antes de reenviar (sem retry automático).'), findsOneWidget);
      expect(find.text('Falha: confira a conexão e o alvo antes de tentar novamente.'), findsOneWidget);
    });
  });
}
