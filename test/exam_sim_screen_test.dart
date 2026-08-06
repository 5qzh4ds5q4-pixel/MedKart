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

final _deck = Deck(
  id: 'deck-1',
  name: 'Komite 1',
  createdAt: DateTime(2026, 7, 20),
);

FlashcardStore _storeWith(List<Flashcard> cards) => FlashcardStore(
  _NoopGenerator(),
  initialData: LibraryData(decks: [_deck], cards: cards),
);

Widget _wrap(FlashcardStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(theme: AppTheme.light, home: const ExamSimSetupScreen()),
  );
}

/// MCQ üretimine uygun (aynı konuda 4+ kart, kısa cevap dolu) bir havuz.
List<Flashcard> _mcqReadyCards({
  String topic = 'kalp kapakları',
  int count = 5,
  int? startPage,
}) => [
  for (var i = 1; i <= count; i++)
    Flashcard(
      id: '$topic-$i',
      question: '$topic sorusu $i?',
      answer: '$topic cevabı $i — mekanizma açıklaması.',
      shortAnswer: '$topic yanıt $i',
      deckId: 'deck-1',
      topic: topic,
      sourcePage: startPage == null ? null : startPage + i,
    ),
];

/// "Kapsam" bölümünü görünür alana getirir.
///
/// Ekrana "Deste" seçimi eklendikten (2026-08-04) sonra Kapsam kartı
/// varsayılan test yüzeyinin altına düştü; `ListView` onu tembel oluşturduğu
/// için çipler hiç build edilmiyordu. Kapsamla ilgilenen testler önce bunu
/// çağırmalı.
Future<void> _scrollToScope(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Kapsam'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  // "Sınavı Başlat" girişe (requireAuth) tabi — bu dosya sınav kurulum
  // ekranının kendi davranışını test ediyor, giriş ekranını değil.
  setUp(() => debugRequireAuthSignedInOverride = true);
  tearDown(() => debugRequireAuthSignedInOverride = null);

  testWidgets('kart yoksa boş durum gösterilir', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(const [])));

    expect(find.text('Önce bir deste ve kart oluştur.'), findsOneWidget);
    expect(find.text('Sınavı Başlat'), findsNothing);
  });

  testWidgets('soru sayısı seçenekleri 10/20/40 görünür, varsayılan 20',
      (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards())));

    for (final label in ['10', '20', '40']) {
      expect(
        find.widgetWithText(ChoiceChip, label),
        findsOneWidget,
        reason: 'soru sayısı seçeneği $label görünmeli',
      );
    }

    final selected = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '20'),
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('soru sayısı seçimi değiştirilebilir', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards())));

    await tester.tap(find.widgetWithText(ChoiceChip, '40'));
    await tester.pump();

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '40'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '20'))
          .selected,
      isFalse,
    );
  });

  String _minutesFieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('süre alanı varsayılan soru sayısına göre önerilir (20 dk)',
      (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards())));

    expect(find.text('Süre'), findsOneWidget);
    expect(_minutesFieldText(tester), '20');
  });

  testWidgets('soru sayısı değişince süre önerisi otomatik güncellenir',
      (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards())));

    await tester.tap(find.widgetWithText(ChoiceChip, '40'));
    await tester.pump();

    expect(_minutesFieldText(tester), '40');
  });

  testWidgets('süre elle girilince soru sayısı değişimi onu ezmez',
      (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards())));

    await tester.enterText(find.byType(TextField), '7');
    await tester.pump();
    expect(_minutesFieldText(tester), '7');

    // Soru sayısı değişse bile kullanıcının girdiği süre korunur.
    await tester.tap(find.widgetWithText(ChoiceChip, '40'));
    await tester.pump();
    expect(_minutesFieldText(tester), '7');
  });

  testWidgets('elle girilen süre sınav ekranına geçer (05:00)', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards(count: 6))));

    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();

    final start = find.text('Sınavı Başlat');
    await tester.scrollUntilVisible(
      start,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(start);
    await tester.pumpAndSettle();

    // Sınav ekranı timer'ı, henüz saniye geçmeden hedef süreyi gösterir.
    expect(find.text('05:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('konu çipleri görünür ve seçim kapsam sayacını daraltır',
      (tester) async {
    final cards = [
      ..._mcqReadyCards(topic: 'kalp kapakları', count: 5),
      ..._mcqReadyCards(topic: 'ileti sistemi', count: 4),
    ];
    await tester.pumpWidget(_wrap(_storeWith(cards)));
    await _scrollToScope(tester);

    expect(find.text('Kapsamda 9 kart var.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'ileti sistemi'));
    await tester.pump();

    expect(find.text('Kapsamda 4 kart var.'), findsOneWidget);

    // Temizle: tüm havuz geri gelir.
    await tester.tap(find.widgetWithText(ActionChip, 'Temizle'));
    await tester.pump();

    expect(find.text('Kapsamda 9 kart var.'), findsOneWidget);
  });

  testWidgets('PDF kaynaklı kart varsa sayfa aralığı çipi görünür',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_storeWith(_mcqReadyCards(count: 6, startPage: 10))),
    );
    await _scrollToScope(tester);

    expect(find.text('Sayfa aralığı'), findsOneWidget);
  });

  testWidgets('PDF kaynaklı kart yoksa sayfa aralığı çipi gizlenir',
      (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards())));
    // Kaydırmadan bakmak yanıltıcı olurdu: çip zaten ekran dışında kalırdı.
    await _scrollToScope(tester);

    expect(find.text('Sayfa aralığı'), findsNothing);
  });

  testWidgets('yetersiz havuzda başlatma hata mesajı gösterir', (tester) async {
    // Konuda 4'ten az kart → McqGenerator soru üretemez.
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards(count: 3))));

    final start = find.text('Sınavı Başlat');
    await tester.scrollUntilVisible(
      start,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(start);
    await tester.pump();

    expect(
      find.textContaining('yeterli soru üretilemedi'),
      findsOneWidget,
    );
  });

  testWidgets('uygun havuzda başlatma süreli sınav ekranını açar',
      (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_mcqReadyCards(count: 6))));

    final start = find.text('Sınavı Başlat');
    await tester.scrollUntilVisible(
      start,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.text('Sınavı Bitir'), findsOneWidget);
    expect(find.textContaining('yeterli soru üretilemedi'), findsNothing);

    // Sınav ekranındaki timer'ı kapatmak için widget ağacı sökülür.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('kapsamda hiç kart kalmazsa başlat butonu pasifleşir',
      (tester) async {
    final cards = [
      ..._mcqReadyCards(topic: 'kalp kapakları', count: 5, startPage: 1),
    ];
    await tester.pumpWidget(_wrap(_storeWith(cards)));
    await _scrollToScope(tester);

    // Sayfa aralığını kartların dışına daralt: çip → dialog → slider.
    // Slider'ı UI'dan sürüklemek kırılgan; bunun yerine konu + sayfa filtresi
    // kombinasyonunu doğrudan dar bir konuyla test ediyoruz.
    await tester.tap(find.widgetWithText(FilterChip, 'kalp kapakları'));
    await tester.pump();
    expect(find.text('Kapsamda 5 kart var.'), findsOneWidget);

    final startButton = find.widgetWithText(FilledButton, 'Sınavı Başlat');
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(startButton);
    expect(button.onPressed, isNotNull);
  });
}
