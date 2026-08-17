import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/screens/auth_screen.dart';
import 'package:medcard/screens/stats_screen.dart';
import 'package:medcard/screens/study_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/utils/require_auth.dart';
import 'package:medcard/widgets/study_heatmap.dart';
import 'package:provider/provider.dart';

/// DOMİNANT "BUGÜNKÜ ODAK" KARTI + KATLANABİLİR SATIRLAR (2026-08-17):
/// `StatsScreen`'in üst bölümü artık `FlashcardStore.weakestTopicInfo`'yu
/// (yeni bir hesap İCAT EDİLMEDİ — "En Zayıf Konu Antrenmanı" ile AYNI
/// kaynak, bkz. CLAUDE.md) TEK bir dominant kartta gösteriyor; altındaki
/// bölümler (metrikler, takvim, deste hazırlığı, deneme trendi, konu
/// başarısı, önümüzdeki 7 gün) artık varsayılan KAPALI katlanabilir
/// satırlar.

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

final _today = DateTime(2026, 8, 17);
final _deck = Deck(id: 'd1', name: 'Kalp', createdAt: _today);

Flashcard _card(
  String id, {
  String topic = '',
  int repetitions = 0,
  int lapses = 0,
}) => Flashcard(
  id: id,
  question: 'q$id',
  answer: 'a$id',
  deckId: _deck.id,
  topic: topic,
  repetitions: repetitions,
  lapses: lapses,
);

/// Güvenilir bir "en zayıf konu" üretecek 5 kartlık bir havuz: toplam
/// lapses=3, toplam repetitions=6 → başarı = 1 − 3/9 ≈ %67. `weakestTopicMinCards`
/// (5) ve `difficultyMinRepetitions` (2) eşiklerini geçiyor, bkz.
/// [SrsEngine.weakestReliableTopic].
List<Flashcard> _reliableWeakTopicCards() => [
  _card('w0', topic: 'ileti sistemi', repetitions: 2, lapses: 3),
  _card('w1', topic: 'ileti sistemi', repetitions: 1),
  _card('w2', topic: 'ileti sistemi', repetitions: 1),
  _card('w3', topic: 'ileti sistemi', repetitions: 1),
  _card('w4', topic: 'ileti sistemi', repetitions: 1),
];

Future<void> _pumpStats(
  WidgetTester tester, {
  required List<Flashcard> cards,
  Size surface = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final store = FlashcardStore(
    _NoopGenerator(),
    initialData: LibraryData(
      decks: [_deck],
      cards: cards,
      studyLog: StudyLog.fromJson({'2026-08-17': 4}),
    ),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => StudySettings()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: StatsScreen(now: _today),
      ),
    ),
  );
}

