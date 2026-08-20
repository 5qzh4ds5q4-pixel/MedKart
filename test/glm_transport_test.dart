import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/glm_transport.dart';
import 'package:medcard/services/session_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [GlmTransport] DeepSeek'in transport desenini izler ama ÜÇ güvenlik
/// farkıyla kuruldu; bu dosya o üçünü ve mevcut retry davranışının korunduğunu
/// doğrular. Hiçbir test gerçek ağa çıkmaz (MockClient).
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

  GlmTransport transportWith(MockClient client) => GlmTransport(
    client: client,
    retryBackoff: Duration.zero,
    // Testte gerçekten zaman aşımına düşebilmek için kısa süre.
    requestTimeout: const Duration(milliseconds: 50),
  );

  group('güvenlik sabitleri', () {
    test('maxOutputTokens 4096 (DeepSeek\'in 8192\'si DEĞİL)', () {
      expect(GlmTransport.maxOutputTokens, 4096);
    });

    test('üretimde zaman aşımı 120 saniye', () {
      expect(GlmTransport.defaultRequestTimeout, const Duration(seconds: 120));
    });

    test('geçici hatalarda toplam 4 deneme', () {
      expect(GlmTransport.maxAttempts, 4);
    });
  });

  group('zaman aşımı retry\'dan ayrı', () {
    test('yanıt gecikirse isTimeout işaretli hata fırlatır', () async {
      final transport = transportWith(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        transport.send(body: '{"model":"z-ai/glm-4.5v"}'),
        throwsA(
          isA<FlashcardGenerationException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue)
              // Kota DEĞİL: tüm işlemi durdurmamalı, yalnızca o sayfayı atlamalı.
              .having((e) => e.isQuota, 'isQuota', isFalse),
        ),
      );
    });

    test('zaman aşımında YENİDEN DENEMEZ (tek istek atılır)', () async {
      var calls = 0;
      final transport = transportWith(
        MockClient((_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        transport.send(body: '{"model":"z-ai/glm-4.5v"}'),
        throwsA(isA<FlashcardGenerationException>()),
      );

      // maxAttempts=4 zaman aşımını KAPSAMAZ — üretim faturalanmış olabilir.
      expect(calls, 1);
    });

    test('TimeoutException doğrudan gelirse de aynı dala düşer', () async {
      final transport = transportWith(
        MockClient((_) async => throw TimeoutException('istemci zaman aşımı')),
      );

      await expectLater(
        transport.send(body: '{"model":"z-ai/glm-4.5v"}'),
        throwsA(
          isA<FlashcardGenerationException>().having(
            (e) => e.isTimeout,
            'isTimeout',
            isTrue,
          ),
        ),
      );
    });
  });

  group('geçici hatalar hâlâ yeniden denenir', () {
    test('5xx maxAttempts kez denenir', () async {
      var calls = 0;
      final transport = transportWith(
        MockClient((_) async {
          calls++;
          // Gövde ASCII: http.Response'un String kurucusu content-type
          // başlığı yokken latin1 varsayar.
          return http.Response(
            '{"error":{"message":"gecici sunucu hatasi"}}',
            503,
          );
        }),
      );

      final response = await transport.send(body: '{"model":"z-ai/glm-4.5v"}');

      expect(calls, GlmTransport.maxAttempts);
      expect(response.statusCode, 503);
    });

    test('429 da geçici sayılır ve yeniden denenir', () async {
      var calls = 0;
      final transport = transportWith(
        MockClient((_) async {
          calls++;
          return http.Response('{"error":{"message":"rate limit"}}', 429);
        }),
      );

      final response = await transport.send(body: '{"model":"z-ai/glm-4.5v"}');

      expect(calls, GlmTransport.maxAttempts);
      expect(response.statusCode, 429);
    });

    test('ağ hatası (bağlantı yok) zaman aşımı olarak işaretlenmez', () async {
      final transport = transportWith(
        MockClient((_) async => throw http.ClientException('bağlantı koptu')),
      );

      await expectLater(
        transport.send(body: '{"model":"z-ai/glm-4.5v"}'),
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
  });

  group('ai-proxy zarfı', () {
    test('provider "glm" gönderir, model zarfa KONULMAZ', () async {
      Map<String, dynamic>? envelope;
      final transport = GlmTransport(
        client: MockClient((req) async {
          envelope = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
        retryBackoff: Duration.zero,
      );

      await transport.send(body: '{"model":"z-ai/glm-4.5v","messages":[]}');

      expect(envelope!['provider'], 'glm');
      // Model adı OpenRouter'da payload'ın içindedir; Gemini'deki gibi zarfa
      // ayrıca yazılmaz (orada URL path'inde kullanılıyordu).
      expect(envelope!.containsKey('model'), isFalse);
      expect(
        (envelope!['payload'] as Map)['model'],
        'z-ai/glm-4.5v',
      );
      expect(envelope!['pageCount'], 1);
      expect(envelope!['deviceId'], isA<String>());
    });

    test('istek ai-proxy adresine gider: Authorization=oturum, apikey=anon',
        () async {
      Uri? calledUri;
      Map<String, String>? headers;
      final transport = GlmTransport(
        client: MockClient((req) async {
          calledUri = req.url;
          headers = req.headers;
          return http.Response('{}', 200);
        }),
        retryBackoff: Duration.zero,
      );

      await transport.send(body: '{"model":"z-ai/glm-4.5v"}');

      expect(
        calledUri.toString(),
        'https://test.supabase.co/functions/v1/ai-proxy',
      );
      // 2026-08-20: Authorization artık KULLANICI oturum token'ı — anon key
      // gönderilirse sunucu 401 döner (anon JWT'sinde `sub` claim'i yok).
      expect(headers!['Authorization'], 'Bearer test-access-token');
      // apikey anon key OLARAK KALIR: Supabase gateway'i için gerekli.
      expect(headers!['apikey'], 'test-anon-key');
    });
  });
}
