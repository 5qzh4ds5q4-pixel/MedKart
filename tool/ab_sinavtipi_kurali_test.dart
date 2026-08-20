// Test-only A/B ölçüm script'i: [prompt.sinavTipiKurali] prompt'tan
// ÇIKARILDIĞINDA üretilen "zor" etiketli kart oranı ne oluyor?
// Uygulama koduna dahil DEĞİL (`tool/` altında, pakete girmez).
// `tool/ab_ornek_kurali_test.dart` deseniyle yazıldı.
//
// NEDEN GEREKTİ: TUS eklentisi mimarisinde komite (ücretsiz) modundan
// sinavTipiKurali TAMAMEN çıkarılacak. 2026-08-19 ölçümü `zor ⊂ sinav`
// (%100 kapsanma, 733 kartta 0 istisna) gösterdi ve zorlukKurali'nin tek
// BAĞIMSIZ dalı olan "formül/sayısal hesap" 733 kartta HİÇ tetiklenmemişti.
// Buradan "sinavTipiKurali çıkınca zor ≈ 0 olur" TAHMİN ediliyordu — ama
// model kuralları bağımsız uyguluyor, bu hiç ÖLÇÜLMEDİ. Bu script tek
// değişkeni izole eder: AYNI PDF, AYNI sayfalar, AYNI model, AYNI
// generationConfig; tek fark prompt'ta o bloğun VAR/YOK olması.
//
// ÜÇ ARM (üçüncüsü bilinçli — bkz. aşağıdaki not):
//   A_sinavsiz  : sinavTipiKurali ÇIKARILDI. Kullanıcının sorduğu tam soru.
//   B_v30       : prompt olduğu gibi (bugünkü üretim).
//   C_komiteModu: sinavTipiKurali + icerikKalitesiOrnegi ÇIKARILDI.
// C NEDEN VAR: icerikKalitesiOrnegi (v25) kendi başına bir VİNYET örneği
// içeriyor ("40 yaşında çiftçi... Brucella") ve "klinik/patolojik ilişki
// varsa HER ZAMAN güçlü kart formatını tercih et" diyor. Yalnızca
// sinavTipiKurali çıkarılırsa bu blok vinyet üretmeye devam edebilir —
// yani arm A, gerçek "komite modu"nu temsil etmeyebilir. C bunu ölçer.
//
// GÖRSELSİZ: sayfa görüntüsü render etmek bu ortamda mümkün değil (pdf.js
// canvas'ı tarayıcıda çalışıyor). ÜÇ ARM DA görselsiz olduğu için
// karşılaştırma geçerli kalır, ama üretim varsayılanı görselli olduğundan
// mutlak sayılar üretimle birebir DEĞİLDİR — raporlarken bunu yaz.
//
// TEKRAR: temperature 0.4, yani çıktı deterministik değil. Her arm
// [kTekrar] kez koşturulur ki tek çalıştırmalık gürültü ile gerçek etki
// ayrışabilsin.
//
// ⚠️ ÖRNEKLEM SEÇİMİ — BU SCRIPT'İN EN KRİTİK PARÇASI:
// [kSecilenSayfalar] rastgele ya da "metni en uzun" değil, ÜRETİM KANITINA
// göre seçildi. `pdf_cache`'teki gerçek çalıştırma (hash 68144c37…, v23)
// sayfa sayfa çözümlendi ve yalnızca ZATEN "zor"/vinyet kart üretmiş VE
// metni yeterli (>=300 krkt) sayfalar alındı. Seçilen 10 sayfa üretimde
// %19,7 zor üretmişti; PDF geneli %8,0 — olgu bu örneklemde 2,5 kat yoğun.
// Bu, ornekTabanliKartKurali A/B'sinin ilk turunda yapılan hatanın (olgunun
// HİÇ olmadığı sayfalardan örneklem alıp "fark yok" sonucuna varmak)
// tekrarlanmaması için zorunlu. Sayfa listesini değiştireceksen aynı
// kanıt zincirini yeniden kur.
//
// AYRICA ELENDİ: üretimde en çok vinyet üreten sayfalar (s.37 vin=10,
// s.31 vin=8, s.35 vin=6, s.39 vin=6) metinsiz çıktı (2-62 karakter) —
// içerikleri GÖRSELDE. Görselsiz bir ölçümde bunları seçmek, iki arma da
// boş sayfa göndermek olurdu; yani aynı tuzağın ters yüzü.
//
// ÇALIŞTIRMA:  flutter test tool/ab_sinavtipi_kurali_test.dart
// GİRDİ:  <scratch>/bulasici_pages.json  (extract.mjs üretir — web/
//         pdf_extract.js ile AYNI birleştirme: items.map(str).join(' '))
// ÇIKTI:  <scratch>/ab_sinavtipi_sonuc.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/flashcard_prompt.dart' as prompt;
import 'package:medcard/services/gemini_service.dart';
import 'package:medcard/services/session_token.dart';
import 'package:medcard/services/gemini_transport.dart';
import 'package:medcard/services/usage_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scratch =
    r'C:\Users\Admin\AppData\Local\Temp\claude'
    r'\C--Users-Admin-Documents-GitHub-MedKart'
    r'\fde41f7c-032e-4b59-8b1d-726b17745c50\scratchpad\ab';

