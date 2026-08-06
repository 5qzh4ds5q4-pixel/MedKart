/// Kartın zorluk seviyesi.
///
/// Adım 2'de SRS motoru bunu kullanacak: zor kartlar daha sık, kolay kartlar
/// daha seyrek gösterilecek.
enum CardDifficulty {
  kolay('Kolay'),
  orta('Orta'),
  zor('Zor');

  const CardDifficulty(this.label);

  /// Arayüzde gösterilen ad.
  final String label;

  /// Gemini'dan veya diskten gelen değeri çözer.
  /// Tanınmayan/eksik değerde orta kabul edilir — kart yine de kullanılabilir.
  static CardDifficulty parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'kolay' => CardDifficulty.kolay,
      'zor' => CardDifficulty.zor,
      _ => CardDifficulty.orta,
    };
  }
}

/// Kartın biçimi: düz soru-cevap mi, yoksa komite sınavı formatında kısa bir
/// hasta/durum senaryosundan bilgiye geri gitmeyi mi gerektiriyor.
enum CardType {
  temel('Temel'),
  sinav('Sınav Tipi');

  const CardType(this.label);

  /// Arayüzde gösterilen ad.
  final String label;

  /// Gemini'dan veya diskten gelen değeri çözer.
  /// Tanınmayan/eksik değerde temel kabul edilir — kart yine de kullanılabilir.
  static CardType parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'sinav' => CardType.sinav,
      _ => CardType.temel,
    };
  }
}

/// Bir "temel" (temel/tanım tipi) kartın sınav döneminde ayrı tutulacak kadar
/// önemli olup olmadığı. Yalnızca [CardType.temel] kartlar için anlamlıdır —
/// [CardType.sinav] kartlar zaten klinik önem taşıdığı için Sınav Modu'nda her
/// zaman gösterilir, bu etiketten bağımsız.
enum CardPriority {
  oncelikli('Öncelikli'),
  arkaPlan('Arka Plan');

  const CardPriority(this.label);

  /// Arayüzde gösterilen ad.
  final String label;

  /// Gemini'dan veya diskten gelen değeri çözer.
  /// Tanınmayan/eksik değerde [oncelikli] kabul edilir: eski kayıtlarda ya da
  /// ayrıştırma sorununda kart Sınav Modu'nda sessizce kaybolmasın diye
  /// varsayılan görünür tarafta kalır.
  static CardPriority parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'arka plan' || 'arka_plan' || 'arkaplan' => CardPriority.arkaPlan,
      _ => CardPriority.oncelikli,
    };
  }
}

