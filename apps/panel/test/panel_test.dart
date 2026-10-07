import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:nesta_panel/data/demo_panel_repository.dart';
import 'package:nesta_panel/main.dart';
import 'package:nesta_panel/panel_state.dart';
import 'package:nesta_panel/screens/patient_detail.dart';

Future<void> settle(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  Future<PanelState> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 10, 7, 12);
    final state = PanelState(DemoPanelRepository(now: now), clock: () => now);
    await tester.pumpWidget(PanelApp(state: state));
    await settle(tester);
    expect(find.text('Nesta Ebe Paneli'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'ebe@ornek.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.tap(find.text('Giriş yap'));
    await settle(tester);
    return state;
  }

  for (final (name, size) in [
    ('masaüstü', const Size(1440, 900)),
    ('tablet', const Size(800, 1100)),
    ('telefon', const Size(390, 844)),
  ]) {
    testWidgets('$name: panel akışı taşmadan çalışır', (tester) async {
      final state = await boot(tester, size);
      expect(find.textContaining('Merhaba'), findsOneWidget);
      expect(find.text('NESTA1'), findsOneWidget);
      expect(state.patients, hasLength(7));
      expect(state.pending, hasLength(2));

      // Her bölüm
      for (final label in [
        'Gebeler',
        'Uyarılar',
        'Araştırma Verisi',
        'Hesap',
        'Genel Bakış',
      ]) {
        await tester.tap(find.text(label).last);
        await settle(tester, 3);
      }

      // Onay bekleyen gebenin ayrıntısı ve onay
      final seda = state.patients.firstWhere(
        (p) => p.profile.fullName == 'Seda Koç',
      );
      final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PatientDetailScreen(patientId: seda.uid),
        ),
      );
      await settle(tester);
      final approve = find.text('Onayla');
      await tester.scrollUntilVisible(
        approve,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(approve);
      await settle(tester, 2);
      await tester.tap(approve);
      await settle(tester);
      expect(
        state.patient(seda.uid)!.clearance.status,
        ClearanceStatus.approved,
      );
      expect(
        state.patient(seda.uid)!.clearance.decidedBy,
        DemoPanelRepository.midwifeId,
      );
      nav.pop();
      await settle(tester);

      // Seans geçmişi olan gebe
      final ayse = state.patients.firstWhere(
        (p) => p.profile.fullName == 'Ayşe Yılmaz',
      );
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PatientDetailScreen(patientId: ayse.uid),
        ),
      );
      await settle(tester);
      expect(state.sessionsOf(ayse.uid), isNotEmpty);
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 10; i++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 50));
      }
      nav.pop();
      await settle(tester);
    });
  }

  testWidgets('uyarı "görüldü" olarak işaretlenir', (tester) async {
    final state = await boot(tester, const Size(1440, 900));
    final open = state.openAlerts.length;
    expect(open, greaterThan(0));
    await tester.tap(find.text('Uyarılar').last);
    await settle(tester, 3);
    await tester.tap(find.text('Görüldü').first);
    await settle(tester, 3);
    expect(state.openAlerts.length, open - 1);
  });

  test(
    'araştırma verisi yalnızca onam verenleri içerir ve anonimdir',
    () async {
      final now = DateTime(2026, 10, 7, 12);
      final state = PanelState(DemoPanelRepository(now: now), clock: () => now);
      await state.repo.signIn('a@b.c', 'x');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(state.sessions, isNotEmpty);
      final csv = state.researchCsv();
      final summary = state.participantsCsv();
      for (final p in state.patients) {
        expect(csv, isNot(contains(p.profile.fullName)));
        expect(csv, isNot(contains(p.uid)));
        expect(summary, isNot(contains(p.profile.fullName)));
      }
      // Merve Demir (p3) araştırma onamı vermedi.
      final consenting = state.patients
          .where((p) => p.consent!.researchParticipation)
          .length;
      expect(summary.split('\n'), hasLength(consenting + 1));
      expect(csv.split('\n').length, greaterThan(10));
      expect(csv.split('\n')[1], startsWith('K0'));
      state.dispose();
    },
  );
}
