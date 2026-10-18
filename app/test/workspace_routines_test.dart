import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/routines/workspace_routines_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWorkspaceClient extends DroidDeckClient {
  int executeCalls = 0;
  String? lastExecutedId;
  bool? lastConfirmed;

  final List<RoutineDefinitionData> routines;

  FakeWorkspaceClient({
    this.routines = const [],
  }) : super(baseUrl: 'http://localhost:4787');

  @override
  Future<List<RoutineDefinitionData>> getRoutines() async {
    return routines;
  }

  @override
  Future<RoutineExecutionResult> executeRoutine(
    String id, {
    bool confirmed = true,
    String? deviceId,
  }) async {
    executeCalls++;
    lastExecutedId = id;
    lastConfirmed = confirmed;

    return RoutineExecutionResult(
      routineId: id,
      routineName: id == 'study_vault' ? 'Modo Estudo & Vault' : 'Rotina Teste',
      overallStatus: 'succeeded',
      stepResults: const [
        RoutineStepResultData(
          stepId: 's1',
          actionType: 'app.launch',
          targetId: 'obsidian',
          status: 'succeeded',
          durationMs: 150,
        ),
        RoutineStepResultData(
          stepId: 's2',
          actionType: 'screenshot.capture',
          targetId: 'primary',
          status: 'skipped',
          durationMs: 0,
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkspaceRoutinesCard Widget Tests', () {
    testWidgets('renderiza presets padrão e permite abrir diálogo de confirmação', (tester) async {
      final client = FakeWorkspaceClient();
      int executedCallbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkspaceRoutinesCard(
                client: client,
                onRoutineExecuted: () => executedCallbackCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card Header
      expect(find.text('Modos de Ambiente & Rotinas'), findsOneWidget);
      expect(find.text('Nova Rotina'), findsOneWidget);

      // 3 Presets padrão
      expect(find.text('Modo Estudo & Vault'), findsOneWidget);
      expect(find.text('Modo Dev Orbit'), findsOneWidget);
      expect(find.text('Limpeza de Foco'), findsOneWidget);

      // Clica em Executar no primeiro preset
      final executeButtons = find.text('Executar');
      expect(executeButtons, findsNWidgets(3));
      await tester.tap(executeButtons.first);
      await tester.pumpAndSettle();

      // Diálogo de confirmação explícita
      expect(find.text('Confirmar Execução de Rotina'), findsOneWidget);
      expect(find.text('Passos sequenciais que serão executados:'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Executar Rotina'), findsOneWidget);

      // Cancela execução
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(client.executeCalls, 0);
      expect(executedCallbackCount, 0);

      // Executa novamente e confirma
      await tester.tap(executeButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Executar Rotina'));
      await tester.pumpAndSettle();

      expect(client.executeCalls, 1);
      expect(client.lastExecutedId, 'study_vault');
      expect(client.lastConfirmed, isTrue);
      expect(executedCallbackCount, 1);

      // Modal de resultado passo a passo
      expect(find.text('Resultado: Modo Estudo & Vault'), findsOneWidget);
      expect(find.text('Status Geral: succeeded'), findsOneWidget);
      expect(find.textContaining('app.launch (obsidian): succeeded'), findsOneWidget);
      expect(find.textContaining('screenshot.capture (primary): skipped'), findsOneWidget);
    });

    testWidgets('botão Nova Rotina abre RoutineBuilderPage', (tester) async {
      final client = FakeWorkspaceClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceRoutinesCard(client: client),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nova Rotina'));
      await tester.pumpAndSettle();

      // Abre a tela de criação
      expect(find.text('Nova Rotina'), findsOneWidget);
      expect(find.text('Nome da Rotina'), findsOneWidget);
      expect(find.text('Salvar Rotina'), findsOneWidget);
    });
  });
}