/// Tek bir flashcard: içerik + aralıklı tekrar (SRS) durumu.
class Flashcard {
  const Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    this.shortAnswer = '',
    this.deckId = '',
    this.difficulty = CardDifficulty.orta,
    this.difficultyManual = false,
    this.cardType = CardType.temel,
    this.priority = CardPriority.oncelikli,
    this.topic = '',
    this.note = '',
    this.originalQuestion,
    this.originalAnswer,
    this.flagged = false,
    this.sourcePage,
    this.isHandwritten = false,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.lapses = 0,
    this.nextReview,
  });

  final String id;
  final String question;

  /// Açıklamalı cevap: mekanizma/neden-sonuç içeren, terim açıklamalı tam cevap.
  final String answer;

  /// Sorunun doğrudan, kısa yanıtı (3-8 kelime) — [answer]'ın kısaltması
  /// DEĞİL, ayrı ayrı üretilmiş bağımsız bir cevap. Yalnızca bu alanla
  /// üretilen (2026-07-19 sonrası) kartlarda dolu; eski kartlarda boş
  /// string — UI/PDF boşsa tek katmanlı eski davranışa düşer.
  final String shortAnswer;

  /// Kartın ait olduğu destenin kimliği ([Deck.id]).
  final String deckId;

  /// Üretim anında AI'ın verdiği zorluk tahmini. Kart çalışıldıkça
  /// [SrsEngine.deriveDifficulty] gerçek performansa göre otomatik günceller —
  /// kullanıcı elle ayarlamadıysa (bkz. [difficultyManual]).
  final CardDifficulty difficulty;

  /// Kullanıcı zorluğu [EditCardDialog] ile elle mi ayarladı? true ise
  /// otomatik zorluk kalibrasyonu bu kartı atlar, kullanıcının seçimi kalır.
  final bool difficultyManual;

  /// Kartın biçimi: temel soru-cevap mı, komite sınavı formatında
  /// senaryo-tabanlı ("sınav tipi") mi. Yalnızca klinik/uygulamalı konularda
  /// AI [CardType.sinav] üretir; düz tanım/liste bilgisinde hep [CardType.temel].
  final CardType cardType;

  /// Sınav Modu filtresinde kullanılan öncelik etiketi. Bkz. [CardPriority].
  final CardPriority priority;

  /// Alt konu etiketi (ör. "koroner dolaşım"). Boş olabilir.
  ///
  /// Adım 2'de kullanıcının zayıf olduğu konuyu sık göstermek için
  /// kartlar bu etikete göre gruplanacak.
  final String topic;

  /// Kullanıcının kendi eklediği not / mnemonik. Cevabın altında gösterilir.
  /// AI üretmez; yalnızca kullanıcıya aittir.
  final String note;

  // ---- Kullanıcı düzenlemesi (halüsinasyon savunması) ----

  /// AI'ın ürettiği ilk soru metni. Kullanıcı soruyu ilk kez değiştirdiğinde
  /// buraya alınır; hiç düzenlenmediyse null. Böylece [question] override,
  /// orijinal kayıp olmadan gerekince geri alınabilir.
  final String? originalQuestion;

  /// AI'ın ürettiği ilk cevap metni. Bkz. [originalQuestion].
  final String? originalAnswer;

  /// Kullanıcı "bu kartta hata var" diye işaretledi mi? İşaretli kartlar
  /// prompt iyileştirme için ayrıca listelenir ([FlashcardStore.flaggedCards]).
  final bool flagged;

  /// Kart bir PDF'ten üretildiyse kaynak slayt sayfası (1 tabanlı); değilse null.
  /// "Bu kart yanlış" denince hangi sayfaya bakılacağını ve sayfa aralığı
  /// filtresini ([CardFilter]) besler.
  final int? sourcePage;

  /// Kartın bilgisi (öncelikle) el yazısı not/highlight/altı çizili bir
  /// yerden mi geldi? AI bunu şemadaki bir alanla işaretler; soru/cevap
  /// metnine hiçbir uyarı yazılmaz — uyarı yalnızca UI'da kart meta
  /// satırında küçük bir kalem ikonu olarak gösterilir.
  final bool isHandwritten;

  /// Kullanıcı soru veya cevabı AI orijinalinden değiştirmiş mi?
  bool get isEdited => originalQuestion != null || originalAnswer != null;

  bool get hasSourcePage => sourcePage != null;

  /// Bağımsız üretilmiş kısa cevabı var mı (bkz. [shortAnswer]).
  bool get hasShortAnswer => shortAnswer.trim().isNotEmpty;

  bool get isExamType => cardType == CardType.sinav;

  /// Kullanıcının kendi notu var mı?
  bool get hasNote => note.trim().isNotEmpty;

  // ---- SRS durumu ----

  /// Bir sonraki tekrara kaç gün var (son değerlendirmede hesaplanan aralık).
  /// Hiç çalışılmamış kartta 0.
  final int intervalDays;

  /// Kartın "kolaylık" katsayısı (SM-2). Aralık her doğru cevapta bununla
  /// çarpılır. Unutulan kartta düşer, yani kart daha sık gelir.
  final double easeFactor;

  /// Ardışık doğru cevap sayısı. "Bilmiyorum" bunu sıfırlar.
  final int repetitions;

  /// Kartın kaç kez unutulduğu. Konu zayıflığını ölçmekte kullanılır.
  final int lapses;

  /// Kartın tekrar gösterileceği an. null ise kart hiç çalışılmamıştır ve
  /// hemen gösterilmeye hazırdır.
  final DateTime? nextReview;

  bool get hasTopic => topic.trim().isNotEmpty;

  /// Kart hiç çalışılmadı mı?
  bool get isNew => repetitions == 0 && lapses == 0 && nextReview == null;

  /// Kart [now] anında tekrar edilmeli mi?
  bool isDue(DateTime now) {
    final due = nextReview;
    return due == null || !due.isAfter(now);
  }

  Flashcard copyWith({
    String? question,
    String? answer,
    String? shortAnswer,
    String? deckId,
    CardDifficulty? difficulty,
    bool? difficultyManual,
    CardType? cardType,
    CardPriority? priority,
    String? topic,
    String? note,
    String? originalQuestion,
    String? originalAnswer,
    bool? flagged,
    int? sourcePage,
    bool? isHandwritten,
    int? intervalDays,
    double? easeFactor,
    int? repetitions,
    int? lapses,
    DateTime? nextReview,
  }) {
    return Flashcard(
      id: id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      shortAnswer: shortAnswer ?? this.shortAnswer,
      deckId: deckId ?? this.deckId,
      difficulty: difficulty ?? this.difficulty,
      difficultyManual: difficultyManual ?? this.difficultyManual,
      cardType: cardType ?? this.cardType,
      priority: priority ?? this.priority,
      topic: topic ?? this.topic,
      note: note ?? this.note,
      originalQuestion: originalQuestion ?? this.originalQuestion,
      originalAnswer: originalAnswer ?? this.originalAnswer,
      flagged: flagged ?? this.flagged,
      sourcePage: sourcePage ?? this.sourcePage,
      isHandwritten: isHandwritten ?? this.isHandwritten,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      nextReview: nextReview ?? this.nextReview,
    );
  }

  /// Kullanıcı düzenlemesini uygular ve AI orijinalini (ilk kez değişen alanda)
  /// saklar. [flagged]/[note] de bu tek çağrıda güncellenir.
  ///
  /// Orijinal yalnızca ilk düzenlemede yakalanır: sonraki düzenlemeler AI'ın
  /// ilk metnini korur, kullanıcının kendi eski hâlini değil. [shortAnswer]
  /// bu snapshot'a DAHİL DEĞİL (ayrı bir `originalShortAnswer` alanı yok,
  /// bilinçli kapsam sınırı) — "AI orijinaline dön" yalnızca `question`/
  /// `answer`'ı geri alır, kısa cevap kullanıcının son girdiği hâlde kalır.
  Flashcard withEdits({
    required String question,
    required String answer,
    required String shortAnswer,
    required CardDifficulty difficulty,
    required String topic,
    required String note,
    required bool flagged,
  }) {
    return Flashcard(
      id: id,
      question: question,
      answer: answer,
      shortAnswer: shortAnswer,
      deckId: deckId,
      difficulty: difficulty,
      // Kullanıcı zorluğu bu düzenlemede değiştirdiyse artık elle ayarlanmış
      // sayılır; otomatik kalibrasyon (SrsEngine.deriveDifficulty) onu ezmez.
      difficultyManual: difficultyManual || difficulty != this.difficulty,
      cardType: cardType,
      priority: priority,
      topic: topic,
      note: note,
      originalQuestion:
          originalQuestion ?? (question != this.question ? this.question : null),
      originalAnswer:
          originalAnswer ?? (answer != this.answer ? this.answer : null),
      flagged: flagged,
      sourcePage: sourcePage,
      isHandwritten: isHandwritten,
      intervalDays: intervalDays,
      easeFactor: easeFactor,
      repetitions: repetitions,
      lapses: lapses,
      nextReview: nextReview,
    );
  }

  /// AI orijinaline döner: soru/cevap ilk hâline alınır, override kaydı silinir.
  /// Not, işaret ve SRS ilerlemesi korunur.
  Flashcard revertedToOriginal() {
    return Flashcard(
      id: id,
      question: originalQuestion ?? question,
      answer: originalAnswer ?? answer,
      shortAnswer: shortAnswer,
      deckId: deckId,
      difficulty: difficulty,
      difficultyManual: difficultyManual,
      cardType: cardType,
      priority: priority,
      topic: topic,
      note: note,
      originalQuestion: null,
      originalAnswer: null,
      flagged: flagged,
      sourcePage: sourcePage,
      isHandwritten: isHandwritten,
      intervalDays: intervalDays,
      easeFactor: easeFactor,
      repetitions: repetitions,
      lapses: lapses,
      nextReview: nextReview,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    'shortAnswer': shortAnswer,
    'deckId': deckId,
    'difficulty': difficulty.name,
    'difficultyManual': difficultyManual,
    'cardType': cardType.name,
    'priority': priority.name,
    'topic': topic,
    'note': note,
    'originalQuestion': originalQuestion,
    'originalAnswer': originalAnswer,
    'flagged': flagged,
    'sourcePage': sourcePage,
    'isHandwritten': isHandwritten,
    'intervalDays': intervalDays,
    'easeFactor': easeFactor,
    'repetitions': repetitions,
    'lapses': lapses,
    'nextReview': nextReview?.toIso8601String(),
  };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
    id: json['id'] as String,
    question: json['question'] as String,
    answer: json['answer'] as String,
    shortAnswer: (json['shortAnswer'] as String?) ?? '',
    deckId: (json['deckId'] as String?) ?? '',
    difficulty: CardDifficulty.parse(json['difficulty']),
    difficultyManual: (json['difficultyManual'] as bool?) ?? false,
    cardType: CardType.parse(json['cardType']),
    priority: CardPriority.parse(json['priority']),
    topic: (json['topic'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
    originalQuestion: json['originalQuestion'] as String?,
    originalAnswer: json['originalAnswer'] as String?,
    flagged: (json['flagged'] as bool?) ?? false,
    sourcePage: (json['sourcePage'] as num?)?.toInt(),
    isHandwritten: (json['isHandwritten'] as bool?) ?? false,
    intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
    easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
    repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
    lapses: (json['lapses'] as num?)?.toInt() ?? 0,
    nextReview: DateTime.tryParse((json['nextReview'] as String?) ?? ''),
  );
}
