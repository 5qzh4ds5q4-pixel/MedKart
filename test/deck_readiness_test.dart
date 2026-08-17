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

Deck _deck(String id, String name, {DateTime? examDate}) =>
    Deck(id: id, name: name, createdAt: DateTime(2026, 7, 1), examDate: examDate);

Flashcard _card(
  String id, {
  required String deckId,
  int repetitions = 0,
  int lapses = 0,
}) => Flashcard(
  id: id,
  question: 'q$id',
  answer: 'a$id',
  deckId: deckId,
  repetitions: repetitions,
  lapses: lapses,
);

/// [deckId] destesine [count] kart üretir; ilk [ready] tanesi eşiği geçer.
List<Flashcard> _cards(String deckId, {required int count, required int ready}) => [
  for (var i = 0; i < count; i++)
    _card(
      '$deckId-$i',
      deckId: deckId,
      repetitions: i < ready ? SrsEngine.difficultyKolayRepetitions : 0,
    ),
];

void main() {
  group('SrsEngine.isWellLearned', () {
    test('eşiğin altı hazır değil, eşik ve üstü hazır', () {
      final threshold = SrsEngine.difficultyKolayRepetitions;
      expect(
        SrsEngine.isWellLearned(_card('a', deckId: 'd', repetitions: threshold - 1)),
        isFalse,
      );
      expect(
        SrsEngine.isWellLearned(_card('b', deckId: 'd', repetitions: threshold)),
        isTrue,
      );
      expect(
        SrsEngine.isWellLearned(_card('c', deckId: 'd', repetitions: threshold + 5)),
        isTrue,
      );
    });
  });

  group('"iyi öğrenilmiş" tanımı tempo uyarısı ile hazırlık arasında AYNI', () {
    // Bu grup özelliğin sözleşmesi: iki hesap TEK fonksiyondan besleniyor.
    // Biri değişip diğeri değişmezse buradaki testler kırılır.
    test('tempo uyarısındaki "kalan" = hazırlıktaki "hazır olmayan"', () {
      final deck = _deck('d1', 'Kalp', examDate: DateTime(2026, 7, 20));
      // 10 kartın 4'ü eşiği geçmiş → 6 kalan, %40 hazır.
      final cards = _cards('d1', count: 10, ready: 4);

      final warning = SrsEngine.examPaceWarning(
        deck: deck,
        deckCards: cards,
        dailyPace: 0.5, // düşük tempo → uyarı kesin çıksın
        now: DateTime(2026, 7, 16),
      );
      final readiness = SrsEngine.deckReadiness([deck], cards).single;

      expect(warning, isNotNull);
      expect(readiness.readyCards, 4);
      expect(readiness.totalCards, 10);
      expect(readiness.readyPercent, 40);
      // Asıl garanti: iki taraf aynı kartları aynı şekilde bölüyor.
      expect(
        warning!.remainingCards,
        readiness.totalCards - readiness.readyCards,
      );
    });

    test('çok unutulmuş kart eşiği geçse de İKİ tarafta da "öğrenilmiş" DEĞİL', () {
      // 2026-08-04'te `lapses == 0` şartı eklendi: bu kart deriveDifficulty'ye
      // göre "zor" (lapses >= 3) ve artık hazırlık/tempo hesabında da
      // öğrenilmiş sayılmıyor — iki kavram aynı tanımdan besleniyor.
      final deck = _deck('d1', 'Kalp', examDate: DateTime(2026, 7, 20));
      final cards = [
        _card(
          'çok-unutulan',
          deckId: 'd1',
          repetitions: SrsEngine.difficultyKolayRepetitions,
          lapses: 7,
        ),
      ];

      expect(SrsEngine.deriveDifficulty(cards.single), CardDifficulty.zor);
      expect(SrsEngine.isWellLearned(cards.single), isFalse);
      expect(SrsEngine.deckReadiness([deck], cards).single.readyPercent, 0);

      // Aynı kart tempo hesabında da "kalan" sayılıyor → düşük tempoda uyarı
      // çıkar (eskiden bu senaryoda uyarı hiç çıkmıyordu).
      final warning = SrsEngine.examPaceWarning(
        deck: deck,
        deckCards: cards,
        dailyPace: 0.1,
        now: DateTime(2026, 7, 16),
      );
      expect(warning, isNotNull);
      expect(warning!.remainingCards, 1);
    });

    test('tek bir unutma bile kartı "öğrenilmiş" olmaktan çıkarır', () {
      final threshold = SrsEngine.difficultyKolayRepetitions;
      expect(
        SrsEngine.isWellLearned(
          _card('temiz', deckId: 'd', repetitions: threshold, lapses: 0),
        ),
        isTrue,
      );
      expect(
        SrsEngine.isWellLearned(
          _card('tek-unutma', deckId: 'd', repetitions: threshold, lapses: 1),
        ),
        isFalse,
      );
    });
  });

  group('SrsEngine.deckReadiness', () {
    test('en DÜŞÜK hazırlık en üstte', () {
      final decks = [
        _deck('iyi', 'İyi'),
        _deck('kötü', 'Kötü'),
        _deck('orta', 'Orta'),
      ];
      final cards = [
        ..._cards('iyi', count: 4, ready: 4), // %100
        ..._cards('kötü', count: 4, ready: 1), // %25
        ..._cards('orta', count: 4, ready: 2), // %50
      ];

      final result = SrsEngine.deckReadiness(decks, cards);

      expect(result.map((r) => r.deckName).toList(), ['Kötü', 'Orta', 'İyi']);
      expect(result.map((r) => r.readyPercent).toList(), [25, 50, 100]);
    });

    test('kartı olmayan deste listeye hiç girmez', () {
      final decks = [_deck('dolu', 'Dolu'), _deck('boş', 'Boş')];
      final cards = _cards('dolu', count: 2, ready: 1);

      final result = SrsEngine.deckReadiness(decks, cards);

      expect(result, hasLength(1));
      expect(result.single.deckName, 'Dolu');
    });

    test('hiç deste/kart yoksa boş liste', () {
      expect(SrsEngine.deckReadiness(const [], const []), isEmpty);
      expect(SrsEngine.deckReadiness([_deck('d', 'Boş')], const []), isEmpty);
    });

    test('hiç çalışılmamış deste %0 ama listede kalır', () {
      final result = SrsEngine.deckReadiness(
        [_deck('d', 'Yeni')],
        _cards('d', count: 5, ready: 0),
      );

      expect(result.single.readyPercent, 0);
      expect(result.single.readyCards, 0);
      expect(result.single.totalCards, 5);
    });
  });

  group('StatsScreen deste hazırlığı bölümü', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<Deck> decks,
      required List<Flashcard> cards,
    }) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: decks,
          cards: cards,
          studyLog: StudyLog.fromJson({'2026-07-16': 3}),
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
    }

    testWidgets('kart yoksa bölüm başlığıyla birlikte gizli', (tester) async {
      await pump(tester, decks: [_deck('d', 'Boş deste')], cards: const []);

      expect(find.text('Deste hazırlığı'), findsNothing);
      expect(find.text('Boş deste'), findsNothing);
      // Komşu bölümler etkilenmedi.
      expect(find.text('Çalışma takvimi'), findsOneWidget);
      expect(find.text('Konu başarısı'), findsOneWidget);
    });

    testWidgets('yüzde, kart sayısı ve sıra ekranda doğru', (tester) async {
      await pump(
        tester,
        decks: [_deck('a', 'Anatomi'), _deck('b', 'Biyokimya')],
        cards: [
          ..._cards('a', count: 4, ready: 3), // %75
          ..._cards('b', count: 5, ready: 1), // %20
        ],
      );

      // 2026-08-17'den beri varsayılan KAPALI katlanabilir satır — bkz.
      // stats_screen.dart.
      await tester.tap(find.text('Deste hazırlığı'));
      await tester.pumpAndSettle();

      expect(find.text('Deste hazırlığı'), findsOneWidget);
      expect(find.text('%75 hazır'), findsOneWidget);
      expect(find.text('3/4 kart'), findsOneWidget);
      expect(find.text('%20 hazır'), findsOneWidget);
      expect(find.text('1/5 kart'), findsOneWidget);

      // En düşük hazırlık üstte: Biyokimya, Anatomi'den yukarıda olmalı.
      final biyokimya = tester.getTopLeft(find.text('Biyokimya')).dy;
      final anatomi = tester.getTopLeft(find.text('Anatomi')).dy;
      expect(biyokimya, lessThan(anatomi));
    });
  });
}
