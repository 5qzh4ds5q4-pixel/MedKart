import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/gemini_transport.dart';
import 'package:medcard/services/session_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zaman aşımının 5xx/429'dan AYRI ele alındığını doğrular.
///
/// Neden önemli: zaman aşımı "istek başarısız" demek değil — Gemini üretimi
/// tamamlayıp FATURALAMIŞ olabilir. Bu yüzden zaman aşımı ne HTTP katmanında
/// (backoff'lu tekrar) ne de pipeline katmanında yeniden denenmemeli; aksi
/// halde tek sayfa için 2-3 kez ödenir.
void main() {
  setUp(() {
    dotenv.loadFromString(
      envString:
          'SUPABASE_URL=https://test.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
    SharedPreferences.setMockInitialValues({});
    // Transport artık Authorization'a kullanıcı oturum token'ı koyuyor ve
    // token yoksa ağa çıkmadan fırlatıyor (bkz. SessionToken).
    debugSessionAccessTokenOverride = () => 'test-access-token';
  });

  tearDown(() => debugSessionAccessTokenOverride = null);

  GeminiTransport transportWith(MockClient client) => GeminiTransport(
    client: client,
    retryBackoff: Duration.zero,
    // Testte gerçekten zaman aşımına düşebilmek için kısa süre.
    requestTimeout: const Duration(milliseconds: 50),
  );

  test('üretimde zaman aşımı 120 saniye', () {
    expect(GeminiTransport.defaultRequestTimeout, const Duration(seconds: 120));
  });

  test('yanıt gecikirse isTimeout işaretli hata fırlatır', () async {
    final transport = transportWith(
      MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      transport.send(model: 'gemini-3.5-flash', body: '{"contents":[]}'),
      throwsA(
        isA<FlashcardGenerationException>()
            .having((e) => e.isTimeout, 'isTimeout', isTrue)
            // Kota DEĞİL: tüm işlemi durdurmamalı, yalnızca o sayfayı atlamalı.
            .having((e) => e.isQuota, 'isQuota', isFalse),
      ),
    );
  });

  test('zaman aşımında HTTP katmanı YENİDEN DENEMEZ (tek istek atılır)', () async {
    var calls = 0;
    final transport = transportWith(
      MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      transport.send(model: 'gemini-3.5-flash', body: '{"contents":[]}'),
      throwsA(isA<FlashcardGenerationException>()),
    );

    // maxAttempts=4 zaman aşımını KAPSAMAZ — üretim faturalanmış olabilir.
    expect(calls, 1);
  });

  test('5xx hâlâ yeniden denenir ve isTimeout işaretlenmez', () async {
    var calls = 0;
    final transport = transportWith(
      MockClient((_) async {
        calls++;
        // Gövde ASCII: http.Response'un String kurucusu content-type
        // başlığı yokken latin1 varsayar, Türkçe karakter encode hatası verir.
        return http.Response('{"error":{"message":"gecici sunucu hatasi"}}', 503);
      }),
    );

    final response = await transport.send(
      model: 'gemini-3.5-flash',
      body: '{"contents":[]}',
    );

    // Geçici sunucu hatasında davranış DEĞİŞMEDİ: 1 ilk deneme + 3 tekrar.
    expect(calls, GeminiTransport.maxAttempts);
    expect(response.statusCode, 503);
  });

  test('ağ hatası (bağlantı yok) zaman aşımı olarak işaretlenmez', () async {
    final transport = transportWith(
      MockClient((_) async => throw http.ClientException('bağlantı koptu')),
    );

    await expectLater(
      transport.send(model: 'gemini-3.5-flash', body: '{"contents":[]}'),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.isTimeout,
          'isTimeout',
          // Bağlantı hiç kurulamadı → üretim yapılmadı → tekrar denenebilir.
          isFalse,
        ),
      ),
    );
  });

  test('TimeoutException doğrudan gelirse de aynı dala düşer', () async {
    // İstemcinin kendi katmanından (ör. tarayıcı) gelen zaman aşımı.
    final transport = transportWith(
      MockClient((_) async => throw TimeoutException('istemci zaman aşımı')),
    );

    await expectLater(
      transport.send(model: 'gemini-3.5-flash', body: '{"contents":[]}'),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.isTimeout,
          'isTimeout',
          isTrue,
        ),
      ),
    );
  });
}
