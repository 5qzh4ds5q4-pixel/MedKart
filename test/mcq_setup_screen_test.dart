import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/mcq_setup_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/utils/require_auth.dart';
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

final _deckA = Deck(id: 'a', name: 'Anatomi', createdAt: DateTime(2026, 7, 20));
final _deckB = Deck(
  id: 'b',
  name: 'Biyokimya',
  createdAt: DateTime(2026, 7, 21),
);

List<Flashcard> _cards({
  required String deckId,
  required String topic,
  int count = 5,
}) => [
  for (var i = 1; i <= count; i++)
    Flashcard(
      id: '$deckId-$topic-$i',
      question: '$topic sorusu $i?',
      answer: '$topic cevabı $i.',
      shortAnswer: '$topic yanıt $i',
      deckId: deckId,
      topic: topic,
    ),
];

/// Anatomi: "kol kasları" + "ortak konu"; Biyokimya: "enzim kinetiği" +
/// "ortak konu". "ortak konu" iki destede de var — deste değişiminde geçerli
/// seçimin KORUNDUĞUNU, geçersizin düştüğünü ayırt edebilmek için.
final _library = [
  ..._cards(deckId: 'a', topic: 'kol kasları'),
  ..._cards(deckId: 'a', topic: 'ortak konu'),
  ..._cards(deckId: 'b', topic: 'enzim kinetiği'),
  ..._cards(deckId: 'b', topic: 'ortak konu'),
];

Future<void> _pump(WidgetTester tester, {String? initialDeckId}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final store = FlashcardStore(
    _NoopGenerator(),
    initialData: LibraryData(decks: [_deckA, _deckB], cards: _library),
  );

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        theme: AppTheme.light,
        home: McqSetupScreen(initialDeckId: initialDeckId),
      ),
    ),
  );
}

/// Kapsam listesindeki bir satırın radyo durumu.
bool _isTopicSelected(WidgetTester tester, String label) {
  final tile = tester.widget<RadioListTile<String?>>(
    find.widgetWithText(RadioListTile<String?>, label),
  );
  return tile.value == tile.groupValue;
}

/// Dropdown'dan deste seçer (aç → öğeye dokun).
Future<void> _selectDeck(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  // Açılan menüdeki öğe; kapalı haldeki etiketle aynı metin olduğu için
  // sonuncusu (overlay'deki) seçiliyor.
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _tapTopic(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(RadioListTile<String?>, label));
  await tester.pump();
}

void main() {
  setUp(() => debugRequireAuthSignedInOverride = true);
  tearDown(() => debugRequireAuthSignedInOverride = null);

  testWidgets('varsayılan: ilk deste seçili, kapsam "Tüm deste"', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Çoktan seçmeli pratik'), findsOneWidget);
    expect(_isTopicSelected(tester, 'Tüm deste'), isTrue);
    // İlk destenin (Anatomi) konuları listelenir.
    expect(find.widgetWithText(RadioListTile<String?>, 'kol kasları'),
        findsOneWidget);
    expect(find.widgetWithText(RadioListTile<String?>, 'enzim kinetiği'),
        findsNothing);
  });

  testWidgets('bağlam destesi verilirse onunla açılır', (tester) async {
    await _pump(tester, initialDeckId: 'b');

    expect(find.widgetWithText(RadioListTile<String?>, 'enzim kinetiği'),
        findsOneWidget);
    expect(find.widgetWithText(RadioListTile<String?>, 'kol kasları'),
        findsNothing);
  });

  testWidgets('geçersiz bağlam destesi ilk desteye düşer', (tester) async {
    await _pump(tester, initialDeckId: 'silinmiş-deste');

    expect(find.widgetWithText(RadioListTile<String?>, 'kol kasları'),
        findsOneWidget);
  });

  testWidgets('deste değişince konu listesi filtrelenir', (tester) async {
    await _pump(tester);

    await _selectDeck(tester, 'Biyokimya');

    expect(find.widgetWithText(RadioListTile<String?>, 'enzim kinetiği'),
        findsOneWidget);
    expect(find.widgetWithText(RadioListTile<String?>, 'kol kasları'),
        findsNothing);
    // "Tüm deste" her destede durur.
    expect(find.widgetWithText(RadioListTile<String?>, 'Tüm deste'),
        findsOneWidget);
  });

  testWidgets('deste değişince YENİ destede olmayan konu seçimi temizlenir', (
    tester,
  ) async {
    await _pump(tester);

    await _tapTopic(tester, 'kol kasları');
    expect(_isTopicSelected(tester, 'kol kasları'), isTrue);
    expect(_isTopicSelected(tester, 'Tüm deste'), isFalse);

    await _selectDeck(tester, 'Biyokimya');

    // Konu artık yok; kapsam "Tüm deste"ye döndü.
    expect(find.widgetWithText(RadioListTile<String?>, 'kol kasları'),
        findsNothing);
    expect(_isTopicSelected(tester, 'Tüm deste'), isTrue);
  });

  testWidgets('deste değişince YENİ destede de VAR OLAN konu seçimi korunur', (
    tester,
  ) async {
    await _pump(tester);

    await _tapTopic(tester, 'ortak konu');
    expect(_isTopicSelected(tester, 'ortak konu'), isTrue);

    await _selectDeck(tester, 'Biyokimya');

    expect(_isTopicSelected(tester, 'ortak konu'), isTrue);
    expect(_isTopicSelected(tester, 'Tüm deste'), isFalse);
  });

  testWidgets('kapsam TEKLİ seçim: yeni konu seçilince eskisi kalkar', (
    tester,
  ) async {
    await _pump(tester);

    await _tapTopic(tester, 'kol kasları');
    expect(_isTopicSelected(tester, 'kol kasları'), isTrue);

    await _tapTopic(tester, 'ortak konu');

    expect(_isTopicSelected(tester, 'ortak konu'), isTrue);
    expect(_isTopicSelected(tester, 'kol kasları'), isFalse);
    expect(_isTopicSelected(tester, 'Tüm deste'), isFalse);
  });

  testWidgets('"Tüm deste"ye geri dönülebilir', (tester) async {
    await _pump(tester);

    await _tapTopic(tester, 'kol kasları');
    await _tapTopic(tester, 'Tüm deste');

    expect(_isTopicSelected(tester, 'Tüm deste'), isTrue);
    expect(_isTopicSelected(tester, 'kol kasları'), isFalse);
  });

  testWidgets('soru sayısı 5/10/20, varsayılan 10 ve değiştirilebilir', (
    tester,
  ) async {
    await _pump(tester);

    final segmented = find.byType(SegmentedButton<int>);
    expect(segmented, findsOneWidget);
    expect(
      tester.widget<SegmentedButton<int>>(segmented).segments
          .map((s) => (s.label as Text).data)
          .toList(),
      ['5', '10', '20'],
    );
    expect(tester.widget<SegmentedButton<int>>(segmented).selected, {10});

    await tester.tap(find.text('20'));
    await tester.pump();

    expect(tester.widget<SegmentedButton<int>>(segmented).selected, {20});
  });

  testWidgets('deste yoksa boş durum gösterilir', (tester) async {
    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: const LibraryData(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const McqSetupScreen(),
        ),
      ),
    );

    expect(find.text('Önce bir deste ve kart oluştur.'), findsOneWidget);
    expect(find.text('Başla'), findsNothing);
  });
}
