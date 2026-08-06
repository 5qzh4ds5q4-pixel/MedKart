import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/flashcard_prompt.dart' as prompt;
import 'package:medcard/services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gemini'ın gerçek yanıt zarfını taklit eder.
String _geminiEnvelope(String modelText, {String finishReason = 'STOP'}) {
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': modelText},
          ],
        },
        'finishReason': finishReason,
      },
    ],
  });
}

/// 50 karakter alt sınırını aşan geçerli bir girdi.
const _validInput =
    'Kalp dört odacıklı bir kas organdır. Sağ atriyum vena cava yoluyla '
    'oksijenden fakir kanı alır ve sağ ventriküle iletir.';

void main() {
  setUp(() {
    // Servis artık Supabase Edge Function üzerinden çağırıyor; testlerde
    // proje URL'i + anon anahtarını belleğe koyuyoruz (Gemini API anahtarı
    // istemcide hiç yok, yalnızca Edge Function'da).
    dotenv.loadFromString(
      envString:
          'SUPABASE_URL=https://test.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
    // GeminiTransport artık DeviceIdService üzerinden shared_preferences
    // okuyor (anonim cihaz kimliği); testlerde bellek-içi mock yeterli.
    SharedPreferences.setMockInitialValues({});
  });

  GeminiService serviceReturning(String body, {int statusCode = 200}) {
    return GeminiService(
      client: MockClient(
        (_) async => http.Response(
          body,
          statusCode,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  }

  test('geçerli JSON yanıtını kartlara dönüştürür', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {
            'soru': 'Kalp kaç odacıklıdır?',
            'cevap': 'Dört.',
            'zorluk': 'kolay',
            'konu': 'genel yapı',
          },
          {
            'soru': 'LAD tıkanırsa hangi bölge etkilenir?',
            'cevap': 'Ön duvar ve septumun ön bölümü.',
            'zorluk': 'zor',
            'konu': 'koroner dolaşım',
          },
        ]),
      ),
    );

    final cards = await service.generate(_validInput);

    expect(cards, hasLength(2));
    expect(cards.first.question, 'Kalp kaç odacıklıdır?');
    expect(cards.first.answer, 'Dört.');
    expect(cards.first.difficulty, CardDifficulty.kolay);
    expect(cards.first.topic, 'genel yapı');
    expect(cards.last.difficulty, CardDifficulty.zor);
    expect(cards.last.topic, 'koroner dolaşım');
    expect(cards.first.id, isNot(cards.last.id));
  });

  test('kartTipi "sinav" ise CardType.sinav olarak ayrıştırılır', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {
            'soru':
                '45 yaşında hasta omuz abduksiyonunu yapamıyor. Hangi sinir?',
            'cevap': 'N. axillaris.',
            'zorluk': 'orta',
            'konu': 'brakial pleksus',
            'kartTipi': 'sinav',
          },
          {
            'soru': 'N. axillaris hasarında ne olur?',
            'cevap': 'Kol abduksiyonu kaybolur.',
            'zorluk': 'orta',
            'konu': 'brakial pleksus',
            'kartTipi': 'temel',
          },
        ]),
      ),
    );

    final cards = await service.generate(_validInput);

    expect(cards.first.cardType, CardType.sinav);
    expect(cards.first.isExamType, isTrue);
    expect(cards.last.cardType, CardType.temel);
    expect(cards.last.isExamType, isFalse);
  });

  test('kartTipi eksik/tanınmazsa CardType.temel varsayılır', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {'soru': 'Etiketsiz soru?', 'cevap': 'Cevap.'},
          {
            'soru': 'Bozuk etiketli soru?',
            'cevap': 'Cevap.',
            'kartTipi': 'başka bir şey',
          },
        ]),
      ),
    );

    final cards = await service.generate(_validInput);

    expect(cards.every((c) => c.cardType == CardType.temel), isTrue);
  });

  test('varsayılanda thinking kapalı gönderilir (thinkingBudget: 0)', () async {
    http.Request? captured;
    final service = GeminiService(
      client: MockClient((req) async {
        captured = req;
        return http.Response(
          _geminiEnvelope(
            jsonEncode([
              {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
            ]),
          ),
          200,
        );
      }),
    );

    await service.generate(_validInput);

    // Transport artık gövdeyi Edge Function zarfına ('payload' altına) sarıyor.
    final body =
        (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
            as Map<String, dynamic>;
    final generationConfig = body['generationConfig'] as Map<String, dynamic>;
    expect(generationConfig['thinkingConfig'], {'thinkingBudget': 0});
  });

  test(
    'thinkingBudget: null verilirse dinamik thinking için thinkingConfig gönderilmez',
    () async {
      http.Request? captured;
      final service = GeminiService(
        thinkingBudget: null,
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            _geminiEnvelope(
              jsonEncode([
                {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
              ]),
            ),
            200,
          );
        }),
      );

      await service.generate(_validInput);

      // Transport artık gövdeyi Edge Function zarfına ('payload' altına) sarıyor.
      final body =
          (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig.containsKey('thinkingConfig'), isFalse);
    },
  );

  group('maxOutputTokens (maliyet tavanı)', () {
    // Sayfa başına en kötü durum maliyetini belirleyen tek değer bu: çıktı
    // girdinin 6 katı fiyattan faturalanıyor. 8192 → 4096 düşürüldü.
    test('sabit 4096 (8192 değil)', () {
      expect(GeminiService.maxOutputTokens, 4096);
    });

    test('generate() isteğinde sabit değer gönderilir', () async {
      http.Request? captured;
      final service = GeminiService(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            _geminiEnvelope(
              jsonEncode([
                {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
              ]),
            ),
            200,
          );
        }),
      );

      await service.generate(_validInput);

      final body =
          (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['maxOutputTokens'], GeminiService.maxOutputTokens);
      expect(generationConfig['maxOutputTokens'], 4096);
    });

    test('generateForPage() isteğinde de AYNI değer gönderilir', () async {
      http.Request? captured;
      final service = GeminiService(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            _geminiEnvelope(
              jsonEncode([
                {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
              ]),
            ),
            200,
          );
        }),
      );

      await service.generateForPage('Sayfa metni, yeterince uzun bir içerik.', 3);

      final body =
          (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['maxOutputTokens'], GeminiService.maxOutputTokens);
      expect(generationConfig['maxOutputTokens'], 4096);
    });
  });

  test(
    'oncelik "arka_plan"/"oncelikli" doğru CardPriority\'e ayrıştırılır',
    () async {
      final service = serviceReturning(
        _geminiEnvelope(
          jsonEncode([
            {
              'soru': 'Soru?',
              'cevap': 'Cevap.',
              'zorluk': 'kolay',
              'konu': 'x',
              'oncelik': 'arka_plan',
            },
            {
              'soru': 'Soru2?',
              'cevap': 'Cevap2.',
              'zorluk': 'kolay',
              'konu': 'x',
              'oncelik': 'oncelikli',
            },
          ]),
        ),
      );

      final cards = await service.generate(_validInput);

      expect(cards.first.priority, CardPriority.arkaPlan);
      expect(cards.last.priority, CardPriority.oncelikli);
    },
  );

  test(
    'oncelik alanı eksikse öncelikli varsayılır (kart gizli kalmasın)',
    () async {
      final service = serviceReturning(
        _geminiEnvelope(
          jsonEncode([
            {'soru': 'Soru?', 'cevap': 'Cevap.'},
          ]),
        ),
      );

      final cards = await service.generate(_validInput);

      expect(cards.single.priority, CardPriority.oncelikli);
    },
  );

  test(
    'istek şemasında kartlar KOMPAKT dizi olarak istenir (alan adlı nesne '
    'değil) ve eleman sayısı sabitlenir',
    () async {
      http.Request? captured;
      final service = GeminiService(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            _geminiEnvelope(
              jsonEncode([
                ['S', 'K', 'C', 'o', 't', 'o', 'x', null, 'false'],
              ]),
            ),
            200,
          );
        }),
      );

      await service.generate(_validInput);

      // Transport artık gövdeyi Edge Function zarfına ('payload' altına) sarıyor.
      final body =
          (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final schema = (body['generationConfig'] as Map)['responseSchema'] as Map;
      expect(schema['type'], 'ARRAY');

      // Kart = OBJECT değil ARRAY, alan adı yok.
      final kart = schema['items'] as Map;
      expect(kart['type'], 'ARRAY');
      expect(kart.containsKey('properties'), isFalse);
      expect(prompt.kompaktAlanSayisi, 9);

      // minItems/maxItems BİLEREK yok: Gemini'ın bunları nested ARRAY'de
      // kabul ettiği doğrulanamadı, reddedilse tüm istekler 400 olurdu.
      // Şema yalnızca en temel alanları taşımalı (bkz. responseSchema yorumu).
      expect(kart.containsKey('minItems'), isFalse);
      expect(kart.containsKey('maxItems'), isFalse);
      expect(kart.keys.toSet(), {'type', 'items'});
      expect(kart['items'], {'type': 'STRING', 'nullable': true});
    },
  );

  test('konu etiketi küçük harfe normalize edilir', () async {
    // Aynı konunun farklı yazımları tek grup olmalı (SRS gruplaması için).
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {
            'soru': 'Soru?',
            'cevap': 'Cevap.',
            'zorluk': 'orta',
            'konu': '  Koroner Dolaşım  ',
          },
        ]),
      ),
    );

    final cards = await service.generate(_validInput);

    expect(cards.single.topic, 'koroner dolaşım');
  });

  test('etiketler eksik veya tanınmazsa kart yine de kullanılabilir', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {'soru': 'Etiketsiz soru?', 'cevap': 'Cevap.'},
          {
            'soru': 'Bozuk etiketli soru?',
            'cevap': 'Cevap.',
            'zorluk': 'çok zor',
            'konu': null,
          },
        ]),
      ),
    );

    final cards = await service.generate(_validInput);

    expect(cards, hasLength(2));
    // Tanınmayan/eksik zorluk ortaya düşer, kart atılmaz.
    expect(cards.first.difficulty, CardDifficulty.orta);
    expect(cards.first.topic, isEmpty);
    expect(cards.first.hasTopic, isFalse);
    expect(cards.last.difficulty, CardDifficulty.orta);
    expect(cards.last.topic, isEmpty);
  });

  test('eksik alanlı kartları atlar, sağlamları tutar', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {'soru': 'Geçerli soru?', 'cevap': 'Geçerli cevap.'},
          {'soru': '', 'cevap': 'Sorusu boş.'},
          {'soru': 'Cevabı yok?'},
          'kart değil',
        ]),
      ),
    );

    final cards = await service.generate(_validInput);

    expect(cards, hasLength(1));
    expect(cards.single.question, 'Geçerli soru?');
  });

  test('düşünce (thought) parçaları cevaba karıştırılmaz', () async {
    // Gemini 3 modelleri yanıta thought parçaları ekleyebilir; bunlar JSON
    // değildir ve cevapla birleştirilirse parse bozulur.
    final service = serviceReturning(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': 'Önce kalbin odacıklarını düşüneyim…',
                  'thought': true,
                },
                {
                  'text': jsonEncode([
                    {'soru': 'Kalp kaç odacıklıdır?', 'cevap': 'Dört.'},
                  ]),
                },
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      }),
    );

    final cards = await service.generate(_validInput);

    expect(cards, hasLength(1));
    expect(cards.single.question, 'Kalp kaç odacıklıdır?');
  });

  test('model JSON yerine düz metin döndürürse nazik hata verir', () async {
    final service = serviceReturning(
      _geminiEnvelope('Üzgünüm, yardımcı olamam.'),
    );

    expect(
      () => service.generate(_validInput),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.message,
          'message',
          contains('beklenen kart formatında'),
        ),
      ),
    );
  });

  test('boş kart listesi hata olarak bildirilir', () async {
    final service = serviceReturning(_geminiEnvelope('[]'));

    expect(
      () => service.generate(_validInput),
      throwsA(isA<FlashcardGenerationException>()),
    );
  });

  test('403 yanıtı anahtar hatası olarak açıklanır', () async {
    final service = serviceReturning(
      jsonEncode({
        'error': {
          'message': 'API key not valid',
          'status': 'PERMISSION_DENIED',
        },
      }),
      statusCode: 403,
    );

    expect(
      () => service.generate(_validInput),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.message,
          'message',
          contains('Supabase'),
        ),
      ),
    );
  });

  test(
    'kota aşımı (429) bekleme mesajı verir ve isQuota işaretlenir',
    () async {
      final service = GeminiService(
        retryBackoff: Duration.zero,
        client: MockClient((_) async => http.Response('{}', 429)),
      );

      await expectLater(
        () => service.generate(_validInput),
        throwsA(
          isA<FlashcardGenerationException>()
              .having((e) => e.message, 'message', contains('kota'))
              .having((e) => e.isQuota, 'isQuota', isTrue),
        ),
      );
    },
  );

  test('geçici 5xx hatasında yeniden dener ve başarır', () async {
    var calls = 0;
    final service = GeminiService(
      retryBackoff: Duration.zero,
      client: MockClient((_) async {
        calls++;
        if (calls < 3) return http.Response('{}', 503);
        return http.Response(
          _geminiEnvelope(
            jsonEncode([
              {'soru': 'S', 'cevap': 'C'},
            ]),
          ),
          200,
        );
      }),
    );

    final cards = await service.generate(_validInput);

    expect(calls, 3);
    expect(cards, hasLength(1));
  });

  test('kalıcı 5xx hatası denemeler sonrası bildirilir', () async {
    var calls = 0;
    final service = GeminiService(
      retryBackoff: Duration.zero,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );

    await expectLater(
      () => service.generate(_validInput),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.message,
          'message',
          contains('sunucu'),
        ),
      ),
    );
    expect(calls, 4);
  });

  test('429 (kota) üstel backoff ile yeniden denenir sonra pes eder', () async {
    var calls = 0;
    final service = GeminiService(
      retryBackoff: Duration.zero,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 429);
      }),
    );

    await expectLater(
      () => service.generate(_validInput),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.isQuota,
          'isQuota',
          isTrue,
        ),
      ),
    );
    // 429 geçici sayılır: _maxAttempts kadar denenir (1 ilk + 3 retry = 4).
    expect(calls, 4);
  });

  test('kalıcı 4xx (403 anahtar hatası) yeniden denenmez', () async {
    var calls = 0;
    final service = GeminiService(
      retryBackoff: Duration.zero,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 403);
      }),
    );

    await expectLater(
      () => service.generate(_validInput),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.isQuota,
          'isQuota',
          isFalse,
        ),
      ),
    );
    expect(calls, 1);
  });

  test('güvenlik filtresi engeli anlaşılır şekilde bildirilir', () async {
    final service = serviceReturning(
      jsonEncode({
        'promptFeedback': {'blockReason': 'SAFETY'},
      }),
    );

    expect(
      () => service.generate(_validInput),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.message,
          'message',
          contains('güvenlik filtresi'),
        ),
      ),
    );
  });

  test('çok kısa metin API çağrısı yapılmadan reddedilir', () async {
    var requestSent = false;
    final service = GeminiService(
      client: MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      () => service.generate('Kalp'),
      throwsA(isA<FlashcardGenerationException>()),
    );
    expect(requestSent, isFalse);
  });

  test('görsel eki multimodal istek olarak gönderilir', () async {
    http.Request? captured;
    final service = GeminiService(
      client: MockClient((req) async {
        captured = req;
        return http.Response(
          _geminiEnvelope(
            jsonEncode([
              {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'anatomi'},
            ]),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final cards = await service.generate(
      '',
      media: [
        MediaAttachment(bytes: bytes, mimeType: 'image/png', name: 'slayt.png'),
      ],
    );

    expect(cards, hasLength(1));

    // Transport artık gövdeyi Edge Function zarfına ('payload' altına) sarıyor.
    final body =
        (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
            as Map<String, dynamic>;
    final parts = (body['contents'] as List).first['parts'] as List;
    // Medya parçası önce ve base64 doğru; yönerge metni sonda.
    expect(parts.first['inlineData']['mimeType'], 'image/png');
    expect(parts.first['inlineData']['data'], base64Encode(bytes));
    expect(parts.last['text'], contains('görsel'));
  });

  test('yalnızca ek varken kısa/boş metin reddi atlanır', () async {
    var requestSent = false;
    final service = GeminiService(
      client: MockClient((_) async {
        requestSent = true;
        return http.Response(
          _geminiEnvelope(
            jsonEncode([
              {'soru': 'S', 'cevap': 'C'},
            ]),
          ),
          200,
        );
      }),
    );

    final cards = await service.generate(
      '',
      media: [
        MediaAttachment(
          bytes: Uint8List.fromList([9, 9]),
          mimeType: 'image/png',
          name: 'slayt.png',
        ),
      ],
    );

    expect(requestSent, isTrue);
    expect(cards, hasLength(1));
  });

  test(
    'PDF artık desteklenmiyor (Yol A\'ya taşındı) — istek atılmadan reddedilir',
    () async {
      var requestSent = false;
      final service = GeminiService(
        client: MockClient((_) async {
          requestSent = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        () => service.generate(
          '',
          media: [
            MediaAttachment(
              bytes: Uint8List.fromList([1, 2, 3]),
              mimeType: 'application/pdf',
              name: 'slayt.pdf',
            ),
          ],
        ),
        throwsA(isA<FlashcardGenerationException>()),
      );
      expect(requestSent, isFalse);
    },
  );

  test('desteklenmeyen dosya türü istek atılmadan reddedilir', () async {
    var requestSent = false;
    final service = GeminiService(
      client: MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      () => service.generate(
        '',
        media: [
          MediaAttachment(
            bytes: Uint8List.fromList([1]),
            mimeType: 'text/plain',
            name: 'a.txt',
          ),
        ],
      ),
      throwsA(isA<FlashcardGenerationException>()),
    );
    expect(requestSent, isFalse);
  });

  test('metin ve ek ikisi de boşsa istek atılmaz', () async {
    var requestSent = false;
    final service = GeminiService(
      client: MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      () => service.generate(''),
      throwsA(isA<FlashcardGenerationException>()),
    );
    expect(requestSent, isFalse);
  });

  test('generateForPage kartları sourcePage ile döner', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'anatomi'},
        ]),
      ),
    );

    final cards = await service.generateForPage(
      'Bu sayfada yeterince uzun bir ders metni var.',
      47,
    );

    expect(cards, hasLength(1));
    expect(cards.single.sourcePage, 47);
  });

  test(
    'generateForPage: model geçerli slaytNumarasi dönerse fiziksel sayfa '
    'yerine ONU kullanır (kapak/boş sayfa kayması düzeltmesi)',
    () async {
      final service = serviceReturning(
        _geminiEnvelope(
          jsonEncode([
            {
              'soru': 'S',
              'cevap': 'C',
              'zorluk': 'orta',
              'konu': 'anatomi',
              'slaytNumarasi': 24,
            },
          ]),
        ),
      );

      // Fiziksel sayfa 27 (dosyanın 27. yaprağı) ama slaytın kendi üzerinde
      // yazan numara 24 — slaytNumarasi baskın gelmeli.
      final cards = await service.generateForPage(
        'Bu sayfada yeterince uzun bir ders metni var.',
        27,
        imageBase64: 'aGVsbG8=',
      );

      expect(cards.single.sourcePage, 24);
    },
  );

  test(
    'generateForPage: slaytNumarasi null/eksikse fiziksel sayfaya düşülür',
    () async {
      final service = serviceReturning(
        _geminiEnvelope(
          jsonEncode([
            {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'anatomi'},
          ]),
        ),
      );

      final cards = await service.generateForPage(
        'Bu sayfada yeterince uzun bir ders metni var.',
        27,
        imageBase64: 'aGVsbG8=',
      );

      expect(cards.single.sourcePage, 27);
    },
  );

  test(
    'generateForPage: geçersiz (0/negatif) slaytNumarasi yok sayılır, '
    'fiziksel sayfaya düşülür',
    () async {
      final service = serviceReturning(
        _geminiEnvelope(
          jsonEncode([
            {
              'soru': 'S',
              'cevap': 'C',
              'zorluk': 'orta',
              'konu': 'anatomi',
              'slaytNumarasi': 0,
            },
          ]),
        ),
      );

      final cards = await service.generateForPage(
        'Bu sayfada yeterince uzun bir ders metni var.',
        27,
        imageBase64: 'aGVsbG8=',
      );

      expect(cards.single.sourcePage, 27);
    },
  );

  test('generateForPage kartları oncelik ile döner', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {
            'soru': 'S',
            'cevap': 'C',
            'zorluk': 'orta',
            'konu': 'anatomi',
            'oncelik': 'arka_plan',
          },
        ]),
      ),
    );

    final cards = await service.generateForPage(
      'Bu sayfada yeterince uzun bir ders metni var.',
      47,
    );

    expect(cards.single.priority, CardPriority.arkaPlan);
  });

  test('generateForPage: elYazisindanMi true dönerse isHandwritten true olur, '
      'soru/cevap metni DEĞİŞMEZ', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {
            'soru': 'S',
            'cevap': 'C',
            'zorluk': 'orta',
            'konu': 'anatomi',
            'elYazisindanMi': true,
          },
        ]),
      ),
    );

    final cards = await service.generateForPage(
      'Bu sayfada yeterince uzun bir ders metni var.',
      47,
      imageBase64: 'aGVsbG8=',
    );

    expect(cards.single.isHandwritten, isTrue);
    expect(cards.single.question, 'S');
    expect(cards.single.answer, 'C');
  });

  test(
    'generateForPage: elYazisindanMi false/eksikse isHandwritten false olur',
    () async {
      final service = serviceReturning(
        _geminiEnvelope(
          jsonEncode([
            {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'anatomi'},
          ]),
        ),
      );

      final cards = await service.generateForPage(
        'Bu sayfada yeterince uzun bir ders metni var.',
        47,
      );

      expect(cards.single.isHandwritten, isFalse);
      expect(cards.single.answer, 'C');
    },
  );

  test('generateForPage kartları kartTipi ile döner', () async {
    final service = serviceReturning(
      _geminiEnvelope(
        jsonEncode([
          {
            'soru': '60 yaşında hastada düşük el (wrist drop) var. Sinir?',
            'cevap': 'N. radialis.',
            'zorluk': 'orta',
            'konu': 'brakial pleksus',
            'kartTipi': 'sinav',
          },
        ]),
      ),
    );

    final cards = await service.generateForPage(
      'Bu sayfada yeterince uzun bir ders metni var.',
      47,
    );

    expect(cards.single.cardType, CardType.sinav);
    expect(cards.single.sourcePage, 47);
  });

  test('generateForPage boş sayfada hata fırlatmadan [] döner', () async {
    final service = serviceReturning(_geminiEnvelope('[]'));
    final cards = await service.generateForPage('kısa metin', 5);
    expect(cards, isEmpty);
  });

  test(
    'generateForPage metin VE görsel ikisi de boşsa istek atılmaz',
    () async {
      var requestSent = false;
      final service = GeminiService(
        client: MockClient((_) async {
          requestSent = true;
          return http.Response('{}', 200);
        }),
      );
      final cards = await service.generateForPage('', 6);
      expect(cards, isEmpty);
      expect(requestSent, isFalse);
    },
  );

  test(
    'generateForPage metin boş ama görsel varsa yine de istek atılır (renkli tablo)',
    () async {
      http.Request? captured;
      final service = GeminiService(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            _geminiEnvelope(
              jsonEncode([
                {
                  'soru': 'Anofel hangi hastalığı taşır?',
                  'cevap': 'Sıtma.',
                  'zorluk': 'orta',
                  'konu': 'vektörler',
                },
              ]),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final cards = await service.generateForPage(
        '31',
        31,
        imageBase64: 'aGVsbG8=',
      );

      expect(cards, hasLength(1));
      expect(cards.single.sourcePage, 31);

      // Transport artık gövdeyi Edge Function zarfına ('payload' altına) sarıyor.
      final body =
          (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final parts = (body['contents'] as List).first['parts'] as List;
      // Görsel önce, yönerge metni sonra; prompt tabloyu vision'dan okumayı anlatır.
      expect(parts.first['inlineData']['mimeType'], 'image/png');
      expect(parts.first['inlineData']['data'], 'aGVsbG8=');
      expect(parts.last['text'], contains('HEM METNİ HEM GÖRÜNTÜSÜ'));
      expect(parts.last['text'], contains('el yazısı'));
      // Görsel eklendiğinde model slaytın kendi numarasını okumaya yönlendirilir.
      expect(parts.last['text'], contains('SLAYT NUMARASI'));
    },
  );

  test(
    'generateForPage: görsel yoksa prompt SLAYT NUMARASI kuralını içermez',
    () async {
      http.Request? captured;
      final service = GeminiService(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            _geminiEnvelope(
              jsonEncode([
                {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
              ]),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.generateForPage(
        'Bu sayfada yeterince uzun bir ders metni var.',
        5,
      );

      final body =
          (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final parts = (body['contents'] as List).first['parts'] as List;
      expect(parts.single['text'], isNot(contains('SLAYT NUMARASI')));
    },
  );

  test(
    'generate (Yol B): görsel ekli olsa bile prompt SLAYT NUMARASI kuralını '
    'içermez (sourcePage Yol B için hiç anlamlı değil)',
    () async {
      http.Request? captured;
      final service = GeminiService(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            _geminiEnvelope(
              jsonEncode([
                {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
              ]),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.generate(
        _validInput,
        media: [
          MediaAttachment(
            name: 'a.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );

      final body =
          (jsonDecode(captured!.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final parts = (body['contents'] as List).first['parts'] as List;
      expect(parts.last['text'], isNot(contains('SLAYT NUMARASI')));
    },
  );

  test(
    'generateForPage HTTP hatasında fırlatır (pipeline yeniden denesin)',
    () async {
      final service = GeminiService(
        retryBackoff: Duration.zero,
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      await expectLater(
        () => service.generateForPage('metin', 1),
        throwsA(isA<FlashcardGenerationException>()),
      );
    },
  );

  test('generateForPage 429\'da isQuota işaretli hata fırlatır', () async {
    final service = GeminiService(
      retryBackoff: Duration.zero,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 429, 'message': 'RESOURCE_EXHAUSTED'},
          }),
          429,
        ),
      ),
    );
    await expectLater(
      () => service.generateForPage('yeterince uzun sayfa metni', 3),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.isQuota,
          'isQuota',
          isTrue,
        ),
      ),
    );
  });

  test(
    'generateForPage: model dizi yerine nesne dönerse çökmez, [] döner',
    () async {
      // Regresyonun kalbi: gelen JSON bir Map ({...}); kod bunu List sanıp cast
      // etmemeli, TypeError atmamalı — sayfa yalnızca kart üretmemiş sayılır.
      final service = serviceReturning(
        _geminiEnvelope(jsonEncode({'soru': 'S', 'cevap': 'C'})),
      );
      final cards = await service.generateForPage(
        'yeterince uzun sayfa metni',
        8,
      );
      expect(cards, isEmpty);
    },
  );

  test(
    'generateForPage: 200 gövdesinde error nesnesi kartla karıştırılmaz',
    () async {
      final service = serviceReturning(
        jsonEncode({
          'error': {'message': 'beklenmedik'},
        }),
      );
      final cards = await service.generateForPage(
        'yeterince uzun sayfa metni',
        9,
      );
      expect(cards, isEmpty);
    },
  );

  test('SUPABASE_ANON_KEY boşsa istek atılmaz', () async {
    // setUp her testten önce geçerli değerleri geri yüklüyor.
    dotenv.loadFromString(
      envString: 'SUPABASE_URL=https://test.supabase.co\nSUPABASE_ANON_KEY=',
    );

    var requestSent = false;
    final service = GeminiService(
      client: MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      () => service.generate(_validInput),
      throwsA(
        isA<FlashcardGenerationException>().having(
          (e) => e.message,
          'message',
          contains('.env'),
        ),
      ),
    );
    expect(requestSent, isFalse);
  });

  test('Yol A ve Yol B aynı "her kart için etiketler" bloğunu birebir paylaşır '
      '(kisaCevap dahil) — biri güncellenip diğeri unutulmasın diye', () async {
    http.Request? pageRequest;
    final pageService = GeminiService(
      client: MockClient((req) async {
        pageRequest = req;
        return http.Response(
          _geminiEnvelope(
            jsonEncode([
              {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
            ]),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await pageService.generateForPage('yeterince uzun sayfa metni', 1);

    http.Request? textRequest;
    final textService = GeminiService(
      client: MockClient((req) async {
        textRequest = req;
        return http.Response(
          _geminiEnvelope(
            jsonEncode([
              {'soru': 'S', 'cevap': 'C', 'zorluk': 'orta', 'konu': 'x'},
            ]),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await textService.generate(_validInput);

    String promptOf(http.Request req) {
      final body =
          (jsonDecode(req.body) as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final parts = (body['contents'] as List).first['parts'] as List;
      return (parts.last as Map)['text'] as String;
    }

    final pagePrompt = promptOf(pageRequest!);
    final textPrompt = promptOf(textRequest!);

    // Ortak biçim bloğunun her satırı ikisinde de BİREBİR aynı geçmeli.
    const sharedLines = [
      '[1] kisaCevap — yukarıdaki İKİ AYRI CEVAP kuralına göre 3-8 kelimelik doğrudan yanıt.',
      '[3] zorluk kodu — yukarıdaki ZORLUK KALİBRASYONU kuralına göre "k"=kolay, "o"=orta, "z"=zor.',
      '[5] oncelik kodu — yukarıdaki ÖNCELİK ETİKETİ kuralına göre "o"=oncelikli, "a"=arka_plan.',
      '[8] elYazisindanMi — yukarıdaki EL YAZISI İŞARETİ kuralına göre "true"/"false" (görsel yoksa her zaman "false").',
    ];
    for (final line in sharedLines) {
      expect(pagePrompt, contains(line));
      expect(textPrompt, contains(line));
    }
  });
}
