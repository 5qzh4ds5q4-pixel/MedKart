// Test-only CANLI DOĞRULAMA script'i: prompt v31 (zorlukKurali kaldırıldı)
// gerçek üretim yolunda beklendiği gibi davranıyor mu?
// Uygulama koduna dahil DEĞİL (`tool/` altında, pakete girmez).
//
// A/B script'lerinden FARKI: burada prompt elle kurulmuyor. Doğrudan
// [GeminiService.generateForPage] çağrılıyor — yani üretimin KENDİ yolu
// (buildPagePrompt + responseSchema + flashcardFromItem çözücüsü dahil).
// Amaç tam olarak bu: "prompt'ta ne yazıyor" değil, "üretim ne üretiyor".
//
// ÜÇ SORU:
//   1. Tüm kartların zorluk kodu gerçekten "o" (orta) mu geliyor?
//   2. sinavTipiKurali HÂLÂ çalışıyor mu (vinyet/sinav kartlar üretiliyor mu)?
//      — bu kural v31'de KALDIRILMADI, kontrol amaçlı bakılıyor.
//   3. (Kod tarafında) kart listesi zorluk çipleri ne gösterecek?
//
// SAYFA SEÇİMİ: klinik/patolojik içerik taşıdığı ÜRETİM KANITIYLA bilinen
// sayfalar (bkz. tool/ab_sinavtipi_kurali_test.dart'taki seçim zinciri).
// s.27 en çok vinyet üreten metin-dolu sayfa, s.14 formül sayfası, s.4 ise
// düz tanım sayfası (kontrast için: burada vinyet BEKLENMİYOR).
//
// GÖRSELSİZ: sayfa görüntüsü render etmek bu ortamda mümkün değil (pdf.js
// canvas'ı tarayıcıda çalışıyor). Bu, zorluk/kartTipi etiketlerini
// etkilemez — ikisi de görselden bağımsız kurallardan geliyor.
//
// ÇALIŞTIRMA:  flutter test tool/verify_v31_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/flashcard_prompt.dart' as prompt;
import 'package:medcard/services/gemini_service.dart';
import 'package:medcard/services/session_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scratch =
    r'C:\Users\Admin\AppData\Local\Temp\claude'
    r'\C--Users-Admin-Documents-GitHub-MedKart'
    r'\fde41f7c-032e-4b59-8b1d-726b17745c50\scratchpad\ab';

/// Klinik yoğunluğu üretim kanıtıyla bilinen sayfalar + bir kontrast sayfası.
const List<int> kSayfalar = [4, 14, 17, 24, 27, 28];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test binding'i TÜM HTTP'ye 400 döndürüyor; bu script GERÇEK çağrı yapar.
  // Normal test paketinde bunu ASLA yapma.
  HttpOverrides.global = null;

  test('CANLI: v31 uretimde zorluk hep orta mi, sinav tipi duruyor mu', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: File('.env').readAsStringSync());
    // 2026-08-20: ai-proxy dogrulanmis oturum token i istiyor (fail-closed).
    // Gercek Supabase oturumu burada yok — token disaridan verilir:
    //   MEDKART_ACCESS_TOKEN=<jwt> flutter test <bu dosya>
    final token = Platform.environment['MEDKART_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      fail('MEDKART_ACCESS_TOKEN tanimli degil — ai-proxy oturum token i istiyor.');
    }
    debugSessionAccessTokenOverride = () => token;

    final ham =
        jsonDecode(File('$_scratch/bulasici_pages.json').readAsStringSync())
            as List<dynamic>;
    final metin = {for (final p in ham) p['page'] as int: p['text'] as String};

    // ÖN KOŞUL: gerçekten v31 prompt'unu test ettiğimizi doğrula.
    expect(prompt.kPromptVersion, 'v31');
    final ornekPrompt = prompt.buildPagePrompt('x', 1, hasImage: false);
    expect(
      ornekPrompt.contains('ZORLUK KALİBRASYONU'),
      isFalse,
      reason: 'zorlukKurali hâlâ prompt icinde — script yanlis surumu olcuyor',
    );
    expect(
      ornekPrompt.contains('SINAV TİPİ KART'),
      isTrue,
      reason: 'sinavTipiKurali kaybolmus — v31 kapsamini asmis olmali',
    );
    print('ON KOSUL OK: ${prompt.kPromptVersion}, zorlukKurali YOK, '
        'sinavTipiKurali VAR');

    final service = GeminiService();
    final hepsi = <Flashcard>[];
    final sayfaOzet = <String>[];

    for (final no in kSayfalar) {
      final kartlar = await service.generateForPage(metin[no]!, no);
      hepsi.addAll(kartlar);
      final zor = kartlar.where((c) => c.difficulty == CardDifficulty.zor).length;
      final kolay =
          kartlar.where((c) => c.difficulty == CardDifficulty.kolay).length;
      final sinav = kartlar.where((c) => c.isExamType).length;
      sayfaOzet.add('  s.$no -> ${kartlar.length} kart | '
          'kolay=$kolay orta=${kartlar.length - kolay - zor} zor=$zor | '
          'sinav=$sinav');
    }

    print('\n=== SAYFA BAZINDA ===');
    sayfaOzet.forEach(print);

    final kolay =
        hepsi.where((c) => c.difficulty == CardDifficulty.kolay).toList();
    final zor = hepsi.where((c) => c.difficulty == CardDifficulty.zor).toList();
    final orta = hepsi.where((c) => c.difficulty == CardDifficulty.orta).length;
    final sinav = hepsi.where((c) => c.isExamType).toList();

    print('\n=== TOPLAM (${hepsi.length} kart) ===');
    print('SORU 1 — zorluk: kolay=${kolay.length} orta=$orta zor=${zor.length}');
    print('SORU 2 — kartTipi: sinav=${sinav.length} '
        'temel=${hepsi.length - sinav.length}');

    if (sinav.isNotEmpty) {
      print('\nSinav tipi kart ornekleri (ilk 3):');
      for (final c in sinav.take(3)) {
        print('  s.${c.sourcePage}: '
            '${c.question.replaceAll(RegExp(r"\s+"), " ")}');
      }
    }
    for (final c in [...kolay, ...zor]) {
      print('!! BEKLENMEYEN ${c.difficulty.name}: s.${c.sourcePage} '
          '${c.question.replaceAll(RegExp(r"\s+"), " ")}');
    }

    // Ham çıktı, elle incelemek için.
    File('$_scratch/v31_dogrulama.json').writeAsStringSync(
      jsonEncode([
        for (final c in hepsi)
          {
            'page': c.sourcePage,
            'question': c.question,
            'shortAnswer': c.shortAnswer,
            'difficulty': c.difficulty.name,
            'cardType': c.cardType.name,
            'priority': c.priority.name,
            'topic': c.topic,
          },
      ]),
    );

    expect(hepsi, isNotEmpty, reason: 'hic kart uretilmedi — cagri basarisiz?');
    expect(
      kolay.length + zor.length,
      0,
      reason: 'v31 tum kartlari orta bekliyor; kolay/zor cikti',
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
