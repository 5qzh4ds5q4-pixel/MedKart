import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/glm_service.dart';
import 'package:medcard/services/session_token.dart';
import 'package:medcard/services/glm_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GLM'in (OpenRouter, `z-ai/glm-4.5v`) OpenAI-uyumlu yanıt zarfını taklit
/// eder — DeepSeek ile aynı biçim.
String _glmEnvelope(String modelText, {String finishReason = 'stop'}) {
  return jsonEncode({
    'choices': [
      {
        'message': {'role': 'assistant', 'content': modelText},
        'finish_reason': finishReason,
      },
    ],
  });
}

/// Modelin döndürmesi beklenen `{"cards": [...]}` zarfı.
String _cardsPayload(List<List<Object?>> cards) =>
    jsonEncode({'cards': cards});

/// 50 karakter alt sınırını aşan geçerli bir girdi.
const _validInput =
    'Kalp dört odacıklı bir kas organdır. Sağ atriyum vena cava yoluyla '
    'oksijenden fakir kanı alır ve sağ ventriküle iletir.';

/// Kompakt biçimde tek bir örnek kart (9 eleman, sırası sabit).
const _ornekKart = <Object?>[
  'Mitral kapak nerede bulunur?',
  'Sol atriyum ile sol ventrikül arasında',
  'Mitral kapak sol atriyum ile sol ventrikül arasında yer alır ve iki '
      'yaprakçığı vardır. Bu konumu sayesinde sol ventrikül kasıldığında '
      'kanın atriyuma geri kaçmasını engeller.',
  'z',
  's',
  'o',
  'kapaklar',
  '12',
  'true',
];

