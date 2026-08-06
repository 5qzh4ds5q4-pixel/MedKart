import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/pdf_cache_service.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString:
          'SUPABASE_URL=https://test.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
  });

  group('PdfCacheService.hashBytes', () {
    test('bilinen SHA-256 test vektörüyle eşleşir (boş içerik)', () {
      expect(
        PdfCacheService.hashBytes(Uint8List(0)),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('aynı bayt dizisi her zaman aynı hash\'i üretir', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(PdfCacheService.hashBytes(bytes), PdfCacheService.hashBytes(bytes));
    });

    test('farklı içerik farklı hash üretir', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 4]);
      expect(PdfCacheService.hashBytes(a), isNot(PdfCacheService.hashBytes(b)));
    });

    group('includeImages (görsel açık/kapalı cache rafı ayrımı)', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      test('aynı dosyanın görsel açık ve kapalı anahtarları FARKLIDIR', () {
        expect(
          PdfCacheService.hashBytes(bytes, includeImages: true),
          isNot(PdfCacheService.hashBytes(bytes, includeImages: false)),
        );
      });

      test('görsel açık anahtar eski (parametresiz) anahtarla BİREBİR aynı '
          '— mevcut soneksiz cache kayıtları bulunmaya devam eder', () {
        expect(
          PdfCacheService.hashBytes(bytes, includeImages: true),
          PdfCacheService.hashBytes(bytes),
        );
        // Düz SHA-256, sonek yok (bilinen boş-içerik vektörüyle de sabitle).
        expect(
          PdfCacheService.hashBytes(Uint8List(0), includeImages: true),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        );
      });

      test('görsel kapalı anahtar = düz özet + noVisionSuffix', () {
        final plain = PdfCacheService.hashBytes(bytes);
        expect(
          PdfCacheService.hashBytes(bytes, includeImages: false),
          '$plain${PdfCacheService.noVisionSuffix}',
        );
      });

      test('görsel kapalı anahtar deterministiktir', () {
        expect(
          PdfCacheService.hashBytes(bytes, includeImages: false),
          PdfCacheService.hashBytes(bytes, includeImages: false),
        );
      });

      test('iki mod birbirinin kaydını ezmez/servis etmez: save ve lookup '
          'kendi anahtarlarıyla ayrı raflara gider', () async {
        // Sahte sunucu: hash → kartlar. Gerçek Edge Function'ın yaptığı gibi
        // yalnızca anahtar üzerinden eşleştirir.
        final store = <String, List<dynamic>>{};
        final service = PdfCacheService(
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final hash = body['hash'] as String;
            if (body['action'] == 'save') {
              store[hash] = body['cards'] as List<dynamic>;
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            final cards = store[hash];
            return http.Response(
              jsonEncode({'found': cards != null, 'cards': cards}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final visionKey = PdfCacheService.hashBytes(bytes, includeImages: true);
        final noVisionKey =
            PdfCacheService.hashBytes(bytes, includeImages: false);

        // Görsel KAPALI işleme sonucunu kaydet.
        await service.save(noVisionKey, const [
          Flashcard(id: 'nv', question: 'Metin-only soru?', answer: 'C.'),
        ]);

        // Görsel AÇIK lookup bu kaydı GÖRMEMELİ (ayrı raf).
        expect(await service.lookup(visionKey), isNull);
        // Kendi rafında ise bulunur.
        final hit = await service.lookup(noVisionKey);
        expect(hit, isNotNull);
        expect(hit!.cards.single.question, 'Metin-only soru?');

        // Görsel AÇIK sonucu kaydetmek görselsiz rafı EZMEZ.
        await service.save(visionKey, const [
          Flashcard(id: 'v', question: 'Görselli soru?', answer: 'C.'),
        ]);
        expect(
          (await service.lookup(noVisionKey))!.cards.single.question,
          'Metin-only soru?',
        );
        expect(
          (await service.lookup(visionKey))!.cards.single.question,
          'Görselli soru?',
        );
      });
    });
  });

  group('PdfCacheService.lookup', () {
    test('found:true dönerse kartları ayrıştırır ve id\'leri yeniden üretir', () async {
      final service = PdfCacheService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'found': true,
              'hit_count': 3,
              'cards': [
                {
                  'id': 'original-id-1',
                  'question': 'Kalp kaç odacıklıdır?',
                  'answer': 'Dört.',
                  'shortAnswer': 'Dört',
                  'topic': 'genel yapı',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final result = await service.lookup('deadbeef');

      expect(result, isNotNull);
      expect(result!.cards, hasLength(1));
      expect(result.cards.first.question, 'Kalp kaç odacıklıdır?');
      // id ham önbellek değeriyle DEĞİL, yeniden üretilmiş olmalı.
      expect(result.cards.first.id, isNot('original-id-1'));
      expect(result.cards.first.id, startsWith('cache-'));
      expect(result.hitCount, 3);
    });

    test('hit_count eksik/null gelirse hitCount null olur', () async {
      final service = PdfCacheService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'found': true,
              'cards': [
                {'id': 'x', 'question': 'S?', 'answer': 'C.'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final result = await service.lookup('deadbeef');
      expect(result, isNotNull);
      expect(result!.hitCount, isNull);
    });

    test('found:false dönerse null döner', () async {
      final service = PdfCacheService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'found': false, 'cards': null}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      expect(await service.lookup('yok'), isNull);
    });

    test('sunucu hata (500) dönerse null döner (pipeline\'ı bozmaz)', () async {
      final service = PdfCacheService(
        client: MockClient(
          (_) async => http.Response(
            'sunucu hatasi',
            500,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      expect(await service.lookup('herhangi'), isNull);
    });

    test('ağ hatası fırlatırsa yakalanır, null döner', () async {
      final service = PdfCacheService(
        client: MockClient((_) async => throw Exception('bağlantı koptu')),
      );

      expect(await service.lookup('herhangi'), isNull);
    });

    test('bozuk bir kayıt varken diğerleri yine de dönülür', () async {
      final service = PdfCacheService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'found': true,
              'cards': [
                {'not': 'a valid flashcard shape at all, missing required fields'},
                {
                  'id': 'x',
                  'question': 'Geçerli soru?',
                  'answer': 'Geçerli cevap.',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final result = await service.lookup('karisik');
      expect(result!.cards, hasLength(1));
      expect(result.cards.first.question, 'Geçerli soru?');
    });
  });

  group('PdfCacheService.save', () {
    test('doğru action/hash/cards gövdesiyle POST atar', () async {
      Map<String, dynamic>? capturedBody;
      final service = PdfCacheService(
        client: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      const card = Flashcard(
        id: 'k1',
        question: 'Soru?',
        answer: 'Cevap.',
        shortAnswer: 'Kısa',
        topic: 'konu',
      );
      await service.save('abc123', [card]);

      expect(capturedBody, isNotNull);
      expect(capturedBody!['action'], 'save');
      expect(capturedBody!['hash'], 'abc123');
      expect(capturedBody!['cards'], hasLength(1));
      expect(capturedBody!['cards'][0]['question'], 'Soru?');
    });

    test('sunucu hatası fırlatmaz (best-effort, sessizce yutar)', () async {
      final service = PdfCacheService(
        client: MockClient((_) async => http.Response('hata', 500)),
      );

      await expectLater(
        service.save('abc123', const [
          Flashcard(id: 'k1', question: 'S', answer: 'C'),
        ]),
        completes,
      );
    });

    test('ağ hatası fırlatmaz (best-effort, sessizce yutar)', () async {
      final service = PdfCacheService(
        client: MockClient((_) async => throw Exception('koptu')),
      );

      await expectLater(
        service.save('abc123', const [
          Flashcard(id: 'k1', question: 'S', answer: 'C'),
        ]),
        completes,
      );
    });
  });
}
