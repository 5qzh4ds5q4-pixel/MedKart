import 'package:flutter/foundation.dart';

import '../models/flashcard.dart';
import '../models/pdf_page.dart';
import 'flashcard_generator.dart';

/// Bir worker'ın, bir sayfayı bitirdikten SONRA sıradaki sayfayı almadan
/// önce beklediği süre (üretim varsayılanı). Amaç: 4 worker'ın sağlayıcıya
/// aralıksız istek yağdırıp timeout/5xx'i tetiklemesini yumuşatmak.
/// Testler [PdfCardPipeline.interPageDelay]'e [Duration.zero] enjekte eder —
/// bu sabiti testte kullanma/bekleme.
const Duration kInterPageDelay = Duration(milliseconds: 400);

/// Tek bir PDF sayfasından kart üreten fonksiyon (LLM çağrısı buraya enjekte
/// edilir; böylece pipeline saf kalır ve testlerde sahte üreticiyle koşar).
typedef PageGenerator = Future<List<Flashcard>> Function(PdfPage page);

/// PDF → kart pipeline'ının sonucu (bitişte gösterilen özet).
class PipelineResult {
  const PipelineResult({
    required this.totalPages,
    required this.cards,
    required this.emptyTextPages,
    required this.emptyResultPages,
    required this.failedPages,
    this.quotaExhausted = false,
    this.quotaMessage,
  });

  final int totalPages;
  final List<Flashcard> cards;

  /// Metin çıkarılamayan (görsel ağırlıklı) sayfa numaraları — atlanmadı,
  /// işaretlendi.
  final List<int> emptyTextPages;

  /// Modele GİDEN ama boş dizi (`[]`) dönen sayfa numaraları — yani modelin
  /// "burada test edilecek bilgi yok" dediği sayfalar (kapak/ajanda/geçiş/
  /// kapanış slaytı, ders-dışı içerik; bkz. flashcard_prompt.dart'taki "boş
  /// dizi döndür" kuralı).
  ///
  /// **Diğer iki listeyle KARIŞTIRMA — üçü ayrı olaydır:**
  /// - [emptyTextPages]: modele HİÇ GİTMEDİ (metin de görüntü de yoktu,
  ///   ön-filtrede elendi) → maliyet YOK.
  /// - [emptyResultPages]: modele GİTTİ, faturalandı, `[]` döndü → maliyet
  ///   VAR, kart YOK. Bu bir HATA DEĞİL, beklenen ve doğru davranıştır.
  /// - [failedPages]: modele gitti ama istisna fırlattı (ağ/parse/timeout)
  ///   → kart yok, sebep teknik.
  ///
  /// Bu liste 2026-08-18'de eklendi: öncesinde `[]` dönen sayfa hiçbir yerde
  /// kaydedilmiyordu ([processedPages]'e sessizce başarılı sayılıyordu), bu
  /// yüzden "sayfaların yüzde kaçı kart üretmeye değmez bulunuyor" sorusu
  /// ancak `pdf_cache`'teki `sourcePage` boşluklarından TAHMİN edilebiliyordu.
  final List<int> emptyResultPages;

  /// Denemelere rağmen işlenemeyen sayfa numaraları.
  final List<int> failedPages;

  /// API kotasına (429) takılıp işlem erken durduysa true. Bu durumda kalan
  /// sayfalar hiç denenmedi; kullanıcıya "kota doldu" mesajı gösterilir.
  final bool quotaExhausted;

  /// Kota hatasının kullanıcıya gösterilecek mesajı.
  final String? quotaMessage;

  int get cardCount => cards.length;
  int get processedPages => totalPages - failedPages.length;

  /// Modele gerçekten gönderilen sayfa sayısı (ön-filtrede elenenler ve
  /// hataya düşenler hariç) — [emptyResultPages] oranının DOĞRU paydası.
  /// Toplam sayfaya bölmek yanıltıcı olurdu: modele hiç gitmemiş sayfalar
  /// "kart üretmeye değmez bulundu" sayılamaz.
  int get billedPages =>
      totalPages - emptyTextPages.length - failedPages.length;
}

