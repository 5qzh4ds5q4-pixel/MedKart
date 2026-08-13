import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flashcard.dart';
import 'flashcard_generator.dart';
import 'flashcard_prompt.dart' as prompt;
import 'gemini_transport.dart';

/// Gemini API'ye bağlanan kart üreticisi: prompt kurma + yanıt ayrıştırma
/// burada, ham ağ isteği [GeminiTransport]'ta (bkz. o dosyanın doc yorumu —
/// backend proxy'ye geçişte değişecek tek yer orası).
class GeminiService implements FlashcardGenerator {
  GeminiService({
    http.Client? client,
    Duration retryBackoff = const Duration(seconds: 1),
    int? thinkingBudget = 0,
  }) : _transport = GeminiTransport(client: client, retryBackoff: retryBackoff),
       _thinkingBudget = thinkingBudget;

  final GeminiTransport _transport;

  /// Modele ayrılan "thinking" token bütçesi. Varsayılan `0` (KAPALI):
  /// ölçümde kart kalitesinde gerileme olmadan (bazı sayfalarda hatta daha
  /// eksiksiz kartlarla) maliyeti ~%55-75 düşürdü — çıktı tokenlarının
  /// büyük kısmı görünmez "thinking" tokenlarıydı ve output fiyatından
  /// ($9/M, girdinin 6 katı) faturalanıyordu. Dinamik/model-varsayılanı
  /// thinking'e dönmek isteyen çağıran açıkça `thinkingBudget: null` versin.
  final int? _thinkingBudget;

  /// `gemini-3.5-flash-lite` `generationConfig.thinkingConfig`'i HİÇ KABUL
  /// ETMİYOR — canlı doğrulandı (2026-08-07, `ai-proxy` üzerinden izole
  /// testlerle): bu alan TEK BAŞINA (responseSchema/responseMimeType hiç
  /// yokken bile) gönderilince 400 `INVALID_ARGUMENT` dönüyor. Diğer
  /// modeller (ör. varsayılan `gemini-3.5-flash`) etkilenmedi, davranış
  /// AYNI kaldı.
  ///
  /// PUBLIC + static tutuluyor ki [model]'in o anki derleme-zamanı sabit
  /// değerinden bağımsız, testler her iki dalı da (`flash-lite` ve diğerleri)
  /// doğrudan doğrulayabilsin — bkz. `test/gemini_service_test.dart`.
  static bool supportsThinkingConfig(String model) =>
      model != 'gemini-3.5-flash-lite';

  Map<String, dynamic>? get _thinkingConfig {
    if (!supportsThinkingConfig(model)) return null;
    return _thinkingBudget == null ? null : {'thinkingBudget': _thinkingBudget};
  }

  /// Model değiştirmek için tek yer burası.
  ///
  /// Not: gemini-2.5-flash yeni API anahtarlarına kapatıldı (404 döner).
  /// Anahtarınızın erişebildiği modelleri görmek için:
  /// GET https://generativelanguage.googleapis.com/v1beta/models
  // MODEL TESTİ: gemini-3.5-flash / gemini-2.5-flash / gemini-2.5-flash-lite arasında değiştir
  static const String model = 'gemini-3.5-flash';

  /// Tek seferde gönderilebilecek not uzunluğu. Aşırı uzun metinleri API'ye
  /// göndermeden önce kullanıcıyı uyarmak için.
  static const int maxSourceLength = 30000;

  /// Modele gönderilebilecek ek dosya türleri (yalnızca görsel).
  ///
  /// PDF KASITLI OLARAK YOK: PDF'ler artık tek başına, tek istekte işlenmiyor
  /// (sourcePage damgalayamıyordu ve çok sayfalı PDF'lerde "5-15 kart" tavanına
  /// çarpıp tabloları/sayısal verileri atlıyordu). PDF için tek yol artık
  /// sayfa-bazlı [generateForPage] + `PdfCardPipeline` — bkz. `AddCardsScreen`
  /// ve `PdfImportScreen`. Buraya bir PDF gelirse [_validateInput] reddeder.
  static const Set<String> allowedMediaTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  /// Tek istekte gönderilebilecek toplam ek boyutu (base64 şişmesi için pay).
  /// Inline veri sınırının altında kalmak için ~14 MB.
  static const int maxMediaBytesTotal = 14 * 1024 * 1024;

