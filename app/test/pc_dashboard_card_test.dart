import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/home/pc_dashboard_card.dart';
import 'package:droiddeck/src/home/thermal_color.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('faixa térmica: verde até 60, âmbar até 80, vermelho acima', () {
    expect(thermalColor(60), const Color(0xFF34D5A0));
    expect(thermalColor(75), const Color(0xFFF0B65F));
    expect(thermalColor(81), const Color(0xFFF87171));
    expect(thermalColor(null), const Color(0xFF9CA3AF));
  });

  testWidgets('shows independent PC status and selects the requested target', (
    tester,
  ) async {
    final primary = SignalRService()
      ..connectionStatus.value = 'Connected'
      ..systemStats.value = SystemStats(
        cpuUsage: 24,
        ramUsage: 61,
        cpuTempC: 58,
        gpuTempC: 88,
      );
    final secondary = SignalRService()..connectionStatus.value = 'Disconnected';
    final one = SavedPc(
      id: 'one',
      name: 'PC Escritório',
      ip: '10.0.0.1',
      port: '4787',
    );
    final two = SavedPc(
      id: 'two',
      name: 'PC Sala',
      ip: '10.0.0.2',
      port: '4787',
    );
    SavedPc? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PcDashboardCard(
            primaryPc: one,
            secondaryPc: two,
            primaryConnection: primary,
            secondaryConnection: secondary,
            targetPcId: one.id,
            onTargetSelected: (pc) => selected = pc,
          ),
        ),
      ),
    );

    expect(find.text('Meus 2 PCs'), findsOneWidget);
    expect(find.text('PC Escritório'), findsOneWidget);
    expect(find.text('PC Sala'), findsOneWidget);
    expect(find.text('PC-alvo: PC Escritório'), findsOneWidget);
    expect(find.textContaining('24% CPU'), findsOneWidget);
    expect(find.textContaining('61% RAM'), findsOneWidget);
    expect(find.text('CPU 58°'), findsOneWidget);
    expect(find.text('GPU 88°'), findsOneWidget);
    expect(find.text('Temperatura crítica'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pc-target-two')));
    expect(selected?.id, 'two');
  });
}
