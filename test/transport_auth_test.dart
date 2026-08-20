import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/services/deepseek_transport.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/gemini_transport.dart';
import 'package:medcard/services/glm_transport.dart';
import 'package:medcard/services/session_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `ai-proxy` KİMLİK sözleşmesi — ÜÇ TRANSPORT İÇİN BİREBİR AYNI (2026-08-20).
///
/// Sunucu artık `Authorization` başlığındaki oturum token'ını doğruluyor ve
/// çözemezse isteği HİÇBİR sağlayıcıya göndermeden 401 döndürüyor
/// (FAIL-CLOSED, bkz. `supabase/functions/ai-proxy/index.ts`). İstemci
/// tarafında karşılığı: anon key DEĞİL, kullanıcı access token'ı gönderilmeli.
///
/// BU DOSYA NEDEN TEK VE ORTAK: üç transport'un davranışı ayrışırsa, o
/// sağlayıcının TÜM istekleri sessizce 401'e düşer. Aynı testleri üçüne birden
/// koşturmak, birine token eklenip diğerine unutulmasını yakalar.
void main() {
  setUp(() {
    dotenv.loadFromString(
      envString:
          'SUPABASE_URL=https://test.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => debugSessionAccessTokenOverride = null);

  /// Üç transport'u tek bir imza altında toplar: `send` çağrısı + adı.
  final transports = <String, Future<http.Response> Function(http.Client)>{
    'gemini': (c) => GeminiTransport(client: c, retryBackoff: Duration.zero)
        .send(model: 'test-model', body: jsonEncode({'x': 1})),
    'deepseek': (c) => DeepSeekTransport(client: c, retryBackoff: Duration.zero)
        .send(body: jsonEncode({'x': 1})),
    'glm': (c) => GlmTransport(client: c, retryBackoff: Duration.zero)
        .send(body: jsonEncode({'x': 1})),
  };

  for (final entry in transports.entries) {
    final name = entry.key;
    final send = entry.value;

    group('$name transport — kimlik sözleşmesi', () {
      test('geçerli oturum → Authorization kullanıcı token\'ını taşır', () async {
        debugSessionAccessTokenOverride = () => 'user-jwt-123';
        http.Request? captured;
        final client = MockClient((req) async {
          captured = req;
          return http.Response('{"ok":true}', 200);
        });

        final response = await send(client);

        expect(response.statusCode, 200);
        // Authorization = KULLANICI token'ı (anon key DEĞİL).
        expect(captured!.headers['Authorization'], 'Bearer user-jwt-123');
        expect(
          captured!.headers['Authorization'],
          isNot(contains('test-anon-key')),
          reason: 'anon key gonderilirse sunucu 401 doner (sub claim yok)',
        );
        // apikey ise anon key OLARAK KALIR — Supabase gateway'i için gerekli.
        expect(captured!.headers['apikey'], 'test-anon-key');
      });

      test('oturum yok → ağa HİÇ çıkmadan fırlatır', () async {
        debugSessionAccessTokenOverride = () => null;
        var istekAtildi = false;
        final client = MockClient((req) async {
          istekAtildi = true;
          return http.Response('{"ok":true}', 200);
        });

        await expectLater(
          send(client),
          throwsA(
            isA<FlashcardGenerationException>().having(
              (e) => e.message,
              'message',
              contains('giriş'),
            ),
          ),
        );
        // EN KRİTİK BEKLENTİ: sunucuya kimliksiz istek GİTMEMELİ.
        expect(istekAtildi, isFalse);
      });

      test('boş token da "oturum yok" sayılır', () async {
        debugSessionAccessTokenOverride = () => '';
        var istekAtildi = false;
        final client = MockClient((req) async {
          istekAtildi = true;
          return http.Response('{"ok":true}', 200);
        });

        await expectLater(send(client), throwsA(isA<FlashcardGenerationException>()));
        expect(istekAtildi, isFalse);
      });

      test('sunucu 401 dönerse (token geçersiz/süresi dolmuş) hata yüzeye çıkar',
          () async {
        debugSessionAccessTokenOverride = () => 'expired-jwt';
        var deneme = 0;
        final client = MockClient((req) async {
          deneme++;
          // NOT: `http.Response` gövdeyi content-type'ta charset yoksa
          // LATIN1 ile kodlar; Türkçe karakter (ş/ğ/ı) taşıyan bir gövde
          // testin kendisini patlatır. Gerçek sunucu utf-8 gönderiyor.
          return http.Response(
            jsonEncode({'error': 'Giris yapman gerekiyor.'}),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        // 401 sunucudan gelen bir CEVAP: transport onu yutmamalı.
        final response = await send(client);
        expect(response.statusCode, 401);
        // 401 geçici bir hata DEĞİL — yeniden denenmemeli (5xx/429'un aksine).
        expect(
          deneme,
          1,
          reason: '401 yeniden denenirse gecersiz token bosuna 4 kez gonderilir',
        );
      });
    });
  }

  test('üç transport da AYNI kimlik davranışını gösterir (regresyon kilidi)', () {
    // Bu dosyadaki grupların üçü de aynı testleri koşuyor; bu test yalnızca
    // kapsamın daralmadığını (biri silinmediğini) sabitler.
    expect(transports.keys, containsAll(['gemini', 'deepseek', 'glm']));
  });
}
