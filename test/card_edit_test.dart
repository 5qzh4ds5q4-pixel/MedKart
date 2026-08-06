import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/card_list_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/utils/require_auth.dart';
import 'package:medcard/widgets/card_chips.dart';
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

final _deck = Deck(
  id: 'deck-1',
  name: 'Komite 1 · Kalp',
  createdAt: DateTime(2026, 7, 16),
);

Flashcard _card({
  String question = 'AV düğümün görevi?',
  String answer = 'İletiyi geciktirmek.',
  String note = '',
  String? originalQuestion,
  String? originalAnswer,
  bool flagged = false,
}) {
  return Flashcard(
    id: '1',
    question: question,
    answer: answer,
    deckId: _deck.id,
    topic: 'ileti sistemi',
    note: note,
    originalQuestion: originalQuestion,
    originalAnswer: originalAnswer,
    flagged: flagged,
    repetitions: 3,
    lapses: 1,
    intervalDays: 10,
  );
}

FlashcardStore _store(Flashcard card) {
  return FlashcardStore(
    _NoopGenerator(),
    initialData: LibraryData(decks: [_deck], cards: [card]),
  );
}

Widget _wrap(FlashcardStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      theme: AppTheme.light,
      home: CardListScreen(deckId: _deck.id),
    ),
  );
}

