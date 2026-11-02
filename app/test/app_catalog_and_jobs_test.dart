import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/home/status_page.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDroidDeckClient extends DroidDeckClient {
  FakeDroidDeckClient() : super(baseUrl: 'http://localhost:4787');

  List<AllowedApp> mockApps = [
    const AllowedApp(
      id: 'obsidian',
      name: 'Obsidian',
      description: 'Base de conhecimento',
      icon: 'description',
      canKill: false,
      isRunning: false,
    ),
    const AllowedApp(
      id: 'orbit',
      name: 'Orbit PJ',
      description: 'Projeto Orbit no editor',
      icon: 'code',
      canKill: false,
      isRunning: false,
    ),
    const AllowedApp(
      id: 'test_notepad',
      name: 'Bloco de Notas (Teste)',
      description: 'App de teste',
      icon: 'edit_note',
      canKill: true,
      isRunning: true,
      processId: 4321,
    ),
  ];

  List<CommandJob> mockJobs = [
    CommandJob(
      id: 'job-1',
      requestId: 'req-1',
      actionType: 'app.launch',
      targetId: 'obsidian',
      status: 'succeeded',
      createdAtUtc: DateTime.now().toUtc(),
    ),
  ];

  bool launchCalled = false;
  bool killCalled = false;
  bool clearJobsCalled = false;

  @override
  Future<List<AllowedApp>> getApps() async => mockApps;

  @override
  Future<List<CommandJob>> getJobs({String? deviceId, int limit = 50}) async => mockJobs;

  @override
  Future<CommandJob> launchApp(String appId, {required String requestId, String? deviceId}) async {
    launchCalled = true;
    final job = CommandJob(
      id: 'job-new',
      requestId: requestId,
      actionType: 'app.launch',
      targetId: appId,
      status: 'succeeded',
      createdAtUtc: DateTime.now().toUtc(),
    );
    mockJobs.insert(0, job);
    return job;
  }

  @override
  Future<CommandJob> killApp(
    String appId, {
    required String requestId,
    required bool confirmed,
    int? processId,
    DateTime? startTimeUtc,
    String? deviceId,
  }) async {
    killCalled = true;
    final job = CommandJob(
      id: 'job-kill',
      requestId: requestId,
      actionType: 'app.kill',
      targetId: appId,
      status: 'succeeded',
      createdAtUtc: DateTime.now().toUtc(),
    );
    mockJobs.insert(0, job);
    return job;
  }

  @override
  Future<void> clearJobs({String? deviceId}) async {
    clearJobsCalled = true;
    mockJobs.clear();
  }
}

