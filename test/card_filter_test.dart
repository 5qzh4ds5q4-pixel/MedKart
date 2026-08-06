import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/card_filter.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/card_list_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
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

final _deck = Deck(id: 'd1', name: 'Kalp', createdAt: DateTime(2026, 7, 16));

Flashcard _c(String id, CardDifficulty d, String topic) => Flashcard(
  id: id,
  question: 'Q-$id',
  answer: 'A-$id',
  deckId: 'd1',
  difficulty: d,
  topic: topic,
);

final _cards = [
  _c('zor-kalp', CardDifficulty.zor, 'kalp'),
  _c('kolay-kalp', CardDifficulty.kolay, 'kalp'),
  _c('zor-beyin', CardDifficulty.zor, 'beyin'),
];

FlashcardStore _store() => FlashcardStore(
  _NoopGenerator(),
  initialData: LibraryData(decks: [_deck], cards: _cards),
);

Widget _wrap(FlashcardStore store) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(theme: AppTheme.light, home: CardListScreen(deckId: 'd1')),
);

void main() {
  group('CardFilter', () {
    test('boş filtre her karta uyar', () {
      const f = CardFilter();
      expect(f.isActive, isFalse);
      expect(f.apply(_cards).length, 3);
    });

    test('zorluk ve konu kesişimi uygulanır', () {
      const f = CardFilter(
        difficulties: {CardDifficulty.zor},
        topics: {'beyin'},
      );
      final result = f.apply(_cards);
      expect(result.map((c) => c.id), ['zor-beyin']);
    });

    test('aynı boyutta çoklu seçim OR gibi davranır', () {
      const f = CardFilter(
        difficulties: {CardDifficulty.zor, CardDifficulty.kolay},
      );
      expect(f.apply(_cards).length, 3);
    });

    test('sayfa aralığı filtreler ve sayfasız kartları dışlar', () {
      final cards = [
        _c('s5', CardDifficulty.orta, 'x').copyWith(sourcePage: 5),
        _c('s50', CardDifficulty.orta, 'x').copyWith(sourcePage: 50),
        _c('sayfasiz', CardDifficulty.orta, 'x'),
      ];
      const f = CardFilter(minPage: 40, maxPage: 60);
      expect(f.apply(cards).map((c) => c.id), ['s50']);
      expect(f.isActive, isTrue);
    });

    test('forCard yalnızca o id\'ye sahip kartı bırakır', () {
      final f = CardFilter.forCard('zor-beyin');
      expect(f.isActive, isTrue);
      expect(f.apply(_cards).map((c) => c.id), ['zor-beyin']);
    });

    test('withDifficulty/withTopic seçimi açıp kapatır', () {
      var f = const CardFilter();
      f = f.withDifficulty(CardDifficulty.zor, true);
      expect(f.difficulties, {CardDifficulty.zor});
      f = f.withDifficulty(CardDifficulty.zor, false);
      expect(f.isActive, isFalse);
    });

    test('examOnly yalnızca sınav tipi ve öncelikli temel kartları bırakır', () {
      final cards = [
        Flashcard(
          id: 'sinav-arka-plan',
          question: 'Q',
          answer: 'A',
          cardType: CardType.sinav,
          priority: CardPriority.arkaPlan,
        ),
        Flashcard(
          id: 'temel-oncelikli',
          question: 'Q',
          answer: 'A',
          cardType: CardType.temel,
          priority: CardPriority.oncelikli,
        ),
        Flashcard(
          id: 'temel-arka-plan',
          question: 'Q',
          answer: 'A',
          cardType: CardType.temel,
          priority: CardPriority.arkaPlan,
        ),
      ];

      const f = CardFilter(examOnly: true);
      expect(f.isActive, isTrue);
      // Sınav tipi kart, öncelik etiketinden BAĞIMSIZ her zaman kalır.
      expect(
        f.apply(cards).map((c) => c.id).toSet(),
        {'sinav-arka-plan', 'temel-oncelikli'},
      );
    });

    test('withExamOnly true/false isActive\'ı etkiler', () {
      var f = const CardFilter();
      expect(f.isActive, isFalse);
      f = f.withExamOnly(true);
      expect(f.isActive, isTrue);
      f = f.withExamOnly(false);
      expect(f.isActive, isFalse);
    });

    test('handwrittenOnly yalnızca isHandwritten kartları bırakır', () {
      final cards = [
        Flashcard(
          id: 'hw',
          question: 'Q',
          answer: 'A',
          deckId: 'd1',
          isHandwritten: true,
        ),
        Flashcard(id: 'normal', question: 'Q', answer: 'A', deckId: 'd1'),
      ];

      const f = CardFilter(handwrittenOnly: true);
      expect(f.isActive, isTrue);
      expect(f.apply(cards).map((c) => c.id).toList(), ['hw']);
    });

    test('withHandwrittenOnly true/false isActive\'ı etkiler', () {
      var f = const CardFilter();
      expect(f.isActive, isFalse);
      f = f.withHandwrittenOnly(true);
      expect(f.isActive, isTrue);
      expect(f.handwrittenOnly, isTrue);
      f = f.withHandwrittenOnly(false);
      expect(f.isActive, isFalse);
    });
  });

  group('FlashcardStore.studyQueueFor filtreli', () {
    test('yalnızca filtreye uyan kartları kuyruğa alır', () {
      final store = _store();
      final queue = store.studyQueueFor(
        'd1',
        filter: const CardFilter(difficulties: {CardDifficulty.zor}),
      );
      expect(queue.map((c) => c.id).toSet(), {'zor-kalp', 'zor-beyin'});
    });

    test(
      'ignoreDueDate: true, due olmayan kartları da (karışık havuzda) döner',
      () {
        final now = DateTime(2026, 7, 19, 10);
        final store = FlashcardStore(
          _NoopGenerator(),
          initialData: LibraryData(
            decks: [_deck],
            cards: [
              Flashcard(
                id: 'due',
                question: 'Q',
                answer: 'A',
                deckId: 'd1',
                isHandwritten: true,
                repetitions: 1,
                nextReview: now.subtract(const Duration(days: 1)),
              ),
              Flashcard(
                id: 'future',
                question: 'Q',
                answer: 'A',
                deckId: 'd1',
                isHandwritten: true,
                repetitions: 1,
                nextReview: now.add(const Duration(days: 30)),
              ),
              // Karışık havuzda "future" kartın normalde (ignoreDueDate:
              // false) elenmesini kanıtlamak için due olmayan bir kontrol.
            ],
          ),
        );

        final normal = store.studyQueueFor(
          'd1',
          now: now,
          filter: const CardFilter(handwrittenOnly: true),
        );
        expect(normal.map((c) => c.id), ['due']);

        final ignoringDue = store.studyQueueFor(
          'd1',
          now: now,
          filter: const CardFilter(handwrittenOnly: true),
          ignoreDueDate: true,
        );
        expect(ignoringDue.map((c) => c.id).toSet(), {'due', 'future'});
      },
    );
  });

  /// Liste başındaki özet kartı (2026-08-04) dikeyde yer kapladığı için
  /// varsayılan 800×600 yüzeyde son kart ekran dışında kalıyor; kart
  /// görünürlüğünü sınayan testler daha uzun bir yüzey ister.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('filtre çubuğu listeyi daraltır ve temizlenebilir', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(_wrap(_store()));

    // Başta üç kart da görünür.
    expect(find.text('Q-zor-kalp'), findsOneWidget);
    expect(find.text('Q-kolay-kalp'), findsOneWidget);
    expect(find.text('Q-zor-beyin'), findsOneWidget);

    // "Zor" zorluk çipini seç.
    await tester.tap(find.widgetWithText(FilterChip, 'Zor'));
    await tester.pumpAndSettle();

    expect(find.text('Q-zor-kalp'), findsOneWidget);
    expect(find.text('Q-zor-beyin'), findsOneWidget);
    expect(find.text('Q-kolay-kalp'), findsNothing);
    // Çalışma butonu filtre kipine geçer.
    expect(find.textContaining('Filtreyle Çalış'), findsOneWidget);

    // Temizle → hepsi geri gelir.
    await tester.tap(find.text('Temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Q-kolay-kalp'), findsOneWidget);
  });

  testWidgets('uyumsuz kombinasyon boş durum gösterir', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(_wrap(_store()));

    await tester.tap(find.widgetWithText(FilterChip, 'Kolay'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'beyin'));
    await tester.pumpAndSettle();

    // kolay ∩ beyin = hiçbir kart.
    expect(find.text('Bu filtreyle kart yok'), findsOneWidget);

    await tester.tap(find.text('Filtreyi temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Q-zor-beyin'), findsOneWidget);
  });
}