/// Sayfa bazında, sınırlı paralellikle kart üreten pipeline.
///
/// - Her sayfa AYRI çağrı (tüm PDF tek prompt'a doldurulmaz → kapsam korunur).
/// - Aynı anda en fazla [concurrency] sayfa işlenir (kota/hız dengesi).
/// - Her worker, bir sayfayı bitirince sıradakini almadan önce
///   [interPageDelay] kadar bekler (sağlayıcıyı aralıksız istekle zorlamamak
///   için throttle; kota erken çıkışını geciktirmez).
/// - Bir sayfa hata verirse [maxRetriesPerPage] kez yeniden denenir; yine
///   olmazsa o sayfa işaretlenir ama tüm işlem çökmez. İKİ İSTİSNA hiç
///   denenmez: kota (tüm işlemi durdurur) ve zaman aşımı (yalnızca o sayfa
///   atlanır — üretim faturalanmış olabileceği için tekrar ödememek adına,
///   bkz. [FlashcardGenerationException.isTimeout]).
/// - İlerleme ve üretilen kartlar geri-çağrılarla anlık bildirilir (streaming).
class PdfCardPipeline {
  PdfCardPipeline({
    this.concurrency = 4,
    this.maxRetriesPerPage = 2,
    this.retryDelay = const Duration(seconds: 1),
    this.interPageDelay = kInterPageDelay,
  });

  final int concurrency;
  final int maxRetriesPerPage;
  final Duration retryDelay;

  /// Sayfalar arası throttle — bkz. [kInterPageDelay]. Kota durdurmasını
  /// GECİKTİRMEZ (bekleme yalnızca kota vurulmamışsa ve alınacak sayfa
  /// kaldıysa yapılır).
  final Duration interPageDelay;

  Future<PipelineResult> run(
    List<PdfPage> pages, {
    required PageGenerator generate,
    void Function(int completed, int total)? onProgress,
    void Function(List<Flashcard> cards)? onCards,
  }) async {
    final total = pages.length;
    final allCards = <Flashcard>[];
    final emptyText = <int>[];
    final emptyResult = <int>[];
    final failed = <int>[];
    var completed = 0;

    // Kota (429) yakalanırsa: kalan sayfaları denemeyi bırak; tükenmiş kotayı
    // 100 sayfa boyunca tekrar tekrar yemek anlamsız ve yavaş.
    var quotaHit = false;
    String? quotaMessage;

    void bump() => onProgress?.call(++completed, total);

    // Metinsiz VE görüntüsü de render edilemeyen sayfaları işaretle (anında
    // ilerlet); kalanları işle. Normalde her sayfa render edilmiş bir
    // görüntüyle gelir (bkz. pdf_extract.js) — bu dal yalnızca gerçekten boş
    // sayfa ya da görüntü render hatası gibi nadir durumlarda tetiklenir.
    final workPages = <PdfPage>[];
    for (final p in pages) {
      if (p.hasExtractableText || p.hasImage) {
        workPages.add(p);
      } else {
        emptyText.add(p.page);
        bump();
      }
    }

    var next = 0;
    Future<void> worker() async {
      while (true) {
        // Kota tükendiyse yeni sayfaya başlama; erken çık.
        if (quotaHit) return;
        // await öncesi seçim atomiktir (tek iş parçacığı) → yarış yok.
        if (next >= workPages.length) return;
        final page = workPages[next++];

        try {
          final produced = await _generateWithRetry(page, generate);
          // sourcePage zaten dolu ise (AI slaytın kendi numarasını okuyup
          // döndürdüyse, bkz. flashcard_prompt.dart slaytNumarasiKurali)
          // ONU KORU — kapak/boş sayfa kaymasını düzelten değer bu. Boşsa
          // (okunamadıysa) fiziksel sayfa sırasına (page.page) düş.
          final stamped = [
            for (final c in produced)
              c.sourcePage != null ? c : c.copyWith(sourcePage: page.page),
          ];
          allCards.addAll(stamped);
          if (stamped.isNotEmpty) {
            onCards?.call(stamped);
          } else {
            // Modele gitti, faturalandı, `[]` döndü. HATA DEĞİL — kuralın
            // beklediği davranış (kapak/ajanda/kapanış slaytı vb.). Ama
            // ölçülebilsin diye ayrı kaydediliyor; failedPages'e YAZMA.
            emptyResult.add(page.page);
            debugPrint(
              '[PIPELINE s.${page.page}] model boş dizi döndürdü '
              '(kart üretmeye değmez bulundu)',
            );
          }
        } on FlashcardGenerationException catch (e) {
          failed.add(page.page);
          // SEBEP LOGU: failedPages yalnızca sayfa numarası taşıyor; sebep
          // burada son kez elimizde — atmadan önce konsola yaz (teşhis için,
          // bkz. "10 sayfa işlenemedi ama neden bilinmiyor" vakası).
          debugPrint(
            '[PIPELINE s.${page.page}] işlenemedi: ${e.message} '
            '(quota=${e.isQuota}, timeout=${e.isTimeout})',
          );
          // 429: tüm işlemi durdur, kullanıcıya net mesajla dön.
          if (e.isQuota) {
            quotaHit = true;
            quotaMessage = e.message;
          }
        } catch (e) {
          failed.add(page.page);
          debugPrint('[PIPELINE s.${page.page}] beklenmedik hata: $e');
        } finally {
          bump();
        }

        // THROTTLE: sıradaki sayfayı almadan önce kısa bekleme — 4 worker'ın
        // sağlayıcıya aralıksız istek yağdırmasını yumuşatmak için. Kota
        // vurulduysa ya da alınacak sayfa kalmadıysa HİÇ beklenmez (döngü
        // başındaki erken çıkışlar gecikmesin).
        if (!quotaHit &&
            next < workPages.length &&
            interPageDelay > Duration.zero) {
          await Future<void>.delayed(interPageDelay);
        }
      }
    }

    if (workPages.isNotEmpty) {
      final count = concurrency.clamp(1, workPages.length);
      await Future.wait([for (var i = 0; i < count; i++) worker()]);
    }

    emptyText.sort();
    emptyResult.sort();
    failed.sort();
    allCards.sort((a, b) => (a.sourcePage ?? 0).compareTo(b.sourcePage ?? 0));

    return PipelineResult(
      totalPages: total,
      cards: allCards,
      emptyTextPages: emptyText,
      emptyResultPages: emptyResult,
      failedPages: failed,
      quotaExhausted: quotaHit,
      quotaMessage: quotaMessage,
    );
  }