void main() {
  test('AllowedApp e CommandJob deserializam JSON corretamente', () {
    final appJson = {
      'id': 'test_notepad',
      'name': 'Bloco de Notas',
      'description': 'App de teste',
      'icon': 'edit_note',
      'canKill': true,
      'isRunning': true,
      'processId': 1234,
      'startTimeUtc': '2026-10-17T12:00:00Z',
    };
    final app = AllowedApp.fromJson(appJson);
    expect(app.id, 'test_notepad');
    expect(app.canKill, true);
    expect(app.isRunning, true);
    expect(app.processId, 1234);
    expect(app.startTimeUtc?.isUtc, true);

    final jobJson = {
      'id': 'job-123',
      'requestId': 'req-999',
      'actionType': 'app.launch',
      'targetId': 'obsidian',
      'status': 'succeeded',
      'createdAtUtc': '2026-10-17T12:05:00Z',
      'completedAtUtc': '2026-10-17T12:05:01Z',
    };
    final job = CommandJob.fromJson(jobJson);
    expect(job.id, 'job-123');
    expect(job.actionType, 'app.launch');
    expect(job.status, 'succeeded');
    expect(job.completedAtUtc, isNotNull);
  });

  testWidgets('StatusPage mostra Atividade Recente sem o card de Ações Autorizadas',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PcStore.currentId = null;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeClient = FakeDroidDeckClient();
    final signalR = SignalRService();
    signalR.connectionStatus.value = 'Connected';

    await tester.pumpWidget(
      MaterialApp(
        home: StatusPage(
          isFullscreen: false,
          onToggleFullscreen: () {},
          signalRService: signalR,
          client: fakeClient,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ações Autorizadas'), findsNothing);
    expect(find.text('Obsidian'), findsNothing);
    expect(find.text('Orbit PJ'), findsNothing);
    expect(find.text('Bloco de Notas (Teste)'), findsNothing);

    // Rola para exibir o card de Atividade Recente (ListView)
    await tester.scrollUntilVisible(
      find.text('Atividade Recente'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Atividade Recente'), findsOneWidget);

    // Valida histórico inicial
    expect(find.text('app.launch (obsidian)'), findsOneWidget);
  });

  testWidgets('StatusPage unifica a atividade dos dois PCs e filtra pelo PC escolhido',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PcStore.currentId = null;
    final firstPc = await PcStore.upsert(
      ip: '10.0.0.1',
      port: '4787',
      apiKey: 'key-one',
      name: 'PC Escritório',
    );
    await PcStore.upsert(
      ip: '10.0.0.2',
      port: '4787',
      apiKey: 'key-two',
      name: 'PC Sala',
    );
    final firstPcClient = FakeDroidDeckClient()
      ..mockJobs = [
        CommandJob(
          id: 'job-one',
          requestId: 'req-one',
          actionType: 'app.launch',
          targetId: 'obsidian',
          status: 'succeeded',
          createdAtUtc: DateTime.utc(2026, 10, 20, 10),
        ),
      ];
    final secondPcClient = FakeDroidDeckClient()
      ..mockJobs = [
        CommandJob(
          id: 'job-two',
          requestId: 'req-two',
          actionType: 'app.launch',
          targetId: 'orbit',
          status: 'succeeded',
          createdAtUtc: DateTime.utc(2026, 10, 20, 11),
        ),
      ];
    final signalR = SignalRService();

    await tester.pumpWidget(
      MaterialApp(
        home: StatusPage(
          isFullscreen: false,
          onToggleFullscreen: () {},
          signalRService: signalR,
          client: secondPcClient,
          clientForPc: (pc) => pc.id == firstPc.id
              ? firstPcClient
              : throw StateError('Unexpected PC'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Atividade Recente'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('app.launch (obsidian)'), findsOneWidget);
    expect(find.text('app.launch (orbit)'), findsOneWidget);
    expect(find.text('PC Escritório'), findsWidgets);
    expect(find.text('PC Sala'), findsWidgets);

    await tester.ensureVisible(find.byKey(const ValueKey('activity-pc-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-pc-filter')));
    await tester.pumpAndSettle();
    final firstPcFilter = find.byKey(ValueKey('activity-filter-${firstPc.id}'));
    await tester.ensureVisible(firstPcFilter);
    await tester.tap(firstPcFilter);
    await tester.pumpAndSettle();

    expect(find.text('app.launch (obsidian)'), findsOneWidget);
    expect(find.text('app.launch (orbit)'), findsNothing);
    await tester.tap(find.byTooltip('Limpar histórico'));
    await tester.pumpAndSettle();
    expect(
      find.text('Remover a atividade dos PCs: PC Escritório?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(firstPcClient.clearJobsCalled, false);
  });

  testWidgets('StatusPage: encerrar pelo comando rápido ainda pede confirmação',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeClient = FakeDroidDeckClient();
    final signalR = SignalRService();

    await tester.pumpWidget(
      MaterialApp(
        home: StatusPage(
          isFullscreen: false,
          onToggleFullscreen: () {},
          signalRService: signalR,
          client: fakeClient,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Encerrar'), findsNothing);

    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'encerrar bloco de notas');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar Ação Rápida'), findsOneWidget);
    expect(fakeClient.killCalled, false);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(fakeClient.killCalled, false);

    await tester.enterText(field, 'encerrar bloco de notas');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Executar Agora'));
    await tester.pumpAndSettle();

    expect(fakeClient.killCalled, true);
  });
}
