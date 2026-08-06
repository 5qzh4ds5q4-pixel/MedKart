import 'flashcard.dart';

/// Kart filtresi: seçilen zorluk(lar), konu(lar) ve sayfa aralığının kesişimi.
///
/// Boş küme/aralık "hepsi" demektir. Kullanıcı üstteki filtre çubuğundan zorluk
/// + etiket + (PDF'ten gelen kartlarda) sayfa aralığı seçerek geçici bir çalışma
/// alt kümesi oluşturur (ör. yalnızca "Zor" + "kalp boşlukları", ya da "40-60.
/// sayfalar").
class CardFilter {
  const CardFilter({
    this.difficulties = const {},
    this.topics = const {},
    this.minPage,
    this.maxPage,
    this.examOnly = false,
    this.handwrittenOnly = false,
    this.cardIds = const {},
  });

  /// Yalnızca belirli kart(lar)a odaklanan bir filtre kurar (ör. MCQ pratik
  /// özetindeki "Bu kartı çalışmaya git" — ana çalışma ekranını tam olarak
  /// o karta yönlendirmek için).
  factory CardFilter.forCard(String cardId) => CardFilter(cardIds: {cardId});

  final Set<CardDifficulty> difficulties;
  final Set<String> topics;

  /// Doluysa yalnızca bu id'lere sahip kartlar kalır. Diğer tüm filtre
  /// çubuğu UI'ları (zorluk/konu/sayfa/Sınav Modu) bunu hiç kullanmaz —
  /// yalnızca programatik "tam olarak şu karta git" senaryosu için var.
  final Set<String> cardIds;

  /// Sayfa aralığı (dahil). null uç = o yönde sınırsız. Aralık etkinse
  /// sayfası olmayan (PDF'ten gelmeyen) kartlar dışlanır.
  final int? minPage;
  final int? maxPage;

  /// Sınav Modu: yalnızca [CardType.sinav] kartlar ve [CardPriority.oncelikli]
  /// işaretli temel kartlar kalır; "arka plan" tanım kartları dışlanır.
  final bool examOnly;

  /// Yalnızca [Flashcard.isHandwritten] kartlar kalır ("Sadece Hocanın
  /// Favorileri" — bkz. `HandwrittenFavoriteChip`). Yeni AI çağrısı/veri
  /// üretmez, yalnızca üretim anında zaten doldurulan bu alana göre süzer.
  final bool handwrittenOnly;

  bool get hasPageRange => minPage != null || maxPage != null;

  /// En az bir kriter seçili mi?
  bool get isActive =>
      difficulties.isNotEmpty ||
      topics.isNotEmpty ||
      hasPageRange ||
      examOnly ||
      handwrittenOnly ||
      cardIds.isNotEmpty;

  /// [card] bu filtreye uyuyor mu? (Seçili grup boşsa o boyut serbesttir.)
  bool matches(Flashcard card) {
    if (cardIds.isNotEmpty && !cardIds.contains(card.id)) return false;
    if (difficulties.isNotEmpty && !difficulties.contains(card.difficulty)) {
      return false;
    }
    if (topics.isNotEmpty && !topics.contains(card.topic)) return false;
    if (hasPageRange) {
      final p = card.sourcePage;
      if (p == null) return false;
      if (minPage != null && p < minPage!) return false;
      if (maxPage != null && p > maxPage!) return false;
    }
    if (examOnly &&
        !(card.isExamType || card.priority == CardPriority.oncelikli)) {
      return false;
    }
    if (handwrittenOnly && !card.isHandwritten) return false;
    return true;
  }

  /// [cards] içinden filtreye uyanları döner.
  List<Flashcard> apply(Iterable<Flashcard> cards) =>
      cards.where(matches).toList();

  CardFilter withDifficulty(CardDifficulty d, bool selected) {
    final next = {...difficulties};
    selected ? next.add(d) : next.remove(d);
    return _copy(difficulties: next);
  }

  CardFilter withTopic(String topic, bool selected) {
    final next = {...topics};
    selected ? next.add(topic) : next.remove(topic);
    return _copy(topics: next);
  }

  /// Sayfa aralığını ayarlar; ikisi de null ise aralığı kaldırır.
  CardFilter withPageRange(int? min, int? max) => CardFilter(
    difficulties: difficulties,
    topics: topics,
    minPage: min,
    maxPage: max,
    examOnly: examOnly,
    handwrittenOnly: handwrittenOnly,
    cardIds: cardIds,
  );

  CardFilter withExamOnly(bool value) => _copy(examOnly: value);

  CardFilter withHandwrittenOnly(bool value) => _copy(handwrittenOnly: value);

  CardFilter _copy({
    Set<CardDifficulty>? difficulties,
    Set<String>? topics,
    bool? examOnly,
    bool? handwrittenOnly,
  }) {
    return CardFilter(
      difficulties: difficulties ?? this.difficulties,
      topics: topics ?? this.topics,
      minPage: minPage,
      maxPage: maxPage,
      examOnly: examOnly ?? this.examOnly,
      handwrittenOnly: handwrittenOnly ?? this.handwrittenOnly,
      cardIds: cardIds,
    );
  }

  CardFilter get cleared => const CardFilter();
}
