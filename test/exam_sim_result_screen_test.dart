import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/exam_result.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/exam_sim_result_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/mcq_generator.dart';
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

final _deck = Deck(id: 'd', name: 'Deste', createdAt: DateTime(2026, 7, 20));

/// Farklı konularda, ileride tekrar zamanı gelen kartlar (öne çekme testi
/// için `nextReview` geleceğe kurulu).
Flashcard _card(String id, String topic) => Flashcard(
  id: id,
  question: '$topic sorusu?',
  answer: '$topic açıklaması.',
  shortAnswer: '$topic yanıt',
  deckId: 'd',
  topic: topic,
  repetitions: 2,
  intervalDays: 10,
  nextReview: DateTime(2026, 8, 1),
);

FlashcardStore _storeWith(List<Flashcard> cards) => FlashcardStore(
  _NoopGenerator(),
  initialData: LibraryData(decks: [_deck], cards: cards),
);

McqQuestion _q(String cardId, String topic, {required int correctIndex}) =>
    McqQuestion(
      question: '$topic sorusu?',
      options: [
        McqOption(
          text: 'Şık bir',
          explanation: '$topic açıklaması.',
          sourceCardId: cardId,
        ),
        McqOption(text: 'Şık iki', explanation: 'x', sourceCardId: 'z'),
        McqOption(text: 'Şık üç', explanation: 'y', sourceCardId: 'z'),
        McqOption(text: 'Şık dört', explanation: 'z', sourceCardId: 'z'),
      ],
      correctIndex: correctIndex,
      sourceCardId: cardId,
    );

Widget _wrap(FlashcardStore store, Widget child) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(theme: AppTheme.light, home: child),
);

