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
    this.sourcePdfHash,
    this.sourcePdfName,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// Opsiyonel sınav tarihi. Girilmişse [SrsEngine.applyReview] normal SM-2
  /// aralığını bu tarihi aşmayacak şekilde sıkıştırır ve tarih yaklaşınca
  /// (bkz. [SrsEngine.crammingThresholdDays]) günlük kuyruk limitsiz açılır.
  final DateTime? examDate;

  /// Bu destenin kartlarını üreten PDF'in KİMLİĞİ — PDF'in kendisi DEĞİL.
  ///
  /// [PdfCacheService.hashBytes]'ın DÜZ (soneksiz) SHA-256 özeti: içerik
  /// bazlı, dosya adından bağımsız. Cache anahtarı DEĞİLDİR — oradaki
  /// `:novision`/`:tus` sonekleri bir RAF ayrımıdır, belge kimliği değil.
  /// Aynı PDF görselli ya da görselsiz işlense de AYNI belgedir, o yüzden
  /// burada sonek taşınmaz.
  ///
  /// ⚠️ 2026-08-21 itibarıyla YALNIZCA YAZILIYOR, HİÇBİR YERDE OKUNMUYOR.
  /// Amaç ileriye dönük: TUS eklentisi tetiklendiğinde "kullanıcı doğru
  /// PDF'i mi seçti?" karşılaştırmasını yapabilmek. Karşılaştırma mantığı
  /// ve UI ayrı bir adımda gelecek.
  final String? sourcePdfHash;

  /// Kaynak PDF'in kullanıcıya gösterilebilir dosya adı (ör.
  /// "bulasici_hastaliklar.pdf"). Yalnızca insan okuması içindir —
  /// EŞLEŞTİRME ÖLÇÜTÜ DEĞİLDİR, onun için [sourcePdfHash] kullanılır
  /// (aynı PDF farklı adla yüklenebilir, farklı PDF'ler aynı adı taşıyabilir).
  final String? sourcePdfName;

  bool get hasExamDate => examDate != null;

  /// Bu destenin hangi PDF'ten geldiği biliniyor mu?
  bool get hasSourcePdf => sourcePdfHash != null;

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
    sourcePdfHash: sourcePdfHash,
    sourcePdfName: sourcePdfName,
  );

  /// Sınav tarihini ayarlar/kaldırır. [copyWith] null'u "değiştirme" olarak
  /// yorumladığından, kaldırma işlemi için ayrı bir metot gerekir.
  Deck withExamDate(DateTime? examDate) => Deck(
    id: id,
    name: name,
    createdAt: createdAt,
    examDate: examDate,
    sourcePdfHash: sourcePdfHash,
    sourcePdfName: sourcePdfName,
  );

  /// Kaynak PDF kimliğini damgalar. [copyWith] null'u "değiştirme" diye
  /// yorumladığı için ayrı bir metot gerekir ([withExamDate] ile aynı
  /// gerekçe).
  ///
  /// Bu metot ÜZERİNE YAZAR; "ilk PDF kazanır" politikası burada DEĞİL,
  /// çağıranda (`FlashcardStore.stampDeckSourcePdf`) uygulanır — model
  /// katmanı politika taşımasın diye bilinçli ayrım.
  Deck withSourcePdf({String? hash, String? name}) => Deck(
    id: id,
    name: this.name,
    createdAt: createdAt,
    examDate: examDate,
    sourcePdfHash: hash,
    sourcePdfName: name,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'examDate': examDate?.toIso8601String(),
    'sourcePdfHash': sourcePdfHash,
    'sourcePdfName': sourcePdfName,
  };

  /// Eski kayıtlarda `sourcePdfHash`/`sourcePdfName` anahtarları HİÇ YOKTUR
  /// — o durumda null kalırlar (geriye dönük uyumlu, migration gerekmez).
  /// Boş string de null'a indirgenir: JSON'da `""` taşıyan bir kayıt
  /// "kimliği var" gibi davranmasın.
  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    examDate: DateTime.tryParse((json['examDate'] as String?) ?? ''),
    sourcePdfHash: _nullIfBlank(json['sourcePdfHash']),
    sourcePdfName: _nullIfBlank(json['sourcePdfName']),
  );

  static String? _nullIfBlank(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
