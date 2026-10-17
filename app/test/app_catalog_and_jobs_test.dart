import 'package:dio/dio.dart';
import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/home/status_page.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('StatusPage exibe Ações Autorizadas e Atividade Recente com fake client',
      (tester) async {
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

    // Valida títulos das seções F4
    expect(find.text('Ações Autorizadas'), findsOneWidget);

    // Valida apps cadastrados
    expect(find.text('Obsidian'), findsOneWidget);
    expect(find.text('Orbit PJ'), findsOneWidget);
    expect(find.text('Bloco de Notas (Teste)'), findsOneWidget);

    // Valida botão Encerrar exibido apenas para o app que tem canKill == true
    expect(find.text('Encerrar'), findsOneWidget);

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

  testWidgets('StatusPage: confirmação de encerramento protegida por diálogo',
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

    // Clica no botão Encerrar
    await tester.tap(find.text('Encerrar'));
    await tester.pumpAndSettle();

    // Diálogo deve abrir
    expect(find.text('Encerrar Aplicativo'), findsOneWidget);

    // Clica em Cancelar
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Não deve ter chamado killApp
    expect(fakeClient.killCalled, false);

    // Abre novamente e confirma
    await tester.tap(find.text('Encerrar'));
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(FilledButton, 'Encerrar');
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    // Deve ter chamado killApp com sucesso
    expect(fakeClient.killCalled, true);
  });
}
