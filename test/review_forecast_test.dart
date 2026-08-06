import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/screens/stats_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/srs/srs_engine.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/widgets/review_forecast_chart.dart';
import 'package:provider/provider.dart';

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

/// Perşembe — gün adı etiketlerini sabitlemek için bilinçli seçildi.
final _now = DateTime(2026, 8, 6, 10, 30);

final _deck = Deck(id: 'd1', name: 'Kalp', createdAt: DateTime(2026, 7, 1));

Flashcard _card(String id, {DateTime? nextReview}) => Flashcard(
  id: id,
  question: 'q$id',
  answer: 'a$id',
  deckId: _deck.id,
  nextReview: nextReview,
);

/// [_now]'dan [days] gün sonrası, günün ortasında bir saatle (saat bileşeni
/// hesaba karışmamalı).
DateTime _inDays(int days) => _now.add(Duration(days: days, hours: 3));

List<int> _counts(List<ReviewForecastDay> days) =>
    days.map((d) => d.count).toList();

void main() {
  group('SrsEngine.reviewForecast', () {
    test('7 gün döner, ilk gün bugün', () {
      final days = SrsEngine.reviewForecast(const [], _now);

      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 8, 6));
      expect(days.last.day, DateTime(2026, 8, 12));
      expect(_counts(days), [0, 0, 0, 0, 0, 0, 0]);
    });

    test('kartları doğru güne dağıtır (saat bileşeni önemsiz)', () {
      final days = SrsEngine.reviewForecast([
        _card('bugün-1', nextReview: DateTime(2026, 8, 6, 23, 59)),
        _card('bugün-2', nextReview: DateTime(2026, 8, 6, 0, 1)),
        _card('yarın', nextReview: _inDays(1)),
        _card('6-gün', nextReview: _inDays(6)),
      ], _now);

      expect(_counts(days), [2, 1, 0, 0, 0, 0, 1]);
    });

    test('gecikmiş kartlar BUGÜNE eklenir, kaybolmaz', () {
      final days = SrsEngine.reviewForecast([
        _card('dün', nextReview: _now.subtract(const Duration(days: 1))),
        _card('geçen-ay', nextReview: DateTime(2026, 7, 2)),
        _card('bugün', nextReview: DateTime(2026, 8, 6, 8)),
      ], _now);

      expect(days.first.count, 3);
      expect(_counts(days).reduce((a, b) => a + b), 3);
    });

    test('pencere dışı (7. gün ve sonrası) sayılmaz', () {
      final days = SrsEngine.reviewForecast([
        _card('6-gün', nextReview: _inDays(6)),
        _card('7-gün', nextReview: _inDays(7)),
        _card('30-gün', nextReview: _inDays(30)),
      ], _now);

      expect(_counts(days).reduce((a, b) => a + b), 1);
      expect(days.last.count, 1);
    });

    test('nextReview null olan yeni kartlar sayılmaz', () {
      final days = SrsEngine.reviewForecast([
        _card('yeni-1'),
        _card('yeni-2'),
        _card('planlı', nextReview: _inDays(2)),
      ], _now);

      expect(_counts(days), [0, 0, 1, 0, 0, 0, 0]);
    });
  });

  group('ReviewForecastChart etiketleri ve bağlam cümlesi', () {
    test('ilk iki gün Bugün/Yarın, sonrası gün kısaltması', () {
      final days = SrsEngine.reviewForecast(const [], _now);
      final labels = [
        for (var i = 0; i < days.length; i++)
          ReviewForecastChart.shortLabel(i, days[i].day),
      ];

      // 6 Ağustos 2026 Perşembe → Bugün, Yarın, Cmt, Paz, Pzt, Sal, Çrş.
      expect(labels, ['Bugün', 'Yarın', 'Cmt', 'Paz', 'Pzt', 'Sal', 'Çrş']);
    });

    test('en yoğun günü vurgulayan alt not', () {
      final days = SrsEngine.reviewForecast([
        for (var i = 0; i < 12; i++) _card('c$i', nextReview: _inDays(4)),
        _card('tek', nextReview: _inDays(1)),
      ], _now);

      // 4 gün sonrası = 10 Ağustos 2026, Pazartesi.
      expect(
        ReviewForecastChart.captionFor(days),
        'En yoğun gün: Pazartesi, 12 kart.',
      );
    });

    test('bugün en yoğunsa "bugün" der', () {
      final days = SrsEngine.reviewForecast([
        _card('gecikmiş', nextReview: DateTime(2026, 7, 1)),
        _card('bugün', nextReview: DateTime(2026, 8, 6)),
      ], _now);

      expect(ReviewForecastChart.captionFor(days), 'En yoğun gün: bugün, 2 kart.');
    });

    test('hiç tekrar yoksa yük olmadığını söyler', () {
      final days = SrsEngine.reviewForecast(const [], _now);

      expect(
        ReviewForecastChart.captionFor(days),
        'Önümüzdeki 7 günde tekrara düşecek kart yok.',
      );
      expect(ReviewForecastChart.busiestIndex(days), isNull);
    });

    test('eşitlikte en YAKIN gün en yoğun sayılır', () {
      final days = SrsEngine.reviewForecast([
        _card('a', nextReview: _inDays(1)),
        _card('b', nextReview: _inDays(5)),
      ], _now);

      expect(ReviewForecastChart.busiestIndex(days), 1);
    });
  });

  group('StatsScreen önümüzdeki 7 gün bölümü', () {
    Future<void> pump(WidgetTester tester, List<Flashcard> cards) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: cards,
          studyLog: StudyLog.fromJson({'2026-08-06': 3}),
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => StudySettings()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: StatsScreen(now: _now),
          ),
        ),
      );
    }

    testWidgets('hiç kart yokken bölüm gizli', (tester) async {
      await pump(tester, const []);

      expect(find.text('Önümüzdeki 7 gün'), findsNothing);
      expect(find.byType(ReviewForecastChart), findsNothing);
      // Komşu bölüm etkilenmedi.
      expect(find.text('Konu başarısı'), findsOneWidget);
    });

    testWidgets('kart varken grafik, gün etiketleri ve alt not görünür', (
      tester,
    ) async {
      await pump(tester, [
        _card('gecikmiş', nextReview: DateTime(2026, 7, 20)),
        _card('bugün', nextReview: DateTime(2026, 8, 6, 20)),
        _card('yarın', nextReview: _inDays(1)),
      ]);

      expect(find.text('Önümüzdeki 7 gün'), findsOneWidget);
      expect(find.byType(ReviewForecastChart), findsOneWidget);
      // "Bugün" ekranın üstündeki seri metriğinde de geçiyor — grafiğin
      // içindekini arıyoruz.
      Finder inChart(String text) => find.descendant(
        of: find.byType(ReviewForecastChart),
        matching: find.text(text),
      );
      expect(inChart('Bugün'), findsOneWidget);
      expect(inChart('Yarın'), findsOneWidget);
      // Gecikmiş + bugün = 2, yarın = 1.
      expect(find.text('En yoğun gün: bugün, 2 kart.'), findsOneWidget);
    });

    testWidgets('nextReview hiç olmayan kartlarda bölüm görünür ama yük yok', (
      tester,
    ) async {
      await pump(tester, [_card('yeni-1'), _card('yeni-2')]);

      expect(find.byType(ReviewForecastChart), findsOneWidget);
      expect(
        find.text('Önümüzdeki 7 günde tekrara düşecek kart yok.'),
        findsOneWidget,
      );
    });
  });
}