Future<void> _openEditDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  // Bu dosyanın testleri kart düzenleme akışını (giriş gerektirir, bkz.
  // requireAuth) test ediyor, giriş ekranını değil — sabit "girişli" varsay.
  setUp(() => debugRequireAuthSignedInOverride = true);
  tearDown(() => debugRequireAuthSignedInOverride = null);

  group('Flashcard.withEdits — orijinal koruma', () {
    test('ilk düzenleme AI orijinalini yakalar', () {
      final edited = _card().withEdits(
        question: 'AV düğümün görevi?',
        answer: 'Ventriküllerin dolmasına zaman tanımak.',
        shortAnswer: '',
        difficulty: CardDifficulty.orta,
        topic: 'ileti sistemi',
        note: '',
        flagged: false,
      );

      expect(edited.isEdited, isTrue);
      expect(edited.originalAnswer, 'İletiyi geciktirmek.');
      // Soru değişmediyse orijinali yakalanmaz.
      expect(edited.originalQuestion, isNull);
      // SRS ilerlemesi korunur.
      expect(edited.repetitions, 3);
    });

    test('ikinci düzenleme AI orijinalini korur, kullanıcı ara sürümünü değil', () {
      final first = _card().withEdits(
        question: 'AV düğümün görevi?',
        answer: 'Ara sürüm.',
        shortAnswer: '',
        difficulty: CardDifficulty.orta,
        topic: 'ileti sistemi',
        note: '',
        flagged: false,
      );
      final second = first.withEdits(
        question: 'AV düğümün görevi?',
        answer: 'Son sürüm.',
        shortAnswer: '',
        difficulty: CardDifficulty.orta,
        topic: 'ileti sistemi',
        note: '',
        flagged: false,
      );

      expect(second.answer, 'Son sürüm.');
      expect(second.originalAnswer, 'İletiyi geciktirmek.');
    });

    test('shortAnswer düzenlemesi orijinal snapshot\'a dahil edilmez', () {
      final edited = _card().withEdits(
        question: 'AV düğümün görevi?',
        answer: 'İletiyi geciktirmek.',
        shortAnswer: 'Gecikme sağlamak',
        difficulty: CardDifficulty.orta,
        topic: 'ileti sistemi',
        note: '',
        flagged: false,
      );

      expect(edited.shortAnswer, 'Gecikme sağlamak');
      // question/answer değişmedi -> isEdited hâlâ false (shortAnswer
      // değişikliği tek başına "AI'dan düzenlendi" saymaz).
      expect(edited.isEdited, isFalse);

      final reverted = edited.revertedToOriginal();
      // originalShortAnswer diye bir alan yok -> revert kısa cevabı
      // ETKİLEMEZ, kullanıcının son girdiği hâlde kalır.
      expect(reverted.shortAnswer, 'Gecikme sağlamak');
    });

    test('revertedToOriginal metni geri alır, not/işaret/SRS korunur', () {
      final edited = _card(note: 'benim notum', flagged: true).withEdits(
        question: 'Değişmiş soru?',
        answer: 'Değişmiş cevap.',
        shortAnswer: '',
        difficulty: CardDifficulty.zor,
        topic: 'ileti sistemi',
        note: 'benim notum',
        flagged: true,
      );

      final reverted = edited.revertedToOriginal();

      expect(reverted.question, 'AV düğümün görevi?');
      expect(reverted.answer, 'İletiyi geciktirmek.');
      expect(reverted.isEdited, isFalse);
      expect(reverted.note, 'benim notum');
      expect(reverted.flagged, isTrue);
      expect(reverted.repetitions, 3);
    });

    test('not, işaret ve orijinaller JSON turunu atlatır', () {
      final card = _card(
        note: 'mnemonik',
        originalQuestion: 'AI soru',
        originalAnswer: 'AI cevap',
        flagged: true,
      );
      final restored = Flashcard.fromJson(card.toJson());

      expect(restored.note, 'mnemonik');
      expect(restored.originalQuestion, 'AI soru');
      expect(restored.originalAnswer, 'AI cevap');
      expect(restored.flagged, isTrue);
      expect(restored.isEdited, isTrue);
    });
  });

  group('FlashcardStore.flaggedCards', () {
    test('yalnızca işaretli kartları döner', () {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: [
            _card(flagged: true),
            const Flashcard(id: '2', question: 'q', answer: 'a', deckId: 'deck-1'),
          ],
        ),
      );
      expect(store.flaggedCards.length, 1);
      expect(store.flaggedCards.first.flagged, isTrue);
    });
  });

  testWidgets('düzenlemede not + hata işareti kaydedilir ve kartta görünür', (
    tester,
  ) async {
    final store = _store(_card());
    await tester.pumpWidget(_wrap(store));
    await _openEditDialog(tester);

    // Alan sırası: Soru(0), Kısa cevap(1), Cevap(2), Not(3), Konu(4).
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Ventriküllerin dolmasına zaman tanımak.',
    );
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'SÜT: Sinüs → Üçlü → Truncus',
    );

    await tester.ensureVisible(find.text('Bu kartta hata var'));
    await tester.tap(find.text('Bu kartta hata var'));
    await tester.pump();

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final saved = store.cardById('1')!;
    expect(saved.note, 'SÜT: Sinüs → Üçlü → Truncus');
    expect(saved.flagged, isTrue);
    expect(saved.isEdited, isTrue);
    expect(saved.originalAnswer, 'İletiyi geciktirmek.');

    // Kartta göstergeler görünür.
    expect(find.byType(MnemonicNote), findsOneWidget);
    expect(find.byType(EditedChip), findsOneWidget);
    expect(find.byType(FlaggedChip), findsOneWidget);
  });

  testWidgets('"AI orijinaline dön" düzenlemeyi geri alır', (tester) async {
    final store = _store(
      _card(question: 'Kullanıcı sorusu?', originalQuestion: 'AI sorusu?'),
    );
    await tester.pumpWidget(_wrap(store));
    await _openEditDialog(tester);

    expect(find.text('AI orijinaline dön'), findsOneWidget);
    await tester.ensureVisible(find.text('AI orijinaline dön'));
    await tester.tap(find.text('AI orijinaline dön'));
    await tester.pumpAndSettle();

    final saved = store.cardById('1')!;
    expect(saved.question, 'AI sorusu?');
    expect(saved.isEdited, isFalse);
    expect(find.byType(EditedChip), findsNothing);
  });
}
