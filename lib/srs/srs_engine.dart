import 'dart:math';

import '../models/deck.dart';
import '../models/flashcard.dart';

/// Kullanıcının bir karta verdiği değerlendirme (Anki tarzı 3 kademe).
enum ReviewGrade {
  /// Bilinemedi/zorlandı: aralık sıfırlanır, kart yakında tekrar gelir.
  zor,

  /// Hatırlandı: normal ilerleme.
  orta,

  /// Rahatça hatırlandı: aralık daha çok açılır.
  kolay;

  /// Doğru cevap mı? "zor" bir unutma/başarısızlık sayılır.
  bool get isCorrect => this != ReviewGrade.zor;
}

/// Kütüphanenin en zayıf konusu hakkında — bkz. [SrsEngine.weakestReliableTopic].
class WeakestTopicInfo {
  const WeakestTopicInfo({required this.topic, required this.cardCount});

  final String topic;

  /// O konudaki toplam kart sayısı (deste ayrımı olmadan).
  final int cardCount;
}

/// Önümüzdeki bir günün tekrar yükü — bkz. [SrsEngine.reviewForecast].
class ReviewForecastDay {
  const ReviewForecastDay({required this.day, required this.count});

  /// Gün (saat bileşeni sıfırlanmış).
  final DateTime day;

  /// O gün tekrara düşecek kart sayısı. İlk gün (bugün) gecikmiş kartları da
  /// içerir.
  final int count;
}

/// Bir destenin "ne kadarı öğrenildi" özeti — bkz. [SrsEngine.deckReadiness].
///
/// "Hazır" ölçütü [SrsEngine.isWellLearned] ile TEK yerden gelir; sınav tempo
/// uyarısındaki (`ExamPaceWarning.remainingCards`) "kalan kart" sayımı da aynı
/// fonksiyonu kullanır — iki ekran aynı kartı farklı sınıflandıramaz.
class DeckReadiness {
  const DeckReadiness({
    required this.deckId,
    required this.deckName,
    required this.readyCards,
    required this.totalCards,
  });

  final String deckId;
  final String deckName;

  /// "İyi öğrenilmiş" sayılan kart sayısı.
  final int readyCards;

  /// Destedeki toplam kart sayısı. [SrsEngine.deckReadiness] boş desteleri
  /// hiç döndürmediği için burada her zaman > 0.
  final int totalCards;

  /// 0..1 arası hazırlık oranı.
  double get readyRate => totalCards == 0 ? 0 : readyCards / totalCards;

  /// Yüzde olarak hazırlık (0-100).
  int get readyPercent => (readyRate * 100).round();
}

/// Bir konunun yüzdesinin ne kadar güvenilir olduğu.
///
/// Az veriyle hesaplanmış bir yüzde ("1 kartta 1 hata = %0") yanıltıcı
/// olduğu için istatistik ekranı bu konuları sayı yerine etiketle gösterir.
///
/// DİKKAT: enum sırası aynı zamanda GÖSTERİM sırasıdır
/// ([SrsEngine.topicStats] sıralaması `index` üzerinden karşılaştırıyor) —
/// sırayı değiştirme, sona ekle.
enum TopicDataState {
  /// Yüzde anlamlı: [TopicStat.attempts] eşiği geçmiş.
  normal,

  /// En az bir değerlendirme var ama yüzdeye güvenmek için çok az.
  lowData,

  /// Konudaki hiçbir kart hiç çalışılmamış.
  notStarted,
}

/// Bir konunun (etiket) çalışma istatistiği — istatistik ekranı için.
class TopicStat {
  const TopicStat({
    required this.topic,
    required this.cardCount,
    required this.attempts,
    required this.successRate,
  });

  final String topic;

  /// Bu konudaki kart sayısı.
  final int cardCount;

  /// Değerlendirme sayısı (yaklaşık: lapses + repetitions). 0 ise hiç
  /// çalışılmamış demektir; o durumda [successRate] anlamsızdır.
  final int attempts;

  /// Başarı oranı 0..1 (= 1 − zayıflık = doğru / deneme).
  final double successRate;

