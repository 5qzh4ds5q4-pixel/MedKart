import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/card_filter.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/srs/srs_engine.dart';
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

final _now = DateTime(2026, 7, 19, 10);

FlashcardStore _storeWith(List<Flashcard> cards) =>
    FlashcardStore(_NoopGenerator(), initialData: LibraryData(cards: cards));

FlashcardStore _storeWithDecks(List<Deck> decks, List<Flashcard> cards) =>
    FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: decks, cards: cards),
    );

void main() {
  group('dailyQueue', () {
    test('tekrar zamanı gelmiş kartlar yeni kartlardan önce gelir', () {
      final due = Flashcard(
        id: 'due',
        question: 'S',
        answer: 'C',
        repetitions: 2,
        nextReview: _now.subtract(const Duration(days: 1)),
      );
      const fresh = Flashcard(id: 'fresh', question: 'S', answer: 'C');

      final store = _storeWith([fresh, due]);
      final queue = store.dailyQueue(now: _now);

      expect(queue.map((c) => c.id), ['due', 'fresh']);
    });

    test('gelecekteki tekrar tarihi olan kart kuyruğa girmez', () {
      final notYetDue = Flashcard(
        id: 'later',
        question: 'S',
        answer: 'C',
        repetitions: 1,
        nextReview: _now.add(const Duration(days: 3)),
      );
      const fresh = Flashcard(id: 'fresh', question: 'S', answer: 'C');

      final store = _storeWith([notYetDue, fresh]);
      final queue = store.dailyQueue(now: _now);

      expect(queue.map((c) => c.id), ['fresh']);
    });

    test('yeni kart sayısı günlük limitle sınırlanır', () {
      final cards = [
        for (var i = 0; i < 5; i++)
          Flashcard(id: 'n$i', question: 'S$i', answer: 'C$i'),
      ];

      final store = _storeWith(cards);
      final queue = store.dailyQueue(now: _now, newCardLimit: 2);

      expect(queue, hasLength(2));
    });

    test('zayıf konudaki yeni kartlar öncelikli sırada gelir', () {
      // 'zayif' konusunda geçmişte çok unutulmuş bir kart var; iki konudaki
      // yeni kartlardan zayıf konuya ait olan önce gelmeli.
      final zayifGecmis = Flashcard(
        id: 'zayif-gecmis',
        question: 'S',
        answer: 'C',
        topic: 'zayif',
        lapses: 3,
        repetitions: 1,
        nextReview: _now.add(const Duration(days: 30)),
      );
      const yeniZayif = Flashcard(
        id: 'yeni-zayif',
        question: 'S',
        answer: 'C',
        topic: 'zayif',
      );
      const yeniSaglam = Flashcard(
        id: 'yeni-saglam',
        question: 'S',
        answer: 'C',
        topic: 'saglam',
      );

      final store = _storeWith([yeniSaglam, zayifGecmis, yeniZayif]);
      final queue = store.dailyQueue(now: _now, newCardLimit: 10);

      // zayifGecmis henüz due değil (30 gün sonraya planlı), kuyrukta yalnızca
      // yeni kartlar kalır ama zayıf konudaki önce gelmeli.
      expect(queue.map((c) => c.id), ['yeni-zayif', 'yeni-saglam']);
    });

    test('filtre (ör. Sınav Modu) uygulanır', () {
      const examCard = Flashcard(
        id: 'exam',
        question: 'S',
        answer: 'C',
        cardType: CardType.sinav,
      );
      const backgroundCard = Flashcard(
        id: 'background',
        question: 'S',
        answer: 'C',
        priority: CardPriority.arkaPlan,
      );

      final store = _storeWith([examCard, backgroundCard]);
      final queue = store.dailyQueue(
        now: _now,
        filter: const CardFilter(examOnly: true),
      );

      expect(queue.map((c) => c.id), ['exam']);
    });

    test('birden fazla desteden kartlar birleşik kuyruğa girer', () {
      const a = Flashcard(id: 'a', question: 'S', answer: 'C', deckId: 'd1');
      const b = Flashcard(id: 'b', question: 'S', answer: 'C', deckId: 'd2');

      final store = _storeWith([a, b]);
      final queue = store.dailyQueue(now: _now);

      expect(queue.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('yoğun tekrar modundaki destenin yeni kartları limitsiz girer', () {
      final crammingDeck = Deck(
        id: 'cram',
        name: 'Yaklaşan sınav',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 2)),
      );
      final normalDeck = Deck(id: 'normal', name: 'Uzak sınav', createdAt: _now);

      final crammedCards = [
        for (var i = 0; i < 5; i++)
          Flashcard(id: 'c$i', question: 'S$i', answer: 'C$i', deckId: 'cram'),
      ];
      final normalCards = [
        for (var i = 0; i < 5; i++)
          Flashcard(id: 'n$i', question: 'S$i', answer: 'C$i', deckId: 'normal'),
      ];

      final store = _storeWithDecks(
        [crammingDeck, normalDeck],
        [...crammedCards, ...normalCards],
      );
      final queue = store.dailyQueue(now: _now, newCardLimit: 2);

      // Yoğun tekrar modundaki destenin 5 kartı da girer, normal deste 2'yle sınırlı.
      expect(queue.where((c) => c.deckId == 'cram'), hasLength(5));
      expect(queue.where((c) => c.deckId == 'normal'), hasLength(2));
    });

    test('sınavı 3 günden uzak olan deste normal limite tabidir', () {
      final farDeck = Deck(
        id: 'far',
        name: 'Uzak sınav',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 10)),
      );
      final cards = [
        for (var i = 0; i < 5; i++)
          Flashcard(id: 'f$i', question: 'S$i', answer: 'C$i', deckId: 'far'),
      ];

      final store = _storeWithDecks([farDeck], cards);
      final queue = store.dailyQueue(now: _now, newCardLimit: 2);

      expect(queue, hasLength(2));
    });

    test('sınavı geçmiş deste yoğun tekrar modunda sayılmaz', () {
      final pastExamDeck = Deck(
        id: 'past',
        name: 'Geçmiş sınav',
        createdAt: _now,
        examDate: _now.subtract(const Duration(days: 1)),
      );
      final cards = [
        for (var i = 0; i < 5; i++)
          Flashcard(id: 'p$i', question: 'S$i', answer: 'C$i', deckId: 'past'),
      ];

      final store = _storeWithDecks([pastExamDeck], cards);
      final queue = store.dailyQueue(now: _now, newCardLimit: 2);

      expect(queue, hasLength(2));
    });
  });

  group('setDeckExamDate', () {
    test('sınav tarihini ayarlar ve kaldırır', () {
      final deck = Deck(id: 'd1', name: 'Deste', createdAt: _now);
      final store = _storeWithDecks([deck], const []);

      store.setDeckExamDate('d1', DateTime(2026, 8, 1));
      expect(store.deckById('d1')!.examDate, DateTime(2026, 8, 1));

      store.setDeckExamDate('d1', null);
      expect(store.deckById('d1')!.examDate, isNull);
    });
  });

  group('reviewCard sınav tarihine duyarlılık', () {
    test('destenin sınav tarihi normal SM-2 aralığını sıkıştırır', () {
      final deck = Deck(
        id: 'd1',
        name: 'Deste',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 6)),
      );
      final card = Flashcard(
        id: 'c1',
        question: 'S',
        answer: 'C',
        deckId: 'd1',
        repetitions: 2,
        intervalDays: 4,
        easeFactor: 2.5,
      );

      final store = _storeWithDecks([deck], [card]);
      store.reviewCard('c1', ReviewGrade.orta, now: _now);

      // Sıkıştırılmamış hâli 10 gün olurdu (4 × 2.5); kalan 6 günün yarısı: 3.
      expect(store.cardById('c1')!.intervalDays, 3);
    });
  });

  group('dailyQueue öncelikli mod', () {
    test('priorityModeDeckIds boşken davranış değişmez', () {
      final cards = [
        Flashcard(
          id: 'bg',
          question: 'S',
          answer: 'C',
          deckId: 'd1',
          priority: CardPriority.arkaPlan,
        ),
        Flashcard(
          id: 'p',
          question: 'S',
          answer: 'C',
          deckId: 'd1',
          priority: CardPriority.oncelikli,
        ),
      ];
      final store = _storeWith(cards);

      final withoutMode = store.dailyQueue(now: _now).map((c) => c.id).toList();
      final withEmptyMode = store
          .dailyQueue(now: _now, priorityModeDeckIds: const {})
          .map((c) => c.id)
          .toList();

      expect(withEmptyMode, withoutMode);
    });

    test('mod açılan destede arkaPlan kartlar sona itilir, silinmez', () {
      final cards = [
        Flashcard(
          id: 'bg',
          question: 'S',
          answer: 'C',
          deckId: 'd1',
          priority: CardPriority.arkaPlan,
        ),
        Flashcard(
          id: 'p',
          question: 'S',
          answer: 'C',
          deckId: 'd1',
          priority: CardPriority.oncelikli,
        ),
      ];
      final store = _storeWith(cards);

      final queue = store.dailyQueue(
        now: _now,
        priorityModeDeckIds: const {'d1'},
      );

      expect(queue.map((c) => c.id), ['p', 'bg']);
      expect(queue.map((c) => c.id).toSet(), {'bg', 'p'});
    });
  });

  group('examPaceWarning', () {
    FlashcardStore storeWithLog(
      List<Deck> decks,
      List<Flashcard> cards,
      StudyLog studyLog,
    ) => FlashcardStore(
      _NoopGenerator(),
      initialData: LibraryData(decks: decks, cards: cards, studyLog: studyLog),
    );

    final steadyLog = StudyLog(const {
      '2026-07-14': 10,
      '2026-07-15': 10,
      '2026-07-16': 10,
    });

    test('yeterli çalışma geçmişi olmayan kullanıcıda hiç uyarı çıkmaz', () {
      final deck = Deck(
        id: 'd1',
        name: 'Deste',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 2)),
      );
      final cards = [
        for (var i = 0; i < 200; i++)
          Flashcard(id: 'c$i', question: 'S$i', answer: 'C$i', deckId: 'd1'),
      ];

      final store = storeWithLog([deck], cards, const StudyLog());

      expect(store.examPaceWarning(now: _now), isNull);
    });

    test('yetişebilir durumda uyarı çıkmaz', () {
      final deck = Deck(
        id: 'd1',
        name: 'Deste',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 10)),
      );
      // Tempo günde 10 kart; 10 günde 100 kapasite (+tolerans) — 50 kart rahat yetişir.
      final cards = [
        for (var i = 0; i < 50; i++)
          Flashcard(id: 'c$i', question: 'S$i', answer: 'C$i', deckId: 'd1'),
      ];

      final store = storeWithLog([deck], cards, steadyLog);

      expect(store.examPaceWarning(now: _now), isNull);
    });

    test('yetişmez durumda uyarı çıkar', () {
      final deck = Deck(
        id: 'd1',
        name: 'Deste',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 2)),
      );
      // Tempo günde 10 kart; 2 günde 20 kapasite (+tolerans 22) — 200 kart hiç yetişmez.
      final cards = [
        for (var i = 0; i < 200; i++)
          Flashcard(id: 'c$i', question: 'S$i', answer: 'C$i', deckId: 'd1'),
      ];

      final store = storeWithLog([deck], cards, steadyLog);

      final warning = store.examPaceWarning(now: _now);
      expect(warning, isNotNull);
      expect(warning!.deckId, 'd1');
    });

    test('birden fazla deste yetişmiyorsa sınav tarihi en yakın olan döner', () {
      final farDeck = Deck(
        id: 'far',
        name: 'Uzak',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 5)),
      );
      final nearDeck = Deck(
        id: 'near',
        name: 'Yakın',
        createdAt: _now,
        examDate: _now.add(const Duration(days: 2)),
      );
      final cards = [
        for (var i = 0; i < 200; i++)
          Flashcard(id: 'far$i', question: 'S', answer: 'C', deckId: 'far'),
        for (var i = 0; i < 200; i++)
          Flashcard(id: 'near$i', question: 'S', answer: 'C', deckId: 'near'),
      ];

      final store = storeWithLog([farDeck, nearDeck], cards, steadyLog);

      final warning = store.examPaceWarning(now: _now);
      expect(warning, isNotNull);
      expect(warning!.deckId, 'near');
    });
  });

  group('weakestTopicInfo', () {
    test('yeterli/güvenilir veri yoksa null döner', () {
      final store = _storeWith([
        for (var i = 0; i < 4; i++)
          Flashcard(id: 'c$i', question: 'S', answer: 'C', topic: 'zayif'),
      ]);
      expect(store.weakestTopicInfo, isNull);
    });

    test('destelerden bağımsız, kütüphanenin tamamındaki en zayıf konuyu döner', () {
      final store = _storeWithDecks(
        [
          Deck(id: 'd1', name: 'Deste 1', createdAt: _now),
          Deck(id: 'd2', name: 'Deste 2', createdAt: _now),
        ],
        [
          // "zayif" konusu iki AYRI destede dağılmış — deste sınırı gözetmeden
          // birleşik değerlendirilmeli.
          for (var i = 0; i < 3; i++)
            Flashcard(
              id: 'w1-$i',
              question: 'S',
              answer: 'C',
              deckId: 'd1',
              topic: 'zayif',
              repetitions: 1,
              lapses: 3,
            ),
          for (var i = 0; i < 2; i++)
            Flashcard(
              id: 'w2-$i',
              question: 'S',
              answer: 'C',
              deckId: 'd2',
              topic: 'zayif',
              repetitions: 1,
              lapses: 3,
            ),
          for (var i = 0; i < 5; i++)
            Flashcard(
              id: 'g$i',
              question: 'S',
              answer: 'C',
              deckId: 'd1',
              topic: 'guclu',
              repetitions: 5,
            ),
        ],
      );

      final info = store.weakestTopicInfo;
      expect(info, isNotNull);
      expect(info!.topic, 'zayif');
      expect(info.cardCount, 5);
    });
  });

  // stampDeckSourcePdf: alan HENÜZ HİÇBİR YERDE OKUNMUYOR (TUS eklentisi
  // ayrı bir adım). Burada sabitlenen şey POLİTİKA: ilk PDF kazanır.
  group('stampDeckSourcePdf', () {
    Deck deck() => Deck(id: 'd1', name: 'Deste', createdAt: _now);

    test('damgasiz desteyi damgalar', () {
      final store = _storeWithDecks([deck()], const []);

      store.stampDeckSourcePdf('d1', hash: 'abc', name: 'a.pdf');

      expect(store.deckById('d1')!.sourcePdfHash, 'abc');
      expect(store.deckById('d1')!.sourcePdfName, 'a.pdf');
    });

    test('ILK PDF KAZANIR — zaten damgali desteyi EZMEZ', () {
      final store = _storeWithDecks([deck()], const []);

      store.stampDeckSourcePdf('d1', hash: 'ilk', name: 'ilk.pdf');
      store.stampDeckSourcePdf('d1', hash: 'ikinci', name: 'ikinci.pdf');

      expect(store.deckById('d1')!.sourcePdfHash, 'ilk');
      expect(store.deckById('d1')!.sourcePdfName, 'ilk.pdf');
    });

    test('bos/eksik hash sessizce yok sayilir', () {
      final store = _storeWithDecks([deck()], const []);

      store.stampDeckSourcePdf('d1', hash: null, name: 'a.pdf');
      store.stampDeckSourcePdf('d1', hash: '   ', name: 'a.pdf');

      expect(store.deckById('d1')!.hasSourcePdf, isFalse);
    });

    test('bos ad null olur ama hash yine damgalanir', () {
      final store = _storeWithDecks([deck()], const []);

      store.stampDeckSourcePdf('d1', hash: 'abc', name: '  ');

      expect(store.deckById('d1')!.sourcePdfHash, 'abc');
      expect(store.deckById('d1')!.sourcePdfName, isNull);
    });

    test('olmayan deste id sessizce yok sayilir', () {
      final store = _storeWithDecks([deck()], const []);

      store.stampDeckSourcePdf('yok', hash: 'abc', name: 'a.pdf');

      expect(store.deckById('d1')!.hasSourcePdf, isFalse);
    });

    test('damga desteyi baska yonden BOZMAZ', () {
      final store = _storeWithDecks([
        Deck(
          id: 'd1',
          name: 'Deste',
          createdAt: _now,
          examDate: DateTime(2026, 9, 1),
        ),
      ], const []);

      store.stampDeckSourcePdf('d1', hash: 'abc', name: 'a.pdf');

      final updated = store.deckById('d1')!;
      expect(updated.name, 'Deste');
      expect(updated.examDate, DateTime(2026, 9, 1));
    });
  });
}