/// Kaç tekrar. Maliyet = sayfa(10) x arm(3) x tekrar.
const int kTekrar = 2;

/// ÜRETİM KANITIYLA seçildi — bkz. dosya başındaki uyarı. Değiştirme.
const List<int> kSecilenSayfalar = [4, 5, 14, 17, 22, 24, 27, 28, 36, 40];

const String kArmA = 'A_sinavsiz';
const String kArmB = 'B_v30';
const String kArmC = 'C_komiteModu';

List<Map<String, dynamic>> _sayfalariSec(List<dynamic> ham) {
  final harita = {for (final p in ham) p['page'] as int: p['text'] as String};
  return [
    for (final no in kSecilenSayfalar)
      if (harita[no] case final t?) {'page': no, 'text': t},
  ];
}

/// Verilen kural bloğunu prompt'tan çıkarır. Bulunamazsa FIRLATIR — sessizce
/// "değişmemiş prompt" göndermek armı geçersiz kılar ve ölçüm yalan söyler.
String _blogunuCikar(String tamPrompt, String blok, String ad) {
  final hedef = '$blok\n\n';
  if (!tamPrompt.contains(hedef)) {
    throw StateError(
      '$ad prompt icinde bulunamadi — script eskimis olabilir, arm gecersiz.',
    );
  }
  return tamPrompt.replaceFirst(hedef, '');
}

String _armPrompt(String tam, String arm) => switch (arm) {
  kArmB => tam,
  kArmA => _blogunuCikar(tam, prompt.sinavTipiKurali, 'sinavTipiKurali'),
  kArmC => _blogunuCikar(
    _blogunuCikar(tam, prompt.sinavTipiKurali, 'sinavTipiKurali'),
    prompt.icerikKalitesiOrnegi,
    'icerikKalitesiOrnegi',
  ),
  _ => throw StateError('bilinmeyen arm: $arm'),
};

