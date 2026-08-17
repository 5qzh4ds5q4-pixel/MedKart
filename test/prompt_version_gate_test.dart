import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:medcard/services/flashcard_prompt.dart';
import 'package:medcard/services/pdf_cache_service.dart';

/// `pdf_cache` bayatlık kapısı (2026-08-17).
///
/// Sunucu tarafı (`supabase/functions/pdf-cache/index.ts`) bu depoda test
/// edilemiyor (Deno); buradaki testler İSTEMCİ sözleşmesini ve sürüm
/// karşılaştırma mantığını koruyor.
void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'SUPABASE_URL=https://ornek.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
  });

  group('promptVersionNumber', () {
    test('"v27" -> 27', () => expect(promptVersionNumber('v27'), 27));
    test('"v9" -> 9', () => expect(promptVersionNumber('v9'), 9));
    test('"v100" -> 100', () => expect(promptVersionNumber('v100'), 100));
    test('boşluklu değer kırpılır', () {
      expect(promptVersionNumber(' v28 '), 28);
    });
    test('null -> null', () => expect(promptVersionNumber(null), isNull));
    test('sürümsüz/bozuk -> null', () {
      expect(promptVersionNumber(''), isNull);
      expect(promptVersionNumber('28'), isNull);
      expect(promptVersionNumber('v28-beta'), isNull);
      expect(promptVersionNumber('sürüm yok'), isNull);
    });
  });

  group('isCacheablePromptVersion', () {
    test('eşiğin ALTINDAKİ sürümler reddedilir', () {
      // Canlı önbellekte 2026-08-17'de bulunan gerçek değerler.
      expect(isCacheablePromptVersion('v16'), isFalse);
      expect(isCacheablePromptVersion('v23'), isFalse);
      expect(isCacheablePromptVersion('v24'), isFalse);
      // v26 HATALI sürümdü (güncellik dili tavsiyesini yanlışlıkla
      // kaldırmıştı) — kabul EDİLMEMELİ.
      expect(isCacheablePromptVersion('v26'), isFalse);
    });

    test('eşik ve üstü kabul edilir', () {
      expect(isCacheablePromptVersion('v27'), isTrue);
      expect(isCacheablePromptVersion('v28'), isTrue);
      expect(isCacheablePromptVersion('v999'), isTrue);
    });

    test('SÜRÜMSÜZ kayıt asla kabul edilmez', () {
      // Canlı önbellekteki 3 kayıt böyle (sürüm sütunları sonradan eklendi).
      expect(isCacheablePromptVersion(null), isFalse);
      expect(isCacheablePromptVersion(''), isFalse);
    });

    test('güncel kPromptVersion her zaman kabul edilebilir olmalı', () {
      // Eşik yanlışlıkla kPromptVersion'ın ÜSTÜNE çıkarılırsa hiçbir yeni
      // kayıt bile isabet saymaz — önbellek tamamen ölür.
      expect(
        isCacheablePromptVersion(kPromptVersion),
        isTrue,
        reason:
            'kMinCacheablePromptVersion ($kMinCacheablePromptVersion) '
            'kPromptVersion ($kPromptVersion) değerini aşmış olabilir',
      );
    });
  });

  group('PdfCacheService.lookup — eşiği sunucuya gönderir', () {
    test('istek gövdesinde min_prompt_version var', () async {
      Map<String, dynamic>? capturedBody;
      final service = PdfCacheService(
        client: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'found': false}), 200);
        }),
      );

      await service.lookup('abc123');

      expect(capturedBody, isNotNull);
      expect(capturedBody!['action'], 'lookup');
      expect(capturedBody!['hash'], 'abc123');
      expect(
        capturedBody!['min_prompt_version'],
        'v$kMinCacheablePromptVersion',
      );
    });

    test('sunucu bayat diye found:false derse null döner (miss gibi)', () async {
      final service = PdfCacheService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'found': false,
              'cards': null,
              'hit_count': null,
              'stale': true,
              'stored_prompt_version': 'v16',
            }),
            200,
          ),
        ),
      );

      expect(await service.lookup('abc123'), isNull);
    });
  });

  group('save — sürüm gönderiliyor (sunucunun ezme kararı buna dayanıyor)', () {
    test('promptVersion gövdeye konur', () async {
      Map<String, dynamic>? capturedBody;
      final service = PdfCacheService(
        client: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await service.save(
        'abc123',
        const [],
        modelVersion: 'gemini-3.5-flash',
        promptVersion: kPromptVersion,
      );

      expect(capturedBody!['prompt_version'], kPromptVersion);
      expect(capturedBody!['model_version'], 'gemini-3.5-flash');
    });
  });
}