  /// Tek istekte eklenebilecek en fazla dosya sayısı.
  static const int maxMediaCount = 10;

  /// Modelin tek yanıtta üretebileceği en fazla token (her iki yolda da aynı).
  ///
  /// MALİYET TAVANI: 8192'den düşürüldü. Çıktı, girdinin 6 katı fiyattan
  /// ($9/M) faturalandığı için sayfa başına en kötü durum maliyetini
  /// belirleyen tek şey bu değerdi — 8192'de tavan ~$0.085/sayfa, 4096'da
  /// ~$0.048/sayfa (tipik sayfa ~$0.019, yani normal kullanım etkilenmiyor:
  /// yoğun bir sayfa 25 kartla bile ~4.000-5.000 token civarında kalıyor).
  ///
  /// 2048 geçmişte yoğun sayfalarda MAX_TOKENS ile boş çıktıya yol açmıştı;
  /// 4096 bunun iki katı güvenlik marjı. Daha da düşürmeden önce yoğun
  /// tablo sayfalarında boş çıktı (finishReason=MAX_TOKENS) olup olmadığını
  /// ölç — [_parsePageCards] bu durumda sessizce boş liste döner.
  static const int maxOutputTokens = 4096;

  /// Gemini'ın döndürmesi gereken şema. `responseSchema` sayesinde model
  /// açıklama/markdown ekleyemez, çıktı her zaman geçerli JSON dizisi olur.
  ///
  /// Şemanın kendisi (alan adları/enum değerleri) [prompt.responseSchema]'da
  /// paylaşılır; burada yalnızca Gemini'a özgü isimle yeniden kullanılır.
  static const Map<String, dynamic> _responseSchema = prompt.responseSchema;

  String _buildPrompt(String sourceText, {required bool hasMedia}) =>
      prompt.buildGeneralPrompt(sourceText, hasMedia: hasMedia);

  @override
  Future<List<Flashcard>> generate(
    String sourceText, {
    List<MediaAttachment> media = const [],
  }) async {
    final text = sourceText.trim();

    _validateInput(text, media);

    // Gemini önerisi: medya parçaları önce, yönerge metni sonra.
    final parts = <Map<String, dynamic>>[
      for (final m in media)
        {
          'inlineData': {'mimeType': m.mimeType, 'data': base64Encode(m.bytes)},
        },
      {'text': _buildPrompt(text, hasMedia: media.isNotEmpty)},
    ];

    final requestBody = jsonEncode({
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
        'temperature': 0.4,
        'maxOutputTokens': maxOutputTokens,
        if (_thinkingConfig != null) 'thinkingConfig': _thinkingConfig,
      },
    });

    final response = await _transport.send(model: model, body: requestBody);

    if (response.statusCode != 200) {
      throw FlashcardGenerationException(
        _describeHttpError(response),
        isQuota: response.statusCode == 429,
      );
    }

