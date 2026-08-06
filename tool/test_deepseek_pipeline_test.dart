// Test-only script (flutter_test harness gerekiyor — plugin FFI kodu ham
// `dart run`'da derleme hatası veriyor): DeepSeekService + PdfCardPipeline'ı
// GERÇEK ağ istekleriyle 40 sentetik sayfa üzerinden uçtan uca koşturur.
// Uygulama koduna dahil değil — /tool klasörü, kalıcı test suite'inin parçası
// değil.
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/pdf_page.dart';
import 'package:medcard/services/deepseek_service.dart';
import 'package:medcard/services/pdf_card_pipeline.dart';

final topics = <String, List<String>>{
  'Kalp Kapaklari': [
    'Mitral kapak sol atriyum ile sol ventrikul arasinda yer alir ve iki yaprakcigi vardir.',
    'Trikuspid kapak sag atriyum ile sag ventrikul arasindadir ve uc yaprakcigi vardir.',
    'Aort kapagi sol ventrikul ile aort arasinda yer alir, uc yariay (semilunar) yaprakciktan olusur.',
    'Normal mitral kapak alani 4-6 cm2 dir; 2 cm2 altina inmesi mitral stenoz olarak kabul edilir.',
  ],
  'Kranial Sinirler': [
    'Olfaktor sinir (I. kranial sinir) koku alma duyusunu tasir, tek bası duyusal bir sinirdir.',
    'Fasiyal sinir (VII. kranial sinir) hasar gordugunde ayni taraf yuz kaslarinda felç gorulur.',
    'Trigeminal sinir (V. kranial sinir) yuz bolgesinin duyusunu ve cigneme kaslarini kontrol eder.',
    'Vagus siniri (X. kranial sinir) parasempatik innervasyonun buyuk kismindan sorumludur.',
  ],
  'Elektrolit Dengesi': [
    'Normal serum sodyum degeri 135-145 mEq/L arasindadir.',
    'Hipokalemi genellikle 3.5 mEq/L altindaki potasyum degerleri icin kullanilir.',
    'Hiperkalsemi böbrek taslari, kabizlik ve bilinc bulanikligina yol acabilir.',
    'Magnezyum eksikliginde hem hipokalemi hem hipokalsemi gorulebilir cunku PTH salinimi bozulur.',
  ],
  'Solunum Fizyolojisi': [
    'Normal solunum sayisi eriskinde dakikada 12-20 arasindadir.',
    'FEV1/FVC orani 0.7 altinda ise obstruktif akciger hastaligi dusunulur.',
    'Hipoksik pulmoner vazokonstriksiyon, iyi havalanmayan alveollerdeki kan akimini azaltir.',
    'Diyafragma en onemli solunum kasidir, frenik sinir (C3-C5) tarafindan innerve edilir.',
  ],
};

void main() {
  test('DeepSeek: 40 sayfalık PDF pipeline uçtan uca (gerçek API)', () async {
    dotenv.loadFromString(envString: File('.env').readAsStringSync());

    final entries = topics.entries.toList();
    final pages = <PdfPage>[
      for (var i = 1; i <= 40; i++)
        PdfPage(
          page: i,
          text: '${entries[(i - 1) % entries.length].key}:\n'
              '${entries[(i - 1) % entries.length].value.map((f) => '- $f').join('\n')}',
        ),
    ];

    final service = DeepSeekService();
    final pipeline = PdfCardPipeline(concurrency: 5);

    final sw = Stopwatch()..start();
    final result = await pipeline.run(
      pages,
      generate: (p) => service.generateForPage(
        p.text,
        p.page,
        imageBase64: p.imageBase64,
        imageMimeType: p.imageMimeType,
      ),
      onProgress: (done, total) => stdout.write('\rİlerleme: $done/$total'),
    );
    sw.stop();

    print('\n--- SONUÇ ---');
    print('Toplam sayfa: ${result.totalPages}');
    print('İşlenen sayfa: ${result.processedPages}');
    print('Üretilen kart: ${result.cardCount}');
    print('Boş metin sayfası: ${result.emptyTextPages}');
    print('Başarısız sayfa: ${result.failedPages}');
    print('Kota tükendi mi: ${result.quotaExhausted} ${result.quotaMessage ?? ''}');
    print('Süre: ${sw.elapsed}');

    expect(result.quotaExhausted, isFalse);
    expect(result.cardCount, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
