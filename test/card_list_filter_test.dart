import 'package:flutter/gestures.dart';
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
import 'package:medcard/utils/require_auth.dart';
import 'package:medcard/widgets/flashcard_tile.dart';
import 'package:medcard/widgets/horizontal_wheel_scroll.dart';
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

final _deck = Deck(id: 'd1', name: 'fizyo', createdAt: DateTime(2026, 8, 1));

Flashcard _card(
  String id, {
  required CardDifficulty difficulty,
  required String topic,
}) => Flashcard(
  id: id,
  question: '$id sorusu?',
  answer: '$id cevabı.',
  shortAnswer: '$id kısa',
  deckId: _deck.id,
  difficulty: difficulty,
  topic: topic,
);

/// Zorluk × konu matrisi — her kombinasyonda tam 1 kart:
///   kolay/tiroid, kolay/insülin, orta/tiroid, orta/insülin, zor/tiroid.
/// Dağılım: Kolay 2 · Orta 2 · Zor 1 (toplam 5).
final _cards = [
  _card('k-tiroid', difficulty: CardDifficulty.kolay, topic: 'tiroid'),
  _card('k-insulin', difficulty: CardDifficulty.kolay, topic: 'insülin'),
  _card('o-tiroid', difficulty: CardDifficulty.orta, topic: 'tiroid'),
  _card('o-insulin', difficulty: CardDifficulty.orta, topic: 'insülin'),
  _card('z-tiroid', difficulty: CardDifficulty.zor, topic: 'tiroid'),
];

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final store = FlashcardStore(
    _NoopGenerator(),
    initialData: LibraryData(decks: [_deck], cards: _cards),
  );

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        theme: AppTheme.light,
        home: CardListScreen(deckId: _deck.id),
      ),
    ),
  );
}

Finder _chip(String label) => find.widgetWithText(FilterChip, label);

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<FilterChip>(_chip(label)).selected;

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tap(_chip(label));
  await tester.pump();
}

/// Yalnızca özet kartının içindeki metni arar.
Finder _inSummary(String text) => find.descendant(
  of: find.byKey(cardListSummaryKey),
  matching: find.text(text),
);

int _visibleCards(WidgetTester tester) =>
    tester.widgetList<FlashcardTile>(find.byType(FlashcardTile)).length;

