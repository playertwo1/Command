import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:droiddeck/src/routines/workspace_routines_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWorkspaceClient extends DroidDeckClient {
  int executeCalls = 0;
  int deleteCalls = 0;
  String? lastExecutedId;
  String? lastDeletedId;
  String? lastDeviceId;
  bool? lastConfirmed;
  bool failExecution = false;

  final List<RoutineDefinitionData> routines;

  FakeWorkspaceClient({
    this.routines = const [],
  }) : super(baseUrl: 'http://localhost:4787');

  @override
  Future<void> deleteRoutine(String id) async {
    deleteCalls++;
    lastDeletedId = id;
  }

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
    lastDeviceId = deviceId;
    lastConfirmed = confirmed;
    if (failExecution) throw StateError('private network detail');

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

class _RoutineSignalR extends SignalRService {
  _RoutineSignalR(String status) {
    connectionStatus.value = status;
  }
}

RoutineDefinitionData _routine({String targetId = 'obsidian'}) => RoutineDefinitionData(
      id: 'routine-1',
      name: 'Rotina pareada',
      description: 'Abre o editor',
      icon: 'auto_mode',
      isPreset: false,
      requiresConfirmation: true,
      steps: [
        RoutineStepData(
          stepId: 'step-1',
          actionType: 'app.launch',
          targetId: targetId,
          delayMs: 100,
          continueOnError: false,
        ),
      ],
    );

RoutinePcTarget _target(String id, String name, FakeWorkspaceClient client) => RoutinePcTarget(
      pcId: id,
      pcName: name,
      client: client,
      connection: _RoutineSignalR('Connected'),
    );

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
                targetPcName: 'PC Sala',
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
      expect(find.text('PC-alvo: PC Sala'), findsOneWidget);
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

    testWidgets('cancelar confirmação pareada não dispara chamadas', (tester) async {
      final routine = _routine();
      final first = FakeWorkspaceClient(routines: [routine]);
      final second = FakeWorkspaceClient(routines: [routine]);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: WorkspaceRoutinesCard(
          client: first,
          dualTargets: [_target('pc-1', 'PC Sala', first), _target('pc-2', 'PC Quarto', second)],
        ),
      ))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Executar nos dois PCs'));
      await tester.pumpAndSettle();
      expect(find.text('PC Sala'), findsOneWidget);
      expect(find.text('PC Quarto'), findsOneWidget);
      expect(find.textContaining('app.launch -> obsidian'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(first.executeCalls, 0);
      expect(second.executeCalls, 0);
    });

    testWidgets('definições divergentes bloqueiam a execução pareada', (tester) async {
      final first = FakeWorkspaceClient(routines: [_routine()]);
      final second = FakeWorkspaceClient(routines: [_routine(targetId: 'code')]);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: WorkspaceRoutinesCard(
          client: first,
          dualTargets: [_target('pc-1', 'PC Sala', first), _target('pc-2', 'PC Quarto', second)],
        ),
      ))));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Executar nos dois PCs'),
        matching: find.byType(OutlinedButton),
      ).first);
      expect(button.onPressed, isNull);
      expect(find.textContaining('definições diferem'), findsOneWidget);
      expect(first.executeCalls, 0);
      expect(second.executeCalls, 0);
    });

    testWidgets('desconexão após confirmação impede ambas as chamadas', (tester) async {
      final routine = _routine();
      final first = FakeWorkspaceClient(routines: [routine]);
      final second = FakeWorkspaceClient(routines: [routine]);
      final firstConnection = _RoutineSignalR('Connected');
      final secondConnection = _RoutineSignalR('Connected');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: WorkspaceRoutinesCard(
          client: first,
          dualTargets: [
            RoutinePcTarget(pcId: 'pc-1', pcName: 'PC Sala', client: first, connection: firstConnection),
            RoutinePcTarget(pcId: 'pc-2', pcName: 'PC Quarto', client: second, connection: secondConnection),
          ],
        ),
      ))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Executar nos dois PCs'));
      await tester.pumpAndSettle();
      secondConnection.connectionStatus.value = 'Disconnected';
      await tester.pump();
      await tester.tap(find.text('Confirmar nos dois'));
      await tester.pumpAndSettle();

      expect(first.executeCalls, 0);
      expect(second.executeCalls, 0);
      expect(find.textContaining('A conexão de um dos PCs caiu'), findsOneWidget);
    });

    testWidgets('sucesso duplo mostra status e identidade de cada PC', (tester) async {
      final routine = _routine();
      final first = FakeWorkspaceClient(routines: [routine]);
      final second = FakeWorkspaceClient(routines: [routine]);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: WorkspaceRoutinesCard(
          client: first,
          dualTargets: [_target('profile-a', 'PC Sala', first), _target('profile-b', 'PC Quarto', second)],
        ),
      ))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Executar nos dois PCs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar nos dois'));
      await tester.pumpAndSettle();

      expect(first.executeCalls, 1);
      expect(second.executeCalls, 1);
      expect(first.lastDeviceId, 'profile-a');
      expect(second.lastDeviceId, 'profile-b');
      expect(find.text('PC Sala'), findsOneWidget);
      expect(find.text('PC Quarto'), findsOneWidget);
      expect(find.text('Status: succeeded'), findsNWidgets(2));
      expect(find.text('Status Geral: succeeded'), findsNothing);
    });

    testWidgets('falha parcial só aparece para o PC correspondente', (tester) async {
      final routine = _routine();
      final first = FakeWorkspaceClient(routines: [routine]);
      final second = FakeWorkspaceClient(routines: [routine])..failExecution = true;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: WorkspaceRoutinesCard(
          client: first,
          dualTargets: [_target('pc-1', 'PC Sala', first), _target('pc-2', 'PC Quarto', second)],
        ),
      ))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Executar nos dois PCs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar nos dois'));
      await tester.pumpAndSettle();

      expect(find.text('PC Sala'), findsOneWidget);
      expect(find.text('Status: succeeded'), findsOneWidget);
      expect(find.textContaining('PC Quarto'), findsOneWidget);
      expect(find.textContaining('Falha de comunicação'), findsOneWidget);
      expect(find.textContaining('private network detail'), findsNothing);
      expect(find.text('Status Geral: succeeded'), findsNothing);
    });

    testWidgets('menu popup permite excluir rotina com confirmação', (tester) async {
      final routine = _routine();
      final client = FakeWorkspaceClient(routines: [routine]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorkspaceRoutinesCard(client: client),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rotina pareada'), findsOneWidget);
      final moreBtn = find.byIcon(Icons.more_vert);
      expect(moreBtn, findsOneWidget);

      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      expect(find.text('Excluir'), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir Rotina'), findsOneWidget);
      final confirmDeleteBtn = find.widgetWithText(ElevatedButton, 'Excluir');
      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle();

      expect(client.deleteCalls, 1);
      expect(client.lastDeletedId, 'routine-1');
    });
  });
}