  Future<List<Flashcard>> _generateWithRetry(
    PdfPage page,
    PageGenerator generate,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await generate(page);
      } on FlashcardGenerationException catch (e) {
        // Kota hatasını sayfa düzeyinde tekrar denemek anlamsız (HTTP katmanı
        // zaten üstel backoff'la denedi) — hemen yukarı ver ki pipeline dursun.
        if (e.isQuota) rethrow;
        // Zaman aşımını da TEKRAR DENEME — ama farklı sebeple: sağlayıcı
        // üretimi tamamlayıp faturalamış olabilir, yeniden denemek aynı sayfa
        // için ikinci/üçüncü kez ödemek demek. Yukarı verilir, çağıran (run)
        // bunu kota-DIŞI hata olarak görüp yalnızca o sayfayı failedPages'e
        // yazar; diğer sayfalar işlenmeye devam eder.
        if (e.isTimeout) rethrow;
        if (attempt >= maxRetriesPerPage) rethrow;
        debugPrint(
          '[PIPELINE s.${page.page}] deneme ${attempt + 1}/'
          '${maxRetriesPerPage + 1} başarısız (${e.message}) — '
          'deneme ${attempt + 2} yapılacak',
        );
        if (retryDelay > Duration.zero) await Future.delayed(retryDelay);
      } catch (e) {
        if (attempt >= maxRetriesPerPage) rethrow;
        debugPrint(
          '[PIPELINE s.${page.page}] deneme ${attempt + 1}/'
          '${maxRetriesPerPage + 1} beklenmedik hatayla başarısız ($e) — '
          'deneme ${attempt + 2} yapılacak',
        );
        if (retryDelay > Duration.zero) await Future.delayed(retryDelay);
      }
    }
  }
}