void main() {
  setUp(() {
    // Servis Supabase Edge Function üzerinden çağırıyor; OpenRouter anahtarı
    // istemcide HİÇ yok, testlerde de gerekmiyor.
    dotenv.loadFromString(
      envString:
          'SUPABASE_URL=https://test.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
    // GlmTransport DeviceIdService üzerinden shared_preferences okuyor.
    SharedPreferences.setMockInitialValues({});
    // 2026-08-20: Authorization artık kullanıcı oturum token'ı (bkz.
    // SessionToken); testlerde oturumu sabitliyoruz.
    debugSessionAccessTokenOverride = () => 'test-access-token';
  });

  tearDown(() => debugSessionAccessTokenOverride = null);

  /// Gönderilen isteklerin ai-proxy zarflarını biriktirir.
  late List<Map<String, dynamic>> sent;

  setUp(() => sent = []);

  GlmService serviceReturning(String body, {int statusCode = 200}) {
    return GlmService(
      retryBackoff: Duration.zero,
      client: MockClient((req) async {
        sent.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(
          body,
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  /// Son isteğin sağlayıcıya iletilen ham gövdesi (`payload`).
  Map<String, dynamic> lastPayload() =>
      sent.last['payload'] as Map<String, dynamic>;

  /// Son isteğin tek kullanıcı mesajının içeriği (String ya da List).
  Object lastContent() =>
      ((lastPayload()['messages'] as List).first as Map)['content'] as Object;

  /// Multimodal içerikteki metin bloğunu çeker.
  String lastPromptText() {
    final content = lastContent();
    if (content is String) return content;
    final textBlock = (content as List).firstWhere(
      (b) => (b as Map)['type'] == 'text',
    );
    return (textBlock as Map)['text'] as String;
  }

  group('yanıt ayrıştırma', () {
    test('kompakt kart dizisini Flashcard\'a çevirir', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      final cards = await service.generateForPage('Kalp kapakları.', 7);

      expect(cards, hasLength(1));
      final card = cards.single;
      expect(card.question, 'Mitral kapak nerede bulunur?');
      expect(card.shortAnswer, 'Sol atriyum ile sol ventrikül arasında');
      expect(card.difficulty, CardDifficulty.zor);
      expect(card.cardType, CardType.sinav);
      expect(card.priority, CardPriority.oncelikli);
      expect(card.topic, 'kapaklar');
      expect(card.isHandwritten, isTrue);
      // Modelin okuduğu slayt numarası fiziksel sayfayı EZER (7 değil 12).
      expect(card.sourcePage, 12);
    });

    test('slaytNumarasi null ise fiziksel sayfaya düşer', () async {
      final kart = [..._ornekKart]..[7] = null;
      final service = serviceReturning(_glmEnvelope(_cardsPayload([kart])));

      final cards = await service.generateForPage('Kalp kapakları.', 7);

      expect(cards.single.sourcePage, 7);
    });

    test('bozuk iç JSON sayfayı düşürür ama fırlatmaz', () async {
      final service = serviceReturning(_glmEnvelope('bu JSON değil'));

      expect(await service.generateForPage('Kalp kapakları.', 3), isEmpty);
    });

    test('"cards" alanı List değilse boş liste döner', () async {
      final service = serviceReturning(
        _glmEnvelope(jsonEncode({'cards': 'olmadı'})),
      );

      expect(await service.generateForPage('Kalp kapakları.', 3), isEmpty);
    });

    test('choices boşsa boş liste döner', () async {
      final service = serviceReturning(jsonEncode({'choices': []}));

      expect(await service.generateForPage('Kalp kapakları.', 3), isEmpty);
    });

    test('200 gövdesinde error nesnesi kart sanılmaz', () async {
      final service = serviceReturning(
        jsonEncode({
          'error': {'message': 'bir sorun'},
        }),
      );

      expect(await service.generateForPage('Kalp kapakları.', 3), isEmpty);
    });

    test('metin ve görsel boşsa hiç istek atılmaz', () async {
      final service = serviceReturning(_glmEnvelope(_cardsPayload([])));

      expect(await service.generateForPage('   ', 4), isEmpty);
      expect(sent, isEmpty);
    });
  });

  group('görsel desteği (DeepSeek\'ten temel fark)', () {
    test('sayfa görüntüsü OpenAI image_url data URI olarak gider', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await service.generateForPage(
        'Kalp kapakları.',
        7,
        imageBase64: 'QUJD',
        imageMimeType: 'image/jpeg',
      );

      final content = lastContent();
      expect(content, isA<List>());
      final blocks = content as List;
      final image = blocks.firstWhere((b) => (b as Map)['type'] == 'image_url');
      expect(
        ((image as Map)['image_url'] as Map)['url'],
        'data:image/jpeg;base64,QUJD',
      );
      // Gemini'deki parts sıralamasıyla aynı: görsel önce, yönerge sonra.
      expect((blocks.first as Map)['type'], 'image_url');
      expect((blocks.last as Map)['type'], 'text');
    });

    test('görsel yokken content düz metin kalır', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await service.generateForPage('Kalp kapakları.', 7);

      expect(lastContent(), isA<String>());
    });

    test('görsel varken vision prompt blokları devreye girer', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await service.generateForPage(
        'Kalp kapakları.',
        7,
        imageBase64: 'QUJD',
      );

      // Blok BAŞLIKLARI aranıyor, salt "EL YAZISI İŞARETİ" değil: o ifade her
      // zaman eklenen çıktı biçimi bloğunun [8] satırında da geçiyor, yani
      // koşullu bloğun varlığını kanıtlamaz.
      final text = lastPromptText();
      expect(text, contains('EL YAZISI İŞARETİ (kart dizisinin son elemanı'));
      expect(text, contains('SLAYT NUMARASI (kart dizisinin'));
      expect(text, contains('SAYFANIN HEM METNİ HEM GÖRÜNTÜSÜ EKLİ'));
    });

    test('görsel yokken vision blokları prompt\'a HİÇ girmez', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await service.generateForPage('Kalp kapakları.', 7);

      final text = lastPromptText();
      expect(
        text,
        isNot(contains('EL YAZISI İŞARETİ (kart dizisinin son elemanı')),
      );
      expect(text, isNot(contains('SLAYT NUMARASI (kart dizisinin')));
      expect(text, isNot(contains('SAYFANIN HEM METNİ HEM GÖRÜNTÜSÜ EKLİ')));
    });

    test('generate() görsel ekini multimodal bloğa çevirir', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await service.generate(
        _validInput,
        media: [
          MediaAttachment(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/png',
            name: 'slayt.png',
          ),
        ],
      );

      final content = lastContent();
      expect(content, isA<List>());
      final image = (content as List).first as Map;
      expect(image['type'], 'image_url');
      expect(
        (image['image_url'] as Map)['url'],
        'data:image/png;base64,${base64Encode([1, 2, 3])}',
      );
    });

    test('desteklenmeyen dosya türü reddedilir (istek atılmaz)', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await expectLater(
        service.generate(
          _validInput,
          media: [
            MediaAttachment(
              bytes: Uint8List.fromList([1]),
              mimeType: 'application/pdf',
              name: 'ders.pdf',
            ),
          ],
        ),
        throwsA(isA<FlashcardGenerationException>()),
      );
      expect(sent, isEmpty);
    });
  });

  group('istek gövdesi', () {
    test('model ve max_tokens sabitlerden gelir', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await service.generateForPage('Kalp kapakları.', 7);

      final payload = lastPayload();
      expect(payload['model'], 'z-ai/glm-4.5v');
      expect(payload['model'], GlmService.model);
      // Gemini ile tutarlı maliyet tavanı — DeepSeek'in 8192'si DEĞİL.
      expect(payload['max_tokens'], 4096);
      expect(payload['max_tokens'], GlmTransport.maxOutputTokens);
      expect((payload['response_format'] as Map)['type'], 'json_object');
      // Reasoning KAPALI gitmeli (Gemini'deki thinkingBudget: 0 karşılığı):
      // reasoning tokenları görünmez ama çıktı fiyatından faturalanır. Bu
      // satır silinirse maliyet sessizce ~2 katına çıkar. "exclude" DEĞİL —
      // o, model düşünmeye devam ederken yalnızca gizler (bkz.
      // GlmService._reasoningKapali).
      expect((payload['reasoning'] as Map)['effort'], 'none');
    });

    test('prompt kompakt "cards" zarfını ister', () async {
      final service = serviceReturning(
        _glmEnvelope(_cardsPayload([_ornekKart])),
      );

      await service.generateForPage('Kalp kapakları.', 7);

      expect(lastPromptText(), contains('ÇIKTI ZARFI (ZORUNLU)'));
      expect(lastPromptText(), contains('"cards"'));
    });
  });

  group('HTTP hataları', () {
    test('429 isQuota işaretli fırlatır (pipeline işlemi durdurur)', () async {
      final service = serviceReturning(
        jsonEncode({
          'error': {'message': 'rate limited'},
        }),
        statusCode: 429,
      );

      await expectLater(
        service.generateForPage('Kalp kapakları.', 5),
        throwsA(
          isA<FlashcardGenerationException>()
              .having((e) => e.isQuota, 'isQuota', isTrue)
              .having((e) => e.isTimeout, 'isTimeout', isFalse),
        ),
      );
    });

    test('401 mesajı .env\'e YÖNLENDİRMEZ, sunucu tarafını işaret eder', () async {
      final service = serviceReturning(
        jsonEncode({
          'error': {'message': 'invalid key'},
        }),
        statusCode: 401,
      );

      await expectLater(
        service.generateForPage('Kalp kapakları.', 5),
        throwsA(
          isA<FlashcardGenerationException>()
              .having((e) => e.message, 'mesaj', isNot(contains('.env')))
              .having((e) => e.message, 'mesaj', contains('OPENROUTER_API_KEY')),
        ),
      );
    });

    test('400 kota bayrağı taşımaz', () async {
      final service = serviceReturning(
        jsonEncode({
          'error': {'message': 'bozuk istek'},
        }),
        statusCode: 400,
      );

      await expectLater(
        service.generateForPage('Kalp kapakları.', 5),
        throwsA(
          isA<FlashcardGenerationException>().having(
            (e) => e.isQuota,
            'isQuota',
            isFalse,
          ),
        ),
      );
    });
  });

  group('generate() giriş doğrulama', () {
    test('boş girdi reddedilir', () async {
      final service = serviceReturning(_glmEnvelope(_cardsPayload([])));

      await expectLater(
        service.generate('   '),
        throwsA(isA<FlashcardGenerationException>()),
      );
      expect(sent, isEmpty);
    });

    test('kart üretilemezse anlaşılır hata verir', () async {
      final service = serviceReturning(_glmEnvelope(_cardsPayload([])));

      await expectLater(
        service.generate(_validInput),
        throwsA(isA<FlashcardGenerationException>()),
      );
    });

    test('geçerli metinden kart üretir', () async {
      // Yol B'de slaytNumarasi hiç istenmez; modelin o pozisyonu null
      // bırakması beklenir ve sourcePage null kalır.
      final kart = [..._ornekKart]..[7] = null;
      final service = serviceReturning(_glmEnvelope(_cardsPayload([kart])));

      final cards = await service.generate(_validInput);

      expect(cards, hasLength(1));
      expect(cards.single.sourcePage, isNull);
    });
  });
}
