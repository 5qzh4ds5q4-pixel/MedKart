import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/screens/stats_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/widgets/daily_goal_ring.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OPSİYONEL GÜNLÜK HEDEF (2026-08-04): istatistik ekranındaki "Bugün"
/// kartının hedefli/hedefsiz iki hâli + halkanın %100'de kilitlenmesi.
/// Hedef hiçbir kuyruk/SRS davranışını etkilemez, yalnızca bu kartı besler.

class _NoopGenerator implements FlashcardGenerator {
  @override
  Future<List<Flashcard>> generate(
    String sourceText, {
    List<MediaAttachment> media = const [],
  }) async => const [];

  @override
  Future<List<Flashcard>> generateForPage(
    String pageText,
    int sourcePage, {
    String? imageBase64,
    String imageMimeType = 'image/png',
  }) async => const [];
}

final _today = DateTime(2026, 7, 16);
final _deck = Deck(id: 'd1', name: 'Kalp', createdAt: _today);

/// [todayCount] kart bugün çalışılmış bir kütüphaneyle [StatsScreen]'i kurar.
Future<void> _pumpStats(
  WidgetTester tester, {
  required int todayCount,
  int? goal,
  Size surface = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final store = FlashcardStore(
    _NoopGenerator(),
    initialData: LibraryData(
      decks: [_deck],
      cards: [
        Flashcard(id: '1', question: 'q', answer: 'a', deckId: _deck.id),
      ],
      studyLog: StudyLog.fromJson({'2026-07-16': todayCount}),
    ),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(
          create: (_) => StudySettings(initialDailyGoal: goal),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: StatsScreen(now: _today),
      ),
    ),
  );
}