  /// Konu en az bir kez çalışıldı mı?
  bool get studied => attempts > 0;

  /// Yüzde olarak başarı (0..100).
  int get successPercent => (successRate * 100).round();

  /// [successPercent]'in "anlamlı" sayılması için gereken en az
  /// [attempts] sayısı. Bunun altındaki konular yüzde yerine "Az veri"
  /// etiketiyle gösterilir. Kolay ayarlanabilsin diye tek yerde.
  static const int minAttemptsForPercent = 5;

  /// Yüzdenin güvenilirliği — bkz. [TopicDataState].
  ///
  /// Ölçü [attempts] (= lapses + repetitions), ÇIPLAK `repetitions` DEĞİL:
  /// SM-2'de "Zor" cevabı `repetitions`'ı sıfırlıyor
  /// ([SrsEngine.review]), yani hep zorlanılan bir konunun tüm kartları
  /// `repetitions == 0` olabilir. Çıplak repetitions'a bakılsaydı o konu
  /// "Henüz başlanmadı" sayılıp listenin dibine düşerdi — oysa öğrencinin
  /// EN ÇOK çalıştığı ve en çok zorlandığı konu odur.
  TopicDataState get dataState {
    if (attempts <= 0) return TopicDataState.notStarted;
    if (attempts < minAttemptsForPercent) return TopicDataState.lowData;
    return TopicDataState.normal;
  }
}

/// Bir destenin sınav tarihine göre mevcut çalışma tempoda "yetişip
/// yetişmediği" — bkz. [SrsEngine.examPaceWarning]. Yalnızca bir öneri/
/// uyarıdır; hiçbir kartı gizlemez ya da siler.
class ExamPaceWarning {
  const ExamPaceWarning({
    required this.deckId,
    required this.daysLeft,
    required this.dailyPace,
    required this.expectedCapacity,
    required this.remainingCards,
  });

  final String deckId;

  /// Sınava kalan tam gün sayısı (bkz. [Deck.daysUntilExam]).
  final int daysLeft;

  /// Son aktif günlerin ortalama günlük kart tempo'su (bkz.
  /// [StudyLog.recentAverageDailyPace]).
  final double dailyPace;

  /// [dailyPace] * [daysLeft] — kalan günlerde tahmini çalışılabilecek kart.
  final int expectedCapacity;

  /// Destede henüz "iyi öğrenilmiş" sayılmayan kart sayısı.
  final int remainingCards;
}

/// Aralıklı tekrar motoru — SM-2'nin (SuperMemo/Anki) sadeleştirilmiş hali.
///
/// Kural özeti:
/// - "Zor"   → aralık sıfırlanır, kart ertesi güne atanır, kolaylık katsayısı
///   düşer (kart bundan sonra daha sık gelir).
/// - "Orta"  → 1. doğruda 1 gün, 2. doğruda 4 gün, sonrasında aralık kolaylık
///   katsayısıyla çarpılarak büyür (4 → 10 → 25 ...).
/// - "Kolay" → orta ilerlemenin bir kademe önü + kolaylık bonusu; katsayı artar.
///
/// Tüm fonksiyonlar saftır ve zamanı dışarıdan alır; böylece "3 gün sonra ne
/// olur" testle doğrulanabilir.
class SrsEngine {
  const SrsEngine._();

  /// SM-2'nin alt sınırı. Bunun altına inince kart takılıp kalır.
  static const double minEase = 1.3;
  static const double maxEase = 2.8;

  /// "Zor" cevapta kolaylık katsayısından düşülen miktar.
  static const double easePenalty = 0.2;

  /// "Kolay" cevapta kolaylık katsayısına eklenen miktar.
  static const double easeBonus = 0.15;

  /// "Kolay" cevabın aralığı, "orta"ya göre bu oranda uzar.
  static const double easyMultiplier = 1.3;

  /// İlk doğru cevaptan sonraki aralık (gün).
  static const int firstInterval = 1;

  /// İkinci ardışık doğru cevaptan sonraki aralık (gün).
  static const int secondInterval = 4;

