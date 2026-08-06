import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/screens/deck_list_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/state/theme_controller.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/utils/require_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final _deckA = Deck(
  id: 'deck-a',
  name: 'Komite 1 · Kalp',
  createdAt: DateTime(2026, 7, 16),
);
final _deckB = Deck(
  id: 'deck-b',
  name: 'Komite 2 · Solunum',
  createdAt: DateTime(2026, 7, 16),
);

Widget _wrap(FlashcardStore store, {StudySettings? studySettings}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider.value(value: studySettings ?? StudySettings()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const DeckListScreen()),
  );
}

/// Gerçek "bugün"e göre son [days] günün her birine [perDay] kart çalışılmış
/// gibi bir [StudyLog] üretir (tempo hesabı gerçek `DateTime.now()` kullanır,
/// bkz. `SrsEngine.examPaceWarning`/`FlashcardStore.examPaceWarning`).
StudyLog _recentStudyLog({required int days, required int perDay}) {
  final counts = <String, int>{};
  final now = DateTime.now();
  for (var i = 1; i <= days; i++) {
    final d = now.subtract(Duration(days: i));
    final key =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    counts[key] = perDay;
  }
  return StudyLog(counts);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // "Bugün Çalış" girişe (requireAuth) tabi — bu dosya deste listesi
    // davranışını test ediyor, giriş ekranını değil.
    debugRequireAuthSignedInOverride = true;
  });
  tearDown(() => debugRequireAuthSignedInOverride = null);

  testWidgets('kart yokken "Bugün Çalış" bannerı gösterilmez', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [_deckA]),
    );
    await tester.pumpWidget(_wrap(store));

    expect(find.text('Bugün Çalış'), findsNothing);
  });

  testWidgets('birden fazla desteden kartlar birleşik günlük kuyrukta sayılır',
      (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deckA, _deckB],
        cards: const [
          Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-a'),
          Flashcard(id: '2', question: 'S2', answer: 'C', deckId: 'deck-b'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    expect(find.text('Bugün Çalış'), findsOneWidget);
    expect(find.text('2 kart hazır'), findsOneWidget);
  });

  testWidgets('bannera dokununca tüm destelerden birleşik oturum açılır',
      (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deckA, _deckB],
        cards: const [
          Flashcard(id: '1', question: 'Soru A', answer: 'Cevap A', deckId: 'deck-a'),
          Flashcard(id: '2', question: 'Soru B', answer: 'Cevap B', deckId: 'deck-b'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    await tester.tap(find.text('Bugün Çalış'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 2'), findsOneWidget);
  });

  testWidgets('günlük yeni kart limiti düşürülünce banner sayısı azalır',
      (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deckA],
        cards: [
          for (var i = 0; i < 5; i++)
            Flashcard(id: 'n$i', question: 'S$i', answer: 'C$i', deckId: 'deck-a'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    expect(find.text('5 kart hazır'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('2 kart hazır'), findsOneWidget);
  });

  testWidgets('geçersiz limit değeri hata mesajı gösterir ve kaydetmez',
      (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [_deckA]),
    );
    await tester.pumpWidget(_wrap(store));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('arası bir değer gir'),
      findsOneWidget,
    );
  });

  group('sınav tarihi', () {
    testWidgets('sınav tarihi belirlenince deste kartında görünür',
        (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(decks: [_deckA]),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.textContaining('Sınav'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sınav tarihi belirle'));
      await tester.pumpAndSettle();

      // Tarih seçiciyi varsayılan (ön seçili) tarihle onayla.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(store.deckById('deck-a')!.hasExamDate, isTrue);
      expect(find.textContaining('Sınav'), findsOneWidget);
      expect(find.textContaining('gün kaldı'), findsOneWidget);
    });

    testWidgets('sınav tarihi kaldırılınca rozet kaybolur', (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(decks: [_deckA]),
      );
      store.setDeckExamDate(
        'deck-a',
        DateTime.now().add(const Duration(days: 10)),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.textContaining('Sınav'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sınav tarihini kaldır'));
      await tester.pumpAndSettle();

      expect(store.deckById('deck-a')!.hasExamDate, isFalse);
      expect(find.textContaining('Sınav'), findsNothing);
    });

    testWidgets('sınava 3 günden az kalınca yoğun tekrar rozeti gösterilir',
        (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(decks: [_deckA]),
      );
      store.setDeckExamDate('deck-a', DateTime.now().add(const Duration(days: 2)));
      await tester.pumpWidget(_wrap(store));

      expect(find.textContaining('yoğun tekrar modu'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets(
      'yoğun tekrar modundaki destenin yeni kartları banner sayısında limitsiz görünür',
      (tester) async {
        final store = FlashcardStore(
          _NoopGenerator(),
          initialData: LibraryData(
            decks: [_deckA],
            cards: [
              for (var i = 0; i < 5; i++)
                Flashcard(
                  id: 'n$i',
                  question: 'S$i',
                  answer: 'C$i',
                  deckId: 'deck-a',
                ),
            ],
          ),
        );
        store.setDeckExamDate('deck-a', DateTime.now().add(const Duration(days: 1)));
        await tester.pumpWidget(_wrap(store));

        // Varsayılan günlük limit (20) zaten 5'i geçiyor ama yoğun tekrar
        // modunda limite hiç bakılmadığını doğrulamak için önce limiti
        // düşürelim.
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.tune_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '2');
        await tester.tap(find.text('Kaydet'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('5 kart hazır'), findsOneWidget);
      },
    );
  });

  group('sınav tempo uyarısı', () {
    testWidgets(
      'yeterli çalışma geçmişi olmayan kullanıcıda uyarı hiç çıkmaz',
      (tester) async {
        final deck = Deck(
          id: 'deck-a',
          name: 'Komite 1 · Kalp',
          createdAt: DateTime.now(),
          examDate: DateTime.now().add(const Duration(days: 2)),
        );
        final store = FlashcardStore(
          _NoopGenerator(),
          initialData: LibraryData(
            decks: [deck],
            cards: [
              for (var i = 0; i < 50; i++)
                Flashcard(id: 'c$i', question: 'S$i', answer: 'C$i', deckId: 'deck-a'),
            ],
            // Hiç çalışma geçmişi yok → tempo hesaplanamaz.
          ),
        );
        await tester.pumpWidget(_wrap(store));

        expect(find.textContaining('kart çalışabilirsin'), findsNothing);
        expect(find.text('Öncelikli Kartlara Odaklan'), findsNothing);
      },
    );

    testWidgets('yetişebilir durumda uyarı çıkmaz', (tester) async {
      final deck = Deck(
        id: 'deck-a',
        name: 'Komite 1 · Kalp',
        createdAt: DateTime.now(),
        examDate: DateTime.now().add(const Duration(days: 30)),
      );
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [deck],
          cards: [
            for (var i = 0; i < 10; i++)
              Flashcard(id: 'c$i', question: 'S$i', answer: 'C$i', deckId: 'deck-a'),
          ],
          // Günde 20 kart tempo × 30 gün = rahatça yeter.
          studyLog: _recentStudyLog(days: 7, perDay: 20),
        ),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.textContaining('kart çalışabilirsin'), findsNothing);
    });

    testWidgets('yetişmez durumda uyarı çıkar', (tester) async {
      final deck = Deck(
        id: 'deck-a',
        name: 'Komite 1 · Kalp',
        createdAt: DateTime.now(),
        examDate: DateTime.now().add(const Duration(days: 2)),
      );
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [deck],
          cards: [
            for (var i = 0; i < 50; i++)
              Flashcard(id: 'c$i', question: 'S$i', answer: 'C$i', deckId: 'deck-a'),
          ],
          // Günde 1 kart tempo × 2 gün (+tolerans) — 50 kart hiç yetişmez.
          studyLog: _recentStudyLog(days: 3, perDay: 1),
        ),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.textContaining('kart çalışabilirsin'), findsOneWidget);
      expect(find.textContaining('Komite 1 · Kalp'), findsWidgets);
      expect(find.text('Öncelikli Kartlara Odaklan'), findsOneWidget);
    });

    testWidgets(
      'butona basınca öncelikli mod açılır ve kuyruk sıralaması değişir',
      (tester) async {
        final deck = Deck(
          id: 'deck-a',
          name: 'Komite 1 · Kalp',
          createdAt: DateTime.now(),
          examDate: DateTime.now().add(const Duration(days: 2)),
        );
        final cards = [
          Flashcard(
            id: 'bg',
            question: 'Arka plan sorusu',
            answer: 'C',
            deckId: 'deck-a',
            priority: CardPriority.arkaPlan,
          ),
          Flashcard(
            id: 'p',
            question: 'Öncelikli soru',
            answer: 'C',
            deckId: 'deck-a',
            priority: CardPriority.oncelikli,
          ),
          for (var i = 0; i < 50; i++)
            Flashcard(id: 'filler$i', question: 'S$i', answer: 'C$i', deckId: 'deck-a'),
        ];
        final store = FlashcardStore(
          _NoopGenerator(),
          initialData: LibraryData(
            decks: [deck],
            cards: cards,
            studyLog: _recentStudyLog(days: 3, perDay: 1),
          ),
        );
        final settings = StudySettings();

        await tester.pumpWidget(_wrap(store, studySettings: settings));

        expect(settings.isPriorityMode('deck-a'), isFalse);

        await tester.tap(find.text('Öncelikli Kartlara Odaklan'));
        await tester.pumpAndSettle();

        expect(settings.isPriorityMode('deck-a'), isTrue);
        expect(find.text('Normal Moda Dön'), findsOneWidget);

        final after = store
            .dailyQueue(priorityModeDeckIds: settings.priorityModeDeckIds)
            .map((c) => c.id)
            .toList();
        expect(after.indexOf('p') < after.indexOf('bg'), isTrue);
      },
    );
  });

  group('En Zayıf Konu Antrenmanı', () {
    testWidgets('yeterli/güvenilir veri yoksa banner görünmez', (
      tester,
    ) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deckA],
          cards: [
            // Eşik 5 kart — yalnızca 4 tane, yetersiz.
            for (var i = 0; i < 4; i++)
              Flashcard(
                id: 'c$i',
                question: 'S$i',
                answer: 'C$i',
                deckId: 'deck-a',
                topic: 'zayif',
                repetitions: 1,
                lapses: 3,
              ),
          ],
        ),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.textContaining('En zor konun'), findsNothing);
    });

    testWidgets(
      'yeterli veri varsa doğru konu adı ve kart sayısıyla banner görünür',
      (tester) async {
        final store = FlashcardStore(
          _NoopGenerator(),
          initialData: LibraryData(
            decks: [_deckA],
            cards: [
              for (var i = 0; i < 5; i++)
                Flashcard(
                  id: 'c$i',
                  question: 'S$i',
                  answer: 'C$i',
                  deckId: 'deck-a',
                  topic: 'zayif konu',
                  repetitions: 1,
                  lapses: 3,
                ),
            ],
          ),
        );
        await tester.pumpWidget(_wrap(store));

        expect(find.text('En zor konun: zayif konu'), findsOneWidget);
        expect(find.text('5 kart · Antrenman Yap'), findsOneWidget);
      },
    );

    testWidgets(
      'tıklanınca yalnızca o konudaki kartlarla, due olmayanlar dahil, oturum açılır',
      (tester) async {
        final now = DateTime.now();
        final store = FlashcardStore(
          _NoopGenerator(),
          initialData: LibraryData(
            decks: [_deckA],
            cards: [
              for (var i = 0; i < 4; i++)
                Flashcard(
                  id: 'w$i',
                  question: 'Zayıf soru $i?',
                  answer: 'C',
                  deckId: 'deck-a',
                  topic: 'zayif',
                  repetitions: 1,
                  lapses: 3,
                ),
              Flashcard(
                id: 'w-future',
                question: 'Zayıf soru uzak?',
                answer: 'C',
                deckId: 'deck-a',
                topic: 'zayif',
                repetitions: 1,
                lapses: 3,
                // Bilerek uzak bir tarihe planlı — normal kuyrukta hiç
                // görünmezdi, bu antrenman modu due'ya hiç bakmamalı.
                nextReview: now.add(const Duration(days: 60)),
              ),
              Flashcard(
                id: 'other',
                question: 'Başka konu?',
                answer: 'C',
                deckId: 'deck-a',
                topic: 'guclu',
                repetitions: 5,
              ),
            ],
          ),
        );
        await tester.pumpWidget(_wrap(store));

        await tester.tap(find.text('En zor konun: zayif'));
        await tester.pumpAndSettle();

        // 5 "zayif" kart da (due olsun olmasın) oturumda; "guclu" hiç yok.
        expect(find.text('0 / 5'), findsOneWidget);
        expect(find.text('Başka konu?'), findsNothing);
      },
    );
  });
}
