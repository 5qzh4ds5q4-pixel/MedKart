import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/exam_sim_quiz_screen.dart';
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

FlashcardStore _storeWith(List<Flashcard> cards) => FlashcardStore(
  _NoopGenerator(),
  initialData: LibraryData(decks: [_deck], cards: cards),
);

McqOption _opt(String text) =>
    McqOption(text: text, explanation: 'Açıklama: $text', sourceCardId: 'c');

McqQuestion _q(String question, {int correctIndex = 0}) => McqQuestion(
  question: question,
  options: [_opt('Şık bir'), _opt('Şık iki'), _opt('Şık üç'), _opt('Şık dört')],
  correctIndex: correctIndex,
  sourceCardId: 'c',
);

Widget _wrap(FlashcardStore store, Widget child) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(theme: AppTheme.light, home: child),
);

void main() {
  group('süre biçimlendirme', () {
    test('pozitif süre mm:ss', () {
      expect(ExamSimQuizScreen.formatSeconds(0), '00:00');
      expect(ExamSimQuizScreen.formatSeconds(65), '01:05');
      expect(ExamSimQuizScreen.formatSeconds(600), '10:00');
    });

    test('negatif süre eksi işaretiyle', () {
      expect(ExamSimQuizScreen.formatSeconds(-5), '-00:05');
      expect(ExamSimQuizScreen.formatSeconds(-75), '-01:15');
    });
  });

  testWidgets('şık seçimi işaretlenir ama doğru/yanlış GÖSTERİLMEZ',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _storeWith(const []),
        ExamSimQuizScreen(
          questions: [_q('Soru 1?', correctIndex: 0)],
          targetSeconds: 60,
        ),
      ),
    );

    // Yanlış şıkka dokun (correctIndex 0, "Şık iki" yanlış).
    await tester.tap(find.text('Şık iki'));
    await tester.pump();

    // Seçim işaretlenir (radio checked ikonu görünür) ama doğru/yanlış
    // ikonu (check_circle/cancel) sınav sırasında ASLA çıkmaz.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ileri/geri gezinme ve cevap değiştirme çalışır',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _storeWith(const []),
        ExamSimQuizScreen(
          questions: [_q('Soru 1?'), _q('Soru 2?')],
          targetSeconds: 120,
        ),
      ),
    );

    expect(find.text('Soru 1?'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // Önceki ilk soruda pasif.
    final prev = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Önceki'),
    );
    expect(prev.onPressed, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sonraki'));
    await tester.pump();
    expect(find.text('Soru 2?'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    // Son soruda Sonraki pasif.
    final next = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Sonraki'),
    );
    expect(next.onPressed, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('süre dolunca sınav kesilmez, uyarı gösterilir', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _storeWith(const []),
        ExamSimQuizScreen(
          questions: [_q('Soru 1?')],
          targetSeconds: 1,
        ),
      ),
    );

    expect(find.textContaining('Süre doldu'), findsNothing);

    // 2 saniye ilerlet (hedef 1 sn) → süre dolar.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Süre doldu'), findsOneWidget);
    // Sınav hâlâ açık: şıklar ve bitir butonu duruyor.
    expect(find.text('Sınavı Bitir'), findsOneWidget);
    expect(find.text('Soru 1?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tümü cevaplanınca "Sınavı Bitir" onaysız sonuç ekranına geçer',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _storeWith(const []),
        ExamSimQuizScreen(
          questions: [_q('Soru 1?', correctIndex: 0)],
          targetSeconds: 60,
        ),
      ),
    );

    await tester.tap(find.text('Şık bir')); // correctIndex 0 = doğru şık
    await tester.pump();

    await tester.tap(find.text('Sınavı Bitir'));
    await tester.pumpAndSettle();

    // Sonuç ekranı: tek soru doğru → %100 (büyük puan + konu barında).
    expect(find.text('%100'), findsWidgets);
    expect(find.text('1 / 1 doğru'), findsOneWidget);
  });

  testWidgets('boş soru varsa bitirmeden önce onay ister', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _storeWith(const []),
        ExamSimQuizScreen(
          questions: [_q('Soru 1?'), _q('Soru 2?')],
          targetSeconds: 120,
        ),
      ),
    );

    await tester.tap(find.text('Sınavı Bitir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('soru boş bırakıldı'), findsOneWidget);

    // Vazgeç: sınavda kal.
    await tester.tap(find.widgetWithText(TextButton, 'Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('Sınavı Bitir'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