void main() {
  tearDown(() => debugRequireAuthSignedInOverride = null);

  group('Dominant "bugünkü odak" kartı', () {
    testWidgets('güvenilir en zayıf konu varken doğru başlık/yüzde/kart sayısı', (
      tester,
    ) async {
      await _pumpStats(tester, cards: _reliableWeakTopicCards());

      expect(find.text('BUGÜN İÇİN'), findsOneWidget);
      expect(find.text('ileti sistemi konusuna odaklan'), findsOneWidget);
      expect(find.text('%67 başarı · 5 kart'), findsOneWidget);
      expect(find.text('Antrenmana başla'), findsOneWidget);
      expect(
        find.text('Çalışmaya başladığında burada görünecek.'),
        findsNothing,
      );
    });

    testWidgets('güvenilir veri yokken bekleme mesajı gösterir', (
      tester,
    ) async {
      // Tek kart, eşik (5 kart/konu) altında — weakestTopicInfo null döner.
      await _pumpStats(tester, cards: [_card('1', topic: 'tek')]);

      expect(
        find.text('Çalışmaya başladığında burada görünecek.'),
        findsOneWidget,
      );
      expect(find.text('BUGÜN İÇİN'), findsNothing);
      expect(find.text('Antrenmana başla'), findsNothing);
    });

    testWidgets(
      '"Antrenmana başla" girişli kullanıcıda o konuya odaklı StudyScreen açar',
      (tester) async {
        debugRequireAuthSignedInOverride = true;
        await _pumpStats(tester, cards: _reliableWeakTopicCards());

        await tester.tap(find.text('Antrenmana başla'));
        await tester.pumpAndSettle();

        final studyScreen = tester.widget<StudyScreen>(
          find.byType(StudyScreen),
        );
        expect(studyScreen.filter?.topics, {'ileti sistemi'});
        expect(studyScreen.ignoreDueDate, isTrue);
      },
    );

    testWidgets('"Antrenmana başla" girişsiz kullanıcıda giriş ekranına yönlendirir', (
      tester,
    ) async {
      debugRequireAuthSignedInOverride = false;
      await _pumpStats(tester, cards: _reliableWeakTopicCards());

      await tester.tap(find.text('Antrenmana başla'));
      await tester.pumpAndSettle();

      expect(find.byType(StudyScreen), findsNothing);
      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  group('Katlanabilir satırlar — varsayılan KAPALI', () {
    /// Her satırı tetikleyecek zengin bir veri seti: metrikler + takvim +
    /// deste hazırlığı + konu başarısı için yeterli kart. Deneme sınavı
    /// trendi ve önümüzdeki 7 gün bu testte kapsam dışı (ayrı dosyalarda
    /// zaten test ediliyor), burada yalnızca aç/kapa DAVRANIŞI ilgi konusu.
    List<Flashcard> cards() => [
      ..._reliableWeakTopicCards(),
      _card('extra-1', topic: 'başka konu', repetitions: 3),
    ];

    testWidgets('satır başlıkları görünür ama içerikleri varsayılan gizli', (
      tester,
    ) async {
      await _pumpStats(tester, cards: cards());

      // Başlıklar (kapalı satırların header'ı) her zaman görünür.
      expect(find.text('Genel özet'), findsOneWidget);
      expect(find.text('Çalışma takvimi'), findsOneWidget);
      expect(find.text('Deste hazırlığı'), findsOneWidget);
      expect(find.text('Konu başarısı'), findsOneWidget);

      // İçerikleri henüz açılmadı: ne metrik etiketleri ne widget'lar var.
      expect(find.text('Günlük seri'), findsNothing);
      expect(find.byType(StudyHeatmap), findsNothing);
      expect(find.text('ileti sistemi'), findsNothing);
      expect(find.byKey(StatsScreen.metricStreakKey), findsNothing);
    });

    testWidgets('bir satıra dokununca yalnızca O satırın içeriği açılır', (
      tester,
    ) async {
      await _pumpStats(tester, cards: cards());

      await tester.tap(find.text('Çalışma takvimi'));
      await tester.pumpAndSettle();

      // Açılan satırın widget'ı göründü.
      expect(find.byType(StudyHeatmap), findsOneWidget);
      // Diğer satırlar hâlâ kapalı.
      expect(find.text('Günlük seri'), findsNothing);
      expect(find.byKey(StatsScreen.metricStreakKey), findsNothing);
      expect(find.text('ileti sistemi'), findsNothing);
    });

    testWidgets('açık satıra tekrar dokununca kapanır', (tester) async {
      await _pumpStats(tester, cards: cards());

      await tester.tap(find.text('Çalışma takvimi'));
      await tester.pumpAndSettle();
      expect(find.byType(StudyHeatmap), findsOneWidget);

      await tester.tap(find.text('Çalışma takvimi'));
      await tester.pumpAndSettle();
      expect(find.byType(StudyHeatmap), findsNothing);
    });

    testWidgets('"Genel özet" açılınca 4 metrik kartı doğru içerikle görünür', (
      tester,
    ) async {
      await _pumpStats(tester, cards: cards());

      await tester.tap(find.text('Genel özet'));
      await tester.pumpAndSettle();

      expect(find.byKey(StatsScreen.metricStreakKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricTotalKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricActiveDaysKey), findsOneWidget);
      expect(find.byKey(StatsScreen.metricTodayKey), findsOneWidget);
      expect(find.text('Günlük seri'), findsOneWidget);
    });

    testWidgets('"Konu başarısı" açılınca konu listesi görünür', (
      tester,
    ) async {
      await _pumpStats(tester, cards: cards());

      await tester.tap(find.text('Konu başarısı'));
      await tester.pumpAndSettle();

      expect(find.text('ileti sistemi'), findsOneWidget);
      expect(find.text('başka konu'), findsOneWidget);
    });
  });
}
