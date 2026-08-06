/// Tamamlanmış bir deneme sınavının kalıcı kaydı.
///
/// `LibraryData.examResults` içinde saklanır — yani mevcut yedekleme
/// ([BackupService]) ve bulut senkronu ([SyncService]) akışlarına ayrı bir
/// depolama icat edilmeden dahil olur.
///
/// Geçmiş TUTULUR (yalnızca son sonuç değil): şimdilik sadece "bir önceki
/// denemeyle" kıyas gösteriliyor ama trend grafiği ileride bu listeden
/// çizilebilsin diye. Liste `FlashcardStore.maxExamResultHistory` ile
/// sınırlanır (localStorage şişmesin).
library;

/// Tek bir konunun sınavdaki doğru/toplam sayısı.
class ExamTopicScore {
  const ExamTopicScore({
    required this.topic,
    required this.correct,
    required this.total,
  });

  final String topic;
  final int correct;
  final int total;

  /// 0..1 arası başarı oranı; soru yoksa 0.
  double get successRate => total == 0 ? 0 : correct / total;

  /// Yüzde (0-100), yuvarlanmış.
  int get percent => (successRate * 100).round();

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'correct': correct,
    'total': total,
  };

  factory ExamTopicScore.fromJson(Map<String, dynamic> json) => ExamTopicScore(
    topic: (json['topic'] as String?) ?? '',
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}

/// Bir deneme sınavı sonucu.
class ExamResult {
  const ExamResult({
    required this.id,
    required this.takenAt,
    required this.correctCount,
    required this.totalQuestions,
    this.deckId,
    this.topicScores = const [],
  });

  /// Saklanan en fazla deneme sınavı sayısı (en yeniler tutulur).
  ///
  /// Şu an yalnızca "bir önceki" kıyas için gerekiyor ama trend grafiği
  /// ileride bu listeden çizilebilsin diye geçmiş tutuluyor; sınır
  /// localStorage'ın şişmemesi için. Hem [FlashcardStore.recordExamResult]
  /// hem `SyncService.mergeLibraries` bu sınırı uygular.
  static const int maxHistory = 20;

  final String id;

  /// Sınavın kapsamı deste bazlıysa o destenin id'si.
  ///
  /// Deneme sınavı (bkz. `ExamSimSetupScreen`) TÜM kütüphane havuzundan
  /// karışık konu soruyor, tek bir desteye bağlı değil — o yüzden pratikte
  /// hep `null` gelir ve kıyas "bir önceki kütüphane geneli deneme" ile
  /// yapılır. Alan yine de tutuluyor: kıyas eşleştirmesi deste bazlı
  /// (`lastResultFor`) yazıldığı için ileride deste kapsamlı bir sınav
  /// eklenirse kayıtlar karışmaz.
  final String? deckId;

  final DateTime takenAt;
  final int correctCount;
  final int totalQuestions;

  /// Konu bazlı kırılım. Boş olabilir (kartların konusu yoksa).
  final List<ExamTopicScore> topicScores;

  /// Yüzde puan (0-100) — sonuç ekranındaki büyük puanla aynı hesap.
  int get percent => totalQuestions == 0
      ? 0
      : (correctCount / totalQuestions * 100).round();

  Map<String, dynamic> toJson() => {
    'id': id,
    'deckId': deckId,
    'takenAt': takenAt.toIso8601String(),
    'correctCount': correctCount,
    'totalQuestions': totalQuestions,
    'topicScores': topicScores.map((t) => t.toJson()).toList(),
  };