void main() {
  testWidgets('genel puan ve doğru sayısı doğru hesaplanır', (tester) async {
    final store = _storeWith([_card('c1', 'kalp'), _card('c2', 'böbrek')]);
    await tester.pumpWidget(
      _wrap(
        store,
        ExamSimResultScreen(
          questions: [
            _q('c1', 'kalp', correctIndex: 0),
            _q('c2', 'böbrek', correctIndex: 0),
          ],
          selections: const [0, 2], // 1 doğru, 1 yanlış
          elapsedSeconds: 90,
          targetSeconds: 120,
        ),
      ),
    );

    expect(find.text('%50'), findsOneWidget);
    expect(find.text('1 / 2 doğru'), findsOneWidget);
  });

  testWidgets('süre hedefin altında/üstünde doğru raporlanır', (tester) async {
    final store = _storeWith([_card('c1', 'kalp')]);
    await tester.pumpWidget(
      _wrap(
        store,
        ExamSimResultScreen(
          questions: [_q('c1', 'kalp', correctIndex: 0)],
          selections: const [0],
          elapsedSeconds: 90,
          targetSeconds: 60,
        ),
      ),
    );

    expect(find.textContaining('üstünde'), findsOneWidget);
  });

  testWidgets('konu kırılımı ve yanlış soru listesi gösterilir',
      (tester) async {
    final store = _storeWith([_card('c1', 'kalp'), _card('c2', 'böbrek')]);
    await tester.pumpWidget(
      _wrap(
        store,
        ExamSimResultScreen(
          questions: [
            _q('c1', 'kalp', correctIndex: 0),
            _q('c2', 'böbrek', correctIndex: 0),
          ],
          selections: const [0, 1], // böbrek yanlış
          elapsedSeconds: 60,
          targetSeconds: 120,
        ),
      ),
    );

    expect(find.text('Konu kırılımı'), findsOneWidget);
    expect(find.text('Yanlış yaptıkların (1)'), findsOneWidget);
    // Yanlış kartın açıklaması (uzun answer) görünür.
    expect(find.textContaining('böbrek açıklaması.'), findsWidgets);
    expect(find.textContaining('Doğru cevap: Şık bir'), findsOneWidget);
  });

  testWidgets('boş bırakılan soru yanlış sayılır ve "Boş bırakıldı" gösterir',
      (tester) async {
    final store = _storeWith([_card('c1', 'kalp')]);
    await tester.pumpWidget(
      _wrap(
        store,
        ExamSimResultScreen(
          questions: [_q('c1', 'kalp', correctIndex: 0)],
          selections: const [null],
          elapsedSeconds: 30,
          targetSeconds: 60,
        ),
      ),
    );

    expect(find.text('%0'), findsWidgets); // büyük puan + konu barı
    expect(find.text('0 / 1 doğru'), findsOneWidget);
    expect(find.text('Boş bırakıldı'), findsOneWidget);
  });

  testWidgets('"Yanlışları tekrar çalışmaya ekle" nextReview\'ü öne çeker, '
      'SM-2 bozulmaz', (tester) async {
    final store = _storeWith([_card('c1', 'kalp'), _card('c2', 'böbrek')]);
    final before = store.cardById('c2')!;

    await tester.pumpWidget(
      _wrap(
        store,
        ExamSimResultScreen(
          questions: [
            _q('c1', 'kalp', correctIndex: 0),
            _q('c2', 'böbrek', correctIndex: 0),
          ],
          selections: const [0, 1], // c2 (böbrek) yanlış
          elapsedSeconds: 60,
          targetSeconds: 120,
        ),
      ),
    );

    final addButton = find.text('Yanlışları tekrar çalışmaya ekle');
    await tester.scrollUntilVisible(addButton, 200);
    await tester.tap(addButton);
    await tester.pump();

    final c1 = store.cardById('c1')!;
    final c2 = store.cardById('c2')!;

    // c2 yanlıştı → due (nextReview öne çekildi); c1 doğruydu → dokunulmadı.
    expect(c2.isDue(DateTime.now()), isTrue);
    expect(c1.nextReview, DateTime(2026, 8, 1));

    // SM-2 durumu korunur.
    expect(c2.repetitions, before.repetitions);
    expect(c2.intervalDays, before.intervalDays);
    expect(c2.easeFactor, before.easeFactor);
    expect(c2.lapses, before.lapses);

    // Buton bir kez basılınca pasifleşir.
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Çalışmaya eklendi'),
    );
    expect(btn.onPressed, isNull);
  });

  group('önceki denemeyle kıyas', () {
    /// [correct] tanesi doğru işaretlenmiş 4 soruluk bir sınav ekranı.
    Widget screenWith(FlashcardStore store, {required int correct}) =>
        _wrap(
          store,
          ExamSimResultScreen(
            questions: [
              _q('c1', 'kalp', correctIndex: 0),
              _q('c2', 'kalp', correctIndex: 0),
              _q('c3', 'böbrek', correctIndex: 0),
              _q('c4', 'böbrek', correctIndex: 0),
            ],
            // İlk [correct] soruda doğru şık (0), kalanında yanlış (1).
            selections: [for (var i = 0; i < 4; i++) i < correct ? 0 : 1],
            elapsedSeconds: 100,
            targetSeconds: 240,
          ),
        );

    FlashcardStore storeWithHistory(List<ExamResult> results) => FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deck],
        cards: [
          _card('c1', 'kalp'),
          _card('c2', 'kalp'),
          _card('c3', 'böbrek'),
          _card('c4', 'böbrek'),
        ],
        examResults: results,
      ),
    );

    ExamResult previous({required int correct, required int total}) =>
        ExamResult(
          id: 'onceki',
          takenAt: DateTime(2026, 7, 30),
          correctCount: correct,
          totalQuestions: total,
        );

    testWidgets('ilk denemede kıyas bloğu HİÇ gösterilmez', (tester) async {
      final store = storeWithHistory(const []);
      await tester.pumpWidget(screenWith(store, correct: 2));
      await tester.pumpAndSettle();

      expect(find.textContaining('Geçen denemen'), findsNothing);
      expect(find.textContaining('daha iyisin'), findsNothing);
      // Mevcut sonuç ekranı aynen durur.
      expect(find.text('%50'), findsOneWidget);
      expect(find.text('Konu kırılımı'), findsOneWidget);
    });

    testWidgets('ilk denemede bile sonuç geçmişe kaydedilir', (tester) async {
      final store = storeWithHistory(const []);
      await tester.pumpWidget(screenWith(store, correct: 3));
      await tester.pumpAndSettle();

      expect(store.examResults, hasLength(1));
      final saved = store.examResults.single;
      expect(saved.correctCount, 3);
      expect(saved.totalQuestions, 4);
      expect(saved.percent, 75);
      expect(saved.deckId, isNull);
      // Konu kırılımı da kaydedilir: kalp 2/2, böbrek 1/2.
      final topics = {for (final t in saved.topicScores) t.topic: t};
      expect(topics['kalp']!.correct, 2);
      expect(topics['böbrek']!.correct, 1);
    });

    testWidgets('gelişmede pozitif mesaj gösterilir', (tester) async {
      // Önceki %25 → şimdi %75.
      final store = storeWithHistory([previous(correct: 1, total: 4)]);
      await tester.pumpWidget(screenWith(store, correct: 3));
      await tester.pumpAndSettle();

      expect(
        find.text('Geçen denemene göre %50 daha iyisin.'),
        findsOneWidget,
      );
      expect(find.textContaining('Önceki deneme %25'), findsOneWidget);
    });

    testWidgets('gerilemede yumuşak dilli mesaj gösterilir', (tester) async {
      // Önceki %100 → şimdi %25.
      final store = storeWithHistory([previous(correct: 4, total: 4)]);
      await tester.pumpWidget(screenWith(store, correct: 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('%75 daha iyiydin'), findsOneWidget);
      expect(find.textContaining('biraz zorlandın'), findsOneWidget);
    });

    testWidgets('fark yokken "aynı seviye" mesajı gösterilir', (tester) async {
      // Önceki %50 → şimdi %50.
      final store = storeWithHistory([previous(correct: 2, total: 4)]);
      await tester.pumpWidget(screenWith(store, correct: 2));
      await tester.pumpAndSettle();

      expect(find.text('Geçen denemenle aynı seviyedesin.'), findsOneWidget);
    });

    testWidgets('kıyas kaydetmeden ÖNCEKİ sonuçla yapılır (kendisiyle değil)', (
      tester,
    ) async {
      final store = storeWithHistory([previous(correct: 1, total: 4)]);
      await tester.pumpWidget(screenWith(store, correct: 3));
      await tester.pumpAndSettle();

      // Yeni sonuç eklendi ama kıyas eskisiyle yapıldı.
      expect(store.examResults, hasLength(2));
      expect(store.examResults.first.percent, 75);
      expect(
        find.text('Geçen denemene göre %50 daha iyisin.'),
        findsOneWidget,
      );
    });
  });
}
