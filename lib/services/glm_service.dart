import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flashcard.dart';
import 'flashcard_generator.dart';
import 'flashcard_prompt.dart' as prompt;
import 'glm_transport.dart';

/// GLM (`z-ai/glm-4.5v`, OpenRouter üzerinden) bağlanan kart üreticisi.
///
/// DURUM (2026-08-06): yalnızca ALTYAPI. `ai_provider_config.dart`'taki
/// `activeAiProvider` hâlâ `gemini` olduğu için bu sınıf hiçbir kullanıcı
/// akışında koşmuyor ve GERÇEK BİR API ÇAĞRISIYLA HİÇ DOĞRULANMADI —
/// testlerin tamamı sahte (mock) yanıtlarla çalışır.
///
/// Kart içerik/kalite kuralları [GeminiService]/[DeepSeekService] ile BİREBİR
/// aynıdır — üçü de [prompt.buildGeneralPrompt]/[prompt.buildPagePrompt]'tan
/// gelir, burada kopyalanmaz.
///
/// PROTOKOL: OpenAI-uyumlu Chat Completions. DeepSeek'te olduğu gibi
/// `response_format: json_object` kök nesnenin JSON OBJECT olmasını zorunlu
/// kılar (Gemini'nin `responseSchema` gibi dizi şeması yok), bu yüzden
/// kompakt kart dizileri `{"cards": [...]}` zarfı içinde istenir/ayrıştırılır.
///
/// GÖRSEL DESTEKLİ — DeepSeek'ten temel farkı: GLM-4.5V multimodal olduğu için
/// sayfa görüntüsü metinle BİRLİKTE gönderilir. Gemini'nin `inlineData`
/// mantığının OpenAI-stilindeki karşılığı `image_url` + base64 `data:` URI'dır.
/// Bunun sonucu olarak vision'a bağlı prompt blokları (el yazısı işareti,
/// slayt numarası okuma, metin+görsel birleştirme) bu sağlayıcıda da devreye
/// girer — DeepSeek'te hiç girmiyordu.
class GlmService implements FlashcardGenerator {
  GlmService({
    http.Client? client,
    Duration retryBackoff = const Duration(seconds: 1),
    Duration? requestTimeout,
  }) : _transport = GlmTransport(
         client: client,
         retryBackoff: retryBackoff,
         requestTimeout: requestTimeout,
       );

  final GlmTransport _transport;

  /// Model değiştirmek için tek yer burası. OpenRouter'ın `provider/model`
  /// biçimini kullanır (URL'de değil, gövdede taşınır).
  static const String model = 'z-ai/glm-4.5v';

  /// Tek seferde gönderilebilecek not uzunluğu.
  static const int maxSourceLength = 30000;

  /// Modele gönderilebilecek ek dosya türleri (yalnızca görsel).
  ///
  /// PDF KASITLI OLARAK YOK — PDF için tek yol sayfa-bazlı [generateForPage] +
  /// `PdfCardPipeline`'dır (bkz. [GeminiService.allowedMediaTypes]).
  static const Set<String> allowedMediaTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  /// Tek istekte gönderilebilecek toplam ek boyutu (base64 şişmesi için pay).
  static const int maxMediaBytesTotal = 14 * 1024 * 1024;

  /// Tek istekte eklenebilecek en fazla dosya sayısı.
  static const int maxMediaCount = 10;

  /// Kartların hangi zarf içinde isteneceğini belirten sabit talimat. Kart
  /// kalite/kural içeriğini DEĞİL, yalnızca çıktı biçimini etkiler.
  ///
  /// `DeepSeekService._jsonFormatTalimati` ile aynı metin: iki sağlayıcı da
  /// aynı OpenAI-uyumlu `json_object` kısıtına tabi.
  static const String _jsonFormatTalimati = '''

ÇIKTI ZARFI (ZORUNLU):
Yukarıda anlatılan kompakt kart dizilerini bir "cards" alanının içine koy; başka hiçbir metin/açıklama/markdown ekleme:
{"cards": [ ["soru","kisaCevap","cevap","zorlukKodu","kartTipiKodu","oncelikKodu","konu","slaytNumarasi","elYazisindanMi"] ]}
Her kart yine ${prompt.kompaktAlanSayisi} elemanlı bir dizidir ve eleman sırası yukarıdaki SIRA listesindeki gibidir. Hiçbir bilgi üretmeyeceksen "cards": [] döndür.''';

