import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/srs/srs_engine.dart';

final _now = DateTime(2026, 7, 16, 10);

Flashcard _card({
  String id = '1',
  CardDifficulty difficulty = CardDifficulty.orta,
  bool difficultyManual = false,
  String topic = 'kapaklar',
  String deckId = '',
  CardPriority priority = CardPriority.oncelikli,
  int intervalDays = 0,
  double easeFactor = 2.5,
  int repetitions = 0,
  int lapses = 0,
  DateTime? nextReview,
}) {
  return Flashcard(
    id: id,
    question: 'Soru?',
    answer: 'Cevap.',
    difficulty: difficulty,
    difficultyManual: difficultyManual,
    topic: topic,
    deckId: deckId,
    priority: priority,
    intervalDays: intervalDays,
    easeFactor: easeFactor,
    repetitions: repetitions,
    lapses: lapses,
    nextReview: nextReview,
  );
}

void main() {
  group('aralık ilerlemesi', () {
    test('yeni kartta ilk "Biliyorum" kartı yarına atar', () {
      final reviewed = SrsEngine.applyReview(
        _card(),
        ReviewGrade.orta,
        now: _now,
      );

      expect(reviewed.intervalDays, 1);
      expect(reviewed.repetitions, 1);
      expect(reviewed.nextReview, _now.add(const Duration(days: 1)));
    });

    test('ikinci ardışık "Biliyorum" kartı 4 gün sonraya atar', () {
      final reviewed = SrsEngine.applyReview(
        _card(repetitions: 1, intervalDays: 1),
        ReviewGrade.orta,
        now: _now,
      );

      expect(reviewed.intervalDays, 4);
      expect(reviewed.repetitions, 2);
      expect(reviewed.nextReview, _now.add(const Duration(days: 4)));
    });

    test('üçüncüden sonra aralık kolaylık katsayısıyla büyür', () {
      // 4 gün × 2.5 = 10 gün
      final reviewed = SrsEngine.applyReview(
        _card(repetitions: 2, intervalDays: 4, easeFactor: 2.5),
        ReviewGrade.orta,
        now: _now,
      );

      expect(reviewed.intervalDays, 10);
    });

    test('aralık üst sınırı aşmaz', () {
      final reviewed = SrsEngine.applyReview(
        _card(repetitions: 9, intervalDays: 300, easeFactor: 2.5),
        ReviewGrade.orta,
        now: _now,
      );

      expect(reviewed.intervalDays, SrsEngine.maxIntervalDays);
    });
  });

  group('"Kolay" cevabı', () {
    test('yeni kartta bile aralığı bariz açar (4 gün)', () {
      // Orta yeni kartı 1 güne atar; kolay en az ikinci aralığa atlar.
      final kolay = SrsEngine.applyReview(_card(), ReviewGrade.kolay, now: _now);
      final orta = SrsEngine.applyReview(_card(), ReviewGrade.orta, now: _now);

      expect(orta.intervalDays, 1);
      expect(kolay.intervalDays, 4);
      expect(kolay.repetitions, 1);
    });

    test('olgun kartta aralık ortadan daha çok uzar', () {
      final card = _card(repetitions: 2, intervalDays: 10, easeFactor: 2.5);
      final orta = SrsEngine.applyReview(card, ReviewGrade.orta, now: _now);
      final kolay = SrsEngine.applyReview(card, ReviewGrade.kolay, now: _now);

      expect(kolay.intervalDays, greaterThan(orta.intervalDays));
    });

    test('kolaylık katsayısını artırır', () {
      final reviewed = SrsEngine.applyReview(
        _card(repetitions: 2, intervalDays: 10, easeFactor: 2.5),
        ReviewGrade.kolay,
        now: _now,
      );

      expect(reviewed.easeFactor, closeTo(2.65, 0.001));
    });

    test('kolaylık katsayısı üst sınırı aşmaz', () {
      final reviewed = SrsEngine.applyReview(
        _card(repetitions: 2, intervalDays: 10, easeFactor: 2.75),
        ReviewGrade.kolay,
        now: _now,
      );

      expect(reviewed.easeFactor, SrsEngine.maxEase);
    });

    test('kolay cevap unutma sayısını artırmaz', () {
      final reviewed = SrsEngine.applyReview(
        _card(repetitions: 1, intervalDays: 4, lapses: 2),
        ReviewGrade.kolay,
        now: _now,
      );

      expect(reviewed.lapses, 2);
    });
  });

  group('değerlendirme sınıflandırması', () {
    test('zor bir başarısızlık, orta ve kolay doğru sayılır', () {
      expect(ReviewGrade.zor.isCorrect, isFalse);
      expect(ReviewGrade.orta.isCorrect, isTrue);
      expect(ReviewGrade.kolay.isCorrect, isTrue);
    });
  });

  group('unutma', () {
    test('"Bilmiyorum" kartı ertesi güne atar ve ilerlemeyi sıfırlar', () {
      final reviewed = SrsEngine.applyReview(
        _card(repetitions: 3, intervalDays: 25, easeFactor: 2.5),
        ReviewGrade.zor,
        now: _now,
      );

      expect(reviewed.intervalDays, 1);
      expect(reviewed.repetitions, 0);
      expect(reviewed.lapses, 1);
      expect(reviewed.nextReview, _now.add(const Duration(days: 1)));
    });

    test('her unutmada kolaylık katsayısı düşer, kart sıklaşır', () {
      final once = SrsEngine.applyReview(
        _card(repetitions: 2, intervalDays: 4),
        ReviewGrade.zor,
        now: _now,
      );
      expect(once.easeFactor, closeTo(2.3, 0.001));

      final twice = SrsEngine.applyReview(
        once,
        ReviewGrade.zor,
        now: _now,
      );
      expect(twice.easeFactor, closeTo(2.1, 0.001));
      expect(twice.lapses, 2);
    });

    test('kolaylık katsayısı alt sınırın altına inmez', () {
      var card = _card(easeFactor: 1.4, repetitions: 1);
      for (var i = 0; i < 5; i++) {
        card = SrsEngine.applyReview(card, ReviewGrade.zor, now: _now);
      }

      expect(card.easeFactor, SrsEngine.minEase);
    });

    test('unutulan kart, hiç unutulmayana göre daha erken geri gelir', () {
      // İkisi de 3. tekrarında; biri geçmişte unutmuş olduğu için katsayısı düşük.
      final saglam = SrsEngine.applyReview(
        _card(repetitions: 2, intervalDays: 4, easeFactor: 2.5),
        ReviewGrade.orta,
        now: _now,
      );
      final unutulmus = SrsEngine.applyReview(
        _card(repetitions: 2, intervalDays: 4, easeFactor: 2.1, lapses: 2),
        ReviewGrade.orta,
        now: _now,
      );

      expect(unutulmus.intervalDays, lessThan(saglam.intervalDays));
    });
  });

  group('zorluk etiketi başlangıç katsayısını belirler', () {
    test('"zor" kart "kolay" karta göre daha yavaş aralıklanır', () {
      Flashcard grow(CardDifficulty d) {
        var card = _card(difficulty: d);
        // Üç kez üst üste bilinsin: 1 gün → 4 gün → 4×ease
        for (var i = 0; i < 3; i++) {
          card = SrsEngine.applyReview(card, ReviewGrade.orta, now: _now);
        }
        return card;
      }

      final kolay = grow(CardDifficulty.kolay);
      final zor = grow(CardDifficulty.zor);

      expect(zor.intervalDays, lessThan(kolay.intervalDays));
      expect(kolay.easeFactor, 2.6);
      expect(zor.easeFactor, 2.3);
    });
  });

  group('tekrar zamanı', () {
    test('hiç çalışılmamış kart hemen tekrara hazırdır', () {
      expect(_card().isDue(_now), isTrue);
      expect(_card().isNew, isTrue);
    });

    test('ileri atılmış kart zamanı gelene kadar due olmaz', () {
      final reviewed = SrsEngine.applyReview(
        _card(),
        ReviewGrade.orta,
        now: _now,
      );

      expect(reviewed.isDue(_now), isFalse);
      expect(reviewed.isDue(_now.add(const Duration(hours: 23))), isFalse);
      expect(reviewed.isDue(_now.add(const Duration(days: 1))), isTrue);
    });

    test('dueCards yalnızca zamanı gelenleri döner', () {
      final bekleyen = SrsEngine.applyReview(
        _card(id: 'bekleyen'),
        ReviewGrade.orta,
        now: _now,
      );
      final yeni = _card(id: 'yeni');

      final due = SrsEngine.dueCards([bekleyen, yeni], _now);

      expect(due.map((c) => c.id), ['yeni']);
    });
  });

  group('konu zayıflığı', () {
    test('unutma oranı yüksek konu daha zayıf sayılır', () {
      final cards = [
        _card(id: '1', topic: 'ileti sistemi', lapses: 3, repetitions: 1),
        _card(id: '2', topic: 'kapaklar', lapses: 0, repetitions: 4),
      ];

      final weakness = SrsEngine.topicWeakness(cards);

      expect(weakness['ileti sistemi'], closeTo(0.75, 0.001));
      expect(weakness['kapaklar'], 0);
    });

    test('hiç çalışılmamış konu sıfır zayıflıkla başlar', () {
      final weakness = SrsEngine.topicWeakness([_card(topic: 'koroner')]);
      expect(weakness['koroner'], 0);
    });

    test('çalışma sırası zayıf konuyu öne alır', () {
      final zayif = _card(id: 'zayif', topic: 'ileti sistemi', lapses: 3, repetitions: 1);
      final saglam = _card(id: 'saglam', topic: 'kapaklar', lapses: 0, repetitions: 4);
      final all = [saglam, zayif];

      final sorted = SrsEngine.sortForStudy(all, all);

      expect(sorted.first.id, 'zayif');
    });

    test('eşit zayıflıkta en uzun süredir bekleyen kart öne gelir', () {
      final eski = _card(
        id: 'eski',
        topic: 'a',
        nextReview: _now.subtract(const Duration(days: 5)),
      );
      final yeni = _card(
        id: 'yeni',
        topic: 'a',
        nextReview: _now.subtract(const Duration(days: 1)),
      );
      final all = [yeni, eski];

      final sorted = SrsEngine.sortForStudy(all, all);

      expect(sorted.first.id, 'eski');
    });
  });

  group('konu harmanlama (interleaveByTopic)', () {
    test('2+ farklı konu varsa art arda gelen iki kart aynı konu olmaz', () {
      final sorted = [
        _card(id: 'a1', topic: 'a'),
        _card(id: 'a2', topic: 'a'),
        _card(id: 'a3', topic: 'a'),
        _card(id: 'b1', topic: 'b'),
        _card(id: 'b2', topic: 'b'),
        _card(id: 'b3', topic: 'b'),
        _card(id: 'c1', topic: 'c'),
        _card(id: 'c2', topic: 'c'),
        _card(id: 'c3', topic: 'c'),
      ];

      final result = SrsEngine.interleaveByTopic(sorted);

      expect(result.length, sorted.length);
      expect(result.toSet(), sorted.toSet());
      for (var i = 1; i < result.length; i++) {
        expect(result[i].topic, isNot(result[i - 1].topic));
      }
    });

    test('konu-içi sıra aynen korunur, yalnızca konular harmanlanır', () {
      final sorted = [
        _card(id: 'a1', topic: 'a'),
        _card(id: 'a2', topic: 'a'),
        _card(id: 'b1', topic: 'b'),
      ];

      final result = SrsEngine.interleaveByTopic(sorted);

      // 'a' konusunun kendi içindeki sırası (a1 önce a2) korunmalı.
      final aIds = result.where((c) => c.topic == 'a').map((c) => c.id).toList();
      expect(aIds, ['a1', 'a2']);
    });

    test('tükenen konu atlanır, kalan konudan almaya devam edilir', () {
      final sorted = [
        _card(id: 'a1', topic: 'a'),
        _card(id: 'b1', topic: 'b'),
        _card(id: 'b2', topic: 'b'),
        _card(id: 'b3', topic: 'b'),
      ];

      final result = SrsEngine.interleaveByTopic(sorted);

      expect(result.map((c) => c.id), ['a1', 'b1', 'b2', 'b3']);
    });

    test('tek konu varsa sıra AYNEN korunur (harmanlama yapılmaz)', () {
      final sorted = [
        _card(id: '1', topic: 'kapaklar'),
        _card(id: '2', topic: 'kapaklar'),
        _card(id: '3', topic: 'kapaklar'),
      ];

      final result = SrsEngine.interleaveByTopic(sorted);

      expect(result, same(sorted));
    });

    test('konu yoksa (boş liste) sıra aynen korunur', () {
      expect(SrsEngine.interleaveByTopic(const []), isEmpty);
    });

    test('sortForStudy + interleaveByTopic birlikte: en zayıf konudan başlar', () {
      final zayif = [
        _card(id: 'z1', topic: 'zayif', lapses: 3, repetitions: 1),
        _card(id: 'z2', topic: 'zayif', lapses: 3, repetitions: 1),
      ];
      final saglam = [
        _card(id: 's1', topic: 'saglam', lapses: 0, repetitions: 4),
        _card(id: 's2', topic: 'saglam', lapses: 0, repetitions: 4),
      ];
      final all = [...saglam, ...zayif];

      final sorted = SrsEngine.sortForStudy(all, all);
      final result = SrsEngine.interleaveByTopic(sorted);

      // En zayıf konu (zayif) ilk turda önde olmalı.
      expect(result.first.topic, 'zayif');
      expect(result[1].topic, 'saglam');
    });
  });

  group('aralık hesabı tutarlılığı', () {
    test('nextIntervalDays, applyReview ile aynı sonucu verir', () {
      final card = _card(repetitions: 1, intervalDays: 1);

      final preview = SrsEngine.nextIntervalDays(card, ReviewGrade.orta);
      final applied = SrsEngine.applyReview(
        card,
        ReviewGrade.orta,
        now: _now,
      );

      expect(preview, applied.intervalDays);
      expect(preview, 4);
    });
  });

  group('sınav tarihine sıkıştırma', () {
    test('normal aralık sınavdan sonraya düşerse sıkıştırılır', () {
      // Olgun kart: orta cevap 10 gün sonraya atar (4 × 2.5), ama sınava
      // yalnızca 6 gün var — sıkıştırılmalı.
      final card = _card(repetitions: 2, intervalDays: 4, easeFactor: 2.5);
      final examDate = _now.add(const Duration(days: 6));

      final reviewed = SrsEngine.applyReview(
        card,
        ReviewGrade.orta,
        now: _now,
        examDate: examDate,
      );

      // Sıkıştırılmamış hâli 10 gün olurdu; kalan 6 günün yarısına inmeli.
      expect(reviewed.intervalDays, 3);
      expect(reviewed.nextReview, _now.add(const Duration(days: 3)));
    });

    test('normal aralık zaten sınavdan önceyse dokunulmaz', () {
      final card = _card(repetitions: 1, intervalDays: 1);
      final examDate = _now.add(const Duration(days: 30));

      final reviewed = SrsEngine.applyReview(
        card,
        ReviewGrade.orta,
        now: _now,
        examDate: examDate,
      );

      // Normalde 4 gün sonraya atardı; sınav çok uzakta, sıkıştırma yok.
      expect(reviewed.intervalDays, 4);
    });

    test('sınav tam aralığın düştüğü güne denk gelirse dokunulmaz', () {
      final card = _card(repetitions: 1, intervalDays: 1);
      // Normal aralık 4 gün; sınav da tam 4 gün sonra.
      final examDate = _now.add(const Duration(days: 4));

      final reviewed = SrsEngine.applyReview(
        card,
        ReviewGrade.orta,
        now: _now,
        examDate: examDate,
      );

      expect(reviewed.intervalDays, 4);
    });

    test('sınav tarihi geçmişse sıkıştırma uygulanmaz', () {
      final card = _card(repetitions: 2, intervalDays: 4, easeFactor: 2.5);
      final examDate = _now.subtract(const Duration(days: 1));

      final reviewed = SrsEngine.applyReview(
        card,
        ReviewGrade.orta,
        now: _now,
        examDate: examDate,
      );

      expect(reviewed.intervalDays, 10);
    });

    test('sıkıştırılmış aralık en az 1 gündür', () {
      final card = _card(repetitions: 2, intervalDays: 4, easeFactor: 2.5);
      final examDate = _now.add(const Duration(days: 2));

      final reviewed = SrsEngine.applyReview(
        card,
        ReviewGrade.orta,
        now: _now,
        examDate: examDate,
      );

      expect(reviewed.intervalDays, greaterThanOrEqualTo(1));
    });
  });

  group('otomatik zorluk kalibrasyonu', () {
    test('az tekrarlı kartta (repetitions < 2) üretim zorluğuna dokunulmaz', () {
      final derived = SrsEngine.deriveDifficulty(
        _card(difficulty: CardDifficulty.zor, repetitions: 1, lapses: 0),
      );

      expect(derived, CardDifficulty.zor);
    });

    test('3+ unutma kartı "zor" yapar', () {
      final derived = SrsEngine.deriveDifficulty(
        _card(difficulty: CardDifficulty.kolay, repetitions: 2, lapses: 3),
      );

      expect(derived, CardDifficulty.zor);
    });

    test('"zor" kontrolü repetitions guard\'ından bağımsızdır', () {
      // "Zor" cevap repetitions'ı sıfırlar; lapses>=3 olan kart buna rağmen
      // (repetitions < 2 olsa bile) "zor" işaretlenmeli.
      final derived = SrsEngine.deriveDifficulty(
        _card(difficulty: CardDifficulty.orta, repetitions: 0, lapses: 3),
      );

      expect(derived, CardDifficulty.zor);
    });

    test('hiç unutulmamış + 3 ardışık doğru kartı "kolay" yapar', () {
      final derived = SrsEngine.deriveDifficulty(
        _card(difficulty: CardDifficulty.zor, repetitions: 3, lapses: 0),
      );

      expect(derived, CardDifficulty.kolay);
    });

    test('ara durumlar "orta"ya çekilir', () {
      // Yeterli tekrar var ama ne "zor" (lapses < 3) ne "kolay" (lapses > 0).
      final derived = SrsEngine.deriveDifficulty(
        _card(difficulty: CardDifficulty.kolay, repetitions: 4, lapses: 1),
      );

      expect(derived, CardDifficulty.orta);
    });

    test('applyReview her cevaptan sonra zorluğu yeniden hesaplar', () {
      // 2 doğrusu olan kart üçüncü "Biliyorum"da lapses=0, repetitions=3
      // olur → kolay'a kalibre edilmeli.
      final reviewed = SrsEngine.applyReview(
        _card(difficulty: CardDifficulty.orta, repetitions: 2, intervalDays: 4),
        ReviewGrade.orta,
        now: _now,
      );

      expect(reviewed.repetitions, 3);
      expect(reviewed.lapses, 0);
      expect(reviewed.difficulty, CardDifficulty.kolay);
    });

    test('applyReview güncellenmiş (cevap sonrası) sayaçları kullanır: '
        '"Zor" cevabın hemen ardından lapses>=3 kartı "zor" yapar', () {
      // lapses=2 ile gelen karta "Zor" denince lapses=3 olur; kalibrasyon
      // cevap ÖNCESİ 2'yi değil, sonrası 3'ü görür ve — "Zor" cevap
      // repetitions'ı sıfırlamış olsa da — kartı hemen "zor" işaretler.
      final reviewed = SrsEngine.applyReview(
        _card(difficulty: CardDifficulty.orta, repetitions: 5, lapses: 2),
        ReviewGrade.zor,
        now: _now,
      );

      expect(reviewed.lapses, 3);
      expect(reviewed.repetitions, 0);
      expect(reviewed.difficulty, CardDifficulty.zor);
    });

    test('elle ayarlanmış zorluk (difficultyManual) asla ezilmez', () {
      final reviewed = SrsEngine.applyReview(
        _card(
          difficulty: CardDifficulty.zor,
          difficultyManual: true,
          repetitions: 2,
          intervalDays: 4,
        ),
        ReviewGrade.orta,
        now: _now,
      );

      // Kalibrasyon "kolay" derdi (lapses=0, repetitions=3) ama kullanıcının
      // seçtiği "zor" korunur.
      expect(reviewed.repetitions, 3);
      expect(reviewed.difficulty, CardDifficulty.zor);
    });

    test('withEdits zorluk değişince kartı elle-ayarlanmış işaretler', () {
      final card = _card(difficulty: CardDifficulty.orta);

      final edited = card.withEdits(
        question: card.question,
        answer: card.answer,
        shortAnswer: card.shortAnswer,
        difficulty: CardDifficulty.zor,
        topic: card.topic,
        note: card.note,
        flagged: card.flagged,
      );

      expect(edited.difficultyManual, isTrue);

      // Zorluk aynı bırakılırsa işaret konmaz.
      final untouched = card.withEdits(
        question: 'Yeni soru?',
        answer: card.answer,
        shortAnswer: card.shortAnswer,
        difficulty: card.difficulty,
        topic: card.topic,
        note: card.note,
        flagged: card.flagged,
      );

      expect(untouched.difficultyManual, isFalse);
    });

    test('difficultyManual JSON gidiş-dönüşte korunur, eski kayıtta false', () {
      final manual = _card(difficultyManual: true);
      expect(Flashcard.fromJson(manual.toJson()).difficultyManual, isTrue);

      final legacyJson = _card().toJson()..remove('difficultyManual');
      expect(Flashcard.fromJson(legacyJson).difficultyManual, isFalse);
    });
  });

  group('sortForStudy — öncelikli mod', () {
    test('priorityModeDeckIds boşken sıralama hiç değişmez', () {
      final cards = [
        _card(id: 'a', deckId: 'd1', priority: CardPriority.arkaPlan),
        _card(id: 'b', deckId: 'd1', priority: CardPriority.oncelikli),
      ];

      final withoutMode = SrsEngine.sortForStudy(cards, cards);
      final withEmptyMode = SrsEngine.sortForStudy(
        cards,
        cards,
        priorityModeDeckIds: const {},
      );

      expect(
        withEmptyMode.map((c) => c.id),
        withoutMode.map((c) => c.id),
      );
    });

    test('mod açık destede arkaPlan kartlar oncelikli kartlardan sonraya gider', () {
      final cards = [
        _card(id: 'bg1', deckId: 'd1', priority: CardPriority.arkaPlan),
        _card(id: 'p1', deckId: 'd1', priority: CardPriority.oncelikli),
        _card(id: 'bg2', deckId: 'd1', priority: CardPriority.arkaPlan),
        _card(id: 'p2', deckId: 'd1', priority: CardPriority.oncelikli),
      ];

      final sorted = SrsEngine.sortForStudy(
        cards,
        cards,
        priorityModeDeckIds: const {'d1'},
      );

      expect(sorted.map((c) => c.id), ['p1', 'p2', 'bg1', 'bg2']);
    });

    test('modda olmayan destenin kartları etkilenmez', () {
      final cards = [
        _card(id: 'bg', deckId: 'd2', priority: CardPriority.arkaPlan),
        _card(id: 'p', deckId: 'd2', priority: CardPriority.oncelikli),
      ];

      // d1 modda ama kartlar d2'ye ait — sıra AI zorluk/zayıflık kuralına
      // (burada eşit, giriş sırası korunur) göre kalır, priority'e göre değil.
      final sorted = SrsEngine.sortForStudy(
        cards,
        cards,
        priorityModeDeckIds: const {'d1'},
      );

      expect(sorted.map((c) => c.id), ['bg', 'p']);
    });

    test('arkaPlan kartlar silinmez, yalnızca sona itilir', () {
      final cards = [
        _card(id: 'bg', deckId: 'd1', priority: CardPriority.arkaPlan),
        _card(id: 'p', deckId: 'd1', priority: CardPriority.oncelikli),
      ];

      final sorted = SrsEngine.sortForStudy(
        cards,
        cards,
        priorityModeDeckIds: const {'d1'},
      );

      expect(sorted, hasLength(2));
      expect(sorted.map((c) => c.id).toSet(), {'bg', 'p'});
    });
  });

  group('examPaceWarning', () {
    final deck = Deck(id: 'd1', name: 'Test', createdAt: _now);

    test('dailyPace null ise (yeterli geçmiş yok) uyarı vermez', () {
      final result = SrsEngine.examPaceWarning(
        deck: deck.withExamDate(_now.add(const Duration(days: 5))),
        deckCards: List.generate(100, (i) => _card(id: '$i')),
        dailyPace: null,
        now: _now,
      );

      expect(result, isNull);
    });

    test('sınav tarihi yoksa uyarı vermez', () {
      final result = SrsEngine.examPaceWarning(
        deck: deck,
        deckCards: List.generate(100, (i) => _card(id: '$i')),
        dailyPace: 5,
        now: _now,
      );

      expect(result, isNull);
    });

    test('sınav geçmişse uyarı vermez', () {
      final result = SrsEngine.examPaceWarning(
        deck: deck.withExamDate(_now.subtract(const Duration(days: 1))),
        deckCards: List.generate(100, (i) => _card(id: '$i')),
        dailyPace: 5,
        now: _now,
      );

      expect(result, isNull);
    });

    test('kapasite kalan karta yetiyorsa (tolerans dahil) uyarı vermez', () {
      // 10 kart/gün * 5 gün = 50 kapasite * 1.1 tolerans = 55 — 50 kart yetişir.
      final result = SrsEngine.examPaceWarning(
        deck: deck.withExamDate(_now.add(const Duration(days: 5))),
        deckCards: List.generate(50, (i) => _card(id: '$i')),
        dailyPace: 10,
        now: _now,
      );

      expect(result, isNull);
    });

    test('kalan kart kapasiteyi toleransın da üzerinde aşarsa uyarır', () {
      // 5 kart/gün * 5 gün = 25 kapasite * 1.1 = 27.5 — 100 kart hiç yetişmez.
      final result = SrsEngine.examPaceWarning(
        deck: deck.withExamDate(_now.add(const Duration(days: 5))),
        deckCards: List.generate(100, (i) => _card(id: '$i')),
        dailyPace: 5,
        now: _now,
      );

      expect(result, isNotNull);
      expect(result!.daysLeft, 5);
      expect(result.expectedCapacity, 25);
      expect(result.remainingCards, 100);
    });

    test('iyi öğrenilmiş kartlar (repetitions yüksek) kalan sayıma girmez', () {
      final wellLearned = List.generate(
        100,
        (i) => _card(id: 'w$i', repetitions: SrsEngine.difficultyKolayRepetitions),
      );

      final result = SrsEngine.examPaceWarning(
        deck: deck.withExamDate(_now.add(const Duration(days: 5))),
        deckCards: wellLearned,
        dailyPace: 1,
        now: _now,
      );

      expect(result, isNull);
    });
  });

  group('weakestReliableTopic', () {
    test('hiç konu etiketi yoksa null döner', () {
      final cards = [
        for (var i = 0; i < 10; i++) _card(id: 'c$i', topic: ''),
      ];
      expect(SrsEngine.weakestReliableTopic(cards), isNull);
    });

    test('konunun kart sayısı yetersizse (< minCardsPerTopic) seçilmez', () {
      // Tek konu, yalnızca 4 kart (eşik 5) — weakness yüksek olsa da (yarı
      // yarıya unutulmuş) kart sayısı yetersiz olduğu için hiç seçilmez.
      final cards = [
        for (var i = 0; i < 4; i++)
          _card(id: 'az$i', topic: 'zayif', repetitions: 5, lapses: 5),
      ];
      expect(SrsEngine.weakestReliableTopic(cards), isNull);
    });

    test(
      'toplam repetitions yetersizse (yalnızca lapses olsa bile) seçilmez',
      () {
        // weakness = 1/1 = 1.0 (mümkün olan en yüksek skor) ama toplam
        // repetitions 0 — difficultyMinRepetitions (2) eşiğini geçmiyor.
        final cards = [
          for (var i = 0; i < 5; i++)
            _card(id: 'lo$i', topic: 'sahte-zayif', repetitions: 0, lapses: 1),
        ];
        expect(SrsEngine.weakestReliableTopic(cards), isNull);
      },
    );

    test('yeterli veri olan konular arasında en zayıf (en yüksek weakness) seçilir', () {
      final weakTopicCards = [
        for (var i = 0; i < 5; i++)
          // weakness = 3 / (3+1) = 0.75
          _card(id: 'w$i', topic: 'zayif', repetitions: 1, lapses: 3),
      ];
      final strongTopicCards = [
        for (var i = 0; i < 5; i++)
          // weakness = 0 / 5 = 0
          _card(id: 's$i', topic: 'guclu', repetitions: 5, lapses: 0),
      ];

      final result = SrsEngine.weakestReliableTopic([
        ...weakTopicCards,
        ...strongTopicCards,
      ]);

      expect(result, isNotNull);
      expect(result!.topic, 'zayif');
      expect(result.cardCount, 5);
    });

    test('cardCount o konudaki TÜM kart sayısını yansıtır', () {
      final cards = [
        for (var i = 0; i < 8; i++)
          _card(id: 'c$i', topic: 'zayif', repetitions: 1, lapses: 1),
      ];
      final result = SrsEngine.weakestReliableTopic(cards);
      expect(result!.cardCount, 8);
    });

    test('minCardsPerTopic parametresiyle eşik özelleştirilebilir', () {
      final cards = [
        for (var i = 0; i < 3; i++)
          _card(id: 'c$i', topic: 'zayif', repetitions: 1, lapses: 1),
      ];
      expect(SrsEngine.weakestReliableTopic(cards), isNull);
      expect(
        SrsEngine.weakestReliableTopic(cards, minCardsPerTopic: 3),
        isNotNull,
      );
    });
  });
}
