import 'package:command/core/core.dart';
import 'package:command/src/routines/routine_builder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRoutineClient extends CommandClient {
  int saveCalls = 0;
  RoutineDefinitionData? lastSavedRoutine;

  FakeRoutineClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<RoutineDefinitionData> saveRoutine(RoutineDefinitionData routine) async {
    saveCalls++;
    lastSavedRoutine = routine;
    return routine;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Routine Models Serialization', () {
    test('RoutineStepData: serialização e parsing com delay', () {
      const step = RoutineStepData(
        stepId: 'step_1',
        actionType: 'app.launch',
        targetId: 'obsidian',
        delayMs: 1500,
        continueOnError: true,
      );

      final json = step.toJson();
      final fromJson = RoutineStepData.fromJson(json);

      expect(fromJson.stepId, 'step_1');
      expect(fromJson.actionType, 'app.launch');
      expect(fromJson.targetId, 'obsidian');
      expect(fromJson.delayMs, 1500);
      expect(fromJson.continueOnError, isTrue);

      final pascalJson = {
        'StepId': 'step_p',
        'ActionType': 'screenshot.capture',
        'TargetId': 'primary',
        'DelayAfterMs': 2000,
        'ContinueOnError': false,
      };
      final fromPascal = RoutineStepData.fromJson(pascalJson);
      expect(fromPascal.stepId, 'step_p');
      expect(fromPascal.actionType, 'screenshot.capture');
      expect(fromPascal.targetId, 'primary');
      expect(fromPascal.delayMs, 2000);
      expect(fromPascal.continueOnError, isFalse);
    });

    test('RoutineDefinitionData: serialização e parsing com lista de passos', () {
      const def = RoutineDefinitionData(
        id: 'r_study',
        name: 'Modo Estudo',
        description: 'Abre apps de estudo',
        icon: 'auto_mode',
        isPreset: true,
        requiresConfirmation: true,
        steps: [
          RoutineStepData(
            stepId: 's1',
            actionType: 'app.launch',
            targetId: 'obsidian',
          ),
        ],
      );

      final json = def.toJson();
      final fromJson = RoutineDefinitionData.fromJson(json);

      expect(fromJson.id, 'r_study');
      expect(fromJson.name, 'Modo Estudo');
      expect(fromJson.isPreset, isTrue);
      expect(fromJson.steps.length, 1);
      expect(fromJson.steps.first.targetId, 'obsidian');
    });

    test('RoutineExecutionResult: serialização e resultados de passos', () {
      final json = {
        'routineId': 'r_focus',
        'routineName': 'Limpeza de Foco',
        'overallStatus': 'succeeded',
        'stepResults': [
          {
            'stepId': 's1',
            'actionType': 'app.kill',
            'targetId': 'test_notepad',
            'status': 'succeeded',
            'durationMs': 120,
          },
          {
            'stepId': 's2',
            'actionType': 'screenshot.capture',
            'targetId': 'primary',
            'status': 'skipped',
            'durationMs': 0,
          }
        ],
      };

      final res = RoutineExecutionResult.fromJson(json);
      expect(res.routineId, 'r_focus');
      expect(res.overallStatus, 'succeeded');
      expect(res.stepResults.length, 2);
      expect(res.stepResults.first.status, 'succeeded');
      expect(res.stepResults.last.status, 'skipped');
    });
  });

  group('RoutineBuilderPage Widget Tests', () {
    testWidgets('valida campos obrigatórios antes de salvar', (tester) async {
      final client = FakeRoutineClient();

      await tester.pumpWidget(
        MaterialApp(
          home: RoutineBuilderPage(client: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nova Rotina'), findsOneWidget);
      expect(find.text('Nome da Rotina'), findsOneWidget);
      expect(find.text('Descrição'), findsOneWidget);

      // Tenta salvar sem preencher nada
      await tester.tap(find.text('Salvar Rotina'));
      await tester.pumpAndSettle();

      expect(find.text('O nome da rotina é obrigatório.'), findsOneWidget);
      expect(client.saveCalls, 0);

      // Preenche o nome mas sem passos
      final nameFinder = find.widgetWithText(TextField, 'Nome da Rotina');
      await tester.enterText(nameFinder, 'Rotina Vazia');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar Rotina'));
      await tester.pumpAndSettle();

      expect(find.text('Adicione pelo menos um passo na rotina.'), findsOneWidget);
      expect(client.saveCalls, 0);
    });

    testWidgets('adiciona passo, configura valores e salva rotina com sucesso', (tester) async {
      final client = FakeRoutineClient();
      RoutineDefinitionData? savedData;

      await tester.pumpWidget(
        MaterialApp(
          home: RoutineBuilderPage(
            client: client,
            onSaved: (routine) => savedData = routine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preenche nome e descrição
      final nameFinder = find.widgetWithText(TextField, 'Nome da Rotina');
      await tester.enterText(nameFinder, 'Modo Dev Custom');
      final descFinder = find.widgetWithText(TextField, 'Descrição');
      await tester.enterText(descFinder, 'Abre Orbit e monitor');
      await tester.pumpAndSettle();

      // Adiciona um passo
      await tester.tap(find.text('Adicionar Passo'));
      await tester.pumpAndSettle();

      expect(find.text('Passos da Sequência (1)'), findsOneWidget);
      expect(find.text('Passo 1'), findsOneWidget);
      expect(find.text('Continuar se falhar'), findsOneWidget);

      // Clica em Salvar (AppBar action)
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(client.saveCalls, 1);
      expect(client.lastSavedRoutine, isNotNull);
      expect(client.lastSavedRoutine!.name, 'Modo Dev Custom');
      expect(client.lastSavedRoutine!.steps.length, 1);
      expect(savedData, isNotNull);
      expect(savedData!.name, 'Modo Dev Custom');
    });
  });
}