  @override
  Future<List<Flashcard>> generate(
    String sourceText, {
    List<MediaAttachment> media = const [],
  }) async {
    final text = sourceText.trim();

    _validateInput(text, media);

    final hasMedia = media.isNotEmpty;
    final promptText =
        prompt.buildGeneralPrompt(text, hasMedia: hasMedia) +
        _jsonFormatTalimati;

    // OpenAI-uyumlu multimodal içerik: görseller önce, yönerge metni sonra
    // (Gemini'deki parts sıralamasıyla aynı mantık). Görsel yoksa content
    // düz string kalır — gereksiz yere dizi zarfı kurmuyoruz.
    final Object content = hasMedia
        ? <Map<String, dynamic>>[
            for (final m in media)
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:${m.mimeType};base64,${base64Encode(m.bytes)}',
                },
              },
            {'type': 'text', 'text': promptText},
          ]
        : promptText;

    final response = await _send(content);

    if (response.statusCode != 200) {
      throw FlashcardGenerationException(
        _describeHttpError(response),
        isQuota: response.statusCode == 429,
      );
    }

    final cards = _parseCards(response.body);
    if (cards.isEmpty) {
      throw const FlashcardGenerationException(
        'Bu metinden kart üretilemedi. Daha fazla bilgi içeren bir ders notu dene.',
      );
    }
    return cards;
  }

  /// Tek bir PDF sayfasının metni VE görüntüsünden kart üretir.
  ///
  /// [imageBase64] doluysa metinle BİRLİKTE tek istekte gönderilir; metin
  /// terminoloji/tablo yapısı için, görüntü el yazısı not/highlight gibi
  /// metne hiç girmeyen işaretler için kullanılır. `hasImage` prompt'a da
  /// geçirilir — vision'a bağlı kural blokları ancak o zaman devreye girer.
  @override
  Future<List<Flashcard>> generateForPage(
    String pageText,
    int sourcePage, {
    String? imageBase64,
    String imageMimeType = 'image/png',
  }) async {
    final text = pageText.trim();
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;
    // TEŞHİS: sayfaya giren metin uzunluğu + görsel eki var mı.
    print(
      '[GLM s.$sourcePage] giren metin: ${text.length} karakter'
      '${hasImage ? ' + görsel eki' : ''}',
    );
    if (text.isEmpty && !hasImage) {
      print(
        '[GLM s.$sourcePage] metin ve görsel boş → çağrı yapılmadı, [] dönüldü',
      );
      return const [];
    }

    final promptText =
        prompt.buildPagePrompt(text, sourcePage, hasImage: hasImage) +
        _jsonFormatTalimati;

    final Object content = hasImage
        ? <Map<String, dynamic>>[
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$imageMimeType;base64,$imageBase64'},
            },
            {'type': 'text', 'text': promptText},
          ]
        : promptText;

    final response = await _send(content);

    // HTTP başarısızsa gövdeyi ASLA kart JSON'u sanıp ayrıştırmaya kalkma.
    if (response.statusCode != 200) {
      print(
        '[GLM s.$sourcePage] HTTP ${response.statusCode} — '
        'sayfa işlenemedi. Gövde: '
        '${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );
      throw FlashcardGenerationException(
        _describeHttpError(response),
        isQuota: response.statusCode == 429,
      );
    }

    return _parseCards(response.body, sourcePage: sourcePage);
  }

  /// OpenRouter'ın birleşik `reasoning` parametresi — Gemini'deki
  /// `thinkingBudget: 0`'ın karşılığı: model HİÇ reasoning tokenı üretmesin.
  ///
  /// NEDEN: reasoning tokenları görünmezdir ama completion (çıktı) fiyatından
  /// faturalanır. 2026-08-06'da canlı ölçümde, önemsiz bir test prompt'unda
  /// bile 124 çıktı tokenının 82'si (%66) reasoning'di; kapatınca aynı istek
  /// 41 tokena ve $0.00029542 → $0.00014122'ye (~%52 ucuz) düştü.
  ///
  /// `exclude: true` KULLANMA — o, modelin düşünmeye DEVAM edip yalnızca
  /// düşünceyi yanıtta göstermemesi demektir; tokenlar yine üretilir ve yine
  /// faturalanır. Kapatan iki biçim `{'effort': 'none'}` ve
  /// `{'enabled': false}`; ikisi de `z-ai/glm-4.5v` üzerinde canlı denendi ve
  /// birebir aynı sonucu verdi (reasoning_tokens: 0). Dokümanın kanonik
  /// biçimi olduğu için `effort: 'none'` tercih edildi.
  static const Map<String, dynamic> _reasoningKapali = {'effort': 'none'};

  Future<http.Response> _send(Object content) {
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': content},
      ],
      'temperature': 0.4,
      // Maliyet tavanı transport'ta tek yerde tanımlı (bkz.
      // [GlmTransport.maxOutputTokens]) — Gemini ile aynı 4096.
      'max_tokens': GlmTransport.maxOutputTokens,
      'response_format': {'type': 'json_object'},
      'reasoning': _reasoningKapali,
    });
    return _transport.send(body: body);
  }

  /// Metin ve ek girdilerini API'ye göndermeden önce doğrular.
  void _validateInput(String text, List<MediaAttachment> media) {
    if (text.isEmpty && media.isEmpty) {
      throw const FlashcardGenerationException(
        'Önce bir ders notu yapıştır ya da bir görsel ekle.',
      );
    }

    // Yalnızca metin: anlamlı kart için asgari uzunluk beklenir.
    if (media.isEmpty && text.length < 50) {
      throw const FlashcardGenerationException(
        'Metin kart üretmek için çok kısa. Biraz daha uzun bir ders notu yapıştır.',
      );
    }

    if (text.length > maxSourceLength) {
      throw FlashcardGenerationException(
        'Metin çok uzun (${text.length} karakter). '
        'Lütfen en fazla $maxSourceLength karakterlik bir bölüm gönder.',
      );
    }

    if (media.isEmpty) return;

    if (media.length > maxMediaCount) {
      throw FlashcardGenerationException(
        'En fazla $maxMediaCount dosya ekleyebilirsin.',
      );
    }

    var total = 0;
    for (final m in media) {
      if (!allowedMediaTypes.contains(m.mimeType)) {
        throw FlashcardGenerationException(
          '"${m.name}" desteklenmeyen bir dosya türü. '
          'Görsel (PNG/JPG/WebP) ekleyebilirsin.',
        );
      }
      total += m.sizeBytes;
    }
    if (total > maxMediaBytesTotal) {
      throw FlashcardGenerationException(
        'Eklenen dosyalar çok büyük (${(total / (1024 * 1024)).toStringAsFixed(1)} MB). '
        'Toplam ${(maxMediaBytesTotal / (1024 * 1024)).round()} MB sınırını aşma; '
        'daha az ya da daha küçük dosya dene.',
      );
    }
  }

  /// OpenAI biçimli yanıtı hoşgörülü ayrıştırır: `choices[0].message.content`
  /// içindeki metni JSON olarak çözer, `cards` alanını çıkarır.
  ///
  /// SAVUNMACI: gelen hiçbir şeyi tipini kontrol etmeden cast etmez; sorun
  /// olursa NEDENİNİ loglayıp boş liste döner (sayfa "kart üretmedi" sayılır,
  /// tüm işlem etkilenmez). Kartlar tek tek ortak [prompt.flashcardFromItem]
  /// çözücüsünden geçer — kompakt dizi de, eski alan adlı nesne de kabul.
  List<Flashcard> _parseCards(String body, {int? sourcePage}) {
    final tag = sourcePage == null ? '[GLM]' : '[GLM s.$sourcePage]';

    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      print('$tag dış JSON çözülemedi');
      return const [];
    }
    if (decoded is! Map) {
      print('$tag dış JSON Map değil (${decoded.runtimeType})');
      return const [];
    }
    if (decoded['error'] != null) {
      print('$tag gövdede error nesnesi: ${decoded['error']}');
      return const [];
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      print('$tag choices yok/boş');
      return const [];
    }

    final choice = choices.first;
    if (choice is! Map) {
      print('$tag choice Map değil');
      return const [];
    }

    final message = choice['message'];
    if (message is! Map) {
      print('$tag message yok');
      return const [];
    }

    final rawText = message['content'];
    if (rawText is! String || rawText.trim().isEmpty) {
      print('$tag boş içerik (finish_reason=${choice['finish_reason']})');
      return const [];
    }

    Object? inner;
    try {
      inner = jsonDecode(rawText);
    } catch (_) {
      print('$tag iç JSON çözülemedi');
      return const [];
    }
    if (inner is! Map) {
      print('$tag iç JSON Map değil (${inner.runtimeType})');
      return const [];
    }

    final items = inner['cards'];
    if (items is! List) {
      print('$tag "cards" List değil (${items.runtimeType})');
      return const [];
    }

    final cards = <Flashcard>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      final id = sourcePage == null ? '$stamp-$i' : 'p$sourcePage-$i-$stamp';
      final card = prompt.flashcardFromItem(
        items[i],
        id: id,
        sourcePage: sourcePage,
      );
      if (card != null) cards.add(card);
    }
    return cards;
  }

  /// Hata mesajları API anahtarı için ASLA `.env`'e yönlendirmez: OpenRouter
  /// anahtarı istemcide yok, `ai-proxy`'nin `OPENROUTER_API_KEY` Supabase
  /// secret'ında duruyor. Kullanıcının kendi başına düzeltebileceği bir şey
  /// olmadığı için sorun sunucu tarafı olarak ifade edilir.
  String _describeHttpError(http.Response response) {
    // OpenRouter hata gövdesi OpenAI biçimi: {"error": {"message": "...", ...}}
    String? apiMessage;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is Map) {
        apiMessage = (body['error'] as Map)['message'] as String?;
      }
    } catch (_) {
      // Gövde JSON değilse önemli değil, genel mesaja düşeriz.
    }

    switch (response.statusCode) {
      case 400:
        return 'İstek geçersiz. ${apiMessage ?? ''}'.trim();
      case 401:
      case 403:
        return 'Sunucu tarafında API anahtarı sorunu var (OPENROUTER_API_KEY '
            'Supabase secret\'ı yanlış/eksik olabilir). Bu senin '
            'bilgisayarındaki bir ayardan kaynaklanmıyor — geliştiriciye '
            'bildir.';
      case 404:
        return '"$model" modeli bulunamadı. Sunucudaki OpenRouter anahtarının '
            'bu modele erişimi olmayabilir — geliştiriciye bildir.';
      case 429:
        return 'GLM kota/hız limitine takıldın. Biraz bekleyip tekrar dene.';
      case >= 500:
        return 'OpenRouter sunucusunda geçici bir sorun sürüyor (birkaç deneme '
                'yapıldı). Birazdan tekrar dene. ${apiMessage ?? ''}'
            .trim();
      default:
        return 'Kartlar üretilemedi (HTTP ${response.statusCode}). '
            '${apiMessage ?? 'Lütfen tekrar dene.'}';
    }
  }
}
