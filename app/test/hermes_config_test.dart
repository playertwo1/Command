import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/hermes/hermes_config_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHermesClient extends DroidDeckClient {
  HermesConfigData currentConfig;
  int updateCalls = 0;
  bool shouldThrow = false;

  FakeHermesClient({
    HermesConfigData? config,
  })  : currentConfig = config ??
            const HermesConfigData(
              enabled: false,
              endpointUrl: 'https://generativelanguage.googleapis.com',
              modelName: 'gemini-3.8-flash',
              hasApiKey: false,
            ),
        super(baseUrl: 'http://localhost:4787');

  @override
  Future<HermesConfigData> getHermesStatus() async {
    return currentConfig;
  }

  @override
  Future<HermesConfigData> updateHermesConfig({
    required bool enabled,
    String? endpointUrl,
    String? modelName,
    String? apiKey,
  }) async {
    updateCalls++;
    if (shouldThrow) {
      throw Exception('Falha ao comunicar com o PC');
    }
    currentConfig = HermesConfigData(
      enabled: enabled,
      endpointUrl: endpointUrl ?? currentConfig.endpointUrl,
      modelName: modelName ?? currentConfig.modelName,
      hasApiKey: apiKey != null && apiKey.isNotEmpty ? true : currentConfig.hasApiKey,
    );
    return currentConfig;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hermes Models', () {
    test('HermesConfigData: serialização e parsing', () {
      const config = HermesConfigData(
        enabled: true,
        endpointUrl: 'http://127.0.0.1:11434',
        modelName: 'hermes-model',
        hasApiKey: true,
      );

      final json = config.toJson();
      final fromJson = HermesConfigData.fromJson(json);

      expect(fromJson.enabled, isTrue);
      expect(fromJson.endpointUrl, 'http://127.0.0.1:11434');
      expect(fromJson.modelName, 'hermes-model');
      expect(fromJson.hasApiKey, isTrue);

      final pascalJson = {
        'Enabled': false,
        'EndpointUrl': 'https://api.openai.com',
        'ModelName': 'gpt-4o',
        'HasApiKey': false,
      };
      final fromPascal = HermesConfigData.fromJson(pascalJson);
      expect(fromPascal.enabled, isFalse);
      expect(fromPascal.endpointUrl, 'https://api.openai.com');
      expect(fromPascal.modelName, 'gpt-4o');
      expect(fromPascal.hasApiKey, isFalse);
    });

    test('HermesSuggestedAction: parsing', () {
      final json = {
        'actionType': 'app.launch',
        'targetId': 'obsidian',
        'title': 'Abrir Obsidian',
        'reason': 'Anotações rápidas',
        'requiresConfirmation': true,
      };

      final action = HermesSuggestedAction.fromJson(json);
      expect(action.actionType, 'app.launch');
      expect(action.targetId, 'obsidian');
      expect(action.title, 'Abrir Obsidian');
      expect(action.reason, 'Anotações rápidas');
      expect(action.requiresConfirmation, isTrue);
    });

    test('HermesAnalyzeResult: parsing completo', () {
      final json = {
        'success': true,
        'reply': 'O sistema apresenta alto uso de memória.',
        'sanitizedContextSummary': 'CPU 20%, RAM 85%',
        'suggestedActions': [
          {
            'actionType': 'app.kill',
            'targetId': 'test_notepad',
            'title': 'Encerrar Bloco de Notas',
            'reason': 'Consumo elevado',
          }
        ],
      };

      final res = HermesAnalyzeResult.fromJson(json);
      expect(res.success, isTrue);
      expect(res.reply, contains('alto uso de memória'));
      expect(res.sanitizedContextSummary, 'CPU 20%, RAM 85%');
      expect(res.suggestedActions.length, 1);
      expect(res.suggestedActions.first.title, 'Encerrar Bloco de Notas');
    });
  });

  group('HermesConfigSheet Widget', () {
    testWidgets('renderiza campos e aviso de privacidade', (tester) async {
      final client = FakeHermesClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HermesConfigSheet(
              client: client,
              initialConfig: client.currentConfig,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Configuração Hermes IA'), findsOneWidget);
      expect(find.text('Ativar Módulo Hermes IA (Opcional)'), findsOneWidget);
      expect(find.text('Endpoint / Gateway URL'), findsOneWidget);
      expect(find.text('Modelo (ex: gemini-3.8-flash)'), findsOneWidget);
      expect(find.text('Chave de API (opcional, protegida no PC)'), findsOneWidget);
      expect(
        find.text('Dados são sanitizados antes do envio. O controle do PC funciona 100% sem IA.'),
        findsOneWidget,
      );
      expect(find.text('Salvar Configuração'), findsOneWidget);
    });

    testWidgets('salva nova configuração e invoca onSaved callback', (tester) async {
      final client = FakeHermesClient();
      HermesConfigData? savedData;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HermesConfigSheet(
              client: client,
              initialConfig: client.currentConfig,
              onSaved: (cfg) => savedData = cfg,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ativa o Switch
      await tester.tap(find.text('Ativar Módulo Hermes IA (Opcional)'));
      await tester.pumpAndSettle();

      // Altera endpoint
      final endpointFinder = find.widgetWithText(TextField, 'Endpoint / Gateway URL');
      await tester.enterText(endpointFinder, 'http://custom-host:8080');
      await tester.pumpAndSettle();

      // Clica em Salvar Configuração
      await tester.tap(find.text('Salvar Configuração'));
      await tester.pumpAndSettle();

      expect(client.updateCalls, 1);
      expect(savedData, isNotNull);
      expect(savedData!.enabled, isTrue);
      expect(savedData!.endpointUrl, 'http://custom-host:8080');
    });

    testWidgets('exibe erro quando updateHermesConfig falha', (tester) async {
      final client = FakeHermesClient()..shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HermesConfigSheet(
              client: client,
              initialConfig: client.currentConfig,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar Configuração'));
      await tester.pumpAndSettle();

      expect(client.updateCalls, 1);
      expect(find.textContaining('Falha ao salvar configuração'), findsOneWidget);
    });
  });
}
