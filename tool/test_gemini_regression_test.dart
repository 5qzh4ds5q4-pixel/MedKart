// Test-only script: gemini_service.dart refactor'ının (flashcard_prompt.dart
// paylaşımı) davranışı bozmadığını doğrular — 3 sayfalık gerçek GeminiService
// çağrısı. Uygulama koduna dahil değil.
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/pdf_page.dart';
import 'package:medcard/services/gemini_service.dart';
import 'package:medcard/services/session_token.dart';
import 'package:medcard/services/pdf_card_pipeline.dart';

void main() {
  test('Gemini regresyon: 3 sayfalık PDF pipeline (gerçek API)', () async {
    dotenv.loadFromString(envString: File('.env').readAsStringSync());
    // 2026-08-20: ai-proxy dogrulanmis oturum token i istiyor (fail-closed).
    // Gercek Supabase oturumu burada yok — token disaridan verilir:
    //   MEDKART_ACCESS_TOKEN=<jwt> flutter test <bu dosya>
    final token = Platform.environment['MEDKART_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      fail('MEDKART_ACCESS_TOKEN tanimli degil — ai-proxy oturum token i istiyor.');
    }
    debugSessionAccessTokenOverride = () => token;

    final pages = <PdfPage>[
      const PdfPage(
        page: 1,
        text: 'Mitral kapak sol atriyum ile sol ventrikul arasinda yer alir ve iki '
            'yaprakcigi vardir. Trikuspid kapak sag atriyum ile sag ventrikul '
            'arasindadir ve uc yaprakcigi vardir.',
      ),
      const PdfPage(
        page: 2,
        text: 'Normal mitral kapak alani 4-6 cm2 dir; 2 cm2 altina inmesi mitral '
            'stenoz olarak kabul edilir. Aort kapagi sol ventrikul ile aort '
            'arasinda yer alir, uc yariay (semilunar) yaprakciktan olusur.',
      ),
      const PdfPage(
        page: 3,
        text: 'Normal serum sodyum degeri 135-145 mEq/L arasindadir. Hipokalemi '
            'genellikle 3.5 mEq/L altindaki potasyum degerleri icin kullanilir.',
      ),
    ];

    final service = GeminiService();
    final pipeline = PdfCardPipeline();

    final result = await pipeline.run(
      pages,
      generate: (p) => service.generateForPage(
        p.text,
        p.page,
        imageBase64: p.imageBase64,
        imageMimeType: p.imageMimeType,
      ),
      onProgress: (done, total) => print('İlerleme: $done/$total'),
    );

    print('--- SONUÇ ---');
    print('Toplam sayfa: ${result.totalPages}');
    print('İşlenen sayfa: ${result.processedPages}');
    print('Üretilen kart: ${result.cardCount}');
    print('Başarısız sayfa: ${result.failedPages}');
    print('Kota tükendi mi: ${result.quotaExhausted} ${result.quotaMessage ?? ''}');
    for (final c in result.cards) {
      print('  s.${c.sourcePage} [${c.difficulty.name}/${c.cardType.name}] '
          '${c.question} => ${c.answer} (kısa: ${c.shortAnswer})');
    }

    expect(result.quotaExhausted, isFalse);
    expect(result.failedPages, isEmpty);
    expect(result.cardCount, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
