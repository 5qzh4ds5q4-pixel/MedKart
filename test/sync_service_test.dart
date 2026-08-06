import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/sync_service.dart';

Flashcard _card({
  required String id,
  String question = 'S',
  String deckId = 'd1',
  int? sourcePage,
  int repetitions = 0,
  DateTime? nextReview,
}) => Flashcard(
  id: id,
  question: question,
  answer: 'C',
  deckId: deckId,
  sourcePage: sourcePage,
  repetitions: repetitions,
  nextReview: nextReview,
);

void main() {
  group('SyncService.mergeLibraries — kartlar', () {
    test('yalnızca lokalde olan kart korunur', () {
      final local = LibraryData(cards: [_card(id: '1')]);
      const remote = LibraryData();

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.cards.map((c) => c.id), ['1']);
    });

    test('yalnızca buluttaki kart eklenir', () {
      const local = LibraryData();
      final remote = LibraryData(cards: [_card(id: '1')]);

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.cards.map((c) => c.id), ['1']);
    });

    test('aynı id: repetitions yüksek olan kazanır', () {
      final local = LibraryData(cards: [_card(id: '1', repetitions: 2)]);
      final remote = LibraryData(cards: [_card(id: '1', repetitions: 5)]);

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.cards.single.repetitions, 5);
    });

    test('aynı id: repetitions eşitse nextReview geç olan kazanır', () {
      final local = LibraryData(
        cards: [
          _card(id: '1', repetitions: 2, nextReview: DateTime(2026, 7, 20)),
        ],
      );
      final remote = LibraryData(
        cards: [
          _card(id: '1', repetitions: 2, nextReview: DateTime(2026, 7, 25)),
        ],
      );

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.cards.single.nextReview, DateTime(2026, 7, 25));
    });

    test(
      'farklı id ama aynı (question+sourcePage): içerik bazlı eşleşir, '
      'daha ileri SM-2 kazanır',
      () {
        final local = LibraryData(
          cards: [
            _card(
              id: 'local-1',
              question: 'Aynı soru',
              sourcePage: 3,
              repetitions: 1,
            ),
          ],
        );
        final remote = LibraryData(
          cards: [
            _card(
              id: 'remote-1',
              question: 'Aynı soru',
              sourcePage: 3,
              repetitions: 4,
            ),
          ],
        );

        final merged = SyncService.mergeLibraries(local, remote);

        expect(merged.cards.length, 1);
        expect(merged.cards.single.id, 'remote-1');
        expect(merged.cards.single.repetitions, 4);
      },
    );

    test('farklı sourcePage/soru: ayrı kart olarak kalır (eşleşmez)', () {
      final local = LibraryData(
        cards: [_card(id: 'local-1', question: 'S', sourcePage: 1)],
      );
      final remote = LibraryData(
        cards: [_card(id: 'remote-1', question: 'S', sourcePage: 2)],
      );

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.cards.map((c) => c.id).toSet(), {'local-1', 'remote-1'});
    });
  });

  group('SyncService.mergeLibraries — desteler', () {
    test('aynı isimli desteler tek desteye birleşir, kartlar yeni id\'ye taşınır', () {
      final local = LibraryData(
        decks: [Deck(id: 'local-d', name: 'Kalp', createdAt: DateTime(2026, 1, 1))],
        cards: [_card(id: '1', deckId: 'local-d')],
      );
      final remote = LibraryData(
        decks: [Deck(id: 'remote-d', name: 'Kalp', createdAt: DateTime(2026, 1, 2))],
        cards: [_card(id: '2', deckId: 'remote-d')],
      );

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.decks.length, 1);
      final survivorId = merged.decks.single.id;
      expect(merged.cards.every((c) => c.deckId == survivorId), isTrue);
    });

    test('farklı isimli desteler ayrı kalır', () {
      final local = LibraryData(
        decks: [Deck(id: 'a', name: 'Kalp', createdAt: DateTime(2026, 1, 1))],
      );
      final remote = LibraryData(
        decks: [Deck(id: 'b', name: 'Böbrek', createdAt: DateTime(2026, 1, 1))],
      );

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.decks.map((d) => d.name).toSet(), {'Kalp', 'Böbrek'});
    });

    test('sınav tarihi yalnızca birinde varsa korunur', () {
      final local = LibraryData(
        decks: [Deck(id: 'a', name: 'Kalp', createdAt: DateTime(2026, 1, 1))],
      );
      final remote = LibraryData(
        decks: [
          Deck(
            id: 'b',
            name: 'Kalp',
            createdAt: DateTime(2026, 1, 1),
            examDate: DateTime(2026, 8, 1),
          ),
        ],
      );

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.decks.single.examDate, DateTime(2026, 8, 1));
    });
  });

  group('SyncService.mergeLibraries — studyLog', () {
    test('gün bazlı büyük sayım alınır, kaybolan gün olmaz', () {
      final local = LibraryData(
        studyLog: StudyLog.fromJson({'2026-07-20': 3, '2026-07-21': 5}),
      );
      final remote = LibraryData(
        studyLog: StudyLog.fromJson({'2026-07-20': 7, '2026-07-22': 2}),
      );

      final merged = SyncService.mergeLibraries(local, remote);

      expect(merged.studyLog.countOn(DateTime(2026, 7, 20)), 7);
      expect(merged.studyLog.countOn(DateTime(2026, 7, 21)), 5);
      expect(merged.studyLog.countOn(DateTime(2026, 7, 22)), 2);
    });
  });
}
