import 'package:flutter/foundation.dart';

import '../models/card_filter.dart';
import '../models/deck.dart';
import '../models/exam_result.dart';
import '../models/flashcard.dart';
import '../models/study_log.dart';
import '../models/pdf_page.dart';
import '../services/card_storage.dart';
import '../services/flashcard_generator.dart';
import '../services/pdf_card_pipeline.dart';
import '../srs/srs_engine.dart';

/// Destelerin ve kartların tek doğruluk kaynağı.
class FlashcardStore extends ChangeNotifier {
  /// [dailyQueue] için varsayılan günlük yeni kart limiti (ayarlardan
  /// değiştirilebilir, bkz. `StudySettings`).
  static const int defaultDailyNewCardLimit = 20;

  /// [initialData] uygulama açılışında diskten yüklenen kütüphanedir.
  /// [storage] verilmezse değişiklikler kalıcı olmaz (testlerde böyle kullanılır).
  FlashcardStore(
    this._generator, {
    this.storage,
    LibraryData initialData = const LibraryData(),
  }) : _decks = List<Deck>.of(initialData.decks),
       _cards = List<Flashcard>.of(initialData.cards),
       _studyLog = initialData.studyLog,
       _examResults = List<ExamResult>.of(initialData.examResults);

  final FlashcardGenerator _generator;

  /// Kartların yazıldığı yer. null ise kalıcılık kapalıdır.
  final CardStorage? storage;

  final List<Deck> _decks;
  final List<Flashcard> _cards;
  StudyLog _studyLog;
  final List<ExamResult> _examResults;

  /// Günlük çalışma geçmişi (heatmap + streak).
  StudyLog get studyLog => _studyLog;

  List<Deck> get decks => List.unmodifiable(_decks);

  /// Tüm kartlar (deste ayrımı olmadan).
  List<Flashcard> get cards => List.unmodifiable(_cards);

  /// Deneme sınavı geçmişi, EN YENİ ÖNCE.
  List<ExamResult> get examResults => List.unmodifiable(_examResults);

  /// Anlık kütüphanenin kopyası (yedek dışa aktarma için).
  LibraryData get libraryData => LibraryData(
    decks: _decks,
    cards: _cards,
    studyLog: _studyLog,
    examResults: _examResults,
  );

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Kart listesindeki her değişiklikten sonra çağrılır.
  ///
  /// Kaydetme beklenmez (fire-and-forget): arayüz diske yazmayı beklemesin.
  /// Hata durumunda [CardStorage] kendi içinde loglar.
  void _persist() {
    storage?.save(
      LibraryData(
        decks: _decks,
        cards: _cards,
        studyLog: _studyLog,
        examResults: _examResults,
      ),
    );
  }

  // ---- Deneme sınavı geçmişi ----

  /// [deckId] kapsamındaki EN SON sınav sonucu; hiç yoksa null.
  ///
  /// Deneme sınavı kütüphane geneli olduğu için pratikte `deckId: null` ile
  /// çağrılır (bkz. [ExamResult.deckId]).
  ExamResult? lastExamResultFor(String? deckId) {
    for (final result in _examResults) {
      if (result.deckId == deckId) return result;
    }
    return null;
  }

  /// Yeni bir sınav sonucunu geçmişin BAŞINA ekler ve kalıcılaştırır.
  void recordExamResult(ExamResult result) {
    _examResults.insert(0, result);
    if (_examResults.length > ExamResult.maxHistory) {
      _examResults.removeRange(ExamResult.maxHistory, _examResults.length);
    }
    _persist();
    notifyListeners();
  }

  // ---- Desteler ----

  Deck? deckById(String id) {
    final index = _decks.indexWhere((d) => d.id == id);
    return index == -1 ? null : _decks[index];
  }

  /// Yeni deste oluşturur ve onu döner.
  Deck createDeck(String name) {
    final deck = Deck(
      id: 'deck-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      createdAt: DateTime.now(),
    );

    _decks.add(deck);
    _persist();
    notifyListeners();
    return deck;
  }