  factory ExamResult.fromJson(Map<String, dynamic> json) => ExamResult(
    id: (json['id'] as String?) ?? '',
    deckId: json['deckId'] as String?,
    takenAt:
        DateTime.tryParse((json['takenAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
    totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
    topicScores: [
      for (final item in (json['topicScores'] as List?) ?? const [])
        if (item is Map) ExamTopicScore.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

/// Kıyasın yönü.
enum ExamTrend {
  /// Belirgin şekilde daha iyi.
  improved,

  /// Belirgin şekilde daha kötü.
  declined,

  /// Fark önemsiz (bkz. [ExamComparison.neutralThresholdPoints]).
  same,
}

/// İki sınav arasında tek bir konunun değişimi.
class ExamTopicDelta {
  const ExamTopicDelta({
    required this.topic,
    required this.previousPercent,
    required this.currentPercent,
  });

  final String topic;
  final int previousPercent;
  final int currentPercent;

  /// Yüzde puan farkı (pozitif = gelişme).
  int get deltaPoints => currentPercent - previousPercent;
}

/// İki deneme sınavı sonucunun karşılaştırması (saf, UI'dan bağımsız).
class ExamComparison {
  const ExamComparison({
    required this.trend,
    required this.deltaPoints,
    required this.previousPercent,
    required this.currentPercent,
    this.improvedTopics = const [],
    this.declinedTopics = const [],
  });

  /// Bu yüzde puan farkının ALTINDAKİ değişimler "aynı seviye" sayılır.
  ///
  /// Neden 0 değil: 40 soruluk bir sınavda tek soru 2.5 puan eder. Tek soruluk
  /// dalgalanmayı "daha iyisin" diye kutlamak da "gerilemişsin" diye
  /// söylemek de yanıltıcı olurdu.
  static const int neutralThresholdPoints = 3;

  /// Bir konunun vurgulanmaya değer sayılması için gereken en az değişim.
  static const int topicDeltaThresholdPoints = 10;

  /// Her yönde en fazla kaç konu vurgulanır.
  static const int maxTopicHighlights = 2;

  final ExamTrend trend;

  /// `currentPercent - previousPercent`. Mesajlarda mutlak değeri kullanılır.
  final int deltaPoints;

  final int previousPercent;
  final int currentPercent;

  /// En çok gelişen konular (en iyiden başlayarak, en fazla
  /// [maxTopicHighlights] tane). İki sınavda da bulunan konular arasından.
  final List<ExamTopicDelta> improvedTopics;

  /// En çok gerileyen konular (en kötüden başlayarak).
  final List<ExamTopicDelta> declinedTopics;

  /// [previous] ile [current] arasında kıyas kurar.
  static ExamComparison between(ExamResult previous, ExamResult current) {
    final delta = current.percent - previous.percent;

    final trend = delta.abs() < neutralThresholdPoints
        ? ExamTrend.same
        : (delta > 0 ? ExamTrend.improved : ExamTrend.declined);

    // Konu kıyası yalnızca İKİ sınavda da sorusu çıkmış konular için anlamlı;
    // yeni gelen/düşen konular "gelişme" ya da "gerileme" sayılamaz.
    final previousByTopic = {
      for (final t in previous.topicScores) t.topic: t,
    };

    final deltas = <ExamTopicDelta>[];
    for (final currentScore in current.topicScores) {
      final previousScore = previousByTopic[currentScore.topic];
      if (previousScore == null) continue;
      deltas.add(
        ExamTopicDelta(
          topic: currentScore.topic,
          previousPercent: previousScore.percent,
          currentPercent: currentScore.percent,
        ),
      );
    }

    final improved =
        deltas.where((d) => d.deltaPoints >= topicDeltaThresholdPoints).toList()
          ..sort((a, b) => b.deltaPoints.compareTo(a.deltaPoints));
    final declined =
        deltas.where((d) => d.deltaPoints <= -topicDeltaThresholdPoints).toList()
          ..sort((a, b) => a.deltaPoints.compareTo(b.deltaPoints));

    return ExamComparison(
      trend: trend,
      deltaPoints: delta,
      previousPercent: previous.percent,
      currentPercent: current.percent,
      improvedTopics: improved.take(maxTopicHighlights).toList(),
      declinedTopics: declined.take(maxTopicHighlights).toList(),
    );
  }

  /// Kullanıcıya gösterilecek ana cümle.
  ///
  /// Gerileme dilinde bilinçli olarak yumuşak: suçlayıcı değil, tek bir
  /// denemenin kötü geçebileceğini ima eden bir ton.
  String get message => switch (trend) {
    ExamTrend.improved =>
      'Geçen denemene göre %${deltaPoints.abs()} daha iyisin.',
    ExamTrend.declined =>
      'Geçen denemende %${deltaPoints.abs()} daha iyiydin, bu sefer biraz '
          'zorlandın. Tek bir deneme her şeyi söylemez.',
    ExamTrend.same => 'Geçen denemenle aynı seviyedesin.',
  };
}
