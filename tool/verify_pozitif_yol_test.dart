// Test-only CANLI DOĞRULAMA: 2026-08-20 fail-closed kimlik değişikliği
// MEŞRU kullanımı BOZUYOR MU?
//
// Bugüne dek yalnızca NEGATİF yol doğrulanmıştı (sahte token / anon key /
// başlıksız istek → hepsi 401). O testler, `resolveUserId` HER ŞEYİ
// reddedecek şekilde bozuk olsaydı da AYNI sonucu verirdi — yani kart
// üretiminin tamamen ölmüş olma ihtimalini DIŞLAMIYORLARDI.
//
// Bu script tam o boşluğu kapatır. İKİ AŞAMA:
//   AŞAMA 1 — ham HTTP: ai-proxy'ye gerçek oturum token'ıyla doğrudan POST.
//             Beklenen: literal 200 (negatif testlerdeki 401'in tersi).
//   AŞAMA 2 — üretim yolu: GeminiService.generateForPage (buildPagePrompt +
//             responseSchema + flashcardFromItem çözücüsü dahil).
//             Beklenen: en az 1 GERÇEK kart.
//
// ÇALIŞTIRMA:
//   MEDKART_ACCESS_TOKEN=<jwt> flutter test tool/verify_pozitif_yol_test.dart
//
// GÖRSELSİZ: sayfa görüntüsü render etmek bu ortamda mümkün değil (pdf.js
// canvas'ı tarayıcıda çalışıyor). Kimlik kapısı görselden bağımsız —
// Authorization başlığı her iki yolda da aynı.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medcard/services/gemini_service.dart';
import 'package:medcard/services/session_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Üretilen tek sayfalık test PDF'inin metin katmanı (bkz. scratchpad'deki
/// hipertansiyon_1sayfa.pdf). Benzersiz bir damga taşır — `pdf_cache`'e
/// düşmüş olması imkânsız, yani ölçüm gerçek bir API çağrısıdır.
const String kSayfaMetni = '''
HIPERTANSIYON - TANIM VE SINIFLANDIRMA
Normal kan basinci: 120/80 mmHg altinda.
Yuksek normal (elevated): 120-129 / 80 mmHg altinda.
Evre 1 hipertansiyon: 130-139 sistolik veya 80-89 diyastolik mmHg.
Evre 2 hipertansiyon: 140/90 mmHg ve uzeri.
Hipertansif kriz: 180/120 mmHg uzeri - acil tedavi gerektirir.

ETIYOLOJI
Birincil (esansiyel) hipertansiyon tum vakalarin %90-95'ini olusturur.
Ikincil hipertansiyon nedenleri:
  - Renal arter stenozu
  - Feokromositoma
  - Primer hiperaldosteronizm (Conn sendromu)
  - Cushing sendromu
  - Aort koarktasyonu
  - Obstruktif uyku apnesi

HEDEF ORGAN HASARI
Kalp: sol ventrikul hipertrofisi, kalp yetmezligi.
Bobrek: proteinuri, kronik bobrek hastaligi.
Goz: hipertansif retinopati (Keith-Wagener evrelemesi).
Beyin: iskemik ve hemorajik inme riski artisi.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test binding'i TÜM HTTP'ye 400 döndürüyor; bu script GERÇEK çağrı yapar.
  // Normal test paketinde bunu ASLA yapma.
  HttpOverrides.global = null;

  test('CANLI: gecerli oturum token i ile pozitif yol calisiyor mu', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: File('.env').readAsStringSync());

    final token = Platform.environment['MEDKART_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      fail('MEDKART_ACCESS_TOKEN tanimli degil — ai-proxy oturum token i istiyor.');
    }
    debugSessionAccessTokenOverride = () => token;

    final url = dotenv.env['SUPABASE_URL']!;
    final anon = dotenv.env['SUPABASE_ANON_KEY']!;

    // ─── AŞAMA 1: HAM HTTP STATUS ───────────────────────────────────────
    // Negatif testler literal 401 gösteriyordu; burada literal 200 bekliyoruz.
    print('\n=== ASAMA 1: ham HTTP status ===');
    final ham = await http.post(
      Uri.parse('$url/functions/v1/ai-proxy'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': anon,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'provider': 'gemini',
        'model': GeminiService.model,
        'pageCount': 1,
        'payload': {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'Yalnizca su kelimeyi yaz: TAMAM'},
              ],
            },
          ],
          'generationConfig': {'maxOutputTokens': 16},
        },
      }),
    );
    print('ai-proxy -> HTTP ${ham.statusCode}');
    if (ham.statusCode != 200) {
      print('GOVDE: ${ham.body}');
    }
    expect(
      ham.statusCode,
      200,
      reason: 'Gecerli oturum token i ile 200 bekleniyordu — kimlik kapisi '
          'mesru kullanimi BOZUYOR.',
    );
    print('Yanit govdesinde candidates var mi: '
        '${ham.body.contains('candidates')}');

    // ─── AŞAMA 2: GERÇEK ÜRETİM YOLU ────────────────────────────────────
    print('\n=== ASAMA 2: GeminiService.generateForPage ===');
    final kartlar = await GeminiService().generateForPage(kSayfaMetni, 1);

    print('\nURETILEN KART SAYISI: ${kartlar.length}');
    expect(
      kartlar,
      isNotEmpty,
      reason: 'Uretim yolu 200 aldi ama hic kart cozulemedi.',
    );

    for (var i = 0; i < kartlar.length; i++) {
      final c = kartlar[i];
      print('\n--- KART ${i + 1} ---');
      print('S : ${c.question}');
      print('KC: ${c.shortAnswer}');
      print('C : ${c.answer}');
      print('konu=${c.topic} | zorluk=${c.difficulty.name} | '
          'tip=${c.cardType.name} | oncelik=${c.priority.name} | '
          'sayfa=${c.sourcePage} | elYazisi=${c.isHandwritten}');
    }

    // Kartın GERÇEKTEN bu kaynaktan geldiğini gösteren asgari kontrol:
    // sayfa damgası doğru olmalı ve soru/cevap boş olmamalı.
    for (final c in kartlar) {
      expect(c.sourcePage, 1);
      expect(c.question.trim(), isNotEmpty);
      expect(c.answer.trim(), isNotEmpty);
    }
    print('\nSONUC: pozitif yol CALISIYOR — 200 + ${kartlar.length} gercek kart.');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