Future<List<Flashcard>> _cagir(String promptMetni, int sayfaNo) async {
  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': promptMetni},
        ],
      },
    ],
    // GeminiService.generateForPage ile BİREBİR aynı config.
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': prompt.responseSchema,
      'temperature': 0.4,
      'maxOutputTokens': GeminiService.maxOutputTokens,
      'thinkingConfig': {'thinkingBudget': 0},
    },
  });

  final response = await GeminiTransport().send(
    model: GeminiService.model,
    body: body,
  );
  if (response.statusCode != 200) {
    print('  !! s.$sayfaNo HTTP ${response.statusCode}');
    return const [];
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) return const [];
  logUsageMetadata(decoded, 's.$sayfaNo');

  final candidates = decoded['candidates'];
  if (candidates is! List || candidates.isEmpty) return const [];
  final parts = (candidates.first as Map)['content']?['parts'];
  if (parts is! List || parts.isEmpty) return const [];
  final text = (parts.first as Map)['text'];
  if (text is! String) return const [];

  final items = jsonDecode(text);
  if (items is! List) return const [];
  final kartlar = <Flashcard>[];
  for (var i = 0; i < items.length; i++) {
    final c = prompt.flashcardFromItem(
      items[i],
      id: 'ab-$sayfaNo-$i',
      sourcePage: sayfaNo,
    );
    if (c != null) kartlar.add(c);
  }
  return kartlar;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test binding'i TÜM HTTP'ye 400 döndürüyor; bu script'in amacı GERÇEK
  // çağrı yapmak. Normal test paketinde bunu ASLA yapma.
  HttpOverrides.global = null;

  test('A/B: sinavTipiKurali cikinca zor orani ne oluyor', () async {
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

    final ham = jsonDecode(
      File('$_scratch/bulasici_pages.json').readAsStringSync(),
    );
    final sayfalar = _sayfalariSec(ham as List<dynamic>);
    const armlar = [kArmA, kArmB, kArmC];

    print('=== KURULUM ===');
    print('Sayfalar: ${sayfalar.map((s) => s['page']).join(", ")}');
    print('Armlar: ${armlar.join(", ")} x $kTekrar tekrar');
    print('Toplam cagri: ${sayfalar.length * armlar.length * kTekrar}');

    // ÖN KOŞUL: her armin prompt'u SADECE ilgili blok(lar) kadar farkli olmali.
    final ornek = prompt.buildPagePrompt(
      sayfalar.first['text'] as String,
      sayfalar.first['page'] as int,
      hasImage: false,
    );
    final farkA = ornek.length - _armPrompt(ornek, kArmA).length;
    final farkC = ornek.length - _armPrompt(ornek, kArmC).length;
    print('Prompt farki A: $farkA krkt (sinavTipiKurali '
        '${prompt.sinavTipiKurali.length} + 2)');
    print('Prompt farki C: $farkC krkt (+ icerikKalitesiOrnegi '
        '${prompt.icerikKalitesiOrnegi.length} + 2)');
    expect(farkA, prompt.sinavTipiKurali.length + 2);
    expect(
      farkC,
      prompt.sinavTipiKurali.length + prompt.icerikKalitesiOrnegi.length + 4,
    );

    final sonuclar = <Map<String, dynamic>>[];

    for (var tekrar = 1; tekrar <= kTekrar; tekrar++) {
      for (final arm in armlar) {
        print('\n=== ARM $arm — tekrar $tekrar ===');
        for (final s in sayfalar) {
          final sayfaNo = s['page'] as int;
          final tam = prompt.buildPagePrompt(
            s['text'] as String,
            sayfaNo,
            hasImage: false,
          );
          final kartlar = await _cagir(_armPrompt(tam, arm), sayfaNo);
          final zor = kartlar
              .where((c) => c.difficulty == CardDifficulty.zor)
              .length;
          print('  s.$sayfaNo -> ${kartlar.length} kart ($zor zor)');
          sonuclar.add({
            'arm': arm,
            'tekrar': tekrar,
            'page': sayfaNo,
            'cards': [
              for (final c in kartlar)
                {
                  'question': c.question,
                  'shortAnswer': c.shortAnswer,
                  'cardType': c.cardType.name,
                  'priority': c.priority.name,
                  'difficulty': c.difficulty.name,
                  'topic': c.topic,
                },
            ],
          });
        }
      }
    }

    File(
      '$_scratch/ab_sinavtipi_sonuc.json',
    ).writeAsStringSync(jsonEncode(sonuclar));
    print('\nYAZILDI: $_scratch/ab_sinavtipi_sonuc.json');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
