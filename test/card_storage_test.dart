import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/srs/srs_engine.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Diske değil belleğe yazan depolama; store'un ne kaydettiğini gözlemler.
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

final _deck = Deck(
  id: 'deck-1',
  name: 'Komite 1 · Kalp',
  createdAt: DateTime(2026, 7, 16),
);

final _card = Flashcard(
  id: '1',
  question: 'AV düğümdeki gecikmenin amacı nedir?',
  answer: 'Atriyumların önce kasılmasını sağlar.',
  deckId: 'deck-1',
  difficulty: CardDifficulty.zor,
  topic: 'ileti sistemi',
  intervalDays: 4,
  easeFactor: 2.3,
  repetitions: 2,
  lapses: 1,
  nextReview: DateTime(2026, 7, 20, 9, 30),
);

void main() {
  group('JSON', () {
    test('kart tüm SRS durumuyla birlikte yazılıp okunur', () {
      final restored = Flashcard.fromJson(_card.toJson());

      expect(restored.id, _card.id);
      expect(restored.question, _card.question);
      expect(restored.deckId, 'deck-1');
      expect(restored.difficulty, CardDifficulty.zor);
      expect(restored.topic, 'ileti sistemi');
      expect(restored.intervalDays, 4);
      expect(restored.easeFactor, 2.3);
      expect(restored.repetitions, 2);
      expect(restored.lapses, 1);
      expect(restored.nextReview, DateTime(2026, 7, 20, 9, 30));
    });

    test('sourcePage yazılıp okunur', () {
      final card = _card.copyWith(sourcePage: 47);
      expect(Flashcard.fromJson(card.toJson()).sourcePage, 47);
      // PDF'ten gelmeyen kartta null kalır.
      expect(Flashcard.fromJson(_card.toJson()).sourcePage, isNull);
    });

    test('deste yazılıp okunur', () {
      final restored = Deck.fromJson(_deck.toJson());

      expect(restored.id, 'deck-1');
      expect(restored.name, 'Komite 1 · Kalp');
      expect(restored.createdAt, DateTime(2026, 7, 16));
    });

    test('jsonEncode/jsonDecode turunda veri bozulmaz', () {
      final decoded = jsonDecode(jsonEncode(_card.toJson()));
      final restored = Flashcard.fromJson(decoded as Map<String, dynamic>);

      expect(restored.nextReview, _card.nextReview);
      expect(restored.easeFactor, _card.easeFactor);
    });

    test('hiç çalışılmamış kartın nextReview alanı null kalır', () {
      const fresh = Flashcard(id: '2', question: 'S', answer: 'C');
      final restored = Flashcard.fromJson(fresh.toJson());

      expect(restored.nextReview, isNull);
      expect(restored.isNew, isTrue);
    });

    test('eksik alanlı kayıt varsayılanlarla okunur', () {
      final restored = Flashcard.fromJson({
        'id': '3',
        'question': 'Soru?',
        'answer': 'Cevap.',
      });

      expect(restored.deckId, '');
      expect(restored.difficulty, CardDifficulty.orta);
      expect(restored.topic, '');
      expect(restored.intervalDays, 0);
      expect(restored.easeFactor, 2.5);
      expect(restored.nextReview, isNull);
    });
  });

  group('SharedPrefsCardStorage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('desteler ve kartlar birlikte kaydedilip yüklenir', () async {
      final storage = SharedPrefsCardStorage();
      await storage.save(LibraryData(decks: [_deck], cards: [_card]));

      final loaded = await storage.load();

      expect(loaded.decks, hasLength(1));
      expect(loaded.decks.single.name, 'Komite 1 · Kalp');
      expect(loaded.cards, hasLength(1));
      expect(loaded.cards.single.deckId, 'deck-1');
      expect(loaded.cards.single.nextReview, _card.nextReview);
    });

    test('kayıt yokken boş kütüphane döner', () async {
      final loaded = await SharedPrefsCardStorage().load();

      expect(loaded.isEmpty, isTrue);
    });

    test('bozuk JSON uygulamayı çökertmez', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsCardStorage.storageKey: 'bu json değil {{{',
      });

      final loaded = await SharedPrefsCardStorage().load();

      expect(loaded.isEmpty, isTrue);
    });

    test('tek bozuk kayıt diğerlerini düşürmez', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsCardStorage.storageKey: jsonEncode({
          'decks': [_deck.toJson()],
          'cards': [
            {'id': '1', 'question': 'Sağlam', 'answer': 'Kart.'},
            {'id': '2'}, // question/answer yok → atlanmalı
            'kart değil',
          ],
        }),
      });

      final loaded = await SharedPrefsCardStorage().load();

      expect(loaded.decks, hasLength(1));
      expect(loaded.cards, hasLength(1));
      expect(loaded.cards.single.question, 'Sağlam');
    });

    test('boş kütüphaneyi kaydetmek kayıtları temizler', () async {
      final storage = SharedPrefsCardStorage();
      await storage.save(LibraryData(decks: [_deck], cards: [_card]));
      await storage.save(const LibraryData());

      expect((await storage.load()).isEmpty, isTrue);
    });
  });

  group('deste öncesi kayıtların taşınması', () {
    test('eski kartlar tek desteye taşınır ve ilerlemeleri korunur', () async {
      // Deste desteği gelmeden önce kaydedilmiş kartlar.
      SharedPreferences.setMockInitialValues({
        SharedPrefsCardStorage.legacyKey: jsonEncode([
          {
            'id': '1',
            'question': 'Eski soru?',
            'answer': 'Eski cevap.',
            'difficulty': 'zor',
            'topic': 'ileti sistemi',
            'intervalDays': 4,
            'easeFactor': 2.3,
            'repetitions': 2,
            'lapses': 1,
            'nextReview': '2026-07-20T09:30:00.000',
          },
          {'id': '2', 'question': 'İkinci?', 'answer': 'Cevap.'},
        ]),
      });

      final loaded = await SharedPrefsCardStorage().load();

      // Kartlar kaybolmadı ve hepsi tek destede toplandı.
      expect(loaded.decks, hasLength(1));
      expect(loaded.decks.single.name, SharedPrefsCardStorage.migratedDeckName);
      expect(loaded.cards, hasLength(2));
      expect(
        loaded.cards.every((c) => c.deckId == loaded.decks.single.id),
        isTrue,
      );

      // SRS ilerlemesi korundu.
      final first = loaded.cards.firstWhere((c) => c.id == '1');
      expect(first.intervalDays, 4);
      expect(first.repetitions, 2);
      expect(first.lapses, 1);
      expect(first.difficulty, CardDifficulty.zor);
      expect(first.nextReview, DateTime(2026, 7, 20, 9, 30));
    });

    test('taşınan veri yeni biçimde kaydedilir, tekrar taşınmaz', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsCardStorage.legacyKey: jsonEncode([
          {'id': '1', 'question': 'S', 'answer': 'C'},
        ]),
      });

      final storage = SharedPrefsCardStorage();
      final first = await storage.load();
      final deckId = first.decks.single.id;

      // İkinci okumada v2 kaydı kullanılır: aynı deste, yeni deste açılmaz.
      final second = await storage.load();

      expect(second.decks, hasLength(1));
      expect(second.decks.single.id, deckId);
      expect(second.cards, hasLength(1));
    });

    test('yeni kayıt varken eski kayda bakılmaz', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsCardStorage.legacyKey: jsonEncode([
          {'id': 'eski', 'question': 'S', 'answer': 'C'},
        ]),
        SharedPrefsCardStorage.storageKey: jsonEncode({
          'decks': [_deck.toJson()],
          'cards': [_card.toJson()],
        }),
      });

      final loaded = await SharedPrefsCardStorage().load();

      expect(loaded.cards, hasLength(1));
      expect(loaded.cards.single.id, '1');
    });

    test('boş eski kayıt deste oluşturmaz', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsCardStorage.legacyKey: jsonEncode([]),
      });

      final loaded = await SharedPrefsCardStorage().load();

      expect(loaded.isEmpty, isTrue);
    });
  });

  group('FlashcardStore kalıcılığı', () {
    test('açılışta verilen kütüphane yüklenir', () {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(decks: [_deck], cards: [_card]),
      );

      expect(store.decks, hasLength(1));
      expect(store.cardsIn('deck-1'), hasLength(1));
      expect(store.cardById('1'), isNotNull);
    });

    test('addCards kartları deckId ve sourcePage ile ekler ve kaydeder', () {
      final storage = _FakeStorage();
      final store = FlashcardStore(
        _NoopGenerator(),
        storage: storage,
        initialData: LibraryData(decks: [_deck]),
      );

      store.addCards('deck-1', const [
        Flashcard(id: 'x', question: 'q', answer: 'a', sourcePage: 12),
      ]);

      final card = store.cardsIn('deck-1').single;
      expect(card.deckId, 'deck-1');
      expect(card.sourcePage, 12);
      expect(storage.saved.cards.single.sourcePage, 12);
    });

    test('cevap verildiğinde SRS durumu kaydedilir', () async {
      final storage = _FakeStorage();
      final store = FlashcardStore(
        _NoopGenerator(),
        storage: storage,
        initialData: LibraryData(
          decks: [_deck],
          cards: const [
            Flashcard(id: '1', question: 'S', answer: 'C', deckId: 'deck-1'),
          ],
        ),
      );

      store.reviewCard('1', ReviewGrade.orta, now: DateTime(2026, 7, 16));

      expect(storage.saveCount, 1);
      expect(storage.saved.cards.single.repetitions, 1);
      expect(storage.saved.cards.single.nextReview, DateTime(2026, 7, 17));
    });

    test('deste oluşturma, adlandırma ve silme kaydedilir', () async {
      final storage = _FakeStorage();
      final store = FlashcardStore(_NoopGenerator(), storage: storage);

      final deck = store.createDeck('Komite 2');
      expect(storage.saved.decks.single.name, 'Komite 2');

      store.renameDeck(deck.id, 'Komite 2 · Solunum');
      expect(storage.saved.decks.single.name, 'Komite 2 · Solunum');

      store.deleteDeck(deck.id);
      expect(storage.saved.decks, isEmpty);
    });

    test('düzenleme ve silme kaydedilir', () async {
      final storage = _FakeStorage();
      final store = FlashcardStore(
        _NoopGenerator(),
        storage: storage,
        initialData: LibraryData(
          decks: [_deck],
          cards: const [
            Flashcard(id: '1', question: 'S', answer: 'C', deckId: 'deck-1'),
          ],
        ),
      );

      store.updateCard(store.cardById('1')!.copyWith(question: 'Yeni soru'));
      expect(storage.saved.cards.single.question, 'Yeni soru');

      store.deleteCard('1');
      expect(storage.saved.cards, isEmpty);
    });

    test('silinen kart geri alınınca tekrar kaydedilir', () async {
      final storage = _FakeStorage();
      const card = Flashcard(
        id: '1',
        question: 'S',
        answer: 'C',
        deckId: 'deck-1',
      );
      final store = FlashcardStore(
        _NoopGenerator(),
        storage: storage,
        initialData: LibraryData(decks: [_deck], cards: const [card]),
      );

      final index = store.deleteCard('1')!;
      expect(storage.saved.cards, isEmpty);

      store.restoreCard(index, card);
      expect(storage.saved.cards, hasLength(1));
    });

    test('storage verilmezse çağrılar hata vermez', () {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: const [
            Flashcard(id: '1', question: 'S', answer: 'C', deckId: 'deck-1'),
          ],
        ),
      );

      expect(
        () => store.reviewCard('1', ReviewGrade.orta),
        returnsNormally,
      );
    });
  });

  group('deste yönetimi', () {
    test('deste silinince yalnızca kendi kartları gider', () {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [
            _deck,
            Deck(id: 'deck-2', name: 'Komite 2', createdAt: DateTime(2026, 7)),
          ],
          cards: const [
            Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-1'),
            Flashcard(id: '2', question: 'S2', answer: 'C', deckId: 'deck-2'),
          ],
        ),
      );

      store.deleteDeck('deck-1');

      expect(store.decks, hasLength(1));
      expect(store.cards, hasLength(1));
      expect(store.cardById('2'), isNotNull);
    });

    test('kartlar yalnızca kendi destesinde listelenir', () {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: const [
            Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-1'),
            Flashcard(id: '2', question: 'S2', answer: 'C', deckId: 'deck-2'),
          ],
        ),
      );

      expect(store.cardsIn('deck-1').map((c) => c.id), ['1']);
      expect(store.cardsIn('deck-2').map((c) => c.id), ['2']);
    });

    test('çalışma kuyruğu diğer destelerin kartlarını içermez', () {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: const [
            Flashcard(id: '1', question: 'S1', answer: 'C', deckId: 'deck-1'),
            Flashcard(id: '2', question: 'S2', answer: 'C', deckId: 'deck-2'),
          ],
        ),
      );

      expect(store.studyQueueFor('deck-1').map((c) => c.id), ['1']);
      expect(store.dueIn('deck-1').map((c) => c.id), ['1']);
    });

    test('konu etiketleri desteye göre ayrılır', () {
      final store = FlashcardStore(
        _NoopGenerator(),
        initialData: LibraryData(
          decks: [_deck],
          cards: const [
            Flashcard(
              id: '1',
              question: 'S',
              answer: 'C',
              deckId: 'deck-1',
              topic: 'kapaklar',
            ),
            Flashcard(
              id: '2',
              question: 'S',
              answer: 'C',
              deckId: 'deck-2',
              topic: 'solunum',
            ),
          ],
        ),
      );

      expect(store.topicsIn('deck-1'), ['kapaklar']);
      expect(store.topicsIn('deck-2'), ['solunum']);
    });
  });
}
