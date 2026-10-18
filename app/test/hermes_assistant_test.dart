import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/hermes/hermes_assistant_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAssistantClient extends DroidDeckClient {
  int analyzeCalls = 0;
  String? lastPrompt;
  bool? lastIncludeTelemetry;
  bool? lastIncludeTopProcesses;

  HermesAnalyzeResult analyzeResponse = const HermesAnalyzeResult(
    success: true,
    reply: 'Identifiquei alto consumo de memória causado pelo Bloco de Notas.',
    sanitizedContextSummary: 'CPU 12%, RAM 91%',
    suggestedActions: [
      HermesSuggestedAction(
        actionType: 'app.kill',
        targetId: 'test_notepad',
        title: 'Encerrar Bloco de Notas',
        reason: 'Liberar 450 MB de RAM',
        requiresConfirmation: true,
      ),
    ],
  );

  FakeAssistantClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<HermesAnalyzeResult> analyzeWithHermes({
    required String prompt,
    bool includeTelemetry = true,
    bool includeTopProcesses = true,
    String? screenshotId,
    String? deviceId,
  }) async {
    analyzeCalls++;
    lastPrompt = prompt;
    lastIncludeTelemetry = includeTelemetry;
    lastIncludeTopProcesses = includeTopProcesses;
    return analyzeResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HermesAssistantPage renderiza banner, chips de diagnóstico e envia prompt', (tester) async {
    final client = FakeAssistantClient();

    await tester.pumpWidget(
      MaterialApp(
        home: HermesAssistantPage(client: client),
      ),
    );
    await tester.pumpAndSettle();

    // Banner de consentimento e chips
    expect(
      find.text('Consentimento ativo: apenas métricas sanitizadas (sem IPs/caminhos privados) são enviadas.'),
      findsOneWidget,
    );
    expect(find.text('Incluir Telemetria'), findsOneWidget);
    expect(find.text('Incluir Top Processos'), findsOneWidget);
    expect(find.text('Diagnosticar Lentidão'), findsOneWidget);
    expect(find.text('Analisar Uso de Memória'), findsOneWidget);
    expect(find.text('Resumo de Saúde'), findsOneWidget);

    // Clica no chip Diagnosticar Lentidão
    await tester.tap(find.text('Diagnosticar Lentidão'));
    await tester.pumpAndSettle();

    expect(client.analyzeCalls, 1);
    expect(client.lastPrompt, 'Diagnosticar Lentidão');
    expect(client.lastIncludeTelemetry, isTrue);
    expect(client.lastIncludeTopProcesses, isTrue);

    // Exibe resposta e card de ação sugerida
    expect(find.textContaining('Identifiquei alto consumo de memória'), findsOneWidget);
    expect(find.text('Encerrar Bloco de Notas'), findsOneWidget);
    expect(find.text('Confirmar e Executar'), findsOneWidget);
  });

  testWidgets('HermesAssistantPage: fluxo de confirmação explícita para ação sugerida', (tester) async {
    final client = FakeAssistantClient();
    HermesSuggestedAction? executedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: HermesAssistantPage(
          client: client,
          initialPrompt: 'Diagnosticar Lentidão',
          onExecuteConfirmedAction: (action) async {
            executedAction = action;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.analyzeCalls, 1);
    expect(find.text('Encerrar Bloco de Notas'), findsOneWidget);

    // Toca em "Confirmar e Executar"
    await tester.tap(find.text('Confirmar e Executar'));
    await tester.pumpAndSettle();

    // Deve abrir o AlertDialog de confirmação explícita
    expect(find.text('Confirmar Ação Sugerida'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Executar Agora'), findsOneWidget);
    expect(executedAction, isNull);

    // Testa cancelar primeiro
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(executedAction, isNull);
    expect(find.text('Confirmar Ação Sugerida'), findsNothing);

    // Toca novamente e agora confirma
    await tester.tap(find.text('Confirmar e Executar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Executar Agora'));
    await tester.pumpAndSettle();

    expect(executedAction, isNotNull);
    expect(executedAction!.targetId, 'test_notepad');
    expect(executedAction!.actionType, 'app.kill');
    expect(find.textContaining('executada com sucesso'), findsOneWidget);
  });
}
