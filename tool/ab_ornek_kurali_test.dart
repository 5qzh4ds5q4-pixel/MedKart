// Test-only A/B ölçüm script'i: v30'da eklenen [prompt.ornekTabanliKartKurali]
// gerçekten "aynı bilgiyi iki kez soran" kart fazlalığı üretiyor mu?
// Uygulama koduna dahil DEĞİL (`tool/` altında, pakete girmez).
//
// NEDEN GEREKTİ: 2026-08-18 raporunda önbellekteki çalıştırmalarda aynı
// `kisaCevap`'ı paylaşan kart oranı v23'te %1,7 iken v30'da %19,5 çıktı. Ama
// bu KONTROLLÜ bir karşılaştırma değildi — farklı PDF'ler, farklı konu. Bu
// script tek değişkeni izole eder: AYNI PDF, AYNI sayfalar, AYNI model,
// AYNI generationConfig; tek fark prompt'ta o kural bloğunun VAR/YOK olması.
//
// ARM A ("v28-eşdeğeri"): buildPagePrompt çıktısından ornekTabanliKartKurali
//   bloğu string olarak ÇIKARILIR. Kalan metin v28'deki ile aynıdır (v29
//   yayınlanmadı, v30'un TEK içerik farkı bu bloktur).
// ARM B ("v30"): prompt olduğu gibi.
//
// GÖRSELSİZ: sayfa görüntüsü render etmek bu ortamda mümkün değil (pdf.js
// canvas'ı tarayıcıda çalışıyor). İKİ ARM DA görselsiz olduğu için
// karşılaştırma geçerli kalır, ama üretim varsayılanı görselli olduğundan
// mutlak sayılar üretimle birebir DEĞİLDİR — raporlarken bunu yaz.
//
// TEKRAR: temperature 0.4, yani çıktı deterministik değil. Her arm 2 kez
// koşturulur ki tek çalıştırmalık gürültü ile gerçek etki ayrışabilsin.
//
// ÇALIŞTIRMA:  flutter test tool/ab_ornek_kurali_test.dart
// GİRDİ:  scratchpad/ab/pages.json  (extract.mjs üretir — web/pdf_extract.js
//         ile AYNI birleştirme mantığı: items.map(str).join(' '))
// ÇIKTI:  scratchpad/ab/ab_sonuc.json
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
    r'\b3bc412d-393c-4680-b15d-6fd6b9835e0c\scratchpad\ab';

/// Kaç sayfa ve kaç tekrar. Maliyet = sayfa x arm(2) x tekrar.
const int kSayfaSayisi = 10;
const int kTekrar = 2;

/// Boş bırakılırsa metni en uzun [kSayfaSayisi] sayfa seçilir.
///
/// DOLU BIRAKMAK GENELDE DOĞRUSU: ilk turda "metni en uzun sayfalar"
/// seçilmişti ve sonuç YANILTICI çıktı — o sayfalar üretimin kendi v30
/// çalıştırmasında da yalnızca %3,5 fazlalık gösteriyordu, yani ölçülmek
/// istenen olgu ORADA HİÇ YOKTU. Fazlalık, üretimde diğer 36 sayfada
/// yoğunlaşıyor (%21,1). Buraya, üretimde GERÇEKTEN fazlalık üretmiş ve
/// metni çıkarılabilen sayfaları yaz.
const List<int> kSecilenSayfalar = [8, 9, 12, 14, 19, 22, 24, 26, 31, 43];

/// Metni en uzun [kSayfaSayisi] sayfayı seçer (kapak/boş sayfalar ölçümü
/// seyreltmesin diye). Sayfa numarasına göre sıralı döner.
List<Map<String, dynamic>> _sayfalariSec(List<dynamic> ham) {
  if (kSecilenSayfalar.isNotEmpty) {
    final harita = {
      for (final p in ham) p['page'] as int: p['text'] as String,
    };
    return [
      for (final no in kSecilenSayfalar)
        if (harita[no] case final t?) {'page': no, 'text': t},
    ];
  }
  final dolu = [
    for (final p in ham)
      if ((p['text'] as String).trim().length > 300)
        {'page': p['page'] as int, 'text': p['text'] as String},
  ];
  dolu.sort(
    (a, b) => (b['text'] as String).length.compareTo((a['text'] as String).length),
  );
  final secilen = dolu.take(kSayfaSayisi).toList()
    ..sort((a, b) => (a['page'] as int).compareTo(b['page'] as int));
  return secilen;
}

/// Arm A için: prompt'tan kural bloğunu çıkarır.
String _kuralsiz(String tamPrompt) {
  final blok = '${prompt.ornekTabanliKartKurali}\n\n';
  if (!tamPrompt.contains(blok)) {
    throw StateError(
      'ornekTabanliKartKurali prompt icinde bulunamadi — script eskimis '
      'olabilir, arm A gecersiz olurdu.',
    );
  }
  return tamPrompt.replaceFirst(blok, '');
}

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

  test('A/B: ornekTabanliKartKurali kart fazlaligi uretiyor mu', () async {
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

    final ham = jsonDecode(File('$_scratch/pages.json').readAsStringSync());
    final sayfalar = _sayfalariSec(ham as List<dynamic>);

    print('=== KURULUM ===');
    print('Sayfalar: ${sayfalar.map((s) => s['page']).join(", ")}');
    print('Arm sayisi: 2 (A=kuralsiz/v28-esdeger, B=v30) x $kTekrar tekrar');
    print('Toplam cagri: ${sayfalar.length * 2 * kTekrar}');

    // ÖN KOŞUL: iki armin prompt'u SADECE o blok kadar farkli olmali.
    final ornek = prompt.buildPagePrompt(
      sayfalar.first['text'] as String,
      sayfalar.first['page'] as int,
      hasImage: false,
    );
    final ornekA = _kuralsiz(ornek);
    final fark = ornek.length - ornekA.length;
    print('Prompt farki: $fark karakter '
        '(kural bloğu ${prompt.ornekTabanliKartKurali.length} + 2 satir sonu)');
    expect(fark, prompt.ornekTabanliKartKurali.length + 2);

    final sonuclar = <Map<String, dynamic>>[];

    for (var tekrar = 1; tekrar <= kTekrar; tekrar++) {
      for (final arm in ['A_kuralsiz', 'B_v30']) {
        print('\n=== ARM $arm — tekrar $tekrar ===');
        for (final s in sayfalar) {
          final sayfaNo = s['page'] as int;
          final tam = prompt.buildPagePrompt(
            s['text'] as String,
            sayfaNo,
            hasImage: false,
          );
          final kartlar = await _cagir(
            arm == 'B_v30' ? tam : _kuralsiz(tam),
            sayfaNo,
          );
          print('  s.$sayfaNo -> ${kartlar.length} kart');
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
      '$_scratch/ab_sonuc.json',
    ).writeAsStringSync(jsonEncode(sonuclar));
    print('\nYAZILDI: $_scratch/ab_sonuc.json');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
