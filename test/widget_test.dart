import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/deck_list_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/state/theme_controller.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/utils/require_auth.dart';
import 'package:medcard/widgets/card_chips.dart';
import 'package:provider/provider.dart';

/// Ağa çıkmadan, öngörülebilir kart üreten sahte servis.
class _FakeGenerator implements FlashcardGenerator {
  _FakeGenerator({this.error});

  final String? error;

  @override
  Future<List<Flashcard>> generate(
    String sourceText, {
    List<MediaAttachment> media = const [],
  }) async {
    if (error != null) throw FlashcardGenerationException(error!);
    return const [
      Flashcard(
        id: '1',
        question: 'Kalp kaç odacıklıdır?',
        answer: 'Dört.',
        difficulty: CardDifficulty.kolay,
        topic: 'genel yapı',
      ),
      Flashcard(
        id: '2',
        question: 'LAD tıkanırsa hangi bölge etkilenir?',
        answer: 'Ön duvar ve septumun ön bölümü.',
        difficulty: CardDifficulty.zor,
        topic: 'koroner dolaşım',
      ),
    ];
  }

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

Widget _wrap(FlashcardStore store) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => StudySettings()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const DeckListScreen(),
    ),
  );
}

FlashcardStore _store(FlashcardGenerator generator, {bool withDeck = true}) {
  return FlashcardStore(
    generator,
    initialData: withDeck ? LibraryData(decks: [_deck]) : const LibraryData(),
  );
}

const _sampleNote =
    'Kalp dört odacıklı bir kas organdır ve sistemik dolaşımı sürdürür. '
    'Aort sol ventrikülden çıkar.';

