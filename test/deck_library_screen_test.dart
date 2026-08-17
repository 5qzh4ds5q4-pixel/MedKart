import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/card_list_screen.dart';
import 'package:medcard/screens/deck_library_screen.dart';
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

Widget _wrap(FlashcardStore store, {Widget home = const DeckLibraryScreen()}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => StudySettings()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugRequireAuthSignedInOverride = true;
  });
  tearDown(() => debugRequireAuthSignedInOverride = null);

  testWidgets('tüm desteleri listeler', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [_deckA, _deckB]),
    );
    await tester.pumpWidget(_wrap(store));

    expect(find.text('Komite 1 · Kalp'), findsOneWidget);
    expect(find.text('Komite 2 · Solunum'), findsOneWidget);
  });

  testWidgets('özet satırı deste ve kart sayısını gösterir', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deckA, _deckB],
        cards: const [
          Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-a'),
          Flashcard(id: '2', question: 'S2', answer: 'C', deckId: 'deck-a'),
          Flashcard(id: '3', question: 'S3', answer: 'C', deckId: 'deck-b'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    final summary = tester.widget<Text>(
      find.byKey(DeckLibraryScreen.summaryKey),
    );
    expect(summary.data, '2 deste · 3 kart');
  });

  testWidgets('her deste kendi kart/tekrar sayısını gösterir', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deckA, _deckB],
        cards: const [
          Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-a'),
          Flashcard(id: '2', question: 'S2', answer: 'C', deckId: 'deck-a'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    // deck-a: hiç çalışılmamış 2 kart → ikisi de tekrara hazır.
    expect(find.text('2 kart · 2 tekrara hazır'), findsOneWidget);
    // deck-b: hiç kartı yok.
    expect(find.text('Boş deste'), findsOneWidget);
  });

  testWidgets('kartı olmayan destede yüzde gösterilmez', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(
        decks: [_deckA, _deckB],
        cards: const [
          Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-a'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    // Yalnızca kartı olan deste için yüzde çıkar (deckReadiness boş desteyi
    // hiç döndürmüyor — "%0" göstermek yanıltıcı olurdu).
    expect(find.textContaining('%'), findsOneWidget);
    expect(find.text('%0'), findsOneWidget);
  });

  testWidgets('sınav tarihi olan deste kalan günü gösterir', (tester) async {
    final examDate = DateTime.now().add(const Duration(days: 20));
    final deck = Deck(
      id: 'deck-a',
      name: 'Komite 1 · Kalp',
      createdAt: DateTime(2026, 7, 16),
      examDate: examDate,
    );
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [deck]),
    );
    await tester.pumpWidget(_wrap(store));

    expect(find.textContaining('gün kaldı'), findsOneWidget);
  });

  testWidgets('desteye dokununca kart listesi açılır', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [_deckA, _deckB]),
    );
    await tester.pumpWidget(_wrap(store));

    await tester.tap(find.text('Komite 2 · Solunum'));
    await tester.pumpAndSettle();

    expect(find.byType(CardListScreen), findsOneWidget);
  });

  testWidgets('hiç deste yoksa boş durum gösterilir', (tester) async {
    final store = FlashcardStore(_NoopGenerator());
    await tester.pumpWidget(_wrap(store));

    expect(find.byKey(DeckLibraryScreen.emptyStateKey), findsOneWidget);
    expect(find.text('Henüz deste yok'), findsOneWidget);
  });

  testWidgets('deste menüsünden silinince listeden düşer', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [_deckA, _deckB]),
    );
    await tester.pumpWidget(_wrap(store));

    // İkinci destenin "..." menüsü.
    await tester.tap(find.byTooltip('Deste işlemleri').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    // Onay diyaloğundaki "Sil" butonu.
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Komite 2 · Solunum'), findsNothing);
    expect(find.text('Komite 1 · Kalp'), findsOneWidget);
  });

  testWidgets('dashboard sidebarındaki "Destelerim" bu ekranı açar', (
    tester,
  ) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [_deckA]),
    );
    await tester.pumpWidget(_wrap(store, home: const DeckListScreen()));

    expect(find.byType(DeckLibraryScreen), findsNothing);

    await tester.tap(find.byTooltip('Destelerim'));
    await tester.pumpAndSettle();

    expect(find.byType(DeckLibraryScreen), findsOneWidget);
  });
}
