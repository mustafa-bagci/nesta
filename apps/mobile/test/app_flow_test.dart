import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nesta/app.dart';
import 'package:nesta/data/demo_repository.dart';
import 'package:nesta/features/home/home_screen.dart';
import 'package:nesta/state/app_state.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late AppState state;
  late DemoRepository repo;

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = DemoRepository(prefs, autoApproveDelay: const Duration(seconds: 3));
    state = AppState(repo, prefs, clock: () => DateTime(2026, 10, 7, 9));
    await tester.pumpWidget(NestaApp(state: state));
    await settle(tester);
  }

  /// Tembel oluşturulan listelerde öğe görünene kadar kaydırır.
  Future<void> reveal(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        250,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
    }
    await t.ensureVisible(f.first);
    await t.pump();
  }

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text);
    await reveal(t, f);
    await t.tap(f.first);
    await settle(t);
  }

  testWidgets('kurulumdan egzersiz seansına uçtan uca akış', (tester) async {
    await boot(tester);

    // Hoş geldin
    expect(find.text('HOŞ GELDİNİZ'), findsOneWidget);
    await tapText(tester, 'DEVAM');
    await tapText(tester, 'DEVAM');
    await tapText(tester, 'BAŞLA');

    // Kayıt
    expect(find.text('KAYIT OL'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).at(0), 'ayse@ornek.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'gizli123');
    await tester.enterText(find.byType(TextFormField).at(2), 'gizli123');
    await tapText(tester, 'KAYIT OL');
    await settle(tester);

    // Aydınlatma ve açık rıza
    expect(find.text(privacyNoticeTitle), findsOneWidget);
    final health = find.text(healthDataConsentText);
    await reveal(tester, health);
    await tester.tap(health);
    final disclaimer = find.textContaining('tanı koymadığını');
    await reveal(tester, disclaimer);
    await tester.tap(disclaimer);
    await settle(tester);
    await tapText(tester, 'ONAYLIYORUM');

    // Profil formu açıldı; tarih seçicileri atlayıp profili doğrudan kaydet.
    expect(find.text('PROFİL'), findsOneWidget);
    await state.saveProfile(
      PregnancyProfile(
        fullName: 'Ayşe Yılmaz',
        birthDate: DateTime.utc(1995, 3, 10),
        lastMenstrualPeriod: DateTime.utc(2026, 4, 15),
        heightCm: 165,
        prePregnancyWeightKg: 62,
        riskFactors: {RiskFactor.gestationalDiabetes},
      ),
    );
    await settle(tester);

    // Tarama
    expect(find.text('SAĞLIK TARAMASI'), findsOneWidget);
    await state.saveScreening(
      ScreeningResult(
        answers: {for (final q in allScreeningQuestions) q.id: false},
        completedAt: DateTime.utc(2026, 10, 7),
      ),
    );
    await settle(tester);

    // Ebe bağlantısı → onay bekleniyor → otomatik onay
    expect(find.text('EBENİZE BAĞLANIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nesta1');
    await tapText(tester, 'BAĞLAN');
    expect(find.text('Onay bekleniyor'), findsOneWidget);
    await settle(tester, 30);

    // Ana sayfa
    expect(find.text('Merhaba, Ayşe'), findsOneWidget);
    expect(find.text('Bugünün Programı'), findsOneWidget);
    expect(find.textContaining('25. hafta'), findsOneWidget);
    expect(state.patient!.consent!.healthDataProcessing, isTrue);

    // Sekmeler
    for (final tab in ['Takip', 'Egzersiz', 'İpuçları', 'Profil']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
    await reveal(tester, find.text('Hesabımı sil'));
    expect(find.text('Hesabımı sil'), findsOneWidget);
    await tester.tap(find.text('Ana Sayfa').last);
    await settle(tester);

    // Rehberli egzersiz seansı: Diyafram Nefesi
    await tapText(tester, diaphragmaticBreathing.name);
    await reveal(tester, find.text('Faydaları'));
    await tapText(tester, 'BAŞLA');
    expect(find.text('BAŞLAMADAN ÖNCE'), findsOneWidget);
    await tapText(tester, 'HİÇBİRİ YOK, DEVAM ET');
    await settle(tester, 20);
    expect(find.text('Hazırlanın'), findsWidgets);

    // Seansı bitir
    await tester.tap(find.text('Bitir').last);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Bitir'),
      ),
    );
    await settle(tester);

    // Özet ve kayıt
    expect(find.text('SEANS ÖZETİ'), findsOneWidget);
    await tapText(tester, '13');
    expect(find.text('Biraz zor'), findsOneWidget);
    await tapText(tester, 'KAYDET');
    await settle(tester);
    expect(state.sessions, hasLength(1));
    expect(state.sessions.single.rpe, 13);
    expect(state.sessions.single.endReason, SessionEndReason.userStopped);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('seans öncesi tehlike belirtisi ebeye bildirilir', (
    tester,
  ) async {
    await boot(tester);
    await state.markWelcomeSeen();
    await repo.register('b@ornek.com', 'gizli123');
    await settle(tester);
    await state.acceptConsent(research: true);
    await state.saveProfile(
      PregnancyProfile(
        fullName: 'Elif Kaya',
        birthDate: DateTime.utc(1990, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
      ),
    );
    await settle(tester);
    await state.saveScreening(
      ScreeningResult(
        answers: {for (final q in allScreeningQuestions) q.id: false},
        completedAt: DateTime.utc(2026, 10, 7),
      ),
    );
    await state.linkMidwife(DemoRepository.demoInviteCode);
    await settle(tester, 35);
    expect(find.text('Merhaba, Elif'), findsOneWidget);
    expect(state.patient!.consent!.researchParticipation, isTrue);

    await tapText(tester, state.todaysProgram[1].name);
    await tapText(tester, 'BAŞLA');
    await tapText(tester, 'Vajinal kanama');
    await tapText(tester, 'BİLDİR');
    expect(
      find.text('Lütfen hemen sağlık kuruluşuna başvurun'),
      findsOneWidget,
    );
    expect(repo.alerts, hasLength(1));
    expect(repo.alerts.single.urgent, isTrue);
    expect(repo.alerts.single.type, AlertType.symptomBeforeSession);
    await tapText(tester, 'ANA SAYFAYA DÖN');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('mutlak kontrendikasyonda program açılmaz', (tester) async {
    await boot(tester);
    await state.markWelcomeSeen();
    await repo.register('c@ornek.com', 'gizli123');
    await settle(tester);
    await state.acceptConsent(research: false);
    await state.saveProfile(
      PregnancyProfile(
        fullName: 'Zehra Ak',
        birthDate: DateTime.utc(1992, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
      ),
    );
    await settle(tester);
    await state.saveScreening(
      ScreeningResult(
        answers: {
          for (final q in allScreeningQuestions) q.id: q.id == 'preeclampsia',
        },
        completedAt: DateTime.utc(2026, 10, 7),
      ),
    );
    await settle(tester);
    expect(find.text('Şu an egzersiz önerilmiyor'), findsOneWidget);
    expect(find.textContaining('Preeklampsi'), findsOneWidget);
  });

  testWidgets('tarama değişince onay yeniden ebeye düşer', (tester) async {
    await boot(tester);
    await state.markWelcomeSeen();
    await repo.register('d@ornek.com', 'gizli123');
    await settle(tester);
    await state.acceptConsent(research: false);
    await state.saveProfile(
      PregnancyProfile(
        fullName: 'Deniz Er',
        birthDate: DateTime.utc(1992, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
      ),
    );
    final noAnswers = {for (final q in allScreeningQuestions) q.id: false};
    await state.saveScreening(
      ScreeningResult(
        answers: noAnswers,
        completedAt: DateTime.utc(2026, 10, 7),
      ),
    );
    await state.linkMidwife('NESTA1');
    await settle(tester, 35);
    expect(state.patient!.clearance.isApproved, isTrue);

    await state.saveScreening(
      ScreeningResult(
        answers: {...noAnswers, 'anemia': true},
        completedAt: DateTime.utc(2026, 10, 7),
      ),
    );
    await settle(tester, 1);
    expect(state.patient!.clearance.status, ClearanceStatus.pending);
    expect(repo.alerts.last.type, AlertType.screeningUpdated);
    // Demo ebe yeniden değerlendirip onaylar.
    await settle(tester, 35);
    expect(state.patient!.clearance.isApproved, isTrue);
  });
}
