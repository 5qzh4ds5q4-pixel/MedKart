import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flashcard.dart';
import 'deepseek_transport.dart';
import 'flashcard_generator.dart';
import 'flashcard_prompt.dart' as prompt;

/// ÖNEMLİ: DeepSeek çıktısı SADECE mekanik/hacim testi için kullanılır (PDF
/// işleniyor mu, SRS/export/konu seçimi doğru çalışıyor mu). Kart İÇERİK
/// KALİTESİ hiçbir zaman DeepSeek çıktısına bakılarak değerlendirilmez —
/// kalite kararları sadece Gemini çıktısıyla verilir. Production kullanıcı
/// akışı bu sağlayıcıya hiç dokunmaz (bkz. `ai_provider_config.dart`,
/// varsayılan hep `AiProvider.gemini`).
///
/// DeepSeek (OpenAI uyumlu Chat Completions API) bağlanan kart üreticisi.
/// Kart içerik/kalite kuralları [GeminiService] ile BİREBİR aynıdır — ikisi
/// de [prompt.buildGeneralPrompt]/[prompt.buildPagePrompt]'tan gelir, burada
/// kopyalanmaz. Tek fark, protokolün dayattığı çıktı zarfı: DeepSeek'in
/// `response_format: json_object` modu kök nesnenin JSON OBJECT olmasını
/// zorunlu kılar (Gemini'nin `responseSchema` gibi dizi şeması yok), bu
/// yüzden burada kartlar `{"cards": [...]}" içinde istenir/ayrıştırılır.
///
/// SADECE METİN: DeepSeek vision desteklemiyor; [generate]'e görsel eklenmiş
/// gelirse hemen hata fırlatılır, [generateForPage]'e bir sayfa görüntüsü
/// gelse bile HİÇ gönderilmez (`hasImage` her zaman false).
class DeepSeekService implements FlashcardGenerator {
  DeepSeekService({http.Client? client, Duration retryBackoff = const Duration(seconds: 1)})
    : _transport = DeepSeekTransport(client: client, retryBackoff: retryBackoff);

  final DeepSeekTransport _transport;

  /// `deepseek-chat` (V3) — reasoning modeli `deepseek-reasoner` DEĞİL.
  /// Bilinçli seçim: Gemini'deki `thinkingBudget: 0` (thinking kapalı)
  /// isteğinin DeepSeek karşılığı budur; `deepseek-chat` zaten reasoning
  /// yapmaz, ayrı bir "kapat" parametresi yoktur/gerekmez.
  static const String model = 'deepseek-chat';

  static const int maxSourceLength = 30000;

  /// Kartların DeepSeek'ten hangi zarf içinde isteneceğini belirten sabit
  /// talimat. Kart kalite/kural içeriğini DEĞİL, yalnızca çıktı biçimini
  /// etkiler (bkz. sınıf doc yorumu).
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
    if (media.isNotEmpty) {
      throw const FlashcardGenerationException(
        'DeepSeek görsel/PDF eki desteklemiyor — bu sağlayıcı yalnızca '
        'metinden kart üretir (yalnızca mekanik test amaçlı).',
      );
    }

    final text = sourceText.trim();
    if (text.isEmpty) {
      throw const FlashcardGenerationException(
        'Önce bir ders notu yapıştır.',
      );
    }
    if (text.length < 50) {
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

    final content = prompt.buildGeneralPrompt(text, hasMedia: false) + _jsonFormatTalimati;
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

  /// [imageBase64]/[imageMimeType] imza gereği durur ama DeepSeek'e HİÇ
  /// gönderilmez — bu sağlayıcı metin-only'dir, `hasImage` her zaman false.
  @override
  Future<List<Flashcard>> generateForPage(
    String pageText,
    int sourcePage, {
    String? imageBase64,
    String imageMimeType = 'image/png',
  }) async {
    final text = pageText.trim();
    print('[DEEPSEEK s.$sourcePage] giren metin: ${text.length} karakter (görsel yok sayıldı)');
    if (text.isEmpty) {
      print('[DEEPSEEK s.$sourcePage] metin boş → çağrı yapılmadı, [] dönüldü');
      return const [];
    }

    final content = prompt.buildPagePrompt(text, sourcePage, hasImage: false) + _jsonFormatTalimati;
    final response = await _send(content);

    if (response.statusCode != 200) {
      print('[DEEPSEEK s.$sourcePage] HTTP ${response.statusCode} — '
          'sayfa işlenemedi. Gövde: '
          '${response.body.substring(0, response.body.length.clamp(0, 200))}');
      throw FlashcardGenerationException(
        _describeHttpError(response),
        isQuota: response.statusCode == 429,
      );
    }

    return _parseCards(response.body, sourcePage: sourcePage);
  }

  Future<http.Response> _send(String content) {
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': content},
      ],
      'temperature': 0.4,
      'max_tokens': 8192,
      'response_format': {'type': 'json_object'},
    });
    return _transport.send(body: body);
  }

  /// DeepSeek/OpenAI biçimli yanıtı hoşgörülü ayrıştırır: `choices[0].message
  /// .content` içindeki metni JSON olarak çözer, `cards` alanını çıkarır.
  ///
  /// SAVUNMACI: Gemini tarafındaki disiplinle aynı — gelen hiçbir şeyi tipini
  /// kontrol etmeden cast etmez; sorun olursa boş liste döner.
  List<Flashcard> _parseCards(String body, {int? sourcePage}) {
    final tag = sourcePage == null ? '[DEEPSEEK]' : '[DEEPSEEK s.$sourcePage]';

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
      final card = prompt.flashcardFromItem(items[i], id: id, sourcePage: sourcePage);
      if (card != null) cards.add(card);
    }
    return cards;
  }

  String _describeHttpError(http.Response response) {
    // DeepSeek hata gövdesi OpenAI biçimi: {"error": {"message": "...", ...}}
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
        return 'API anahtarın geçersiz. .env dosyandaki DEEPSEEK_API_KEY '
            'değerini kontrol et.';
      case 404:
        return '"$model" modeli bulunamadı.';
      case 429:
        return 'DeepSeek kota/hız limitine takıldın. Biraz bekleyip tekrar dene.';
      case >= 500:
        return 'DeepSeek sunucusunda geçici bir sorun sürüyor (birkaç deneme '
            'yapıldı). Birazdan tekrar dene. ${apiMessage ?? ''}'.trim();
      default:
        return 'Kartlar üretilemedi (HTTP ${response.statusCode}). '
            '${apiMessage ?? 'Lütfen tekrar dene.'}';
    }
  }
}
