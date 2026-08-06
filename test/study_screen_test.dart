import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/card_filter.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/card_list_screen.dart';
import 'package:medcard/screens/study_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/utils/require_auth.dart';
import 'package:medcard/widgets/card_chips.dart';
import 'package:provider/provider.dart';

/// Çalışma ekranı testleri kart üretmeden çalışsın diye store'a hazır kart koyar.
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

FlashcardStore _storeWith(List<Flashcard> cards) => FlashcardStore(
  _NoopGenerator(),
  initialData: LibraryData(decks: [_deck], cards: cards),
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

const _twoCards = [
  Flashcard(
    id: '1',
    question: 'AV düğümdeki gecikmenin amacı nedir?',
    answer: 'Atriyumların ventriküllerden önce kasılmasını sağlar.',
    deckId: 'deck-1',
    topic: 'ileti sistemi',
  ),
  Flashcard(
    id: '2',
    question: 'LAD tıkanırsa hangi bölge etkilenir?',
    answer: 'Septumun ön bölümü ve sol ventrikülün ön duvarı.',
    deckId: 'deck-1',
    topic: 'koroner dolaşım',
  ),
];

void main() {
  // "Çalışmaya Başla" ve kart düzenleme girişe (requireAuth) tabi — bu dosya
  // çalışma ekranının kendi davranışını test ediyor, giriş ekranını değil.
  setUp(() => debugRequireAuthSignedInOverride = true);
  tearDown(() => debugRequireAuthSignedInOverride = null);

  testWidgets('yeni kartların hepsi tekrara hazır görünür', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_twoCards)));

    expect(find.text('Çalışmaya Başla (2)'), findsOneWidget);
  });

  testWidgets('cevap önce gizli, dokununca açılır', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_twoCards)));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    // Soru görünür, cevap gizli.
    expect(find.text('AV düğümdeki gecikmenin amacı nedir?'), findsOneWidget);
    expect(
      find.text('Atriyumların ventriküllerden önce kasılmasını sağlar.'),
      findsNothing,
    );

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();

    expect(
      find.text('Atriyumların ventriküllerden önce kasılmasını sağlar.'),
      findsOneWidget,
    );
    // Cevap açılınca üç değerlendirme butonu gelir.
    expect(find.widgetWithText(FilledButton, 'Zor'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Orta'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kolay'), findsOneWidget);
  });

  testWidgets('"Orta" ilerlemeyi artırır ve kartı ileri atar', (tester) async {
    final store = _storeWith(_twoCards);
    await tester.pumpWidget(_wrap(store));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 2'), findsOneWidget);

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Orta'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    // Sıradaki karta geçildi ve cevabı yine gizli.
    expect(find.text('LAD tıkanırsa hangi bölge etkilenir?'), findsOneWidget);
    expect(find.text('Cevabı Göster'), findsOneWidget);

    // Kart artık yarına planlandı.
    final card = store.cardById('1')!;
    expect(card.intervalDays, 1);
    expect(card.repetitions, 1);
    expect(card.nextReview, isNotNull);
  });

  testWidgets('"Kolay" kartı ortadan daha ileriye atar', (tester) async {
    final store = _storeWith(_twoCards);
    await tester.pumpWidget(_wrap(store));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kolay'));
    await tester.pumpAndSettle();

    // Yeni kartta orta 1 gün verirken kolay bariz açar (4 gün).
    expect(store.cardById('1')!.intervalDays, 4);
    expect(store.cardById('1')!.repetitions, 1);
  });

  testWidgets('"Zor" kartı aynı oturumda tekrar getirir', (tester) async {
    final store = _storeWith(_twoCards);
    await tester.pumpWidget(_wrap(store));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Zor'));
    await tester.pumpAndSettle();

    // İkinci karta geçildi, ilerleme artmadı.
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('LAD tıkanırsa hangi bölge etkilenir?'), findsOneWidget);

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Orta'));
    await tester.pumpAndSettle();

    // "Zor" denen kart tekrar karşımızda.
    expect(find.text('AV düğümdeki gecikmenin amacı nedir?'), findsOneWidget);
    expect(store.cardById('1')!.lapses, 1);
  });

  testWidgets('tüm kartlar bilinince oturum özeti gösterilir', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_twoCards)));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Cevabı Göster'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Orta'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Oturum tamamlandı'), findsOneWidget);
    expect(find.textContaining('2 kartı tamamladın'), findsOneWidget);
  });

  testWidgets('tekrar zamanı gelmese de kullanıcı istediğinde çalışabilir',
      (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_twoCards)));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Cevabı Göster'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Orta'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Kartlara dön'));
    await tester.pumpAndSettle();

    // Kartlar yarına atıldı: sayaç düştü ama buton çalışır durumda kalmalı.
    expect(find.text('Çalışmaya Başla'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Çalışmaya Başla'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);

    // Basınca tüm kartlarla yeni bir oturum açılır.
    await tester.tap(find.text('Çalışmaya Başla'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('Cevabı Göster'), findsOneWidget);
  });

  testWidgets('klavye kısayolları: Space çevirir, 1/2/3 değerlendirir',
      (tester) async {
    final store = _storeWith(_twoCards);
    await tester.pumpWidget(_wrap(store));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    // Cevap kapalıyken 2'ye basmak bir şey yapmaz.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('Cevabı Göster'), findsOneWidget);

    // Space cevabı açar.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      find.text('Atriyumların ventriküllerden önce kasılmasını sağlar.'),
      findsOneWidget,
    );

    // 3 = Kolay: kart 4 güne atılır ve sıradakine geçilir.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    expect(store.cardById('1')!.intervalDays, 4);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('masaüstünde klavye kısayol ipucu gösterilir', (tester) async {
    // İpucu yalnızca fiziksel klavye olası platformlarda görünür.
    // Override, invariant kontrolünden önce test gövdesinde geri alınmalı.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(_wrap(_storeWith(_twoCards)));
      await tester.tap(find.text('Çalışmaya Başla (2)'));
      await tester.pumpAndSettle();

      expect(find.text('çevir'), findsOneWidget);
      expect(find.text('Boşluk'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobilde klavye ipucu gizlenir', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(_wrap(_storeWith(_twoCards)));
      await tester.tap(find.text('Çalışmaya Başla (2)'));
      await tester.pumpAndSettle();

      expect(find.text('çevir'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('geri butonu oturum başında pasiftir', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_twoCards)));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    final undo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undo.onPressed, isNull);
  });

  testWidgets('geri butonu önceki karta döner ve SRS durumunu geri alır',
      (tester) async {
    final store = _storeWith(_twoCards);
    await tester.pumpWidget(_wrap(store));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Orta'));
    await tester.pumpAndSettle();

    // Kart ileri atıldı ve ikinci karta geçildi.
    expect(store.cardById('1')!.repetitions, 1);
    expect(store.cardById('1')!.nextReview, isNotNull);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    // İlk karta dönüldü, sayaç geriledi.
    expect(find.text('AV düğümdeki gecikmenin amacı nedir?'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);

    // Kartın planlaması cevap öncesine döndü.
    final card = store.cardById('1')!;
    expect(card.repetitions, 0);
    expect(card.intervalDays, 0);
    expect(card.nextReview, isNull);
    expect(card.isNew, isTrue);
  });

  testWidgets('geri dönüldüğünde cevap açık gelir', (tester) async {
    await tester.pumpWidget(_wrap(_storeWith(_twoCards)));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Orta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    expect(
      find.text('Atriyumların ventriküllerden önce kasılmasını sağlar.'),
      findsOneWidget,
    );
    // Cevap açık geldiği için değerlendirme butonları görünür.
    expect(find.widgetWithText(FilledButton, 'Orta'), findsOneWidget);
  });

  testWidgets('"Zor" geri alınınca unutma sayısı da geri alınır',
      (tester) async {
    final store = _storeWith(_twoCards);
    await tester.pumpWidget(_wrap(store));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cevabı Göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Zor'));
    await tester.pumpAndSettle();

    expect(store.cardById('1')!.lapses, 1);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    expect(store.cardById('1')!.lapses, 0);
    expect(find.text('AV düğümdeki gecikmenin amacı nedir?'), findsOneWidget);
  });

  testWidgets('zayıf konudaki kart çalışma sırasında öne gelir', (tester) async {
    // 2 numaralı kart geçmişte çok unutulmuş; önce o sorulmalı.
    final store = _storeWith([
      _twoCards[0],
      _twoCards[1].copyWith(lapses: 3, repetitions: 1),
    ]);

    await tester.pumpWidget(_wrap(store));
    await tester.tap(find.text('Çalışmaya Başla (2)'));
    await tester.pumpAndSettle();

    expect(find.text('LAD tıkanırsa hangi bölge etkilenir?'), findsOneWidget);
  });

  testWidgets(
    'Sınav Modu sınav tipi + öncelikli temel kartları bırakır, arka planı çıkarır',
    (tester) async {
      final mixedCards = [
        const Flashcard(
          id: 's1',
          question: 'Sınav tipi soru?',
          answer: 'Cevap.',
          deckId: 'deck-1',
          cardType: CardType.sinav,
          // Öncelik etiketinden bağımsız kalması gerektiğini kanıtlamak için
          // kasıtlı olarak arkaPlan.
          priority: CardPriority.arkaPlan,
        ),
        const Flashcard(
          id: 't1',
          question: 'Öncelikli temel soru?',
          answer: 'Cevap.',
          deckId: 'deck-1',
          cardType: CardType.temel,
          priority: CardPriority.oncelikli,
        ),
        const Flashcard(
          id: 't2',
          question: 'Arka plan temel soru?',
          answer: 'Cevap.',
          deckId: 'deck-1',
          cardType: CardType.temel,
          priority: CardPriority.arkaPlan,
        ),
      ];

      await tester.pumpWidget(_wrap(_storeWith(mixedCards)));
      await tester.tap(find.text('Çalışmaya Başla (3)'));
      await tester.pumpAndSettle();

      // Sınav Modu kapalıyken üç kart da havuzda.
      expect(find.text('Sınav Modu'), findsOneWidget);
      expect(find.text('3 kart'), findsOneWidget);
      expect(find.text('0 / 3'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Açıkken yalnızca sınav tipi + öncelikli temel kart kalır (2).
      expect(find.text('2 kart'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);

      // Tekrar kapatınca üçe döner.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('3 kart'), findsOneWidget);
      expect(find.text('0 / 3'), findsOneWidget);
    },
  );

  group('Hocanın Favorileri', () {
    testWidgets('el yazısı kartta çalışma ekranında rozet görünür', (
      tester,
    ) async {
      final store = _storeWith(const [
        Flashcard(
          id: 'hw',
          question: 'El yazısı soru?',
          answer: 'Cevap.',
          deckId: 'deck-1',
          isHandwritten: true,
        ),
      ]);
      await tester.pumpWidget(_wrap(store));
      await tester.tap(find.text('Çalışmaya Başla (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Hocanın Favorisi'), findsOneWidget);
    });

    testWidgets(
      '"Sadece Hocanın Favorileri" açılınca yalnızca el yazısı kartlar kalır',
      (tester) async {
        final mixedCards = const [
          Flashcard(
            id: 'hw',
            question: 'El yazısı soru?',
            answer: 'Cevap.',
            deckId: 'deck-1',
            isHandwritten: true,
          ),
          Flashcard(
            id: 'n1',
            question: 'Normal soru?',
            answer: 'Cevap.',
            deckId: 'deck-1',
          ),
          Flashcard(
            id: 'n2',
            question: 'Normal soru 2?',
            answer: 'Cevap.',
            deckId: 'deck-1',
          ),
        ];
        final store = _storeWith(mixedCards);
        await tester.pumpWidget(_wrap(store));
        await tester.tap(find.text('Çalışmaya Başla (3)'));
        await tester.pumpAndSettle();

        expect(find.text('Sadece Hocanın Favorileri'), findsOneWidget);
        expect(find.text('0 / 3'), findsOneWidget);

        // İkinci switch: Sınav Modu'ndan sonra gelen "Sadece Hocanın
        // Favorileri" toggle'ı.
        await tester.tap(find.byType(Switch).last);
        await tester.pumpAndSettle();

        expect(find.text('0 / 1'), findsOneWidget);
        expect(find.text('El yazısı soru?'), findsOneWidget);

        await tester.tap(find.byType(Switch).last);
        await tester.pumpAndSettle();
        expect(find.text('0 / 3'), findsOneWidget);
      },
    );
  });

  group('Hocanın Favorilerini Çalış (hızlı pratik, CardListScreen)', () {
    testWidgets('3\'ten az el yazısı kartta buton görünmez', (tester) async {
      final store = _storeWith(const [
        Flashcard(
          id: 'hw1',
          question: 'S1',
          answer: 'C',
          deckId: 'deck-1',
          isHandwritten: true,
        ),
        Flashcard(
          id: 'hw2',
          question: 'S2',
          answer: 'C',
          deckId: 'deck-1',
          isHandwritten: true,
        ),
        Flashcard(id: 'n1', question: 'S3', answer: 'C', deckId: 'deck-1'),
      ]);
      await tester.pumpWidget(_wrap(store));

      expect(find.text('Hocanın Favorilerini Çalış'), findsNothing);
    });

    testWidgets(
      '3+ el yazısı kartta buton görünür ve due tarihine bakmadan hepsini çalıştırır',
      (tester) async {
        final now = DateTime.now();
        final store = _storeWith([
          Flashcard(
            id: 'hw1',
            question: 'El yazısı 1?',
            answer: 'C',
            deckId: 'deck-1',
            isHandwritten: true,
          ),
          Flashcard(
            id: 'hw2',
            question: 'El yazısı 2?',
            answer: 'C',
            deckId: 'deck-1',
            isHandwritten: true,
            // Bilerek uzak bir tarihe planlı: normal kuyrukta görünmezdi,
            // ama bu hızlı pratik modu due tarihini hiç dikkate almamalı.
            repetitions: 1,
            nextReview: now.add(const Duration(days: 60)),
          ),
          const Flashcard(
            id: 'hw3',
            question: 'El yazısı 3?',
            answer: 'C',
            deckId: 'deck-1',
            isHandwritten: true,
          ),
          const Flashcard(
            id: 'n1',
            question: 'Normal soru?',
            answer: 'C',
            deckId: 'deck-1',
          ),
        ]);
        await tester.pumpWidget(_wrap(store));

        expect(find.text('Hocanın Favorilerini Çalış'), findsOneWidget);

        await tester.tap(find.text('Hocanın Favorilerini Çalış'));
        await tester.pumpAndSettle();

        // Üç el yazısı kart da (due olan/olmayan fark etmeksizin) oturumda;
        // normal kart hiç yok.
        expect(find.text('0 / 3'), findsOneWidget);
        expect(find.text('Normal soru?'), findsNothing);
      },
    );
  });

  group('CardFilter.forCard (MCQ özetinden "Bu kartı çalışmaya git")', () {
    testWidgets('yalnızca belirtilen tek karta odaklanır', (tester) async {
      final store = _storeWith(_twoCards);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            theme: AppTheme.light,
            home: StudyScreen(
              deckId: 'deck-1',
              filter: CardFilter.forCard('2'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('LAD tıkanırsa hangi bölge etkilenir?'), findsOneWidget);
      expect(
        find.text('AV düğümdeki gecikmenin amacı nedir?'),
        findsNothing,
      );
    });
  });

  group('Çalışma ekranında kart düzenleme', () {
    testWidgets(
      'düzenle ikonu paneli açar, kayıt kalır, flagged/edited rozeti görünür',
      (tester) async {
        final store = _storeWith(_twoCards);
        await tester.pumpWidget(_wrap(store));
        await tester.tap(find.text('Çalışmaya Başla (2)'));
        await tester.pumpAndSettle();

        expect(find.byType(FlaggedChip), findsNothing);
        expect(find.byType(EditedChip), findsNothing);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Alan sırası: Soru(0), Kısa cevap(1), Cevap(2), Not(3), Konu(4).
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Değişmiş cevap.',
        );
        await tester.ensureVisible(find.text('Bu kartta hata var'));
        await tester.tap(find.text('Bu kartta hata var'));
        await tester.pump();
        await tester.tap(find.text('Kaydet'));
        await tester.pumpAndSettle();

        // Değişiklik depoda kalıcı.
        final saved = store.cardById('1')!;
        expect(saved.answer, 'Değişmiş cevap.');
        expect(saved.flagged, isTrue);
        expect(saved.isEdited, isTrue);

        // Kartı kapatıp tekrar açınca (aynı ekranda kart hâlâ görünür durumda,
        // depo tek doğruluk kaynağı) değişiklik hâlâ orada.
        expect(find.text('Değişmiş cevap.'), findsNothing); // cevap kapalı
        await tester.tap(find.text('AV düğümdeki gecikmenin amacı nedir?'));
        await tester.pumpAndSettle();
        expect(find.text('Değişmiş cevap.'), findsOneWidget);

        // Rozetler çalışma ekranında da görünür.
        expect(find.byType(EditedChip), findsOneWidget);
        expect(find.byType(FlaggedChip), findsOneWidget);
      },
    );

    testWidgets('"AI orijinaline dön" çalışma ekranında da çalışır', (
      tester,
    ) async {
      final cards = [
        const Flashcard(
          id: '1',
          question: 'Kullanıcı sorusu?',
          answer: 'Kullanıcı cevabı.',
          deckId: 'deck-1',
          originalQuestion: 'AI sorusu?',
          originalAnswer: 'AI cevabı.',
        ),
      ];
      final store = _storeWith(cards);
      await tester.pumpWidget(_wrap(store));
      await tester.tap(find.text('Çalışmaya Başla (1)'));
      await tester.pumpAndSettle();

      expect(find.byType(EditedChip), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AI orijinaline dön'));
      await tester.tap(find.text('AI orijinaline dön'));
      await tester.pumpAndSettle();

      final saved = store.cardById('1')!;
      expect(saved.question, 'AI sorusu?');
      expect(saved.isEdited, isFalse);
      expect(find.text('AI sorusu?'), findsOneWidget);
      expect(find.byType(EditedChip), findsNothing);
    });
  });

  group('Konu Filtrele', () {
    testWidgets('yalnızca seçili konudaki kart kalır', (tester) async {
      final store = _storeWith(_twoCards);
      await tester.pumpWidget(_wrap(store));
      await tester.tap(find.text('Çalışmaya Başla (2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.topic_outlined));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(CheckboxListTile, 'ileti sistemi'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(CheckboxListTile, 'koroner dolaşım'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(CheckboxListTile, 'koroner dolaşım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula (1)'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('LAD tıkanırsa hangi bölge etkilenir?'), findsOneWidget);
    });

    testWidgets('temizleyince tüm kartlar geri gelir', (tester) async {
      final store = _storeWith(_twoCards);
      await tester.pumpWidget(_wrap(store));
      await tester.tap(find.text('Çalışmaya Başla (2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.topic_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'koroner dolaşım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula (1)'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.topic_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temizle'));
      await tester.pump();
      await tester.tap(find.text('Tüm konular'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 2'), findsOneWidget);
    });

    testWidgets('Sınav Modu ile birlikte çalışır (ikisi de uygulanır)',
        (tester) async {
      final mixedCards = [
        const Flashcard(
          id: 's1',
          question: 'Sınav tipi, ileti sistemi?',
          answer: 'Cevap.',
          deckId: 'deck-1',
          cardType: CardType.sinav,
          topic: 'ileti sistemi',
        ),
        const Flashcard(
          id: 's2',
          question: 'Sınav tipi, koroner?',
          answer: 'Cevap.',
          deckId: 'deck-1',
          cardType: CardType.sinav,
          topic: 'koroner dolaşım',
        ),
        const Flashcard(
          id: 't1',
          question: 'Temel, ileti sistemi?',
          answer: 'Cevap.',
          deckId: 'deck-1',
          cardType: CardType.temel,
          priority: CardPriority.arkaPlan,
          topic: 'ileti sistemi',
        ),
      ];
      final store = _storeWith(mixedCards);
      await tester.pumpWidget(_wrap(store));
      await tester.tap(find.text('Çalışmaya Başla (3)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first); // Sınav Modu aç
      await tester.pumpAndSettle();
      expect(find.text('2 kart'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.topic_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'ileti sistemi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula (1)'));
      await tester.pumpAndSettle();

      // Sınav Modu + "ileti sistemi": yalnızca s1 kalmalı.
      expect(find.text('1 kart'), findsOneWidget);
      expect(find.text('Sınav tipi, ileti sistemi?'), findsOneWidget);
    });

    testWidgets('konu yoksa buton pasif kalır', (tester) async {
      final store = _storeWith(const [
        Flashcard(id: '1', question: 'S', answer: 'C', deckId: 'deck-1'),
      ]);
      await tester.pumpWidget(_wrap(store));
      await tester.tap(find.text('Çalışmaya Başla (1)'));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.topic_outlined),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Bugün Çalış modu (deckId null)', () {
    final _deckB = Deck(
      id: 'deck-2',
      name: 'Komite 2 · Solunum',
      createdAt: DateTime(2026, 7, 16),
    );

    Widget wrapDaily(FlashcardStore store) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider(create: (_) => StudySettings()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const StudyScreen(),
        ),
      );
    }

    testWidgets('birden fazla desteden kartları birleştirir', (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck, _deckB],
          cards: const [
            Flashcard(
              id: 'a1',
              question: 'Deste A sorusu?',
              answer: 'Cevap A',
              deckId: 'deck-1',
            ),
            Flashcard(
              id: 'b1',
              question: 'Deste B sorusu?',
              answer: 'Cevap B',
              deckId: 'deck-2',
            ),
          ],
        ),
      );

      await tester.pumpWidget(wrapDaily(store));
      await tester.pumpAndSettle();

      expect(find.text('Bugün Çalış'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
    });

    testWidgets('Sınav Modu birleşik kuyrukta da uygulanır', (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck, _deckB],
          cards: const [
            Flashcard(
              id: 'exam',
              question: 'Sınav tipi?',
              answer: 'Cevap',
              deckId: 'deck-1',
              cardType: CardType.sinav,
            ),
            Flashcard(
              id: 'background',
              question: 'Arka plan?',
              answer: 'Cevap',
              deckId: 'deck-2',
              priority: CardPriority.arkaPlan,
            ),
          ],
        ),
      );

      await tester.pumpWidget(wrapDaily(store));
      await tester.pumpAndSettle();

      expect(find.text('2 kart'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text('1 kart'), findsOneWidget);
    });

    testWidgets('Konu Filtrele birleşik kuyrukta destelerden bağımsız çalışır',
        (tester) async {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck, _deckB],
          cards: const [
            Flashcard(
              id: 'a1',
              question: 'Deste A sorusu?',
              answer: 'Cevap A',
              deckId: 'deck-1',
              topic: 'kalp',
            ),
            Flashcard(
              id: 'b1',
              question: 'Deste B sorusu?',
              answer: 'Cevap B',
              deckId: 'deck-2',
              topic: 'akciğer',
            ),
          ],
        ),
      );

      await tester.pumpWidget(wrapDaily(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.topic_outlined));
      await tester.pumpAndSettle();

      // İki farklı desteden gelen konular birlikte listelenir.
      expect(find.widgetWithText(CheckboxListTile, 'kalp'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'akciğer'), findsOneWidget);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'akciğer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula (1)'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('Deste B sorusu?'), findsOneWidget);
    });
  });
}
