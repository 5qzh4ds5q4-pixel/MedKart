import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'device_id_service.dart';
import 'flashcard_generator.dart';

/// GLM'e (OpenRouter üzerinden `z-ai/glm-4.5v`) giden ağ isteğinden sorumlu
/// tek yer — [GeminiTransport]/[DeepSeekTransport]'ın GLM eşleniği: aynı Edge
/// Function (`ai-proxy`, `provider: 'glm'`) üzerinden proxy'lenir.
///
/// OpenRouter API anahtarı (`OPENROUTER_API_KEY`) İSTEMCİDE HİÇ YOK, yalnızca
/// Edge Function'da Supabase Secret olarak duruyor. Bu sınıf yalnızca herkese
/// açık olması güvenli olan `SUPABASE_URL`/`SUPABASE_ANON_KEY` değerlerini
/// (`.env`) kullanır.
///
/// [DeepSeekTransport]'tan bilinçli ÜÇ GÜVENLİK FARKI ile kuruldu:
///
/// 1. [maxOutputTokens] 4096 (DeepSeek'te 8192) — Gemini ile aynı maliyet
///    tavanı. Sabit burada duruyor çünkü "sağlayıcıya ne kadar para
///    harcayabiliriz" sorusunun cevabı, aşağıdaki zaman aşımı ve yeniden
///    deneme kararlarıyla aynı ailedendir; gövdeyi kuran [GlmService] bu
///    sabiti okur.
/// 2. Zaman aşımı yeniden denemeden AYRI (bkz. [defaultRequestTimeout]) —
///    [GeminiTransport]'taki düzeltmenin birebir aynısı.
/// 3. Hata mesajları API anahtarı için `.env`'e YÖNLENDİRMEZ; anahtar sunucu
///    tarafındadır (bkz. `GlmService._describeHttpError`).
class GlmTransport {
  GlmTransport({
    http.Client? client,
    Duration retryBackoff = const Duration(seconds: 1),
    Duration? requestTimeout,
  }) : _client = client ?? http.Client(),
       _retryBackoff = retryBackoff,
       _requestTimeout = requestTimeout ?? defaultRequestTimeout;

  final http.Client _client;

  /// Tek isteğin yanıt bekleme süresi. Yalnızca testlerde kısaltmak için
  /// enjekte edilir; üretimde her zaman [defaultRequestTimeout].
  final Duration _requestTimeout;

  /// Geçici sunucu hatalarında (5xx/429) denemeler arası temel bekleme.
  /// Testlerde [Duration.zero] verilerek beklemesiz koşturulur.
  final Duration _retryBackoff;

  /// Geçici hatalar (5xx + 429 kota) için toplam deneme sayısı (ilk deneme
  /// dahil). [GeminiTransport.maxAttempts] ile aynı.
  ///
  /// Zaman aşımı bu sayıya DAHİL DEĞİL — bkz. [defaultRequestTimeout].
  static const int maxAttempts = 4;

  /// Tek bir isteğin yanıt bekleme süresi. Aşılırsa
  /// [FlashcardGenerationException] `isTimeout: true` ile fırlatılır ve o
  /// sayfa NE burada NE de `PdfCardPipeline`'da yeniden denenir.
  ///
  /// MALİYET KRİTİK: zaman aşımı "istek başarısız oldu" demek DEĞİL —
  /// yalnızca yanıtı zamanında alamadık demek. Sağlayıcı üretimi tamamlayıp
  /// FATURALAMIŞ olabilir; yeniden denemek aynı sayfa için ikinci/üçüncü kez
  /// ödemek olur. 5xx/429'da ise sağlayıcı üretim yapmadığı için tekrar
  /// denemek bedavadır, o yüzden onlar [maxAttempts] kez denenir.
  static const Duration defaultRequestTimeout = Duration(seconds: 120);

  /// Modelin tek yanıtta üretebileceği en fazla token.
  ///
  /// DeepSeek'teki 8192 DEĞİL, Gemini ile aynı 4096: çıktı tokenları girdinin
  /// katı fiyattan faturalandığı için sayfa başına EN KÖTÜ DURUM maliyetini
  /// belirleyen tek şey bu değerdir. 2048 geçmişte yoğun sayfalarda yanıtın
  /// yarıda kesilmesine yol açmıştı; 4096 bunun iki katı güvenlik marjı.
  static const int maxOutputTokens = 4096;