void main() {
  setUp(() => debugRequireAuthSignedInOverride = true);
  tearDown(() => debugRequireAuthSignedInOverride = null);

  group('filtre çubuğu — çoklu seçim', () {
    testWidgets('zorluk ve konu çipleri görünür, başlangıçta hiçbiri seçili değil',
        (tester) async {
      await _pump(tester);

      for (final label in ['Kolay', 'Orta', 'Zor', 'tiroid', 'insülin']) {
        expect(_chip(label), findsOneWidget, reason: '$label çipi görünmeli');
        expect(_chipSelected(tester, label), isFalse);
      }
      expect(_visibleCards(tester), 5);
    });

    testWidgets('aynı gruptan birden fazla çip AYNI ANDA seçili olabilir', (
      tester,
    ) async {
      await _pump(tester);

      await _tapChip(tester, 'Kolay');
      await _tapChip(tester, 'Orta');

      expect(_chipSelected(tester, 'Kolay'), isTrue);
      expect(_chipSelected(tester, 'Orta'), isTrue);
      expect(_chipSelected(tester, 'Zor'), isFalse);
    });

    testWidgets('farklı gruplardan çipler birlikte seçili kalabilir', (
      tester,
    ) async {
      await _pump(tester);

      await _tapChip(tester, 'Kolay');
      await _tapChip(tester, 'tiroid');

      expect(_chipSelected(tester, 'Kolay'), isTrue);
      expect(_chipSelected(tester, 'tiroid'), isTrue);
    });

    testWidgets('seçili çipe tekrar dokunmak seçimi kaldırır', (tester) async {
      await _pump(tester);

      await _tapChip(tester, 'Zor');
      expect(_chipSelected(tester, 'Zor'), isTrue);

      await _tapChip(tester, 'Zor');
      expect(_chipSelected(tester, 'Zor'), isFalse);
      expect(_visibleCards(tester), 5);
    });
  });

  group('filtre mantığı — grup içi OR, gruplar arası AND', () {
    testWidgets('tek zorluk: yalnızca o zorluktakiler', (tester) async {
      await _pump(tester);

      await _tapChip(tester, 'Kolay');

      // kolay/tiroid + kolay/insülin
      expect(_visibleCards(tester), 2);
    });

    testWidgets('iki zorluk OR ile birleşir (birleşim, kesişim değil)', (
      tester,
    ) async {
      await _pump(tester);

      await _tapChip(tester, 'Kolay');
      await _tapChip(tester, 'Zor');

      // kolay 2 + zor 1
      expect(_visibleCards(tester), 3);
    });

    testWidgets('iki konu OR ile birleşir', (tester) async {
      await _pump(tester);

      await _tapChip(tester, 'tiroid');
      await _tapChip(tester, 'insülin');

      expect(_visibleCards(tester), 5);
    });

    testWidgets('zorluk + konu AND ile kesişir', (tester) async {
      await _pump(tester);

      await _tapChip(tester, 'Kolay');
      await _tapChip(tester, 'tiroid');

      // Yalnızca kolay VE tiroid olan tek kart.
      expect(_visibleCards(tester), 1);
    });

    testWidgets('çoklu zorluk + tek konu: OR grubu AND ile daraltılır', (
      tester,
    ) async {
      await _pump(tester);

      await _tapChip(tester, 'Kolay');
      await _tapChip(tester, 'Orta');
      await _tapChip(tester, 'insülin');

      // (kolay VEYA orta) VE insülin → 2 kart.
      expect(_visibleCards(tester), 2);
    });

    testWidgets('kesişim boşsa "bu filtreyle kart yok" gösterilir', (
      tester,
    ) async {
      await _pump(tester);

      await _tapChip(tester, 'Zor');
      await _tapChip(tester, 'insülin');

      // zor/insülin kartı yok.
      expect(_visibleCards(tester), 0);
      expect(find.text('Bu filtreyle kart yok'), findsOneWidget);
    });
  });

  group('özet kartı', () {
    testWidgets('toplam kart ve filtre seçeneği sayısı', (tester) async {
      await _pump(tester);

      expect(find.text('Kartların hazır'), findsOneWidget);
      expect(find.text('Toplam kart'), findsOneWidget);
      // 3 zorluk + 2 konu = 5 seçenek (SEÇİLİ olanların değil, mevcut olanların
      // sayısı).
      expect(find.text('Seçili filtreler'), findsOneWidget);
      // Özet kartı içindeki "5"ler: toplam kart 5 + seçenek 5. Kapsam şart —
      // listedeki kart numaralarında da "5" geçiyor.
      expect(_inSummary('5'), findsNWidgets(2));
    });

    testWidgets('seviye dağılımı filtreden ETKİLENMEZ', (tester) async {
      await _pump(tester);

      const wholeDeck = 'Kolay 2 · Orta 2 · Zor 1';
      expect(find.text(wholeDeck), findsOneWidget);

      // Filtre uygula: listede tek kart kalsa bile dağılım aynı kalmalı.
      await _tapChip(tester, 'Kolay');
      await _tapChip(tester, 'tiroid');
      expect(_visibleCards(tester), 1);

      expect(find.text(wholeDeck), findsOneWidget);
    });

    testWidgets('toplam kart sayısı da filtreden etkilenmez', (tester) async {
      await _pump(tester);

      await _tapChip(tester, 'Zor');
      expect(_visibleCards(tester), 1);

      // "Toplam kart" (5) ve "Seçili filtreler" (3 zorluk + 2 konu = 5)
      // blokları hâlâ destenin tamamını yansıtıyor.
      expect(_inSummary('5'), findsNWidgets(2));
    });
  });

  group('filtre çubuğu kaydırma (2026-08-04 hata düzeltmesi)', () {
    /// Ekrana sığmayacak kadar çok konu.
    Future<void> pumpManyTopics(WidgetTester tester) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: [
            for (var i = 0; i < 20; i++)
              _card(
                'c$i',
                difficulty: CardDifficulty.orta,
                topic: 'oldukça uzun konu adı $i',
              ),
          ],
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            theme: AppTheme.light,
            home: CardListScreen(deckId: _deck.id),
          ),
        ),
      );
    }

    ScrollController barController(WidgetTester tester) => tester
        .widget<SingleChildScrollView>(
          find
              .descendant(
                of: find.byType(HorizontalWheelScroll),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        )
        .controller!;

    testWidgets('çubuk taşıyor ve fareyle sürüklenerek kaydırılabiliyor', (
      tester,
    ) async {
      await pumpManyTopics(tester);
      final controller = barController(tester);

      expect(
        controller.position.maxScrollExtent,
        greaterThan(0),
        reason: 'taşma yoksa kaydırma testi bir şey kanıtlamaz',
      );

      await tester.drag(
        find.byType(HorizontalWheelScroll),
        const Offset(-200, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
    });

    testWidgets('sona kaydırınca son konu çipine erişilebiliyor', (
      tester,
    ) async {
      await pumpManyTopics(tester);
      final controller = barController(tester);

      // Alfabetik sırada son çip. NOT: SingleChildScrollView tüm satırı
      // inşa ettiği için çip ekran dışındayken de ağaçta VAR — görünürlüğü
      // widget varlığıyla değil KONUMLA ölçmek gerekiyor.
      final lastChip = _chip('oldukça uzun konu adı 9');
      const screenWidth = 700.0;

      final beforeX = tester.getTopLeft(lastChip).dx;
      expect(
        beforeX,
        greaterThan(screenWidth),
        reason: 'başta ekranın sağında, erişilemez olmalı',
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final afterX = tester.getTopLeft(lastChip).dx;
      expect(afterX, lessThan(beforeX));
      expect(afterX, lessThan(screenWidth), reason: 'artık görünür alanda');
    });
  });
}
