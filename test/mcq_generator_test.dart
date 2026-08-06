import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/mcq_generator.dart';

Flashcard _c({
  required String id,
  required String topic,
  required String shortAnswer,
  String? question,
}) => Flashcard(
  id: id,
  question: question ?? 'Soru $id?',
  answer: 'Uzun açıklama $id.',
  shortAnswer: shortAnswer,
  topic: topic,
);

void main() {
  group('McqGenerator.generate', () {
    test('4 karttan az olan konu havuzdan tamamen çıkarılır', () {
      final cards = [
        _c(id: 'a', topic: 'nadir-konu', shortAnswer: 'Cevap A'),
        _c(id: 'b', topic: 'nadir-konu', shortAnswer: 'Cevap B'),
        _c(id: 'c', topic: 'nadir-konu', shortAnswer: 'Cevap C'),
      ];

      final result = McqGenerator.generate(cards, count: 5);

      expect(result, isEmpty);
    });

    test('şıklar her zaman 4 elemanlı ve doğru şık kaynak kartla eşleşir', () {
      final cards = [
        for (var i = 0; i < 8; i++)
          _c(
            id: 'k$i',
            topic: 'bol-konu',
            shortAnswer: 'Benzersiz cevap $i',
          ),
      ];

      final result = McqGenerator.generate(cards, count: 8, random: Random(7));

      expect(result, isNotEmpty);
      for (final q in result) {
        expect(q.options, hasLength(4));
        // hepsi birbirinden farklı metin
        expect(q.options.map((o) => o.text).toSet(), hasLength(4));
        expect(q.correctIndex, inInclusiveRange(0, 3));
        final sourceCard = cards.firstWhere((c) => c.id == q.sourceCardId);
        expect(q.options[q.correctIndex].text, sourceCard.shortAnswer);
      }
    });

    test(
      'her şık kendi kaynak kartının açıklamalı cevabını (answer) taşır',
      () {
        final cards = [
          for (var i = 0; i < 6; i++)
            _c(id: 'k$i', topic: 'aciklama', shortAnswer: 'Kısa cevap $i'),
        ];
        final answerById = {for (final c in cards) c.id: c.answer};

        final result = McqGenerator.generate(
          cards,
          count: 6,
          random: Random(11),
        );

        expect(result, isNotEmpty);
        for (final q in result) {
          for (final option in q.options) {
            expect(option.explanation, answerById[option.sourceCardId]);
          }
          // Doğru şıkkın sourceCardId'si de sorunun kendi kartıyla eşleşir.
          expect(q.correctOption.sourceCardId, q.sourceCardId);
        }
      },
    );

    test('çeldiriciler her zaman kaynak kartla aynı topic\'ten gelir', () {
      final cards = [
        for (var i = 0; i < 5; i++)
          _c(id: 'x$i', topic: 'anatomi', shortAnswer: 'Anatomi cevabı $i'),
        for (var i = 0; i < 5; i++)
          _c(id: 'y$i', topic: 'biyokimya', shortAnswer: 'Biyokimya cevabı $i'),
      ];
      final topicById = {for (final c in cards) c.id: c.topic};

      final result = McqGenerator.generate(cards, count: 10, random: Random(3));

      expect(result, isNotEmpty);
      for (final q in result) {
        final expectedTopic = topicById[q.sourceCardId];
        for (final option in q.options) {
          expect(topicById[option.sourceCardId], expectedTopic);
        }
      }
    });

    test('kelime bazında çok benzer çeldirici (%70+ ortak kelime) elenir', () {
      final target = _c(
        id: 'target',
        topic: 'benzerlik',
        shortAnswer: 'Ekstansör kas zayıflığı',
      );
      // Aynı 3 kelimenin sırası değişmiş -> Jaccard benzerliği 1.0, elenmeli.
      final tooSimilar = _c(
        id: 'benzer1',
        topic: 'benzerlik',
        shortAnswer: 'Zayıflığı kas ekstansör',
      );
      final distinct1 = _c(
        id: 'farkli1',
        topic: 'benzerlik',
        shortAnswer: 'Düşük el bulgusu',
      );
      final distinct2 = _c(
        id: 'farkli2',
        topic: 'benzerlik',
        shortAnswer: 'N. radialis hasarı',
      );
      final distinct3 = _c(
        id: 'farkli3',
        topic: 'benzerlik',
        shortAnswer: 'Karpal tünel sendromu',
      );
      final cards = [target, tooSimilar, distinct1, distinct2, distinct3];

      final result = McqGenerator.generate(cards, count: 10, random: Random(1));
      final targetQuestion = result.firstWhere(
        (q) => q.sourceCardId == 'target',
      );
      final optionTexts = targetQuestion.options.map((o) => o.text).toSet();

      expect(optionTexts, isNot(contains(tooSimilar.shortAnswer)));
      expect(targetQuestion.options, hasLength(4));
      expect(
        optionTexts,
        {
          target.shortAnswer,
          distinct1.shortAnswer,
          distinct2.shortAnswer,
          distinct3.shortAnswer,
        },
      );
    });

    test(
      'yeterli farklı (benzemeyen) çeldirici bulunamazsa o soru atlanır',
      () {
        final target = _c(
          id: 'target',
          topic: 'yetersiz',
          shortAnswer: 'Kalp yetmezliği bulgusu',
        );
        // Her ikisi de hedefle aynı 3 kelimenin farklı sıralaması -> elenir.
        final tooSimilar1 = _c(
          id: 'benzer1',
          topic: 'yetersiz',
          shortAnswer: 'Bulgusu kalp yetmezliği',
        );
        final tooSimilar2 = _c(
          id: 'benzer2',
          topic: 'yetersiz',
          shortAnswer: 'Yetmezliği kalp bulgusu',
        );
        // Tek geçerli çeldirici — 3'ten az, yeterli değil.
        final onlyValid = _c(
          id: 'gecerli',
          topic: 'yetersiz',
          shortAnswer: 'Aritmi tipi',
        );
        final cards = [target, tooSimilar1, tooSimilar2, onlyValid];

        final result = McqGenerator.generate(
          cards,
          count: 10,
          random: Random(2),
        );

        expect(
          result.where((q) => q.sourceCardId == 'target'),
          isEmpty,
        );
      },
    );

    test('topic boş olan kart havuza hiç girmez', () {
      final cards = [
        _c(id: 'a', topic: '', shortAnswer: 'Cevap A'),
        _c(id: 'b', topic: '', shortAnswer: 'Cevap B'),
        _c(id: 'c', topic: '', shortAnswer: 'Cevap C'),
        _c(id: 'd', topic: '', shortAnswer: 'Cevap D'),
      ];

      final result = McqGenerator.generate(cards, count: 5);

      expect(result, isEmpty);
    });

    test('shortAnswer boş olan kart havuza hiç girmez', () {
      final withShort = [
        for (var i = 0; i < 3; i++)
          _c(id: 'w$i', topic: 'karisik', shortAnswer: 'Cevap $i'),
      ];
      final withoutShort = Flashcard(
        id: 'noshort',
        question: 'Soru?',
        answer: 'Cevap.',
        topic: 'karisik',
      );
      final cards = [...withShort, withoutShort];

      // Konu artık yalnızca 3 uygun karta sahip (<4) -> hiç soru üretilmez.
      final result = McqGenerator.generate(cards, count: 5);

      expect(result, isEmpty);
      expect(withoutShort.hasShortAnswer, isFalse);
    });

    test('istenenden fazla soru istenirse yalnızca üretilebilecek kadarı döner', () {
      final cards = [
        for (var i = 0; i < 4; i++)
          _c(id: 'k$i', topic: 'tek-konu', shortAnswer: 'Cevap $i'),
      ];

      final result = McqGenerator.generate(cards, count: 100, random: Random(5));

      expect(result.length, lessThanOrEqualTo(4));
      expect(result, isNotEmpty);
    });
  });
}
