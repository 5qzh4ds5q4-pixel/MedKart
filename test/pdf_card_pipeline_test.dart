import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/models/pdf_page.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/pdf_card_pipeline.dart';

PdfPage _page(int n, {String? text, String? imageBase64}) => PdfPage(
  page: n,
  text: text ?? 'Sayfa $n için yeterince uzun ders metni.',
  imageBase64: imageBase64,
);

Flashcard _card(String id) =>
    Flashcard(id: id, question: 'S-$id', answer: 'C-$id');

void main() {
  // interPageDelay: Duration.zero — üretimdeki sayfalar-arası throttle
  // (kInterPageDelay) test paketini yavaşlatmasın diye tüm testlerde sıfır.
  final pipeline = PdfCardPipeline(
    retryDelay: Duration.zero,
    interPageDelay: Duration.zero,
  );

  test('her sayfadan kart üretir, sourcePage damgalar, ilerleme tamamlanır', () async {
    final progress = <int>[];
    final result = await pipeline.run(
      [_page(1), _page(2), _page(3)],
      generate: (p) async => [_card('${p.page}a'), _card('${p.page}b')],
      onProgress: (done, total) => progress.add(done),
    );

    expect(result.totalPages, 3);
    expect(result.cardCount, 6);
    // Her kart doğru kaynak sayfayı taşır.
    expect(result.cards.every((c) => c.sourcePage != null), isTrue);
    expect(result.cards.map((c) => c.sourcePage).toSet(), {1, 2, 3});
    // İlerleme 3'e ulaşır.
    expect(progress.last, 3);
    expect(result.failedPages, isEmpty);
  });

  test(
    'üretici bir kartın sourcePage\'ini zaten doldurduysa (AI slaytın kendi '
    'numarasını okuduysa) pipeline onu EZMEZ — kapak/boş sayfa kayması '
    'düzeltmesi korunur',
    () async {
      final result = await pipeline.run(
        [_page(27)],
        // AI, fiziksel sayfa 27'nin slayt üzerinde "24" yazdığını okudu.
        generate: (p) async => [
          Flashcard(
            id: 'x',
            question: 'S',
            answer: 'C',
            sourcePage: 24,
          ),
        ],
      );

      expect(result.cards.single.sourcePage, 24);
    },
  );

  test('metinsiz sayfa üreticiye gitmez ama işaretlenir', () async {
    final sentPages = <int>[];
    final result = await pipeline.run(
      [_page(1), _page(2, text: ''), _page(3, text: 'kısa')],
      generate: (p) async {
        sentPages.add(p.page);
        return [_card('${p.page}')];
      },
    );

    // Sadece 1. sayfa üreticiye gitti (2 boş, 3 çok kısa).
    expect(sentPages, [1]);
    expect(result.emptyTextPages, [2, 3]);
    expect(result.cardCount, 1);
    expect(result.totalPages, 3);
  });

  test('sürekli hata veren sayfa retry sonrası failedPages olur, diğerleri başarır', () async {
    var page2Calls = 0;
    final result = await pipeline.run(
      [_page(1), _page(2), _page(3)],
      generate: (p) async {
        if (p.page == 2) {
          page2Calls++;
          throw Exception('geçici hata');
        }
        return [_card('${p.page}')];
      },
    );

    // 1 ilk deneme + 2 retry = 3 çağrı.
    expect(page2Calls, 3);
    expect(result.failedPages, [2]);
    expect(result.processedPages, 2);
    expect(result.cards.map((c) => c.sourcePage).toSet(), {1, 3});
  });

  test('geçici hatadan sonra retry başarır', () async {
    var calls = 0;
    final result = await pipeline.run(
      [_page(1)],
      generate: (p) async {
        calls++;
        if (calls == 1) throw Exception('ilk deneme patladı');
        return [_card('ok')];
      },
    );

    expect(calls, 2);
    expect(result.failedPages, isEmpty);
    expect(result.cardCount, 1);
  });

  test('eşzamanlılık sınırı aşılmaz', () async {
    final limited = PdfCardPipeline(
      concurrency: 2,
      retryDelay: Duration.zero,
      interPageDelay: Duration.zero,
    );
    var active = 0;
    var peak = 0;

    await limited.run(
      [for (var i = 1; i <= 6; i++) _page(i)],
      generate: (p) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        active--;
        return [_card('${p.page}')];
      },
    );

    expect(peak, lessThanOrEqualTo(2));
    expect(peak, greaterThan(1)); // gerçekten paralel çalıştı
  });

  test('kota (429) hatası işlemi durdurur ve quotaExhausted işaretlenir', () async {
    var calls = 0;
    final result = await pipeline.run(
      [for (var i = 1; i <= 10; i++) _page(i)],
      generate: (p) async {
        calls++;
        throw const FlashcardGenerationException(
          'Gemini kota sınırına takıldın.',
          isQuota: true,
        );
      },
    );

    expect(result.quotaExhausted, isTrue);
    expect(result.quotaMessage, contains('kota'));
    // Kota hatası sayfa düzeyinde tekrar DENENMEZ (concurrency=4 → ilk dalga
    // kadar çağrı, 10 sayfanın tamamı değil).
    expect(calls, lessThanOrEqualTo(4));
    expect(result.cardCount, 0);
  });

  test('kotadan önce üretilen kartlar korunur', () async {
    final pipeline1 = PdfCardPipeline(
      concurrency: 1,
      retryDelay: Duration.zero,
      interPageDelay: Duration.zero,
    );
    var calls = 0;
    final result = await pipeline1.run(
      [_page(1), _page(2), _page(3)],
      generate: (p) async {
        calls++;
        if (p.page == 1) return [_card('1')];
        throw const FlashcardGenerationException('kota', isQuota: true);
      },
    );

    // 1. sayfa başarılı, 2. sayfada kota → 3. sayfaya hiç geçilmez.
    expect(calls, 2);
    expect(result.cardCount, 1);
    expect(result.quotaExhausted, isTrue);
  });

  group('zaman aşımı (isTimeout) — çift faturalanmayı önler', () {
    test('zaman aşımına uğrayan sayfa TEKRAR DENENMEZ', () async {
      var calls = 0;
      final result = await pipeline.run(
        [_page(1)],
        generate: (p) async {
          calls++;
          throw const FlashcardGenerationException(
            'Sunucudan yanıt gelmedi.',
            isTimeout: true,
          );
        },
      );

      // Kritik: 3 değil 1. Gemini üretimi tamamlayıp faturalamış olabilir,
      // yeniden denemek aynı sayfayı 2. ve 3. kez ödemek olurdu.
      expect(calls, 1);
      expect(result.failedPages, [1]);
    });

    test('zaman aşımı tüm işlemi durdurmaz, diğer sayfalar işlenir', () async {
      final result = await pipeline.run(
        [_page(1), _page(2), _page(3)],
        generate: (p) async {
          if (p.page == 2) {
            throw const FlashcardGenerationException(
              'Sunucudan yanıt gelmedi.',
              isTimeout: true,
            );
          }
          return [_card('${p.page}')];
        },
      );

      // Kotanın AKSİNE: yalnızca o sayfa atlanır (kısmi başarı akışı).
      expect(result.quotaExhausted, isFalse);
      expect(result.failedPages, [2]);
      expect(result.cards.map((c) => c.sourcePage).toSet(), {1, 3});
      expect(result.processedPages, 2);
    });

    test('zaman aşımı OLMAYAN hata hâlâ yeniden denenir', () async {
      var calls = 0;
      await pipeline.run(
        [_page(1)],
        generate: (p) async {
          calls++;
          throw const FlashcardGenerationException(
            'geçici',
            isTimeout: false,
          );
        },
      );

      // Mevcut davranış korunuyor: 1 ilk deneme + 2 retry.
      expect(calls, 3);
    });
  });

  test('kota-DIŞI hata pipeline\'ı durdurmaz, sadece o sayfa işaretlenir', () async {
    final result = await pipeline.run(
      [_page(1), _page(2)],
      generate: (p) async {
        if (p.page == 1) {
          throw const FlashcardGenerationException('geçici', isQuota: false);
        }
        return [_card('${p.page}')];
      },
    );

    expect(result.quotaExhausted, isFalse);
    expect(result.failedPages, [1]);
    expect(result.cardCount, 1);
  });

  test(
    'metni zayıf ama görsel yedeği olan sayfa (renkli tablo) ATLANMAZ, üreticiye gider',
    () async {
      final sentPages = <int>[];
      final result = await pipeline.run(
        [
          _page(1, text: ''), // gerçekten boş, görsel de yok → atlanır
          _page(2, text: '31', imageBase64: 'aGVsbG8='), // sayfa 31 gibi: neredeyse boş metin ama görsel var
        ],
        generate: (p) async {
          sentPages.add(p.page);
          return [_card('${p.page}')];
        },
      );

      expect(sentPages, [2]);
      expect(result.emptyTextPages, [1]);
      expect(result.cardCount, 1);
    },
  );

  test('kartlar üretildikçe akıtılır (streaming)', () async {
    final streamed = <int>[];
    await pipeline.run(
      [_page(1), _page(2)],
      generate: (p) async => [_card('${p.page}')],
      onCards: (cards) => streamed.add(cards.length),
    );

    // İki sayfa → iki akış olayı, her biri 1 kart.
    expect(streamed, [1, 1]);
  });

  group('emptyResultPages (modele gitti, [] döndü)', () {
    test(
      "boş dizi dönen sayfa emptyResultPages'e girer; failedPages ve "
      "emptyTextPages'e KARIŞMAZ",
      () async {
        final result = await pipeline.run(
          [_page(1), _page(2), _page(3)],
          // s.2 modele gider ama "test edilecek bilgi yok" der.
          generate: (p) async => p.page == 2 ? <Flashcard>[] : [_card('${p.page}a')],
        );

        expect(result.emptyResultPages, [2]);
        expect(result.failedPages, isEmpty, reason: 'boş dizi bir HATA değil');
        expect(
          result.emptyTextPages,
          isEmpty,
          reason: 's.2 modele GİTTİ, ön-filtrede elenmedi',
        );
        expect(result.cardCount, 2);
      },
    );

    test('boş dizi dönen sayfa için onCards çağrılmaz', () async {
      final batches = <int>[];
      await pipeline.run(
        [_page(1), _page(2)],
        generate: (p) async => p.page == 2 ? <Flashcard>[] : [_card('a')],
        onCards: (cards) => batches.add(cards.length),
      );

      expect(batches, [1]);
    });

    test("modele HİÇ gitmeyen sayfa emptyResultPages'e GİRMEZ", () async {
      final result = await pipeline.run(
        // Metni de görüntüsü de olmayan sayfa ön-filtrede elenir.
        [_page(1), _page(2, text: '')],
        generate: (p) async => [_card('a')],
      );

      expect(result.emptyTextPages, [2]);
      expect(
        result.emptyResultPages,
        isEmpty,
        reason: 'faturalanmayan sayfa "kart üretmeye değmez bulundu" sayılamaz',
      );
    });

    test(
      'billedPages boş dizi oranının paydası: ön-filtre ve hata düşülür',
      () async {
        final result = await pipeline.run(
          [_page(1), _page(2), _page(3, text: ''), _page(4)],
          generate: (p) async {
            if (p.page == 1) throw const FlashcardGenerationException('bozuk');
            if (p.page == 2) return <Flashcard>[];
            return [_card('a')];
          },
        );

        expect(result.totalPages, 4);
        expect(result.failedPages, [1]);
        expect(result.emptyTextPages, [3]);
        expect(result.emptyResultPages, [2]);
        // Modele gerçekten gidip sonuç dönen: s.2 ve s.4.
        expect(result.billedPages, 2);
      },
    );

    test('sonuç listesi sıralı gelir', () async {
      final result = await pipeline.run(
        [for (var i = 1; i <= 5; i++) _page(i)],
        generate: (p) async =>
            p.page.isEven ? <Flashcard>[] : [_card('${p.page}')],
      );

      expect(result.emptyResultPages, [2, 4]);
    });
  });
}