  /// Aralığın büyüyebileceği üst sınır (gün).
  static const int maxIntervalDays = 365;

  /// Sınav tarihine bu kadar gün veya daha az kalınca "yoğun tekrar modu"
  /// devreye girer (bkz. `FlashcardStore.dailyQueue`): günlük yeni kart
  /// limiti o deste için uygulanmaz.
  static const int crammingThresholdDays = 3;

  // ---- Sınav tempo uyarısı (bkz. [examPaceWarning]) ----

  /// Kalan kart sayısı, tahmini kapasiteyi bu orandan fazla aşarsa
  /// "yetişmiyor" sayılır (yüzde 10 tolerans — küçük sapmalarda gereksiz
  /// uyarı çıkmasın diye).
  static const double examPaceToleranceFactor = 1.1;

  // ---- En zayıf konu antrenmanı (bkz. [weakestReliableTopic]) ----

  /// "En zayıf konu" güvenilir sayılabilmesi için bir konunun sahip olması
  /// gereken en az kart sayısı — azsa tek bir kartın gürültüsü konuyu
  /// yanlışlıkla "en zayıf" gösterebilir.
  static const int weakestTopicMinCards = 5;

  // ---- Otomatik zorluk kalibrasyonu (bkz. [deriveDifficulty]) ----

  /// Kalibrasyonun devreye girmesi için gereken en az ardışık doğru sayısı.
  /// Bunun altında AI'ın üretimdeki tahmini korunur (henüz yeterince veri yok).
  static const int difficultyMinRepetitions = 2;

  /// Bu kadar veya daha çok unutma → kart "zor" kabul edilir.
  static const int difficultyZorLapses = 3;

  /// Hiç unutulmamış kartın "kolay" sayılması için gereken en az ardışık doğru.
  static const int difficultyKolayRepetitions = 3;

  /// Kartın zorluk etiketi, başlangıç kolaylık katsayısını belirler: "zor"
  /// etiketli kart daha küçük katsayıyla başlar, yani aralıkları daha yavaş
  /// büyür ve karşına daha sık çıkar.
  ///
  /// Bu yalnızca bir başlangıç tahminidir; kullanıcının kendi cevapları
  /// biriktikçe katsayı gerçek performansa göre kayar.
  ///
  /// ⚠️ 2026-08-20 (prompt v31) İTİBARIYLA PRATİKTE HEP 2.5 DÖNER — bu
  /// BİLİNÇLİ ve kabul edilmiş bir sonuçtur, bug değildir. `zorlukKurali`
  /// prompt'tan kaldırıldı (bkz. `flashcard_prompt.dart`, kaldırılan bloğun
  /// yerindeki gerekçe yorumu); model artık kompakt dizinin [3]. pozisyonuna
  /// her zaman "o" yazıyor, dolayısıyla YENİ üretilen her kart `orta` doğuyor
  /// ve `kolay`(2.6)/`zor`(2.3) dalları yalnızca v31 ÖNCESİ kartlarda ve
  /// kullanıcının elle ayarladığı ([Flashcard.difficultyManual]) kartlarda
  /// tetikleniyor.
  ///
  /// Yani AI'ın zorluk sezgisi artık SRS zamanlamasına HİÇ girmiyor. Kayıp
  /// bilinçli: o sezgi ölçümde `sinavTipiKurali`'nin gölgesi çıktı (kural
  /// olmadan "zor" üretilemiyordu) ve zaten kartın 2. tekrarında
  /// [deriveDifficulty] tarafından üzerine yazılıyordu.
  ///
  /// ÜÇ DALI DA KORU: eski kartlar ve elle ayarlanmış kartlar hâlâ bu yoldan
  /// geçiyor; switch'i sadeleştirmek onların davranışını sessizce değiştirir.
  static double initialEase(CardDifficulty difficulty) {
    return switch (difficulty) {
      CardDifficulty.kolay => 2.6,
      CardDifficulty.orta => 2.5,
      CardDifficulty.zor => 2.3,
    };
  }

