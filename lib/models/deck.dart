/// Bir kart destesi (ör. "Komite 1 · Kalp").
///
/// Kartlar [Flashcard.deckId] ile bir desteye bağlanır; her deste ayrı
/// çalışılır ve kendi ilerlemesini taşır.
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.createdAt,
    this.examDate,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// Opsiyonel sınav tarihi. Girilmişse [SrsEngine.applyReview] normal SM-2
  /// aralığını bu tarihi aşmayacak şekilde sıkıştırır ve tarih yaklaşınca
  /// (bkz. [SrsEngine.crammingThresholdDays]) günlük kuyruk limitsiz açılır.
  final DateTime? examDate;

  bool get hasExamDate => examDate != null;

  /// [now]'dan sınav gününe kalan tam gün sayısı (saat/dakika yok sayılır).
  /// Sınav tarihi yoksa null.
  int? daysUntilExam(DateTime now) {
    final exam = examDate;
    if (exam == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(exam.year, exam.month, exam.day);
    return examDay.difference(today).inDays;
  }

  Deck copyWith({String? name}) => Deck(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    examDate: examDate,
  );

  /// Sınav tarihini ayarlar/kaldırır. [copyWith] null'u "değiştirme" olarak
  /// yorumladığından, kaldırma işlemi için ayrı bir metot gerekir.
  Deck withExamDate(DateTime? examDate) =>
      Deck(id: id, name: name, createdAt: createdAt, examDate: examDate);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'examDate': examDate?.toIso8601String(),
  };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    examDate: DateTime.tryParse((json['examDate'] as String?) ?? ''),
  );
}
