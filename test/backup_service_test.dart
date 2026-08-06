import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/services/backup_service.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
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

class _FakeStorage implements CardStorage {
  LibraryData saved = const LibraryData();
  int saveCount = 0;

  @override
  Future<LibraryData> load() async => saved;

  @override
  Future<void> save(LibraryData data) async {
    saved = data;
    saveCount++;
  }
}

final _deck = Deck(id: 'd1', name: 'Kalp', createdAt: DateTime(2026, 7, 16));

final _library = LibraryData(
  decks: [_deck],
  cards: [
    Flashcard(
      id: '1',
      question: 'Kullanıcı sorusu?',
      answer: 'Cevap.',
      deckId: 'd1',
      topic: 'ileti sistemi',
      note: 'benim notum',
      originalQuestion: 'AI sorusu?',
      flagged: true,
      repetitions: 3,
      lapses: 1,
      intervalDays: 10,
      easeFactor: 2.4,
    ),
  ],
  studyLog: StudyLog.fromJson({'2026-07-16': 4}),
);

void main() {
  group('BackupService', () {
    test('export edilen yedek import ile birebir geri gelir', () {
      final json = BackupService.export(_library);
      final restored = BackupService.tryImport(json)!;

      expect(restored.decks.single.name, 'Kalp');
      final card = restored.cards.single;
      expect(card.question, 'Kullanıcı sorusu?');
      expect(card.note, 'benim notum');
      expect(card.originalQuestion, 'AI sorusu?');
      expect(card.flagged, isTrue);
      expect(card.repetitions, 3);
      expect(card.easeFactor, 2.4);
      expect(restored.studyLog.countOn(DateTime(2026, 7, 16)), 4);
    });

    test('export çıktısı app etiketi ve sürüm taşır', () {
      final decoded = jsonDecode(BackupService.export(_library)) as Map;
      expect(decoded['app'], 'medkart');
      expect(decoded['version'], BackupService.formatVersion);
    });

    test('geçersiz JSON null döner', () {
      expect(BackupService.tryImport('bu json değil {['), isNull);
    });

    test('yabancı JSON (bizim biçimimiz değil) null döner', () {
      expect(BackupService.tryImport('{"foo": 1}'), isNull);
    });

    test('bozuk tek kayıt atlanır, kalan korunur', () {
      final json = jsonEncode({
        'app': 'medkart',
        'cards': [
          {'id': '1', 'question': 'S', 'answer': 'C'},
          {'id': '2'}, // eksik alan → atlanır
        ],
      });
      final restored = BackupService.tryImport(json)!;
      expect(restored.cards.length, 1);
      expect(restored.cards.single.id, '1');
    });

    test('suggestedFileName tarih damgalı .json üretir', () {
      expect(
        BackupService.suggestedFileName(DateTime(2026, 7, 9)),
        'medkart-yedek-20260709.json',
      );
    });
  });

  group('BackupService.exportDeck (deste başına ayrı dosya)', () {
    final deckA = Deck(id: 'dA', name: 'Kalp', createdAt: DateTime(2026, 7, 1));
    final deckB = Deck(id: 'dB', name: 'Böbrek', createdAt: DateTime(2026, 7, 2));
    final multiDeckLibrary = LibraryData(
      decks: [deckA, deckB],
      cards: const [
        Flashcard(id: 'a1', question: 'A soru 1?', answer: 'C.', deckId: 'dA'),
        Flashcard(id: 'a2', question: 'A soru 2?', answer: 'C.', deckId: 'dA'),
        Flashcard(id: 'b1', question: 'B soru 1?', answer: 'C.', deckId: 'dB'),
      ],
      studyLog: StudyLog.fromJson({'2026-07-16': 4}),
    );

    test('yalnızca o desteyi ve o destenin kartlarını içerir', () {
      final restored =
          BackupService.tryImport(
            BackupService.exportDeck(multiDeckLibrary, deckA),
          )!;

      expect(restored.decks.single.id, 'dA');
      expect(restored.cards.map((c) => c.id), ['a1', 'a2']);
      // Diğer destenin kartı sızmaz.
      expect(restored.cards.any((c) => c.deckId == 'dB'), isFalse);
    });

    test('studyLog ve examResults dahil edilmez (kütüphane geneli veri)', () {
      final restored =
          BackupService.tryImport(
            BackupService.exportDeck(multiDeckLibrary, deckA),
          )!;

      expect(restored.studyLog.countOn(DateTime(2026, 7, 16)), 0);
      expect(restored.examResults, isEmpty);
    });

    test('zarf tam yedekle aynı: app etiketi + sürüm taşır, tryImport açar', () {
      final decoded =
          jsonDecode(BackupService.exportDeck(multiDeckLibrary, deckB)) as Map;
      expect(decoded['app'], 'medkart');
      expect(decoded['version'], BackupService.formatVersion);

      final restored = BackupService.tryImport(
        BackupService.exportDeck(multiDeckLibrary, deckB),
      );
      expect(restored, isNotNull);
      expect(restored!.decks.single.name, 'Böbrek');
      expect(restored.cards.single.id, 'b1');
    });

    test('suggestedDeckFileName Türkçe karakter ve boşluğu sadeleştirir', () {
      expect(
        BackupService.suggestedDeckFileName(
          'Üro-Genital Sistem 2',
          DateTime(2026, 8, 5),
        ),
        'medkart-uro-genital-sistem-2-20260805.json',
      );
      // 'İ' → toLowerCase'te iki code point'e ayrışan tuzak karakter.
      expect(
        BackupService.suggestedDeckFileName('İLERİ Kardiyo', DateTime(2026, 8, 5)),
        'medkart-ileri-kardiyo-20260805.json',
      );
    });

    test('suggestedDeckFileName tamamen elenen adda "deste"ye düşer', () {
      expect(
        BackupService.suggestedDeckFileName('***', DateTime(2026, 8, 5)),
        'medkart-deste-20260805.json',
      );
    });
  });

  group('FlashcardStore.replaceLibrary', () {
    test('kütüphaneyi değiştirir ve kalıcılaştırır', () {
      final storage = _FakeStorage();
      final store = FlashcardStore(
        _NoopGenerator(),
        storage: storage,
        initialData: LibraryData(
          decks: [Deck(id: 'old', name: 'Eski', createdAt: DateTime(2026, 1, 1))],
          cards: [const Flashcard(id: 'x', question: 'q', answer: 'a', deckId: 'old')],
        ),
      );

      store.replaceLibrary(_library);

      expect(store.decks.single.name, 'Kalp');
      expect(store.cards.single.id, '1');
      expect(store.studyLog.countOn(DateTime(2026, 7, 16)), 4);
      // Diske de yazıldı.
      expect(storage.saved.decks.single.name, 'Kalp');
    });
  });
}
