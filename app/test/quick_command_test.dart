import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/hermes/quick_command_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDeckClient extends DroidDeckClient {
  FakeDeckClient() : super(baseUrl: 'http://localhost:4787');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickCommandParser unit tests', () {
    test('reconhece intenções determinísticas locais', () {
      final obsidian = QuickCommandParser.parseLocalIntent('abrir obsidian');
      expect(obsidian, isNotNull);
      expect(obsidian!.actionType, 'app.launch');
      expect(obsidian.targetId, 'obsidian');
      expect(obsidian.title, 'Abrir Obsidian');
      expect(obsidian.requiresConfirmation, isTrue);

      final orbit = QuickCommandParser.parseLocalIntent('Abrir Orbit');
      expect(orbit, isNotNull);
      expect(orbit!.actionType, 'app.launch');
      expect(orbit.targetId, 'orbit');

      final notepadOpen1 = QuickCommandParser.parseLocalIntent('abrir bloco de notas');
      expect(notepadOpen1, isNotNull);
      expect(notepadOpen1!.actionType, 'app.launch');
      expect(notepadOpen1.targetId, 'test_notepad');

      final notepadOpen2 = QuickCommandParser.parseLocalIntent('abrir notepad');
      expect(notepadOpen2, isNotNull);
      expect(notepadOpen2!.actionType, 'app.launch');
      expect(notepadOpen2.targetId, 'test_notepad');

      final notepadKill1 = QuickCommandParser.parseLocalIntent('fechar bloco de notas');
      expect(notepadKill1, isNotNull);
      expect(notepadKill1!.actionType, 'app.kill');
      expect(notepadKill1.targetId, 'test_notepad');

      final notepadKill2 = QuickCommandParser.parseLocalIntent('encerrar notepad');
      expect(notepadKill2, isNotNull);
      expect(notepadKill2!.actionType, 'app.kill');
      expect(notepadKill2.targetId, 'test_notepad');

      final screen1 = QuickCommandParser.parseLocalIntent('capturar tela');
      expect(screen1, isNotNull);
      expect(screen1!.actionType, 'screenshot.capture');
      expect(screen1.targetId, 'primary_monitor');

      final screen2 = QuickCommandParser.parseLocalIntent('print');
      expect(screen2, isNotNull);
      expect(screen2!.actionType, 'screenshot.capture');
      expect(screen2.targetId, 'primary_monitor');
    });

    test('retorna null para comandos não locais / delegáveis à IA', () {
      expect(QuickCommandParser.parseLocalIntent('qual o uso de cpu agora?'), isNull);
      expect(QuickCommandParser.parseLocalIntent('pesquisar na internet'), isNull);
      expect(QuickCommandParser.parseLocalIntent(''), isNull);
    });
  });

  group('QuickCommandBar widget tests', () {
    testWidgets('renderiza input e processa comando local com confirmação obrigatória', (tester) async {
      final client = FakeDeckClient();
      HermesSuggestedAction? executedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickCommandBar(
                client: client,
                onTriggerAction: (action) async {
                  executedAction = action;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      // Digita comando local
      await tester.enterText(find.byType(TextField), 'abrir obsidian');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Diálogo de confirmação deve ser exibido
      expect(find.text('Confirmar Ação Rápida'), findsOneWidget);
      expect(find.text('Abrir Obsidian'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Executar Agora'), findsOneWidget);

      // Clica em Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(executedAction, isNull);
      expect(find.text('Confirmar Ação Rápida'), findsNothing);

      // Digita novamente e agora executa
      await tester.enterText(find.byType(TextField), 'abrir obsidian');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Executar Agora'));
      await tester.pumpAndSettle();

      expect(executedAction, isNotNull);
      expect(executedAction!.targetId, 'obsidian');
      expect(executedAction!.actionType, 'app.launch');
      expect(find.textContaining('executada com sucesso'), findsOneWidget);
    });

    testWidgets('aciona fallback para Hermes quando comando não é local', (tester) async {
      final client = FakeDeckClient();
      String? fallbackPrompt;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickCommandBar(
                client: client,
                onFallbackToHermes: (prompt) {
                  fallbackPrompt = prompt;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'diagnosticar gargalo no pc');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pumpAndSettle();

      expect(fallbackPrompt, 'diagnosticar gargalo no pc');
      // Diálogo local não deve ter sido aberto
      expect(find.text('Confirmar Ação Rápida'), findsNothing);
    });
  });
}