  /// [deckId] destesini kaynak PDF kimliğiyle damgalar (bkz.
  /// [Deck.sourcePdfHash]).
  ///
  /// **İLK PDF KAZANIR:** deste ZATEN damgalıysa hiçbir şey yapmaz. Sebep:
  /// bir desteye birden fazla PDF eklenebilir ve tek alan bunu temsil
  /// edemez; destenin KÖKENİNİ kaydetmek, en son eklenene göre sessizce
  /// değişen bir değerden daha kararlı. Değiştirmeden önce
  /// [Deck.sourcePdfHash]'i OKUYAN bir yer olup olmadığına bak —
  /// 2026-08-21 itibarıyla yok, o yüzden bu politika bugün risksiz.
  ///
  /// [hash] DÜZ (soneksiz) içerik özeti olmalı — cache anahtarı değil.
  /// Boş/eksik değerlerde sessizce hiçbir şey yapmaz.
  void stampDeckSourcePdf(String deckId, {String? hash, String? name}) {
    final cleanHash = hash?.trim();
    if (cleanHash == null || cleanHash.isEmpty) return;

    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index == -1) return;
    if (_decks[index].hasSourcePdf) return;

    final cleanName = name?.trim();
    _decks[index] = _decks[index].withSourcePdf(
      hash: cleanHash,
      name: (cleanName == null || cleanName.isEmpty) ? null : cleanName,
    );
    _persist();
    notifyListeners();
  }

  void renameDeck(String deckId, String name) {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index == -1) return;

    _decks[index] = _decks[index].copyWith(name: name.trim());
    _persist();
    notifyListeners();
  }

  /// Destenin sınav tarihini ayarlar/kaldırır ([examDate] null verilirse
  /// kaldırır). Bkz. [SrsEngine.applyReview] ve [dailyQueue] için etkisi.
  void setDeckExamDate(String deckId, DateTime? examDate) {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index == -1) return;

    _decks[index] = _decks[index].withExamDate(examDate);
    _persist();
    notifyListeners();
  }

  /// Desteyi ve içindeki bütün kartları siler.
  void deleteDeck(String deckId) {
    _decks.removeWhere((d) => d.id == deckId);
    _cards.removeWhere((c) => c.deckId == deckId);
    _persist();
    notifyListeners();
  }

  // ---- Kartlar ----

  List<Flashcard> cardsIn(String deckId) =>
      _cards.where((c) => c.deckId == deckId).toList();

  Flashcard? cardById(String id) {
    final index = _cards.indexWhere((c) => c.id == id);
    return index == -1 ? null : _cards[index];
  }

  /// Kullanıcının "hata var" diye işaretlediği kartlar (deste ayrımı olmadan).
  ///
  /// İleride prompt iyileştirme için toplu incelenebilsin diye ayrı tutulur;
  /// her kart kendi orijinal AI metnini de ([Flashcard.originalQuestion]) taşır.
  List<Flashcard> get flaggedCards =>
      _cards.where((c) => c.flagged).toList(growable: false);

  /// Verilen metinden kart üretip [deckId] destesine ekler.
  ///
  /// Başarılıysa üretilen kart sayısını, başarısızsa null döner
  /// ([errorMessage] o durumda doludur).
  Future<int?> generateInto(
    String deckId,
    String sourceText, {
    List<MediaAttachment> media = const [],
  }) async {
    if (_isGenerating) return null;

    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newCards = await _generator.generate(sourceText, media: media);
      _cards.addAll([for (final c in newCards) c.copyWith(deckId: deckId)]);
      _persist();
      return newCards.length;
    } on FlashcardGenerationException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      // Beklenmedik hata: kullanıcıya nazik mesaj, konsola ayrıntı.
      debugPrint('Beklenmeyen kart üretim hatası: $e');
      _errorMessage = 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';
      return null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Üretilen kartları [deckId] destesine ekler (PDF pipeline'ı akış hâlinde
  /// buraya yazar). Boş listede iş yapmaz.
  void addCards(String deckId, List<Flashcard> cards) {
    if (cards.isEmpty) return;
    _cards.addAll([for (final c in cards) c.copyWith(deckId: deckId)]);
    _persist();
    notifyListeners();
  }

  /// PDF pipeline'ının kullandığı sayfa-başına üreteç (LLM sayfayı işler).
  PageGenerator get pageGenerator => (PdfPage page) => _generator
      .generateForPage(
        page.text,
        page.page,
        imageBase64: page.imageBase64,
        imageMimeType: page.imageMimeType,
      );

  /// Düzenlenmiş kartı yerine koyar (eşleşme [Flashcard.id] üzerinden).
  void updateCard(Flashcard updated) {
    final index = _cards.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;

    _cards[index] = updated;
    _persist();
    notifyListeners();
  }

  /// Kartı siler ve geri alınabilmesi için eski konumunu döner.
  int? deleteCard(String id) {
    final index = _cards.indexWhere((c) => c.id == id);
    if (index == -1) return null;

    _cards.removeAt(index);
    _persist();
    notifyListeners();
    return index;
  }

  /// "Geri al" için silinen kartı eski yerine koyar.
  void restoreCard(int index, Flashcard card) {
    _cards.insert(index.clamp(0, _cards.length), card);
    _persist();
    notifyListeners();
  }

  // ---- Çalışma ----

  /// Kartın [grade] cevabına göre SRS durumunu günceller.
  ///
  /// [now] testler için dışarıdan verilebilir.
  void reviewCard(String id, ReviewGrade grade, {DateTime? now}) {
    final index = _cards.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final at = now ?? DateTime.now();
    final card = _cards[index];
    final examDate = deckById(card.deckId)?.examDate;
    _cards[index] = SrsEngine.applyReview(
      card,
      grade,
      now: at,
      examDate: examDate,
    );
    // Her cevap günlük çalışma sayacına yazılır (heatmap/streak).
    _studyLog = _studyLog.recordStudy(at);
    _persist();
    notifyListeners();
  }

  /// Tüm kartların konu bazlı başarı istatistikleri (zayıf konu önce).
  List<TopicStat> get topicStats => SrsEngine.topicStats(_cards);

  /// Her destenin hazırlık yüzdesi, en düşük önce — bkz.
  /// [SrsEngine.deckReadiness]. Kartı olmayan desteler listede yer almaz,
  /// yani hiç kart yoksa liste boş döner (bölüm o durumda gizlenmeli).
  List<DeckReadiness> get deckReadiness =>
      SrsEngine.deckReadiness(_decks, _cards);

  /// Kütüphanenin tamamındaki (deste ayrımı olmadan) en zayıf konusu — bkz.
  /// [SrsEngine.weakestReliableTopic]. Yeterli/güvenilir veri yoksa `null`;
  /// bu durumda "En Zayıf Konu Antrenmanı" girişi hiç gösterilmemeli.
  WeakestTopicInfo? get weakestTopicInfo =>
      SrsEngine.weakestReliableTopic(_cards);

  /// [ids] kartlarını bugünkü çalışma kuyruğuna öne çeker: gelecekteki
  /// [Flashcard.nextReview] tarihini şimdiye alır (Deneme Sınavı'nda yanlış
  /// yapılan kartlar için). SM-2 durumu ([Flashcard.easeFactor]/repetitions/
  /// lapses/intervalDays) BOZULMAZ — yalnızca tekrar zamanı öne alınır.
  /// Zaten due/yeni olan kartlara dokunulmaz (yeni kartın `nextReview: null`
  /// hâli korunur ki `isNew` sınıflaması ve zorluk-bazlı başlangıç katsayısı
  /// değişmesin).
  void pullCardsForwardToToday(Iterable<String> ids, {DateTime? now}) {
    final at = now ?? DateTime.now();
    var changed = false;

    for (final id in ids) {
      final index = _cards.indexWhere((c) => c.id == id);
      if (index == -1) continue;

      final due = _cards[index].nextReview;
      if (due == null || !due.isAfter(at)) continue;

      _cards[index] = _cards[index].copyWith(nextReview: at);
      changed = true;
    }

    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  /// [deckId] destesinde şu an tekrar edilmesi gereken kartlar.
  ///
  /// [filter] verilirse yalnızca ona uyan kartlar arasında bakılır.
  List<Flashcard> dueIn(String deckId, {DateTime? now, CardFilter? filter}) {
    final pool = _pool(deckId, filter);
    return SrsEngine.dueCards(pool, now ?? DateTime.now());
  }

  /// [deckId] destesi için çalışma sırasına dizilmiş kuyruk (zayıf konular önce).
  ///
  /// Tekrar zamanı gelen kart yoksa kullanıcı beklemek zorunda kalmaz:
  /// kuyruk (filtreli) kartların tümüyle kurulur (erken tekrar). Verilen
  /// cevaplar yine SRS aralıklarını günceller. [filter] geçici bir çalışma
  /// alt kümesi seçer; zayıflık sıralaması yine destenin tamamına göre yapılır.
  ///
  /// [ignoreDueDate] true ise due kontrolü hiç yapılmaz, [filter]'a uyan TÜM
  /// kartlar (erken/geç fark etmeksizin) döner — bkz. "Hocanın Favorilerini
  /// Çalış" hızlı pratik modu (`CardListScreen`). Varsayılan `false`,
  /// mevcut davranışı hiç değiştirmez.
  List<Flashcard> studyQueueFor(
    String deckId, {
    DateTime? now,
    CardFilter? filter,
    bool ignoreDueDate = false,
  }) {
    final deckCards = cardsIn(deckId);
    final pool = filter != null && filter.isActive
        ? filter.apply(deckCards)
        : deckCards;
    if (ignoreDueDate) return SrsEngine.sortForStudy(pool, deckCards);

    final due = SrsEngine.dueCards(pool, now ?? DateTime.now());
    return SrsEngine.sortForStudy(due.isEmpty ? pool : due, deckCards);
  }

  /// Tüm destelerden birleşik "bugün çalış" kuyruğu.
  ///
  /// Sıra: (1) tekrar zamanı gelmiş kartlar (zayıf konu önce), (2) sınav
  /// tarihi [SrsEngine.crammingThresholdDays] günden az kalmış destelerin
  /// yeni kartları (limitsiz — "yoğun tekrar modu"), (3) diğer yeni kartlar
  /// (zayıf konu önce), [newCardLimit] ile sınırlı. [filter] verilirse (ör.
  /// Sınav Modu) yalnızca ona uyan kartlar arasından seçilir; zayıflık
  /// sıralaması yine kütüphanenin tamamına göre yapılır.
  ///
  /// Her blok kendi içinde ayrıca [SrsEngine.interleaveByTopic] ile
  /// harmanlanır ("karışık pratik" — aynı konu art arda gelmesin diye);
  /// bloklar arası sıra bundan etkilenmez, yalnızca bir bloğun kendi
  /// içindeki gösterim sırası değişir.
  /// [priorityModeDeckIds] doluysa, o destelere ait "arka plan" kartlar
  /// (bkz. [SrsEngine.sortForStudy]) kuyrukta geriye itilir — silinmez,
  /// yalnızca sırası değişir. Bkz. `StudySettings.priorityModeDeckIds`.
  List<Flashcard> dailyQueue({
    DateTime? now,
    CardFilter? filter,
    int newCardLimit = defaultDailyNewCardLimit,
    Set<String> priorityModeDeckIds = const {},
  }) {
    final at = now ?? DateTime.now();
    final pool = filter != null && filter.isActive
        ? filter.apply(_cards)
        : _cards;

    final due = pool.where((c) => !c.isNew && c.isDue(at)).toList();
    final fresh = pool.where((c) => c.isNew).toList();
    final crammed = fresh.where((c) => _isCramming(c.deckId, at)).toList();
    final normal = fresh.where((c) => !_isCramming(c.deckId, at)).toList();

    return [
      ...SrsEngine.interleaveByTopic(
        SrsEngine.sortForStudy(
          due,
          _cards,
          priorityModeDeckIds: priorityModeDeckIds,
        ),
      ),
      ...SrsEngine.interleaveByTopic(
        SrsEngine.sortForStudy(
          crammed,
          _cards,
          priorityModeDeckIds: priorityModeDeckIds,
        ),
      ),
      ...SrsEngine.interleaveByTopic(
        SrsEngine.sortForStudy(
              normal,
              _cards,
              priorityModeDeckIds: priorityModeDeckIds,
            )
            .take(newCardLimit)
            .toList(),
      ),
    ];
  }

  /// En yakın sınav tarihli, mevcut tempoda yetişmeyen deste var mı?
  ///
  /// Birden fazla deste yetişmiyorsa sınav tarihi en yakın olan döner (bkz.
  /// `_DailyStudyBanner`). Tempo hesabı için yeterli çalışma geçmişi yoksa
  /// (bkz. [StudyLog.recentAverageDailyPace]) her zaman `null`.
  ExamPaceWarning? examPaceWarning({DateTime? now}) {
    final at = now ?? DateTime.now();
    final pace = _studyLog.recentAverageDailyPace();
    if (pace == null) return null;

    ExamPaceWarning? worst;
    for (final deck in _decks) {
      if (deck.examDate == null) continue;
      final warning = SrsEngine.examPaceWarning(
        deck: deck,
        deckCards: cardsIn(deck.id),
        dailyPace: pace,
        now: at,
      );
      if (warning == null) continue;
      if (worst == null || warning.daysLeft < worst.daysLeft) {
        worst = warning;
      }
    }
    return worst;
  }

  /// [deckId] destesinin sınav tarihi [SrsEngine.crammingThresholdDays]
  /// günden az (ama geçmemiş) mi kaldı?
  bool _isCramming(String deckId, DateTime now) {
    final remaining = deckById(deckId)?.daysUntilExam(now);
    return remaining != null &&
        remaining >= 0 &&
        remaining < SrsEngine.crammingThresholdDays;
  }

  List<Flashcard> _pool(String deckId, CardFilter? filter) {
    final deckCards = cardsIn(deckId);
    return filter != null && filter.isActive
        ? filter.apply(deckCards)
        : deckCards;
  }

  /// [deckId] destesindeki konu etiketleri, alfabetik ve tekrarsız.
  List<String> topicsIn(String deckId) {
    final topics = cardsIn(deckId)
        .where((c) => c.hasTopic)
        .map((c) => c.topic)
        .toSet()
        .toList()
      ..sort();
    return topics;
  }

  /// Tüm kütüphanedeki konu etiketleri, destelerden bağımsız, alfabetik ve
  /// tekrarsız. "Bugün Çalış" (birleşik günlük kuyruk) modunda konu
  /// filtresinin seçenek listesini beslemek için kullanılır.
  List<String> get allTopics {
    final topics = _cards
        .where((c) => c.hasTopic)
        .map((c) => c.topic)
        .toSet()
        .toList()
      ..sort();
    return topics;
  }

  /// Kütüphanenin tamamını yedekten gelen [data] ile değiştirir (geri yükleme).
  ///
  /// Mevcut desteler/kartlar/geçmiş tümüyle yerini alır ve kalıcılaştırılır.
  void replaceLibrary(LibraryData data) {
    _decks
      ..clear()
      ..addAll(data.decks);
    _cards
      ..clear()
      ..addAll(data.cards);
    _studyLog = data.studyLog;
    _examResults
      ..clear()
      ..addAll(data.examResults);
    _persist();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