  /// [body] zaten hazır JSON gövdesidir ([GlmService] tarafından kurulur,
  /// OpenAI-uyumlu `/chat/completions` şemasıyla aynı — proxy'de değişmeden
  /// `payload` olarak OpenRouter'a iletilir).
  ///
  /// `model` zarfa KONULMAZ: OpenRouter'da model adı payload'ın içindedir
  /// (Gemini'de URL path'inde olduğu için oraya ayrıca gönderiliyor).
  Future<http.Response> send({required String body}) async {
    final functionUrl = _readFunctionUrl();
    final anonKey = _readAnonKey();
    final deviceId = await DeviceIdService.getOrCreate();

    final envelope = jsonEncode({
      'provider': 'glm',
      'payload': jsonDecode(body),
      'deviceId': deviceId,
      'pageCount': 1,
    });

    return _sendWithRetry(Uri.parse(functionUrl), anonKey, envelope);
  }

  Future<http.Response> _sendWithRetry(
    Uri uri,
    String anonKey,
    String body,
  ) async {
    for (var attempt = 1; ; attempt++) {
      final http.Response response;
      try {
        response = await _client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $anonKey',
                'apikey': anonKey,
              },
              body: body,
            )
            .timeout(_requestTimeout);
      } on TimeoutException {
        // AYRI YAKALANIR (jenerik "bağlanılamadı" dalına DÜŞMEMELİ): isTimeout
        // bayrağı sayesinde `PdfCardPipeline` bu sayfayı yeniden DENEMEZ.
        // Bkz. [defaultRequestTimeout] ve [FlashcardGenerationException
        // .isTimeout].
        throw FlashcardGenerationException(
          'Sunucudan ${_requestTimeout.inSeconds} saniye içinde yanıt gelmedi; '
          'bu sayfa atlandı. Yeniden denemek maliyeti artırabileceği için '
          'otomatik tekrar yapılmadı — sayfayı tek başına yeniden '
          'işleyebilirsin.',
          isTimeout: true,
        );
      } on http.ClientException catch (e) {
        // Web'de CORS engeli de buraya düşer; tarayıcı ayrıntıyı gizler.
        throw FlashcardGenerationException(
          'Sunucuya bağlanılamadı. İnternet bağlantını kontrol et. '
          '(Ayrıntı: ${e.message})',
        );
      } catch (_) {
        throw const FlashcardGenerationException(
          'Sunucuya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.',
        );
      }

      final transient =
          response.statusCode >= 500 || response.statusCode == 429;
      if (transient && attempt < maxAttempts) {
        // 1x, 2x, 4x ... üstel bekleme.
        await Future<void>.delayed(_retryBackoff * (1 << (attempt - 1)));
        continue;
      }
      return response;
    }
  }

  /// NOT: buradaki `.env` atfı DOĞRU ve kasıtlıdır — `SUPABASE_URL`/
  /// `SUPABASE_ANON_KEY` gerçekten istemcinin `.env` dosyasında durur ve
  /// gizli değildir. Sağlayıcı API anahtarı için `.env`'e yönlendirme YASAK
  /// (o anahtar sunucuda), bkz. `GlmService._describeHttpError`.
  String _readFunctionUrl() {
    final url = _readEnv('SUPABASE_URL');
    if (url == null) {
      throw const FlashcardGenerationException(
        'SUPABASE_URL bulunamadı. Proje kökündeki .env dosyasına ekleyip '
        'uygulamayı yeniden başlat.',
      );
    }
    return '$url/functions/v1/ai-proxy';
  }

  String _readAnonKey() {
    final key = _readEnv('SUPABASE_ANON_KEY');
    if (key == null) {
      throw const FlashcardGenerationException(
        'SUPABASE_ANON_KEY bulunamadı. Proje kökündeki .env dosyasına '
        'ekleyip uygulamayı yeniden başlat.',
      );
    }
    return key;
  }

  String? _readEnv(String key) {
    // .env yüklenememişse dotenv.env erişimi hata fırlatır; onu da yakalıyoruz.
    String? value;
    try {
      value = dotenv.maybeGet(key);
    } catch (_) {
      value = null;
    }
    value = value?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}