  /// Kartın zorluğunu geçmiş performansına (lapses + repetitions) göre türetir.
  ///
  /// Üretimdeki AI tahmini yalnızca bir başlangıçtır; kart çalışıldıkça bu
  /// fonksiyon [applyReview] içinde çağrılıp zorluk gerçek veriye göre kayar.
  /// Kullanıcı zorluğu elle ayarladıysa ([Flashcard.difficultyManual]) çağıran
  /// bu fonksiyonu hiç uygulamaz — kullanıcının seçimi korunur.
  static CardDifficulty deriveDifficulty(Flashcard card) {
    // "Zor" kontrolü repetitions guard'ından ÖNCE ve ondan bağımsız: "Zor"
    // cevap repetitions'ı sıfırladığı için guard önce gelseydi en çok
    // zorlanılan kart tam da o anda "zor" işaretlenemezdi.
    if (card.lapses >= difficultyZorLapses) return CardDifficulty.zor;

    // Henüz yeterince veri yok: üretimdeki değere dokunma.
    if (card.repetitions < difficultyMinRepetitions) return card.difficulty;

    if (card.lapses == 0 && card.repetitions >= difficultyKolayRepetitions) {
      return CardDifficulty.kolay;
    }
    return CardDifficulty.orta;
  }

  /// "Orta" cevaptaki temel ilerleme aralığı (gün).
  static int _baseInterval(Flashcard card) {
    return switch (card.repetitions) {
      0 => firstInterval,
      1 => secondInterval,
      _ => max(
        secondInterval + 1,
        (card.intervalDays * card.easeFactor).round(),
      ),
    };
  }

  /// [card] için [grade] cevabı verilirse yeni aralık kaç gün olur?
  ///
  /// Arayüzde işlem geri alınmadan sonucu doğrulamak ve testlerde kullanılır.
  static int nextIntervalDays(Flashcard card, ReviewGrade grade) {
    if (grade == ReviewGrade.zor) return firstInterval;

    var base = _baseInterval(card);
    if (grade == ReviewGrade.kolay) {
      // Kolay, orta ilerlemenin bir kademe önünde olsun: yeni kartta bile
      // en az ikinci aralığa (4 gün) atlar, üstüne kolaylık bonusu biner.
      base = max(secondInterval, (base * easyMultiplier).round());
    }
    return min(maxIntervalDays, base);
  }

  /// Cevabı uygular ve kartın güncellenmiş SRS durumunu döner.
  ///
  /// [examDate] verilirse (deste için bir sınav tarihi girilmişse) ve normal
  /// SM-2 aralığı kartı bu tarihten SONRAYA planlıyorsa, aralık sınav
  /// tarihinden önceki bir güne sıkıştırılır (bkz. [_compressForExam]).
  static Flashcard applyReview(
    Flashcard card,
    ReviewGrade grade, {
    required DateTime now,
    DateTime? examDate,
  }) {
    // Hiç çalışılmamış kartın katsayısı AI'ın zorluk tahmininden başlar.
    final currentEase = card.isNew ? initialEase(card.difficulty) : card.easeFactor;
    var interval = nextIntervalDays(card, grade);

    final double newEase;
    final int newRepetitions;
    final int newLapses;

    switch (grade) {
      case ReviewGrade.zor:
        newEase = max(minEase, currentEase - easePenalty);
        newRepetitions = 0;
        newLapses = card.lapses + 1;
      case ReviewGrade.orta:
        newEase = currentEase.clamp(minEase, maxEase);
        newRepetitions = card.repetitions + 1;
        newLapses = card.lapses;
      case ReviewGrade.kolay:
        newEase = min(maxEase, currentEase + easeBonus);
        newRepetitions = card.repetitions + 1;
        newLapses = card.lapses;
    }

    if (examDate != null) {
      interval = _compressForExam(interval, now: now, examDate: examDate);
    }

    final updated = card.copyWith(
      intervalDays: interval,
      easeFactor: newEase,
      repetitions: newRepetitions,
      lapses: newLapses,
      nextReview: now.add(Duration(days: interval)),
    );

    // Zorluk, güncellenmiş lapses/repetitions üzerinden yeniden kalibre edilir;
    // kullanıcının elle ayarladığı zorluk ezilmez.
    if (updated.difficultyManual) return updated;
    return updated.copyWith(difficulty: deriveDifficulty(updated));
  }

