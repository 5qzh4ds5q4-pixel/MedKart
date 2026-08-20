// Test-only doğrulama: v31 ile CANLI üretilmiş gerçek kartlar kart listesi
// ekranına verilince zorluk çipleri ne yapıyor?
// Uygulama koduna dahil DEĞİL (`tool/` altında, pakete girmez).
// AĞA ÇIKMAZ — girdi olarak `tool/verify_v31_test.dart`'ın yazdığı gerçek
// üretim çıktısını (v31_dogrulama.json, 40 kart) okur.
//
// SORU: "Kolay" ve "Zor" çipleri artık hep boş mu geliyor, "Orta" hepsini mi
// topluyor?
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/card_list_screen.dart';
import 'package:medcard/widgets/flashcard_tile.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:provider/provider.dart';

const _scratch =
    r'C:\Users\Admin\AppData\Local\Temp\claude'
    r'\C--Users-Admin-Documents-GitHub-MedKart'
    r'\fde41f7c-032e-4b59-8b1d-726b17745c50\scratchpad\ab';

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

void main() {
  testWidgets('CANLI v31 kartlariyla zorluk cipleri', (tester) async {
    final ham =
        jsonDecode(File('$_scratch/v31_dogrulama.json').readAsStringSync())
            as List<dynamic>;

    final deck = Deck(id: 'd1', name: 'Bulasici', createdAt: DateTime(2026, 8, 20));
    final cards = <Flashcard>[
      for (var i = 0; i < ham.length; i++)
        Flashcard(
          id: 'v31-$i',
          question: ham[i]['question'] as String,
          answer: 'A',
          shortAnswer: (ham[i]['shortAnswer'] as String?) ?? '',
          deckId: 'd1',
          difficulty: CardDifficulty.parse(ham[i]['difficulty']),
          cardType: CardType.parse(ham[i]['cardType']),
          topic: (ham[i]['topic'] as String?) ?? '',
          sourcePage: ham[i]['page'] as int?,
        ),
    ];

    final store = FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: [deck], cards: cards),
    );

    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CardListScreen(deckId: 'd1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Çip = FilterChip. DİKKAT: düz find.text('Orta') 41 eşleşme buluyor —
    // çip + her kartın üstündeki zorluk rozeti. Çipi tipiyle hedefle.
    Finder cip(String etiket) => find.widgetWithText(FilterChip, etiket);

    // 1) Çipler EKRANDA MI? (koşulsuz çiziliyorlar — sayı 0 olsa bile)
    for (final etiket in ['Kolay', 'Orta', 'Zor']) {
      final f = cip(etiket);
      final var_ = f.evaluate().isNotEmpty;
      final secili = var_ ? (tester.widget<FilterChip>(f)).selected : false;
      print('  "$etiket" cipi ekranda: $var_ (secili: $secili)');
    }

    // 2) Her çipe basınca kaç kart kalıyor?
    Future<String> ciptekiKartSayisi(String etiket) async {
      if (cip(etiket).evaluate().isEmpty) return 'CIP YOK (gizlendi)';
      await tester.tap(cip(etiket));
      await tester.pumpAndSettle();
      final bosMu = find.textContaining('Bu filtreyle kart yok').evaluate().isNotEmpty;
      final gorunen = find.byType(FlashcardTile).evaluate().length;
      await tester.tap(cip(etiket));
      await tester.pumpAndSettle();
      return bosMu ? '0 (BOŞ DURUM ekrani)' : '$gorunen kart';
    }

    print('\n=== VERI (canli v31 uretimi, ${cards.length} kart) ===');
    for (final d in CardDifficulty.values) {
      final n = cards.where((c) => c.difficulty == d).length;
      print('  ${d.label}: $n kart');
    }

    print('\n=== CIPE BASINCA ===');
    for (final etiket in ['Kolay', 'Orta', 'Zor']) {
      print('  "$etiket" -> ${await ciptekiKartSayisi(etiket)} gorunuyor');
    }

    // 3) Deste özetindeki dağılım metni (_SummaryCard private, ekrandan oku)
    final dagilim = find
        .textContaining('Kolay ')
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .toList();
    print('\n=== DESTE OZETI METNI ===\n  $dagilim');
  });
}
