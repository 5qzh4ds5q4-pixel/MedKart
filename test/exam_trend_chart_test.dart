import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/exam_result.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/stats_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/widgets/exam_trend_chart.dart';
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

final _deck = Deck(id: 'd1', name: 'Kalp', createdAt: DateTime(2026, 7, 16));

ExamResult _result(
  String id, {
  required DateTime takenAt,
  required int correct,
  required int total,
}) => ExamResult(
  id: id,
  takenAt: takenAt,
  correctCount: correct,
  totalQuestions: total,
);

/// [StatsScreen]'i verilen sınav geçmişiyle kurar.
Future<void> _pumpStats(WidgetTester tester, List<ExamResult> results) async {
  // Bölüm ekranın ortasında; tamamı tek karede görünsün diye uzun yüzey.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final store = FlashcardStore(
    _NoopGenerator(),
    initialData: LibraryData(decks: [_deck], examResults: results),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => StudySettings()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: StatsScreen(now: DateTime(2026, 7, 16)),
      ),
    ),
  );
}

void main() {
  group('ExamTrendChart.pointsFor', () {
    test('yüzdeyi doğru hesaplar', () {
      final points = ExamTrendChart.pointsFor([
        _result('1', takenAt: DateTime(2026, 7, 10), correct: 8, total: 20),
        _result('2', takenAt: DateTime(2026, 7, 12), correct: 15, total: 20),
        // 7/9 = %77.8 → yuvarlanır.
        _result('3', takenAt: DateTime(2026, 7, 14), correct: 7, total: 9),
      ]);

      expect(points.map((p) => p.percent).toList(), [40, 75, 78]);
    });

    test('kronolojik sıralar (store geçmişi yeniden eskiye tutuyor)', () {
      final points = ExamTrendChart.pointsFor([
        _result('yeni', takenAt: DateTime(2026, 7, 14), correct: 9, total: 10),
        _result('eski', takenAt: DateTime(2026, 7, 10), correct: 5, total: 10),
        _result('orta', takenAt: DateTime(2026, 7, 12), correct: 7, total: 10),
      ]);

      expect(points.map((p) => p.percent).toList(), [50, 70, 90]);
      expect(points.first.takenAt, DateTime(2026, 7, 10));
      expect(points.last.takenAt, DateTime(2026, 7, 14));
    });

    test('en fazla maxPoints nokta döner ve EN YENİLERİ tutar', () {
      final results = [
        for (var i = 0; i < ExamResult.maxHistory; i++)
          _result(
            'e$i',
            takenAt: DateTime(2026, 7, 1).add(Duration(days: i)),
            correct: i,
            total: 100,
          ),
      ];

      final points = ExamTrendChart.pointsFor(results);

      expect(points, hasLength(ExamTrendChart.maxPoints));
      // 20 kayıttan son 10'u: index 10..19 → yüzde 10..19.
      expect(points.first.percent, 10);
      expect(points.last.percent, 19);
    });

    test('boş geçmişte boş liste döner', () {
      expect(ExamTrendChart.pointsFor(const []), isEmpty);
    });
  });

  group('ExamTrendChart.shouldShow', () {
    final one = _result('1', takenAt: DateTime(2026, 7, 10), correct: 5, total: 10);
    final two = _result('2', takenAt: DateTime(2026, 7, 12), correct: 7, total: 10);

    test('0 sonuçta false', () {
      expect(ExamTrendChart.shouldShow(const []), isFalse);
    });

    test('1 sonuçta false (tek nokta trend değildir)', () {
      expect(ExamTrendChart.shouldShow([one]), isFalse);
    });

    test('2 sonuçta true', () {
      expect(ExamTrendChart.shouldShow([one, two]), isTrue);
    });
  });

  group('StatsScreen deneme trendi bölümü', () {
    testWidgets('hiç sonuç yokken bölüm gizli, ekranın kalanı etkilenmez', (
      tester,
    ) async {
      await _pumpStats(tester, const []);

      expect(find.text('Deneme sınavı trendi'), findsNothing);
      expect(find.byType(ExamTrendChart), findsNothing);
      // Komşu bölümler yerinde.
      expect(find.text('Çalışma takvimi'), findsOneWidget);
      expect(find.text('Konu başarısı'), findsOneWidget);
    });

    testWidgets('tek sonuçta bölüm gizli', (tester) async {
      await _pumpStats(tester, [
        _result('1', takenAt: DateTime(2026, 7, 10), correct: 5, total: 10),
      ]);

      expect(find.text('Deneme sınavı trendi'), findsNothing);
      expect(find.byType(ExamTrendChart), findsNothing);
    });

    testWidgets('iki sonuçta bölüm görünür ve deneme sayısını yazar', (
      tester,
    ) async {
      // Semantik ağaç testte varsayılan olarak kurulmuyor; handle test
      // BİTMEDEN kapatılmalı (addTearDown doğrulamadan sonra çalışıyor).
      final semantics = tester.ensureSemantics();

      await _pumpStats(tester, [
        _result('1', takenAt: DateTime(2026, 7, 10), correct: 4, total: 10),
        _result('2', takenAt: DateTime(2026, 7, 12), correct: 7, total: 10),
      ]);

      expect(find.text('Deneme sınavı trendi'), findsOneWidget);
      expect(find.byType(ExamTrendChart), findsOneWidget);
      expect(find.text('Son 2 deneme · yüzde puanın'), findsOneWidget);
      // Tuvale çizilen etiketler bulunamaz; erişilebilirlik özeti son/ilk
      // yüzdeyi metin olarak taşıyor.
      expect(
        find.bySemanticsLabel('Deneme sınavı trendi: 40 yüzdeden 70 yüzdeye.'),
        findsOneWidget,
      );

      semantics.dispose();
    });
  });
}
