import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:command/src/connection/constants.dart';
import 'package:command/src/connection/pc_store.dart';
import 'package:command/src/home/status_page.dart';
import 'package:command/src/home/pc_dashboard_card.dart';
import 'package:command/src/services/signalr_service.dart';

class FakeSignalRService extends SignalRService {
  @override
  Future<void> updateUrl(String baseUrl, {String? apiKey}) async {
    currentUrl.value = baseUrl;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PcStore.currentId = null;
  });

  group('PcProfile & PcStore Unit Tests (Fase S7)', () {
    test('PcProfile serializa e deserializa lastConnectedAt e expõe host', () {
      final now = DateTime.now();
      final profile = PcProfile(
        id: 'pc-1',
        name: 'Workstation Desktop',
        ip: '192.168.1.50',
        port: '4787',
        apiKey: 'secret-key-123',
        lastConnectedAt: now,
      );

      expect(profile.host, '192.168.1.50');
      expect(profile.baseUrl, 'http://192.168.1.50:4787');

      final json = profile.toJson();
      expect(json['id'], 'pc-1');
      expect(json['name'], 'Workstation Desktop');
      expect(json['ip'], '192.168.1.50');
      expect(json['apiKey'], 'secret-key-123');
      expect(json['lastConnectedAt'], now.toIso8601String());

      final restored = PcProfile.fromJson(json);
      expect(restored.id, 'pc-1');
      expect(restored.name, 'Workstation Desktop');
      expect(restored.host, '192.168.1.50');
      expect(restored.lastConnectedAt?.toIso8601String(), now.toIso8601String());
    });

    test('migra automaticamente conexão legada para lista de perfis com lastConnectedAt', () async {
      SharedPreferences.setMockInitialValues({
        Constants.ipAddrKey: '192.168.0.100',
        Constants.portKey: '4787',
        Constants.apiKeyKey: 'legacy-api-key',
      });

      final list = await PcStore.load();
      expect(list.length, 1);
      final pc = list.first;
      expect(pc.ip, '192.168.0.100');
      expect(pc.port, '4787');
      expect(pc.apiKey, 'legacy-api-key');
      expect(pc.lastConnectedAt, isNotNull);
      expect(PcStore.currentId, pc.id);
    });

    test('upsert adiciona novos PCs e select atualiza lastConnectedAt', () async {
      final pc1 = await PcStore.upsert(
        ip: '192.168.1.10',
        port: '4787',
        name: 'PC Escritório',
        apiKey: 'key-1',
      );
      final pc2 = await PcStore.upsert(
        ip: '192.168.1.20',
        port: '4787',
        name: 'Notebook Gamer',
        apiKey: 'key-2',
      );

      var list = await PcStore.load();
      expect(list.length, 2);
      expect(PcStore.currentId, pc2.id);

      // Alternar para o PC 1
      await PcStore.select(pc1);
      expect(PcStore.currentId, pc1.id);

      list = await PcStore.load();
      final updatedPc1 = list.firstWhere((p) => p.id == pc1.id);
      expect(updatedPc1.lastConnectedAt, isNotNull);
    });

    test('rename e remove gerenciam perfis corretamente', () async {
      final pc1 = await PcStore.upsert(
        ip: '192.168.1.10',
        port: '4787',
        name: 'PC Antigo',
      );
      final pc2 = await PcStore.upsert(
        ip: '192.168.1.20',
        port: '4787',
        name: 'PC Novo',
      );

      await PcStore.rename(pc1.id, 'PC Principal');
      var list = await PcStore.load();
      expect(list.firstWhere((p) => p.id == pc1.id).name, 'PC Principal');

      // Remove pc2 (atualmente selecionado); deve selecionar automaticamente pc1
      await PcStore.remove(pc2.id);
      list = await PcStore.load();
      expect(list.length, 1);
      expect(list.first.id, pc1.id);
      expect(PcStore.currentId, pc1.id);
    });
  });

  group('Multi-PC Switcher Widget Tests (StatusPage)', () {
    testWidgets('exibe botão de troca e modal com múltiplos PCs', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Inicializa 2 PCs pareados
      SharedPreferences.setMockInitialValues({
        'pcs': '[{"id":"pc1","name":"PC Escritório","ip":"192.168.1.10","port":"4787","apiKey":"k1"},{"id":"pc2","name":"PC Sala","ip":"192.168.1.20","port":"4787","apiKey":"k2"}]',
        'pc_current': 'pc1',
      });

      final signalR = FakeSignalRService();

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Botão de alternar PC ativo deve estar visível no AppBar
      final swapButton = find.byTooltip('Alternar PC ativo');
      expect(swapButton, findsOneWidget);

      // Card do PC exibe o nome do PC ativo
      expect(find.text('PC Escritório'), findsNWidgets(2)); // Painel combinado + PC ativo

      // Toca no botão de troca para abrir o modal
      await tester.tap(swapButton);
      await tester.pumpAndSettle();

      // Modal aberto com o título e a lista de computadores
      expect(find.text('Computadores Pareados'), findsOneWidget);
      expect(find.text('PC Escritório'), findsNWidgets(3)); // Painel combinado + PC ativo + Modal
      expect(find.text('PC Sala'), findsNWidgets(2)); // Painel combinado + Modal
      expect(find.text('Gerenciar PCs e Novo Pareamento'), findsOneWidget);

      // Toca no segundo PC para alternar
      await tester.tap(find.text('PC Sala').last);
      await tester.pumpAndSettle();

      // Verifica que o PC ativo foi alternado
      expect(PcStore.currentId, 'pc2');
      expect(find.text('PC Sala'), findsNWidgets(2)); // Painel combinado + PC ativo
      expect(find.descendant(of: find.byType(PcDashboardCard), matching: find.text('PC-alvo: PC Sala')), findsOneWidget);

      // Tocar no cartão troca também a telemetria e o perfil ativo.
      await tester.tap(find.byKey(const ValueKey('pc-target-pc1')));
      await tester.pumpAndSettle();
      expect(PcStore.currentId, 'pc1');
      expect(find.descendant(of: find.byType(PcDashboardCard), matching: find.text('PC-alvo: PC Escritório')), findsOneWidget);
      expect(find.text('PC Escritório'), findsNWidgets(2));
      expect(signalR.currentUrl.value, 'http://192.168.1.10:4787');
    });
  });
}
