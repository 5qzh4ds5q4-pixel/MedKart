import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/exam_result.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/library_codec.dart';
import 'package:medcard/state/flashcard_store.dart';

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

ExamResult _result({
  required String id,
  required int correct,
  required int total,
  String? deckId,
  DateTime? takenAt,
  List<ExamTopicScore> topics = const [],
}) => ExamResult(
  id: id,
  deckId: deckId,
  takenAt: takenAt ?? DateTime(2026, 7, 31),
  correctCount: correct,
  totalQuestions: total,
  topicScores: topics,
);

void main() {
  group('ExamResult', () {
    test('yüzde doğru hesaplanır', () {
      expect(_result(id: 'a', correct: 3, total: 4).percent, 75);
      expect(_result(id: 'a', correct: 0, total: 4).percent, 0);
      // Sıfıra bölme yok.
      expect(_result(id: 'a', correct: 0, total: 0).percent, 0);
    });

    test('JSON gidiş-dönüşü konu kırılımını korur', () {
      final original = _result(
        id: 'exam-1',
        correct: 7,
        total: 10,
        deckId: 'deck-9',
        takenAt: DateTime(2026, 7, 30, 14, 5),
        topics: const [
          ExamTopicScore(topic: 'kalp', correct: 4, total: 5),
          ExamTopicScore(topic: 'böbrek', correct: 3, total: 5),
        ],
      );

      final restored = ExamResult.fromJson(original.toJson());

      expect(restored.id, 'exam-1');
      expect(restored.deckId, 'deck-9');
      expect(restored.takenAt, original.takenAt);
      expect(restored.correctCount, 7);
      expect(restored.totalQuestions, 10);
      expect(restored.topicScores.length, 2);
      expect(restored.topicScores.first.topic, 'kalp');
      expect(restored.topicScores.first.percent, 80);
    });

    test('bozuk/eksik JSON çökmez, güvenli varsayılana düşer', () {
      final restored = ExamResult.fromJson({'id': 'x'});
      expect(restored.correctCount, 0);
      expect(restored.totalQuestions, 0);
      expect(restored.topicScores, isEmpty);
      expect(restored.deckId, isNull);
    });
  });

  group('ExamComparison — üç durum', () {
    test('gelişme: pozitif mesaj ve doğru fark', () {
      final comparison = ExamComparison.between(
        _result(id: 'p', correct: 2, total: 4), // %50
        _result(id: 'c', correct: 4, total: 4), // %100
      );

      expect(comparison.trend, ExamTrend.improved);
      expect(comparison.deltaPoints, 50);
      expect(comparison.previousPercent, 50);
      expect(comparison.currentPercent, 100);
      expect(comparison.message, 'Geçen denemene göre %50 daha iyisin.');
    });

    test('gerileme: mesaj cesaret kırıcı olmayan dilde, fark mutlak değerde', () {
      final comparison = ExamComparison.between(
        _result(id: 'p', correct: 4, total: 4), // %100
        _result(id: 'c', correct: 1, total: 4), // %25
      );

      expect(comparison.trend, ExamTrend.declined);
      expect(comparison.deltaPoints, -75);
      // Mesajda eksi işareti YOK, mutlak fark yazılır.
      expect(comparison.message, contains('%75 daha iyiydin'));
      expect(comparison.message, isNot(contains('-75')));
      expect(comparison.message, contains('Tek bir deneme her şeyi söylemez'));
    });

    test('aynı seviye: fark tam sıfır', () {
      final comparison = ExamComparison.between(
        _result(id: 'p', correct: 2, total: 4),
        _result(id: 'c', correct: 2, total: 4),
      );

      expect(comparison.trend, ExamTrend.same);
      expect(comparison.deltaPoints, 0);
      expect(comparison.message, 'Geçen denemenle aynı seviyedesin.');
    });

    test('eşik altındaki küçük fark "aynı seviye" sayılır', () {
      // 40 soruda tek soru = 2.5 puan; eşik 3 olduğu için nötr kalmalı.
      final comparison = ExamComparison.between(
        _result(id: 'p', correct: 20, total: 40), // %50
        _result(id: 'c', correct: 21, total: 40), // %53
      );

      expect(comparison.deltaPoints, 3);
      // 3 puan eşiğin ALTINDA değil (>=) → gelişme sayılır.
      expect(comparison.trend, ExamTrend.improved);

      final smaller = ExamComparison.between(
        _result(id: 'p', correct: 20, total: 40), // %50
        _result(id: 'c', correct: 41, total: 80), // %51
      );
      expect(smaller.deltaPoints, 1);
      expect(smaller.trend, ExamTrend.same);
    });
  });

  group('ExamComparison — konu kırılımı', () {
    test('en çok gelişen ve gerileyen konular ayrılır', () {
      final comparison = ExamComparison.between(
        _result(
          id: 'p',
          correct: 5,
          total: 10,
          topics: const [
            ExamTopicScore(topic: 'kalp', correct: 1, total: 5), // %20
            ExamTopicScore(topic: 'böbrek', correct: 5, total: 5), // %100
          ],
        ),
        _result(
          id: 'c',
          correct: 5,
          total: 10,
          topics: const [
            ExamTopicScore(topic: 'kalp', correct: 4, total: 5), // %80
            ExamTopicScore(topic: 'böbrek', correct: 2, total: 5), // %40
          ],
        ),
      );

      expect(comparison.improvedTopics.single.topic, 'kalp');
      expect(comparison.improvedTopics.single.deltaPoints, 60);
      expect(comparison.declinedTopics.single.topic, 'böbrek');
      expect(comparison.declinedTopics.single.deltaPoints, -60);
    });

    test('yalnızca tek sınavda görünen konu kıyasa girmez', () {
      final comparison = ExamComparison.between(
        _result(
          id: 'p',
          correct: 0,
          total: 5,
          topics: const [ExamTopicScore(topic: 'eski', correct: 0, total: 5)],
        ),
        _result(
          id: 'c',
          correct: 5,
          total: 5,
          topics: const [ExamTopicScore(topic: 'yeni', correct: 5, total: 5)],
        ),
      );

      // İki sınavda da olan konu yok → vurgu yok (ana kıyas yine hesaplanır).
      expect(comparison.improvedTopics, isEmpty);
      expect(comparison.declinedTopics, isEmpty);
      expect(comparison.trend, ExamTrend.improved);
    });

    test('eşik altı konu değişimi vurgulanmaz', () {
      final comparison = ExamComparison.between(
        _result(
          id: 'p',
          correct: 5,
          total: 10,
          topics: const [ExamTopicScore(topic: 'kalp', correct: 5, total: 10)],
        ),
        _result(
          id: 'c',
          correct: 5,
          total: 10,
          // %50 → %60, eşik 10'a eşit → vurgulanır.
          topics: const [ExamTopicScore(topic: 'kalp', correct: 6, total: 10)],
        ),
      );
      expect(comparison.improvedTopics, hasLength(1));

      final tiny = ExamComparison.between(
        _result(
          id: 'p',
          correct: 5,
          total: 10,
          topics: const [ExamTopicScore(topic: 'kalp', correct: 10, total: 20)],
        ),
        _result(
          id: 'c',
          correct: 5,
          total: 10,
          // %50 → %55, eşiğin altında.
          topics: const [ExamTopicScore(topic: 'kalp', correct: 11, total: 20)],
        ),
      );
      expect(tiny.improvedTopics, isEmpty);
    });

    test('her yönde en fazla iki konu vurgulanır', () {
      final comparison = ExamComparison.between(
        _result(
          id: 'p',
          correct: 0,
          total: 20,
          topics: const [
            ExamTopicScore(topic: 'a', correct: 0, total: 5),
            ExamTopicScore(topic: 'b', correct: 0, total: 5),
            ExamTopicScore(topic: 'c', correct: 0, total: 5),
            ExamTopicScore(topic: 'd', correct: 0, total: 5),
          ],
        ),
        _result(
          id: 'c',
          correct: 20,
          total: 20,
          topics: const [
            ExamTopicScore(topic: 'a', correct: 5, total: 5),
            ExamTopicScore(topic: 'b', correct: 5, total: 5),
            ExamTopicScore(topic: 'c', correct: 5, total: 5),
            ExamTopicScore(topic: 'd', correct: 5, total: 5),
          ],
        ),
      );

      expect(
        comparison.improvedTopics,
        hasLength(ExamComparison.maxTopicHighlights),
      );
    });
  });

  group('FlashcardStore — sınav geçmişi', () {
    FlashcardStore store({List<ExamResult> results = const []}) =>
        FlashcardStore(
          _NoopGenerator(),
          initialData: LibraryData(examResults: results),
        );

    test('hiç sonuç yokken lastExamResultFor null döner', () {
      expect(store().lastExamResultFor(null), isNull);
    });

    test('kaydedilen sonuç geçmişin başına eklenir', () {
      final s = store();
      s.recordExamResult(_result(id: 'ilk', correct: 1, total: 2));
      s.recordExamResult(_result(id: 'ikinci', correct: 2, total: 2));

      expect(s.examResults.map((r) => r.id), ['ikinci', 'ilk']);
      expect(s.lastExamResultFor(null)!.id, 'ikinci');
    });

    test('lastExamResultFor yalnızca aynı deckId kapsamına bakar', () {
      final s = store(
        results: [
          _result(id: 'deste-a', correct: 1, total: 2, deckId: 'a'),
          _result(id: 'kütüphane', correct: 2, total: 2),
        ],
      );

      expect(s.lastExamResultFor('a')!.id, 'deste-a');
      expect(s.lastExamResultFor(null)!.id, 'kütüphane');
      expect(s.lastExamResultFor('bilinmeyen'), isNull);
    });

    test('geçmiş üst sınırı aşılmaz, en eskiler düşer', () {
      final s = store();
      for (var i = 0; i < ExamResult.maxHistory + 5; i++) {
        s.recordExamResult(_result(id: 'e$i', correct: 1, total: 2));
      }

      expect(s.examResults, hasLength(ExamResult.maxHistory));
      // En yeni başta, en eskiler kırpılmış.
      expect(s.examResults.first.id, 'e${ExamResult.maxHistory + 4}');
      expect(s.examResults.map((r) => r.id), isNot(contains('e0')));
    });

    test('sonuçlar libraryData üzerinden yedeğe/senkrona dahil olur', () {
      final s = store();
      s.recordExamResult(_result(id: 'x', correct: 1, total: 2));

      expect(s.libraryData.examResults.single.id, 'x');
    });
  });

  group('LibraryCodec — sınav sonuçları', () {
    test('gidiş-dönüşte sonuçlar korunur', () {
      final data = LibraryData(
        examResults: [
          _result(
            id: 'exam-1',
            correct: 3,
            total: 4,
            topics: const [ExamTopicScore(topic: 'kalp', correct: 3, total: 4)],
          ),
        ],
      );

      final restored = LibraryCodec.fromMap(LibraryCodec.toMap(data));

      expect(restored.examResults.single.id, 'exam-1');
      expect(restored.examResults.single.percent, 75);
      expect(restored.examResults.single.topicScores.single.topic, 'kalp');
    });

    test('bu özellikten ÖNCEKİ kayıtlar (alan yok) sorunsuz okunur', () {
      final restored = LibraryCodec.fromMap({
        'decks': <dynamic>[],
        'cards': <dynamic>[],
        'studyLog': <String, dynamic>{},
      });

      expect(restored.examResults, isEmpty);
    });
  });
}
