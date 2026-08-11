import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/exam_sim_screen.dart';
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

/// MCQ üretimine uygun (kısa cevabı dolu) kartlar.
List<Flashcard> _cards({
  required String deckId,
  required String topic,
  required int count,
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

/// Anatomi: "kalp kapakları" ×5 + "ortak konu" ×4 = 9 kart.
/// Biyokimya: "enzim kinetiği" ×5 + "ortak konu" ×4 = 9 kart. Toplam 18.
///
/// "ortak konu" bilerek İKİ destede de var: deste değişiminde var olan konu
/// seçiminin KORUNDUĞUNU, olmayanın temizlendiğini ayırt edebilmek için.
final _library = [
  ..._cards(deckId: 'a', topic: 'kalp kapakları', count: 5),
  ..._cards(deckId: 'a', topic: 'ortak konu', count: 4),
  ..._cards(deckId: 'b', topic: 'enzim kinetiği', count: 5),
  ..._cards(deckId: 'b', topic: 'ortak konu', count: 4),
];

Future<void> _pump(WidgetTester tester) async {
  // Deste ve konu çipleri "Soru sayısı"/"Süre"nin altında — hepsi tek karede
  // görünsün ki dokunulabilsinler.
  tester.view.physicalSize = const Size(900, 2000);
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
        home: const ExamSimSetupScreen(),
      ),
    ),
  );
}

Finder _deckChip(String name) => find.widgetWithText(ChoiceChip, name);
Finder _topicChip(String topic) => find.widgetWithText(FilterChip, topic);

bool _isSelected(WidgetTester tester, Finder chip) =>
    tester.widget<ChoiceChip>(chip).selected;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  setUp(() => debugRequireAuthSignedInOverride = true);
  tearDown(() => debugRequireAuthSignedInOverride = null);

  testWidgets('varsayılan "Tüm desteler": tüm konular ve tüm havuz (mevcut '
      'davranış korunur)', (tester) async {
    await _pump(tester);

    expect(_isSelected(tester, _deckChip('Tüm desteler')), isTrue);
    expect(_isSelected(tester, _deckChip('Anatomi')), isFalse);
    expect(_isSelected(tester, _deckChip('Biyokimya')), isFalse);

    // Kütüphanenin tamamındaki konular görünür.
    expect(_topicChip('kalp kapakları'), findsOneWidget);
    expect(_topicChip('enzim kinetiği'), findsOneWidget);
    expect(_topicChip('ortak konu'), findsOneWidget);
    expect(find.text('Kapsamda 18 kart var.'), findsOneWidget);
    expect(
      find.text('Hiçbir şey seçmezsen sınav tüm kartlarından hazırlanır.'),
      findsOneWidget,
    );
  });

  testWidgets('deste seçilince konu listesi o desteyle sınırlanır', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, _deckChip('Anatomi'));

    expect(_isSelected(tester, _deckChip('Anatomi')), isTrue);
    expect(_isSelected(tester, _deckChip('Tüm desteler')), isFalse);

    // Diğer destenin konusu HİÇ görünmez.
    expect(_topicChip('enzim kinetiği'), findsNothing);
    expect(_topicChip('kalp kapakları'), findsOneWidget);
    expect(_topicChip('ortak konu'), findsOneWidget);
  });

  testWidgets('deste seçili + hiç konu seçili değil → o destenin TÜM kartları', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, _deckChip('Biyokimya'));

    expect(find.text('Kapsamda 9 kart var.'), findsOneWidget);
    expect(
      find.text(
        'Hiçbir şey seçmezsen sınav bu destenin tüm kartlarından hazırlanır.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deste değişince yeni destede OLMAYAN konu seçimi temizlenir', (
    tester,
  ) async {
    await _pump(tester);

    // Önce tüm kütüphane kapsamında bir konu seç.
    await _tap(tester, _topicChip('kalp kapakları'));
    expect(find.text('Kapsamda 5 kart var.'), findsOneWidget);

    // Bu konu Biyokimya'da yok → seçim düşmeli, havuz destenin tamamı olmalı.
    await _tap(tester, _deckChip('Biyokimya'));

    expect(_topicChip('kalp kapakları'), findsNothing);
    expect(find.text('Kapsamda 9 kart var.'), findsOneWidget);
    // Filtre gerçekten temizlendi: "Temizle" çipi de kalmamalı.
    expect(find.widgetWithText(ActionChip, 'Temizle'), findsNothing);
  });

  testWidgets('yeni destede VAR OLAN konu seçimi korunur', (tester) async {
    await _pump(tester);

    await _tap(tester, _topicChip('ortak konu'));
    // İki destede 4'er tane.
    expect(find.text('Kapsamda 8 kart var.'), findsOneWidget);

    await _tap(tester, _deckChip('Biyokimya'));

    expect(tester.widget<FilterChip>(_topicChip('ortak konu')).selected, isTrue);
    expect(find.text('Kapsamda 4 kart var.'), findsOneWidget);
  });

  testWidgets('"Tüm desteler"e dönünce kütüphane kapsamı geri gelir', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, _deckChip('Anatomi'));
    expect(find.text('Kapsamda 9 kart var.'), findsOneWidget);

    await _tap(tester, _deckChip('Tüm desteler'));

    expect(_isSelected(tester, _deckChip('Tüm desteler')), isTrue);
    expect(_topicChip('enzim kinetiği'), findsOneWidget);
    expect(find.text('Kapsamda 18 kart var.'), findsOneWidget);
  });

  testWidgets('soru sayısı ve süre ayarları deste seçiminden etkilenmez', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, _deckChip('Anatomi'));

    // Varsayılanlar yerinde: 20 soru, 20 dakika.
    expect(
      tester
          .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .selected,
      {20},
    );
    expect(
      tester
          .widget<Text>(find.byKey(ExamSimSetupScreen.minutesValueKey))
          .data,
      '20',
    );
  });
}
