import 'dart:math';

import '../models/flashcard.dart';

/// Çeldirici kelime-benzerliği eşiği. Bunun üstünde kalan aday çeldirici
/// doğru cevaba çok yakın kabul edilip elenir (ör. "Osteoklast" vs
/// "Aktif osteoklast" gibi neredeyse aynı şıkları göstermemek için).
const double _similarityThreshold = 0.7;

/// Tek bir şık: kısa metni ([text], `shortAnswer`) VE kendi kaynak kartının
/// açıklamalı cevabı ([explanation], `answer`) birlikte taşınır — öğrenci
/// hangi şıkkı seçerse seçsin (doğru ya da yanlış), seçtiğinin VE doğru
/// şıkkın açıklaması ayrı ayrı gösterilebilsin diye.
class McqOption {
  const McqOption({
    required this.text,
    required this.explanation,
    required this.sourceCardId,
  });

  final String text;
  final String explanation;
  final String sourceCardId;
}

/// Bir "Kendini Test Et" (MCQ) sorusu: [options] her zaman 4 eleman içerir,
/// doğru şık [correctIndex]'te durur. [sourceCardId] sorunun türetildiği
/// [Flashcard.id] — ör. "kartı düzenle"ye geri dönmek için kullanılabilir.
class McqQuestion {
  const McqQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.sourceCardId,
  });

  final String question;
  final List<McqOption> options;
  final int correctIndex;
  final String sourceCardId;

  McqOption get correctOption => options[correctIndex];
  String get correctAnswer => correctOption.text;
}

/// Var olan kartlardan, hiç yeni AI çağrısı yapmadan MCQ soruları türetir.
///
/// Şıklar [Flashcard.shortAnswer] alanından geliyor; bu yüzden yalnızca
/// `shortAnswer`'ı dolu VE `topic` etiketi olan kartlar havuza girer —
/// ikisi de eksikse ne doğru şık ne de anlamlı bir çeldirici grubu kurulabilir.
class McqGenerator {
  const McqGenerator._();

  /// [cards]'tan en fazla [count] soru üretir. Yeterli/kaliteli çeldirici
  /// bulunamayan kartlar sessizce atlanır — çıktı [count]'tan az olabilir.
  static List<McqQuestion> generate(
    List<Flashcard> cards, {
    required int count,
    Random? random,
  }) {
    final rng = random ?? Random();

    final eligible = cards
        .where((c) => c.hasTopic && c.hasShortAnswer)
        .toList();

    final byTopic = <String, List<Flashcard>>{};
    for (final card in eligible) {
      byTopic.putIfAbsent(card.topic, () => []).add(card);
    }
    // Kalite filtresi: yetersiz çeldirici riski taşıyan (<4 kart) konular
    // MCQ havuzundan tamamen çıkarılır.
    byTopic.removeWhere((_, cardsInTopic) => cardsInTopic.length < 4);

    final candidatePool = byTopic.values.expand((list) => list).toList()
      ..shuffle(rng);

    final questions = <McqQuestion>[];
    for (final candidate in candidatePool) {
      if (questions.length >= count) break;

      final siblings = byTopic[candidate.topic]!
          .where((c) => c.id != candidate.id)
          .toList()
        ..shuffle(rng);

      final distractors = <Flashcard>[];
      final correctAnswer = candidate.shortAnswer.trim();
      for (final sibling in siblings) {
        if (distractors.length >= 3) break;
        final siblingAnswer = sibling.shortAnswer.trim();
        if (siblingAnswer.isEmpty) continue;
        if (siblingAnswer.toLowerCase() == correctAnswer.toLowerCase()) {
          continue;
        }
        if (distractors.any(
          (d) => d.shortAnswer.trim().toLowerCase() ==
              siblingAnswer.toLowerCase(),
        )) {
          continue;
        }
        if (_wordSimilarity(correctAnswer, siblingAnswer) >=
            _similarityThreshold) {
          continue;
        }
        distractors.add(sibling);
      }

      if (distractors.length < 3) continue;

      McqOption toOption(Flashcard c) => McqOption(
        text: c.shortAnswer.trim(),
        explanation: c.answer,
        sourceCardId: c.id,
      );

      final options = [candidate, ...distractors].map(toOption).toList()
        ..shuffle(rng);
      questions.add(
        McqQuestion(
          question: candidate.question,
          options: options,
          correctIndex: options.indexWhere(
            (o) => o.sourceCardId == candidate.id,
          ),
          sourceCardId: candidate.id,
        ),
      );
    }

    return questions;
  }
}

final _wordSplitter = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

Set<String> _words(String text) => text
    .toLowerCase()
    .split(_wordSplitter)
    .where((w) => w.isNotEmpty)
    .toSet();

/// Jaccard benzerliği (ortak kelime oranı): |kesişim| / |birleşim|.
/// İki metin de kelimesizse (boş) 0 döner — benzer sayılmaz, elenmez.
double _wordSimilarity(String a, String b) {
  final wordsA = _words(a);
  final wordsB = _words(b);
  if (wordsA.isEmpty || wordsB.isEmpty) return 0;

  final intersection = wordsA.intersection(wordsB).length;
  final union = wordsA.union(wordsB).length;
  return intersection / union;
}