/// Deste listesinden desteyi açıp "Kart Ekle" ekranına gider.
///
/// `ensureVisible`: 2026-08-10 kart-ızgara dashboard yenilemesinden sonra
/// hero banner + kısayollar üstte epey yer kaplıyor, test yüzeyinin
/// varsayılan 600px yüksekliğinde deste kartı kaydırılmadan görünmeyebiliyor
/// — gerçek kullanıcı da kısa ekranda aynı şekilde kaydırır, bu doğal.
Future<void> _openAddCards(WidgetTester tester) async {
  final deckFinder = find.text('Komite 1 · Kalp');
  await tester.ensureVisible(deckFinder);
  await tester.pumpAndSettle();
  await tester.tap(deckFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kart Ekle'));
  await tester.pumpAndSettle();
}

void main() {
  // Deste oluşturma girişe (requireAuth) tabi — bu dosya deste listesinin
  // kendi davranışını test ediyor, giriş ekranını değil.
  setUp(() => debugRequireAuthSignedInOverride = true);
  tearDown(() => debugRequireAuthSignedInOverride = null);

  testWidgets('deste yokken kullanıcı deste oluşturmaya yönlendirilir', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_store(_FakeGenerator(), withDeck: false)));

    expect(find.text('Slaytını yükle,\nkomiteye hazır ol.'), findsOneWidget);
    expect(find.text('İlk desteni oluştur'), findsOneWidget);
  });

  testWidgets('deste oluşturulunca listede görünür', (tester) async {
    final store = _store(_FakeGenerator(), withDeck: false);
    await tester.pumpWidget(_wrap(store));

    await tester.tap(find.text('İlk desteni oluştur'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Komite 2 · Solunum');
    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();

    expect(store.decks.single.name, 'Komite 2 · Solunum');
    // Yeni deste boş olduğu için doğrudan içine girilir.
    expect(find.text('Bu deste boş'), findsOneWidget);
  });

  testWidgets('deste adı boş bırakılamaz', (tester) async {
    final store = _store(_FakeGenerator(), withDeck: false);
    await tester.pumpWidget(_wrap(store));

    await tester.tap(find.text('İlk desteni oluştur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();

    expect(find.text('Deste adı boş bırakılamaz.'), findsOneWidget);
    expect(store.decks, isEmpty);
  });

  testWidgets('metin boşken Kart Üret butonu pasiftir', (tester) async {
    await tester.pumpWidget(_wrap(_store(_FakeGenerator())));
    await _openAddCards(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kart Üret'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('metin girilince buton aktifleşir', (tester) async {
    await tester.pumpWidget(_wrap(_store(_FakeGenerator())));
    await _openAddCards(tester);

    await tester.enterText(find.byType(TextField), _sampleNote);
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kart Üret'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('üretilen kartlar destenin listesinde görünür', (tester) async {
    final store = _store(_FakeGenerator());
    await tester.pumpWidget(_wrap(store));
    await _openAddCards(tester);

    await tester.enterText(find.byType(TextField), _sampleNote);
    await tester.pump();
    await tester.tap(find.text('Kart Üret'));
    await tester.pumpAndSettle();

    // Kart ekleme ekranı kapanır, destenin kart listesine dönülür.
    // Eski "2 kart · 2 konu" özet satırının yerini özet kartı aldı
    // (2026-08-04 üst kısım yeniden tasarımı).
    expect(find.text('Kartların hazır'), findsOneWidget);
    expect(find.text('Kalp kaç odacıklıdır?'), findsOneWidget);
    expect(find.text('Ön duvar ve septumun ön bölümü.'), findsOneWidget);

    // Kartlar doğru desteye bağlandı.
    expect(store.cardsIn('deck-1'), hasLength(2));
  });

  testWidgets('kartlarda zorluk ve konu rozetleri görünür', (tester) async {
    await tester.pumpWidget(_wrap(_store(_FakeGenerator())));
    await _openAddCards(tester);

    await tester.enterText(find.byType(TextField), _sampleNote);
    await tester.pump();
    await tester.tap(find.text('Kart Üret'));
    await tester.pumpAndSettle();

    // Kart rozetleri (filtre çubuğundaki çiplerle karışmaması için widget'a özel).
    expect(find.byType(DifficultyChip), findsNWidgets(2));
    expect(find.widgetWithText(DifficultyChip, 'Kolay'), findsOneWidget);
    expect(find.widgetWithText(DifficultyChip, 'Zor'), findsOneWidget);
    expect(find.widgetWithText(TopicChip, 'koroner dolaşım'), findsOneWidget);
  });

  testWidgets('üretim hatası kullanıcıya mesaj olarak gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_store(_FakeGenerator(error: 'API anahtarın geçersiz.'))),
    );
    await _openAddCards(tester);

    await tester.enterText(find.byType(TextField), _sampleNote);
    await tester.pump();
    await tester.tap(find.text('Kart Üret'));
    await tester.pump();

    expect(find.text('API anahtarın geçersiz.'), findsOneWidget);
    // Hata durumunda ekranda kalınır.
    expect(find.text('Kart Üret'), findsOneWidget);
  });

  testWidgets('deste listesi kart ve tekrar sayısını gösterir', (tester) async {
    final store = FlashcardStore(
      _FakeGenerator(),
      initialData: LibraryData(
        decks: [_deck],
        cards: const [
          Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-1'),
          Flashcard(id: '2', question: 'S2', answer: 'C', deckId: 'deck-1'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    // Yeni kartların hepsi tekrara hazırdır.
    expect(find.text('2 kart · 2 tekrara hazır'), findsOneWidget);
  });

  testWidgets('boş deste "Boş deste" olarak işaretlenir', (tester) async {
    await tester.pumpWidget(_wrap(_store(_FakeGenerator())));

    expect(find.text('Boş deste'), findsOneWidget);
  });

  testWidgets('deste yeniden adlandırılabilir', (tester) async {
    final store = _store(_FakeGenerator());
    await tester.pumpWidget(_wrap(store));

    // ensureVisible: bkz. `_openAddCards` doc yorumu.
    await tester.ensureVisible(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden adlandır'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Komite 1 · Kardiyoloji',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(store.decks.single.name, 'Komite 1 · Kardiyoloji');
    expect(find.text('Komite 1 · Kardiyoloji'), findsOneWidget);
  });

  testWidgets('deste silmek onay ister ve kartları da siler', (tester) async {
    final store = FlashcardStore(
      _FakeGenerator(),
      initialData: LibraryData(
        decks: [_deck],
        cards: const [
          Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-1'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(store));

    // ensureVisible: bkz. `_openAddCards` doc yorumu.
    await tester.ensureVisible(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    // Kaç kartın gideceği ve geri alınamayacağı söylenmeli.
    expect(find.textContaining('Destedeki 1 kart'), findsOneWidget);
    expect(find.textContaining('geri alınamaz'), findsOneWidget);

    // Vazgeçince hiçbir şey silinmez.
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(store.decks, hasLength(1));

    await tester.ensureVisible(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(store.decks, isEmpty);
    expect(store.cards, isEmpty);
    expect(find.text('İlk desteni oluştur'), findsOneWidget);
  });
}