  /// [interval] günü sınav tarihinden sonraya denk geliyorsa, kalan gün
  /// sayısının yarısına sıkıştırır (kalan pencereye orantılı, çoklu tekrara
  /// yer bırakır). Sınav geçmişse veya aralık zaten sınavdan önceyse dokunmaz.
  static int _compressForExam(
    int interval, {
    required DateTime now,
    required DateTime examDate,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    final remaining = examDay.difference(today).inDays;

    if (remaining <= 0) return interval;
    if (today.add(Duration(days: interval)).isBefore(examDay) ||
        today.add(Duration(days: interval)).isAtSameMomentAs(examDay)) {
      return interval;
    }

    return max(1, (remaining / 2).round());
  }

  /// [now] anında tekrar edilmesi gereken kartlar.
  static List<Flashcard> dueCards(List<Flashcard> cards, DateTime now) {
    return cards.where((c) => c.isDue(now)).toList();
  }

  /// Önümüzdeki [days] günün tekrar yükü, bugünden başlayarak (bugün dahil).
  ///
  /// Kurallar:
  /// - `nextReview` bugünden ÖNCEYSE (gecikmiş kart) İLK GÜNE eklenir —
  ///   gecikmiş yük kaybolmasın, bugünün gerçek yükünü göstersin.
  /// - `nextReview` `null` olan kartlar (hiç çalışılmamış YENİ kartlar) hiç
  ///   sayılmaz: zamanlanmış bir tekrarları yok, günlük yeni-kart limiti
  ///   üzerinden kuyruğa giriyorlar (bkz. `FlashcardStore.dailyQueue`).
  /// - Penceresin dışına düşen (>= [days] gün sonrası) kartlar sayılmaz.
  static List<ReviewForecastDay> reviewForecast(
    List<Flashcard> cards,
    DateTime now, {
    int days = 7,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(days, 0);

    for (final card in cards) {
      final next = card.nextReview;
      if (next == null) continue;

      final day = DateTime(next.year, next.month, next.day);
      final offset = day.difference(today).inDays;
      if (offset >= days) continue;
      // Gecikmiş (offset < 0) → bugüne yaz.
      counts[offset < 0 ? 0 : offset]++;
    }

    return [
      for (var i = 0; i < days; i++)
        ReviewForecastDay(day: today.add(Duration(days: i)), count: counts[i]),
    ];
  }

  /// Bir kart "iyi öğrenilmiş" sayılır mı? — **TEK ve PAYLAŞILAN tanım.**
  ///
  /// Ölçüt [deriveDifficulty]'nin "kolay" kriteriyle AYNI: hiç unutulmamış
  /// (`lapses == 0`) ve en az [difficultyKolayRepetitions] ardışık doğru
  /// cevap almış kart "öğrenilmiş" sayılır. İki kavramın (zorluk etiketi ve
  /// "hazır" sayımı) aynı tanımdan beslenmesi bilinçli — bir kart aynı anda
  /// "zor" etiketli ama "öğrenilmiş" olamaz.
  ///
  /// Bunu kullananlar: sınav tempo uyarısındaki "kalan kart" sayımı
  /// ([examPaceWarning] → [ExamPaceWarning.remainingCards]) ve deste hazırlık
  /// yüzdesi ([deckReadiness]). İkisi aynı kartı farklı sınıflandırmasın diye
  /// ölçüt buraya çıkarıldı — yeni bir "hazır" tanımı İCAT ETME, bu
  /// fonksiyonu çağır.
  ///
  /// TARİHÇE (2026-08-04): `lapses == 0` şartı sonradan eklendi. Öncesinde
  /// yalnızca repetitions'a bakılıyordu, yani çok unutulmuş ama sonunda üst
  /// üste doğru bilinen bir kart "öğrenilmiş" sayılıyordu. Şart eklenince
  /// tempo uyarısı SERTLEŞTİ (daha çok kart "kalan" sayılıyor → uyarı daha
  /// sık çıkar) — kullanıcının bilinçli kararı. İkisi tek fonksiyondan
  /// beslendiği için ayrı ayrı ayarlanamaz.
  static bool isWellLearned(Flashcard card) =>
      card.lapses == 0 && card.repetitions >= difficultyKolayRepetitions;

  /// Her destenin "%X hazır" özeti — EN DÜŞÜK hazırlık ÖNCE (istatistik
  /// ekranındaki "en zayıf üstte" kuralıyla tutarlı; eşitlikte deste adı).
  ///
  /// Kartı olmayan desteler listeye HİÇ girmez: yüzde tanımsız olurdu ve boş
  /// bir desteyi "%0 hazır" diye göstermek yanıltıcı.
  static List<DeckReadiness> deckReadiness(
    List<Deck> decks,
    List<Flashcard> cards,
  ) {
    final result = <DeckReadiness>[];

    for (final deck in decks) {
      final deckCards = cards.where((c) => c.deckId == deck.id).toList();
      if (deckCards.isEmpty) continue;
      result.add(
        DeckReadiness(
          deckId: deck.id,
          deckName: deck.name,
          readyCards: deckCards.where(isWellLearned).length,
          totalCards: deckCards.length,
        ),
      );
    }

    result.sort((a, b) {
      final byPercent = a.readyPercent.compareTo(b.readyPercent);
      return byPercent != 0 ? byPercent : a.deckName.compareTo(b.deckName);
    });
    return result;
  }

  /// [deck]'in mevcut çalışma tempoda sınavına yetişip yetişmediğini
  /// hesaplar. Hiçbir kartı gizlemez/silmez — yalnızca bir uyarı döner.
  ///
  /// [dailyPace] `null` ise (yeterli çalışma geçmişi yok, bkz.
  /// [StudyLog.recentAverageDailyPace]) tahmin yapılmaz, `null` döner. Deste
  /// sınav tarihi girmemişse veya sınav geçmişse de `null` döner.
  ///
  /// "Kalan kart" = [isWellLearned] olmayanlar (paylaşılan tanım).
  static ExamPaceWarning? examPaceWarning({
    required Deck deck,
    required List<Flashcard> deckCards,
    required double? dailyPace,
    required DateTime now,
  }) {
    if (dailyPace == null) return null;

    final daysLeft = deck.daysUntilExam(now);
    if (daysLeft == null || daysLeft <= 0) return null;

    final remaining = deckCards.where((c) => !isWellLearned(c)).length;
    final expectedCapacity = (dailyPace * daysLeft).round();

    if (remaining <= expectedCapacity * examPaceToleranceFactor) return null;

    return ExamPaceWarning(
      deckId: deck.id,
      daysLeft: daysLeft,
      dailyPace: dailyPace,
      expectedCapacity: expectedCapacity,
      remainingCards: remaining,
    );
  }

  /// Konu bazlı zayıflık skoru: 0 (hiç unutulmamış) ile 1'e yaklaşan değerler.
  ///
  /// Unutma sayısının toplam denemeye oranı. Adım 2'nin amacı buydu:
  /// kullanıcının zayıf olduğu konuyu öne çekmek.
  static Map<String, double> topicWeakness(List<Flashcard> cards) {
    final lapses = <String, int>{};
    final attempts = <String, int>{};

    for (final card in cards) {
      if (!card.hasTopic) continue;
      lapses[card.topic] = (lapses[card.topic] ?? 0) + card.lapses;
      attempts[card.topic] =
          (attempts[card.topic] ?? 0) + card.lapses + card.repetitions;
    }

    return {
      for (final topic in attempts.keys)
        topic: attempts[topic]! == 0 ? 0 : lapses[topic]! / attempts[topic]!,
    };
  }

  /// [topicWeakness]'ı kullanarak GÜVENİLİR şekilde en zayıf konuyu bulur
  /// (bkz. "En Zayıf Konu Antrenmanı", `FlashcardStore.weakestTopicInfo`).
  ///
  /// Bir konunun "en zayıf" sayılabilmesi için İKİ koşul birden gerekir:
  /// (1) en az [minCardsPerTopic] kartı olmalı (azsa tek kartın gürültüsü
  /// yanıltır), (2) o kartların TOPLAM [Flashcard.repetitions]'ı en az
  /// [difficultyMinRepetitions] olmalı (hiç çalışılmamış bir konuda
  /// zayıflık 0/0 anlamsızdır). Hiçbir konu bu iki koşulu birden
  /// karşılamıyorsa `null` döner — bu durumda çağıran taraf ÖZELLİĞİ HİÇ
  /// GÖSTERMEMELİ, tahmini bir sonuç sunmamalı.
  static WeakestTopicInfo? weakestReliableTopic(
    List<Flashcard> cards, {
    int minCardsPerTopic = weakestTopicMinCards,
  }) {
    final byTopic = <String, List<Flashcard>>{};
    for (final card in cards) {
      if (!card.hasTopic) continue;
      byTopic.putIfAbsent(card.topic, () => []).add(card);
    }

    final weakness = topicWeakness(cards);

    String? bestTopic;
    var bestScore = -1.0;
    for (final entry in byTopic.entries) {
      final topicCards = entry.value;
      if (topicCards.length < minCardsPerTopic) continue;

      final totalRepetitions = topicCards.fold<int>(
        0,
        (sum, c) => sum + c.repetitions,
      );
      if (totalRepetitions < difficultyMinRepetitions) continue;

      final score = weakness[entry.key] ?? 0;
      if (score > bestScore) {
        bestScore = score;
        bestTopic = entry.key;
      }
    }

    if (bestTopic == null) return null;
    return WeakestTopicInfo(
      topic: bestTopic,
      cardCount: byTopic[bestTopic]!.length,
    );
  }

  /// Konu bazlı başarı istatistikleri.
  ///
  /// [topicWeakness] ile aynı ölçüyü kullanır (başarı = 1 − zayıflık), böylece
  /// istatistik ekranında "en zayıf" görünen konu, çalışmada öne çekilen konuyla
  /// birebir aynıdır.
  ///
  /// Sıralama önce [TopicDataState] grubuna göre: normal → az veri → henüz
  /// başlanmadı. Yüzdesi anlamsız olan konuları "en zayıf" diye tepeye
  /// koymamak için — 1 kartta 1 hata yapılmış konu %0 çıkıp gerçekten zayıf
  /// konuyu aşağı iterdi. Grup İÇİNDE: normal konular başarı oranına göre
  /// artan (en zayıf üstte); diğer iki grupta yüzde gösterilmediği için
  /// sıralanacak bir şey yok, yalnızca deterministik olsun diye kart sayısı
  /// fazla olan önce, sonra ada göre.
  static List<TopicStat> topicStats(List<Flashcard> cards) {
    final cardCounts = <String, int>{};
    final lapses = <String, int>{};
    final attempts = <String, int>{};

    for (final card in cards) {
      if (!card.hasTopic) continue;
      cardCounts[card.topic] = (cardCounts[card.topic] ?? 0) + 1;
      lapses[card.topic] = (lapses[card.topic] ?? 0) + card.lapses;
      attempts[card.topic] =
          (attempts[card.topic] ?? 0) + card.lapses + card.repetitions;
    }

    final stats = [
      for (final topic in cardCounts.keys)
        TopicStat(
          topic: topic,
          cardCount: cardCounts[topic]!,
          attempts: attempts[topic]!,
          successRate: attempts[topic]! == 0
              ? 0
              : 1 - lapses[topic]! / attempts[topic]!,
        ),
    ];

    stats.sort((a, b) {
      // Önce grup: normal → az veri → henüz başlanmadı (enum sırası =
      // gösterim sırası, bkz. [TopicDataState]).
      final byState = a.dataState.index.compareTo(b.dataState.index);
      if (byState != 0) return byState;

      // Yalnızca yüzdesi anlamlı olanlar başarıya göre sıralanır.
      if (a.dataState == TopicDataState.normal) {
        final byRate = a.successRate.compareTo(b.successRate);
        if (byRate != 0) return byRate;
      }
      final byCount = b.cardCount.compareTo(a.cardCount);
      if (byCount != 0) return byCount;
      return a.topic.compareTo(b.topic);
    });

    return stats;
  }

  /// [sortForStudy] çıktısını konular arası harmanlayarak ("karışık pratik" /
  /// interleaving — aynı konunun art arda gelmesini önleyen öğrenme
  /// tekniği) son gösterim sırasına çevirir.
  ///
  /// Konu-İÇİ sıra [sorted]'dan AYNEN korunur (bu fonksiyon [sortForStudy]'nin
  /// hesapladığı zayıflık/gecikme sırasına dokunmaz) — yalnızca hangi kartın
  /// hangi TURDA gösterileceği değişir. [sorted] zaten zayıf konu önce
  /// sıralı olduğu için, her konunun kuyruktaki ilk kartı da doğal olarak
  /// konuların zayıflık sırasını taşır; bu yüzden burada zayıflığı ayrıca
  /// hesaplamaya gerek yok.
  ///
  /// [sorted] içinde 1 veya 0 farklı konu varsa (harmanlanacak başka konu
  /// yok) [sorted] AYNEN döner. 2+ konu varsa round-robin: her turda sırayla
  /// her konudan bir kart alınır; bir konu tükenirse o tur o konu için
  /// atlanır, diğer konulardan almaya devam edilir.
  static List<Flashcard> interleaveByTopic(List<Flashcard> sorted) {
    final byTopic = <String, List<Flashcard>>{};
    final topicOrder = <String>[];
    for (final card in sorted) {
      final list = byTopic.putIfAbsent(card.topic, () {
        topicOrder.add(card.topic);
        return <Flashcard>[];
      });
      list.add(card);
    }

    if (topicOrder.length < 2) return sorted;

    final result = <Flashcard>[];
    final cursors = List<int>.filled(topicOrder.length, 0);
    while (result.length < sorted.length) {
      for (var i = 0; i < topicOrder.length; i++) {
        final list = byTopic[topicOrder[i]]!;
        if (cursors[i] < list.length) {
          result.add(list[cursors[i]]);
          cursors[i]++;
        }
      }
    }
    return result;
  }

  /// Çalışma sırasını belirler: zayıf konular önce, ardından en çok gecikmiş
  /// kartlar. Aynı konudaki kartlar doğal olarak yan yana gelir.
  ///
  /// [priorityModeDeckIds] doluysa (bkz. "Öncelikli Mod",
  /// `FlashcardStore.dailyQueue`), bu kümedeki desteye ait kartlar için EK
  /// bir üst düzey ayrım devreye girer: [CardPriority.arkaPlan] kartlar,
  /// zayıflık/gecikme sırasından ÖNCE, [CardPriority.oncelikli] olan (ve
  /// kümede olmayan desteye ait TÜM) kartlardan sonraya itilir — silinmez,
  /// yalnızca kuyrukta geriye kayar. Kümede olmayan destelerin kartları bu
  /// ayrımdan hiç etkilenmez (rütbeleri hep eşit), yani mevcut davranış
  /// aynen korunur.
  static List<Flashcard> sortForStudy(
    List<Flashcard> due,
    List<Flashcard> all, {
    Set<String> priorityModeDeckIds = const {},
  }) {
    final weakness = topicWeakness(all);
    final sorted = [...due];

    int priorityRank(Flashcard c) {
      if (!priorityModeDeckIds.contains(c.deckId)) return 0;
      return c.priority == CardPriority.arkaPlan ? 1 : 0;
    }

    sorted.sort((a, b) {
      if (priorityModeDeckIds.isNotEmpty) {
        final byPriority = priorityRank(a).compareTo(priorityRank(b));
        if (byPriority != 0) return byPriority;
      }

      final wa = weakness[a.topic] ?? 0;
      final wb = weakness[b.topic] ?? 0;
      final byWeakness = wb.compareTo(wa);
      if (byWeakness != 0) return byWeakness;

      // Aynı zayıflıkta: en uzun süredir bekleyen önce.
      final da = a.nextReview;
      final db = b.nextReview;
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });

    return sorted;
  }
}
