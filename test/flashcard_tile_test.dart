import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

final _deck = Deck(
  id: 'deck-1',
  name: 'Komite 1 · Kalp',
  createdAt: DateTime(2026, 7, 16),
);

const _withShortAnswer = Flashcard(
  id: '1',
  question: 'MHC moleküllerinin temel görevi nedir?',
  answer:
      'MHC moleküllerinin temel görevi, antijenleri T hücrelerine sunarak '
      'onların tanınmasını sağlamaktır.',
  shortAnswer: 'Antijen sunumu (T hücrelerine).',
  deckId: 'deck-1',
  topic: 'antijen sunumu',
);

const _legacyWithoutShortAnswer = Flashcard(
  id: '2',
  question: 'Eski kart sorusu?',
  answer: 'Eski kartın tam cevabı.',
  deckId: 'deck-1',
);

Widget _wrap(FlashcardStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const CardListScreen(deckId: 'deck-1'),
    ),
  );
}

void main() {
  testWidgets(
    'kart listesinde önce kısa cevap görünür, uzun cevap gizlidir',
    (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(decks: [_deck], cards: [_withShortAnswer]),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.text('Antijen sunumu (T hücrelerine).'), findsOneWidget);
      expect(
        find.text(
          'MHC moleküllerinin temel görevi, antijenleri T hücrelerine '
          'sunarak onların tanınmasını sağlamaktır.',
        ),
        findsNothing,
      );
      expect(find.text('Açıklamasını gör'), findsOneWidget);
    },
  );

  testWidgets(
    '"Açıklamasını gör" ile listede uzun cevap açılır',
    (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(decks: [_deck], cards: [_withShortAnswer]),
      );
      await tester.pumpWidget(_wrap(store));

      await tester.tap(find.text('Açıklamasını gör'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'MHC moleküllerinin temel görevi, antijenleri T hücrelerine '
          'sunarak onların tanınmasını sağlamaktır.',
        ),
        findsOneWidget,
      );
      expect(find.text('Açıklamasını gör'), findsNothing);
    },
  );

  testWidgets(
    'shortAnswer boş olan eski kartlarda doğrudan uzun cevap gösterilir',
    (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: [_legacyWithoutShortAnswer],
        ),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.text('Eski kartın tam cevabı.'), findsOneWidget);
      expect(find.text('Açıklamasını gör'), findsNothing);
    },
  );

  group('Hocanın Favorisi rozeti', () {
    testWidgets('isHandwritten kartta rozet görünür', (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: [_legacyWithoutShortAnswer.copyWith(isHandwritten: true)],
        ),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.text('Hocanın Favorisi'), findsOneWidget);
    });

    testWidgets('el yazısı olmayan kartta rozet görünmez', (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: [_legacyWithoutShortAnswer],
        ),
      );
      await tester.pumpWidget(_wrap(store));

      expect(find.text('Hocanın Favorisi'), findsNothing);
    });
  });
}