/// "Bugün" kartının İÇİNDEKİ metni arar. Gerekli: aynı metin ("Bugün")
/// "Önümüzdeki 7 gün" grafiğinin ilk sütununda da geçiyor.
Finder _inTodayCard(String text) => find.descendant(
  of: find.byKey(StatsScreen.metricTodayKey),
  matching: find.text(text),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DailyGoalRing.percentFor — %100 tavanı', () {
    test('normal ilerleme oranı yüzdeye çevrilir', () {
      expect(DailyGoalRing.percentFor(5, 20), 25);
      expect(DailyGoalRing.percentFor(10, 20), 50);
      expect(DailyGoalRing.percentFor(19, 20), 95);
    });

    test('tam hedefte %100', () {
      expect(DailyGoalRing.percentFor(20, 20), 100);
    });

    test('hedefi AŞAN değerler %100\'de kilitlenir (halka taşmaz)', () {
      expect(DailyGoalRing.percentFor(21, 20), 100);
      expect(DailyGoalRing.percentFor(60, 20), 100);
      expect(DailyGoalRing.percentFor(1000, 1), 100);
    });

    test('hiç çalışılmadıysa 0', () {
      expect(DailyGoalRing.percentFor(0, 20), 0);
      expect(DailyGoalRing.percentFor(-3, 20), 0);
    });

    test('geçersiz hedef (0/negatif) çökmez, 0 döner', () {
      expect(DailyGoalRing.percentFor(5, 0), 0);
      expect(DailyGoalRing.percentFor(5, -10), 0);
    });

    test('isComplete percentFor ile aynı eşiği kullanır', () {
      expect(DailyGoalRing.isComplete(19, 20), isFalse);
      expect(DailyGoalRing.isComplete(20, 20), isTrue);
      expect(DailyGoalRing.isComplete(99, 20), isTrue);
    });
  });

  group('StudySettings.dailyGoal', () {
    test('varsayılan null — hedef opsiyonel', () {
      final settings = StudySettings();
      expect(settings.dailyGoal, isNull);
      expect(settings.hasDailyGoal, isFalse);
    });

    test('hedef ayarlanır ve dinleyicileri uyarır', () {
      final settings = StudySettings();
      var notified = 0;
      settings.addListener(() => notified++);

      settings.setDailyGoal(30);

      expect(settings.dailyGoal, 30);
      expect(settings.hasDailyGoal, isTrue);
      expect(notified, 1);
    });

    test('null vermek hedefi temizler', () {
      final settings = StudySettings(initialDailyGoal: 30);
      settings.setDailyGoal(null);
      expect(settings.dailyGoal, isNull);
    });

    test('0/negatif değer de "hedef yok" sayılır', () {
      expect(StudySettings(initialDailyGoal: 0).dailyGoal, isNull);
      expect(StudySettings(initialDailyGoal: -5).dailyGoal, isNull);

      final settings = StudySettings(initialDailyGoal: 30);
      settings.setDailyGoal(0);
      expect(settings.dailyGoal, isNull);
    });

    test('aralık dışı değer sınıra çekilir', () {
      final settings = StudySettings();
      settings.setDailyGoal(99999);
      expect(settings.dailyGoal, StudySettings.maxDailyGoal);
    });

    test('aynı değer tekrar verilirse uyarı yapılmaz', () {
      final settings = StudySettings(initialDailyGoal: 30);
      var notified = 0;
      settings.addListener(() => notified++);

      settings.setDailyGoal(30);

      expect(notified, 0);
    });

    test('hedef günlük YENİ KART LİMİTİNDEN bağımsızdır', () {
      // İkisi ayrı anahtarlarda ayrı kavramlar; biri diğerini ezmemeli.
      final settings = StudySettings(initialDailyNewCardLimit: 20);
      settings.setDailyGoal(50);
      expect(settings.dailyNewCardLimit, 20);
      expect(settings.dailyGoal, 50);
    });

    test('storage anahtarı yeni kart limitininkinden farklı', () {
      expect(
        StudySettings.dailyGoalStorageKey,
        isNot(StudySettings.storageKey),
      );
    });
  });

  group('StatsScreen "Bugün" kartı', () {
    testWidgets('hedef AYARSIZ: halka yok, sade sayı + nazik ipucu', (
      tester,
    ) async {
      await _pumpStats(tester, todayCount: 7);

      expect(_inTodayCard('Bugün'), findsOneWidget);
      expect(find.text('7 kart'), findsOneWidget);
      expect(find.byType(DailyGoalRing), findsNothing);
      expect(
        find.text('Ayarlar\'dan günlük hedef belirleyebilirsin.'),
        findsOneWidget,
      );
    });

    testWidgets('hedef AYARLI: halka ve yüzde görünür', (tester) async {
      await _pumpStats(tester, todayCount: 5, goal: 20);

      expect(find.text('5 kart'), findsOneWidget);
      expect(find.byType(DailyGoalRing), findsOneWidget);
      expect(find.text('%25'), findsOneWidget);
      expect(find.text('Günlük hedef: 5/20 kart'), findsOneWidget);
      // Hedef varken ipucu gösterilmez.
      expect(
        find.text('Ayarlar\'dan günlük hedef belirleyebilirsin.'),
        findsNothing,
      );
    });

    testWidgets('hedef TAM tamamlandı: %100 + tamamlanma mesajı', (
      tester,
    ) async {
      await _pumpStats(tester, todayCount: 20, goal: 20);

      expect(find.text('%100'), findsOneWidget);
      expect(find.text('Günlük hedefini tamamladın 🎉'), findsOneWidget);
      // Yüzde metni yerine tamamlanma mesajı gösterilir.
      expect(find.text('Günlük hedef: 20/20 kart'), findsNothing);
    });

    testWidgets('hedef AŞILDI: halka %100\'de kalır, %240 yazmaz', (
      tester,
    ) async {
      await _pumpStats(tester, todayCount: 48, goal: 20);

      expect(find.text('48 kart'), findsOneWidget);
      expect(find.text('%100'), findsOneWidget);
      expect(find.text('%240'), findsNothing);
      expect(find.text('Günlük hedefini tamamladın 🎉'), findsOneWidget);
    });

    testWidgets('bugün hiç çalışılmadıysa hedefli kartta %0 gösterilir', (
      tester,
    ) async {
      await _pumpStats(tester, todayCount: 0, goal: 20);

      expect(find.text('0 kart'), findsOneWidget);
      expect(find.text('%0'), findsOneWidget);
      expect(find.text('Günlük hedef: 0/20 kart'), findsOneWidget);
    });
  });

  group('StatsScreen üst 4 metrik kartı', () {
    testWidgets('dördü de etiketleriyle görünür', (tester) async {
      await _pumpStats(tester, todayCount: 3, goal: 10);

      expect(find.text('Günlük seri'), findsOneWidget);
      expect(find.text('Toplam tekrar'), findsOneWidget);
      expect(find.text('Aktif gün'), findsOneWidget);
      expect(_inTodayCard('Bugün'), findsOneWidget);

      // Dördü de ayrı kart olarak kuruluyor.
      expect(find.byKey(StatsScreen.metricStreakKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricTotalKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricActiveDaysKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricTodayKey), findsOneWidget);
    });

    testWidgets(
      'aktif gün "son 30 gün" İDDİA ETMEZ (hesap tüm zamanlar)',
      (tester) async {
        await _pumpStats(tester, todayCount: 3);

        // Alt metinler 2026-08-05'te kaldırıldı (görsel sadeleştirme), yani
        // eski "Çalıştığın toplam gün sayısı." cümlesi artık yok. Testin asıl
        // amacı korunuyor: ekran hiçbir yerde pencereli bir sayım İDDİA
        // ETMEMELİ — `StudyLog.activeDays` tüm zamanları sayıyor.
        expect(find.text('Çalıştığın toplam gün sayısı.'), findsNothing);
        expect(find.textContaining('30 gün'), findsNothing);
      },
    );

    testWidgets('rakamı tekrarlayan açıklama cümleleri kaldırıldı', (
      tester,
    ) async {
      await _pumpStats(tester, todayCount: 3, goal: 10);

      expect(find.text('Serini koru, devam et!'), findsNothing);
      expect(find.text('Bugüne kadar çalıştığın kart sayısı.'), findsNothing);

      // "Bugün" kartının alt metni VERİ taşıdığı için duruyor.
      expect(find.text('Günlük hedef: 3/10 kart'), findsOneWidget);
    });
  });

  group('ızgara düzeni — dar ekran', () {
    // Bu testlerin asıl işi TAŞMA (RenderFlex overflow) yakalamak: dar
    // ekranda kartlar yan yana sığmazsa Flutter test sırasında hata atar.
    testWidgets('mobil genişlikte dört metrik kartı da taşmadan kurulur', (
      tester,
    ) async {
      await _pumpStats(
        tester,
        todayCount: 5,
        goal: 20,
        surface: const Size(380, 900),
      );

      expect(find.byKey(StatsScreen.metricStreakKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricTotalKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricActiveDaysKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricTodayKey), findsOneWidget);
      expect(find.byType(DailyGoalRing), findsOneWidget);
    });

    testWidgets('mobilde metrikler 2x2 dizilir (4\'ü yan yana değil)', (
      tester,
    ) async {
      await _pumpStats(
        tester,
        todayCount: 5,
        surface: const Size(380, 900),
      );

      final streak = tester.getTopLeft(
        find.byKey(StatsScreen.metricStreakKey),
      );
      final total = tester.getTopLeft(find.byKey(StatsScreen.metricTotalKey));
      final active = tester.getTopLeft(
        find.byKey(StatsScreen.metricActiveDaysKey),
      );

      // 1. satır: seri | toplam (aynı hizada, yan yana)
      expect(total.dy, streak.dy);
      expect(total.dx, greaterThan(streak.dx));
      // 2. satır: aktif gün alta iner
      expect(active.dy, greaterThan(streak.dy));
      expect(active.dx, streak.dx);
    });

    testWidgets('geniş ekranda dördü tek satırda yan yana', (tester) async {
      await _pumpStats(tester, todayCount: 5);

      final streak = tester.getTopLeft(
        find.byKey(StatsScreen.metricStreakKey),
      );
      final today = tester.getTopLeft(find.byKey(StatsScreen.metricTodayKey));

      expect(today.dy, streak.dy);
      expect(today.dx, greaterThan(streak.dx));
    });

    testWidgets('dar ekranda bölümler tek sütuna düşer', (tester) async {
      await _pumpStats(
        tester,
        todayCount: 5,
        surface: const Size(380, 900),
      );

      final takvim = tester.getTopLeft(find.text('Çalışma takvimi'));
      final konu = tester.getTopLeft(find.text('Konu başarısı'));

      // Yan yana değil, alt alta.
      expect(konu.dy, greaterThan(takvim.dy));
    });
  });
}
