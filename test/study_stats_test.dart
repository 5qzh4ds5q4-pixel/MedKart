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
import 'package:medcard/widgets/study_heatmap.dart';
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

class _FakeStorage implements CardStorage {
  LibraryData saved = const LibraryData();

  @override
  Future<LibraryData> load() async => saved;

  @override
  Future<void> save(LibraryData data) async => saved = data;
}

final _deck = Deck(id: 'd1', name: 'Kalp', createdAt: DateTime(2026, 7, 16));

Flashcard _card(
  String id, {
  String topic = '',
  int repetitions = 0,
  int lapses = 0,
}) {
  return Flashcard(
    id: id,
    question: 'q$id',
    answer: 'a$id',
    deckId: _deck.id,
    topic: topic,
    repetitions: repetitions,
    lapses: lapses,
  );
}

void main() {
  group('StudyLog', () {
    test('recordStudy o günün sayacını artırır', () {
      final now = DateTime(2026, 7, 16, 22);
      final log = const StudyLog().recordStudy(now).recordStudy(now);
      expect(log.countOn(now), 2);
      expect(log.total, 2);
      expect(log.activeDays, 1);
    });

    test('currentStreak ardışık günleri sayar', () {
      final log = StudyLog.fromJson({
        '2026-07-14': 3,
        '2026-07-15': 1,
        '2026-07-16': 5,
      });
      expect(log.currentStreak(DateTime(2026, 7, 16)), 3);
    });

    test('bugün boşsa seri düne kadar sayılır (tolerans)', () {
      final log = StudyLog.fromJson({'2026-07-14': 1, '2026-07-15': 2});
      expect(log.currentStreak(DateTime(2026, 7, 16)), 2);
    });

    test('araya boş gün girince seri kopar', () {
      final log = StudyLog.fromJson({'2026-07-14': 1, '2026-07-16': 1});
      // 15 boş: bugünden (16) geriye yalnızca 16 sayılır.
      expect(log.currentStreak(DateTime(2026, 7, 16)), 1);
    });

    test('JSON turunu atlatır', () {
      final log = const StudyLog()
          .recordStudy(DateTime(2026, 7, 15))
          .recordStudy(DateTime(2026, 7, 16));
      final restored = StudyLog.fromJson(log.toJson());
      expect(restored.countOn(DateTime(2026, 7, 16)), 1);
      expect(restored.total, 2);
    });
  });

  group('FlashcardStore çalışma geçmişi', () {
    test('reviewCard günlük sayaca yazar ve kalıcılaştırır', () {
      final storage = _FakeStorage();
      final store = FlashcardStore(
        _NoopGenerator(),
        storage: storage,
        initialData: LibraryData(decks: [_deck], cards: [_card('1')]),
      );
      final now = DateTime(2026, 7, 16, 9);

      store.reviewCard('1', ReviewGrade.orta, now: now);

      expect(store.studyLog.countOn(now), 1);
      expect(storage.saved.studyLog.countOn(now), 1);
    });
  });

  group('SrsEngine.topicStats', () {
    test('başarı oranı = 1 − zayıflık; en zayıf önce, çalışılmamış sonda', () {
      final cards = [
        _card('1', topic: 'güçlü', repetitions: 4, lapses: 1), // %80
        _card('2', topic: 'zayıf', repetitions: 2, lapses: 3), // %40
        _card('3', topic: 'yeni'), // hiç çalışılmadı
      ];

      final stats = SrsEngine.topicStats(cards);

      expect(stats.map((s) => s.topic).toList(), ['zayıf', 'güçlü', 'yeni']);
      expect(stats[0].successPercent, 40);
      expect(stats[1].successPercent, 80);
      expect(stats[2].studied, isFalse);
    });
  });

  testWidgets('istatistik ekranı seri, heatmap ve konu oranını gösterir', (
    tester,
  ) async {
    // Uzun test yüzeyi: ekranın tamamı (seri + takvim + konu çubuğu) tek
    // ekranda kalsın, kaydırma mekaniği bu testin konusu değil.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deck],
        cards: [_card('1', topic: 'ileti sistemi', repetitions: 2, lapses: 3)],
        studyLog: StudyLog.fromJson({'2026-07-15': 2, '2026-07-16': 4}),
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
          home: StatsScreen(now: DateTime(2026, 7, 16)),
        ),
      ),
    );

    // 2026-08-17'den beri bu bölümler varsayılan KAPALI katlanabilir
    // satırlar (bkz. stats_screen.dart) — içeriklerini görmek için önce
    // açmak gerekiyor.
    await tester.tap(find.text('Genel özet'));
    await tester.tap(find.text('Çalışma takvimi'));
    await tester.tap(find.text('Konu başarısı'));
    await tester.pumpAndSettle();

    // Metrik kartı: "Günlük seri" etiketi + "2 gün" değeri.
    expect(find.text('Günlük seri'), findsOneWidget);
    expect(find.text('2 gün'), findsOneWidget);
    expect(find.byType(StudyHeatmap), findsOneWidget);
    expect(find.text('ileti sistemi'), findsOneWidget);
    expect(find.text('%40'), findsOneWidget);
  });
}