    return _parseResponse(response.body);
  }

  /// Tek bir PDF sayfasının metni VE görüntüsünden kart üretir (PDF
  /// pipeline'ı için). [imageBase64] doluysa (normalde her sayfada dolu,
  /// bkz. [pdf_extract.js]) ikisi TEK istekte birlikte gönderilir; metin
  /// terminoloji/tablo yapısı için, görüntü el yazısı not/highlight gibi
  /// metne hiç girmeyen işaretler için kullanılır.
  ///
  /// [generate]'ten farkı: yalnızca bu sayfaya odaklı prompt kullanır, asgari
  /// uzunluk dayatmaz ve sayfada test edilecek bilgi yoksa **hata fırlatmadan
  /// boş liste** döner. HTTP hatasında fırlatır ki pipeline yeniden denesin.
  /// [sourcePage] üretilen kartlara damgalanır.
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
      '[GEMINI s.$sourcePage] giren metin: ${text.length} karakter'
      '${hasImage ? ' + görsel eki' : ''}',
    );
    if (text.isEmpty && !hasImage) {
      print(
        '[GEMINI s.$sourcePage] metin ve görsel boş → çağrı yapılmadı, [] dönüldü',
      );
      return const [];
    }

    final parts = <Map<String, dynamic>>[
      if (hasImage)
        {
          'inlineData': {'mimeType': imageMimeType, 'data': imageBase64},
        },
      {'text': _buildPagePrompt(text, sourcePage, hasImage: hasImage)},
    ];

    final body = jsonEncode({
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
        'temperature': 0.4,
        // Sayfa küçük ama flash modelinde "thinking" tokenları da bu bütçeden
        // harcanır; 2048 dar kalıp boş çıktıya (MAX_TOKENS) yol açabiliyordu.
        // Çalışan tek-not yoluyla aynı headroom'u ver (bkz. [maxOutputTokens]).
        'maxOutputTokens': maxOutputTokens,
        if (_thinkingConfig != null) 'thinkingConfig': _thinkingConfig,
      },
    });

    final response = await _transport.send(model: model, body: body);

    // HTTP başarısızsa gövdeyi ASLA kart JSON'u sanıp ayrıştırmaya kalkma;
    // doğrudan anlaşılır bir hata fırlat (429 kota bayrağıyla).
    if (response.statusCode != 200) {
      print(
        '[GEMINI s.$sourcePage] HTTP ${response.statusCode} — '
        'sayfa işlenemedi. Gövde: '
        '${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );
      throw FlashcardGenerationException(
        _describeHttpError(response),
        isQuota: response.statusCode == 429,
      );
    }

    return _parsePageCards(response.body, sourcePage);
  }

  String _buildPagePrompt(
    String pageText,
    int pageNumber, {
    bool hasImage = false,
  }) => prompt.buildPagePrompt(pageText, pageNumber, hasImage: hasImage);

  /// Sayfa yanıtını hoşgörülü ayrıştırır: sorun olursa (boş/bozuk/güvenlik)
  /// hata fırlatmak yerine boş liste döner — o sayfa yalnızca kart üretmemiş
  /// sayılır, tüm işlem etkilenmez.
  ///
  /// SAVUNMACI: gelen hiçbir şeyi tipini kontrol etmeden cast etmez. Model
  /// beklenen kart dizisi yerine bir nesne/hata döndürürse (List değilse)
  /// sessizce boş liste döner ve nedenini loglar — tip hatası fırlatmaz.
  List<Flashcard> _parsePageCards(String body, int sourcePage) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      print('[PARSE s.$sourcePage] dış JSON çözülemedi');
      return const [];
    }
    if (decoded is! Map) {
      print(
        '[PARSE s.$sourcePage] dış JSON Map değil (${decoded.runtimeType})',
      );
      return const [];
    }

    // Beklenmedik biçimde 200 gövdesinde bir hata nesnesi geldiyse, onu kart
    // sanmadan boş liste dön.
    if (decoded['error'] != null) {
      print('[PARSE s.$sourcePage] gövdede error nesnesi: ${decoded['error']}');
      return const [];
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      print('[PARSE s.$sourcePage] candidates yok/boş');
      return const [];
    }

    final candidate = candidates.first;
    if (candidate is! Map) {
      print('[PARSE s.$sourcePage] candidate Map değil');
      return const [];
    }

    final rawText = _extractText(Map<String, dynamic>.from(candidate));
    if (rawText == null || rawText.trim().isEmpty) {
      print(
        '[PARSE s.$sourcePage] boş metin '
        '(finishReason=${candidate['finishReason']})',
      );
      return const [];
    }

    // Cast ETMEDEN önce ayrıştır ve tipi doğrula: model kart dizisi yerine
    // bir nesne ({...}) ya da fence'li/açıklamalı metin dönebilir.
    Object? inner;
    try {
      inner = jsonDecode(rawText);
    } catch (_) {
      print('[PARSE s.$sourcePage] iç JSON çözülemedi (fence/açıklama?)');
      return const [];
    }
    if (inner is! List) {
      print('[PARSE s.$sourcePage] iç JSON List değil (${inner.runtimeType})');
      return const [];
    }
    final items = inner;

    final cards = <Flashcard>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      final card = prompt.flashcardFromItem(
        items[i],
        id: 'p$sourcePage-$i-$stamp',
        sourcePage: sourcePage,
      );
      if (card != null) cards.add(card);
    }
    return cards;
  }

  /// Metin ve ek girdilerini API'ye göndermeden önce doğrular.
  void _validateInput(String text, List<MediaAttachment> media) {
    if (text.isEmpty && media.isEmpty) {
      throw const FlashcardGenerationException(
        'Önce bir ders notu yapıştır ya da bir görsel/PDF ekle.',
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
          'Görsel (PNG/JPG/WebP) veya PDF ekleyebilirsin.',
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

  String _describeHttpError(http.Response response) {
    // Gemini hata gövdesi: {"error": {"message": "...", "status": "..."}}
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
        return 'Sunucu tarafında API anahtarı sorunu var (Supabase '
            'secret\'ı yanlış/eksik olabilir). Bu senin .env dosyandan '
            'kaynaklanmıyor — geliştiriciye bildir.';
      case 404:
        return '"$model" modeli bulunamadı. '
            'Sunucudaki API anahtarının bu modele erişimi olmayabilir.';
      case 429:
        return 'Gemini kota sınırına takıldın. Biraz bekleyip tekrar dene.';
      case >= 500:
        return 'Gemini sunucusunda geçici bir sorun sürüyor (birkaç deneme '
                'yapıldı). Birazdan tekrar dene. ${apiMessage ?? ''}'
            .trim();
      default:
        return 'Kartlar üretilemedi (HTTP ${response.statusCode}). '
            '${apiMessage ?? 'Lütfen tekrar dene.'}';
    }
  }

  List<Flashcard> _parseResponse(String body) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const FlashcardGenerationException(
        'Gemini\'dan gelen yanıt anlaşılamadı. Lütfen tekrar dene.',
      );
    }

    // İstem güvenlik filtresine takıldıysa candidates hiç gelmez.
    final promptFeedback = decoded['promptFeedback'];
    if (promptFeedback is Map && promptFeedback['blockReason'] != null) {
      throw const FlashcardGenerationException(
        'Bu metin Gemini\'ın güvenlik filtresine takıldı ve işlenemedi. '
        'Farklı bir bölüm deneyebilirsin.',
      );
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FlashcardGenerationException(
        'Gemini bu metinden kart üretemedi. Lütfen tekrar dene.',
      );
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map) {
      throw const FlashcardGenerationException(
        'Gemini beklenmedik biçimde bir yanıt döndürdü. Lütfen tekrar dene.',
      );
    }
    final candidate = Map<String, dynamic>.from(firstCandidate);
    final finishReason = candidate['finishReason'];
    if (finishReason == 'SAFETY' || finishReason == 'PROHIBITED_CONTENT') {
      throw const FlashcardGenerationException(
        'Yanıt güvenlik filtresine takıldı. Farklı bir metin deneyebilirsin.',
      );
    }

    final rawText = _extractText(candidate);
    if (rawText == null || rawText.trim().isEmpty) {
      if (finishReason == 'MAX_TOKENS') {
        throw const FlashcardGenerationException(
          'Metin bu seferlik çok uzun geldi ve yanıt yarıda kesildi. '
          'Daha kısa bir bölüm yapıştırıp tekrar dene.',
        );
      }
      throw const FlashcardGenerationException(
        'Gemini boş yanıt döndürdü. Lütfen tekrar dene.',
      );
    }

    // Cast ETMEDEN önce tipi doğrula: model kart dizisi yerine bir nesne ya da
    // fence'li metin dönebilir; bu durumda ham cast yerine anlaşılır hata ver.
    final Object? inner;
    try {
      inner = jsonDecode(rawText);
    } catch (_) {
      throw const FlashcardGenerationException(
        'Gemini beklenen kart formatında yanıt vermedi. Lütfen tekrar dene.',
      );
    }
    if (inner is! List) {
      throw const FlashcardGenerationException(
        'Gemini beklenen kart formatında yanıt vermedi. Lütfen tekrar dene.',
      );
    }
    final items = inner;

    final cards = <Flashcard>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      final card = prompt.flashcardFromItem(items[i], id: '$stamp-$i');
      if (card != null) cards.add(card);
    }

    if (cards.isEmpty) {
      throw const FlashcardGenerationException(
        'Bu metinden kart üretilemedi. Daha fazla bilgi içeren bir ders notu dene.',
      );
    }

    return cards;
  }

  /// Yanıt metni parts dizisine bölünmüş olabilir; hepsini birleştiriyoruz.
  ///
  /// Modelin düşünce (thought) parçaları da metin taşır ama JSON değildir;
  /// cevaba karışmamaları için atlanır.
  String? _extractText(Map<String, dynamic> candidate) {
    final content = candidate['content'];
    if (content is! Map) return null;

    final parts = content['parts'];
    if (parts is! List) return null;

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      if (part['text'] is String) buffer.write(part['text'] as String);
    }
    return buffer.isEmpty ? null : buffer.toString();
  }
}
