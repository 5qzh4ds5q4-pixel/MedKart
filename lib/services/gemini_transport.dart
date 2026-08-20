import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'device_id_service.dart';
import 'session_token.dart';
import 'flashcard_generator.dart';

/// Gemini'a giden ağ isteğinden sorumlu tek yer: [GeminiService] ürettiği
/// prompt gövdesini burada Supabase Edge Function'ına (`ai-proxy`) sarıp
/// gönderir; zaman aşımı ve geçici hatalarda (5xx/429) üstel backoff ile
/// yeniden deneme de burada. Prompt kurma ve yanıt ayrıştırma burada YOK —
/// onlar [GeminiService]'te kalır ve bu sınıftan bağımsızdır.
///
/// Gemini API anahtarı İSTEMCİDE HİÇ YOK — yalnızca `supabase/functions/
/// ai-proxy` içinde, Supabase Secret olarak sunucuda duruyor. Bu sınıf
/// anahtarı değil, herkese açık olması güvenli olan Supabase proje URL'i +
/// anon anahtarını (`SUPABASE_URL`/`SUPABASE_ANON_KEY`, `.env`'de) kullanır;
/// gerçek yetkilendirme sunucu tarafında (Edge Function + secret) yapılır.
class GeminiTransport {
  GeminiTransport({
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

  /// Geçici sunucu hatalarında (5xx) denemeler arası temel bekleme. Testlerde
  /// [Duration.zero] verilerek beklemesiz koşturulur.
  final Duration _retryBackoff;

  /// Geçici hatalar (5xx + 429 kota) için toplam deneme sayısı (ilk deneme dahil).
  ///
  /// Zaman aşımı bu sayıya DAHİL DEĞİL: 5xx/429'da sağlayıcı üretim yapmadığı
  /// için tekrar denemek bedava, zaman aşımında ise üretim yapılmış olabilir
  /// (bkz. [FlashcardGenerationException.isTimeout]).
  static const int maxAttempts = 4;

  /// Tek bir isteğin yanıt bekleme süresi. Aşılırsa [FlashcardGenerationException]
  /// `isTimeout: true` ile fırlatılır ve o sayfa yeniden denenmez.
  static const Duration defaultRequestTimeout = Duration(seconds: 120);

  /// [model]'e `generateContent` isteği göndermek üzere Edge Function'ı
  /// çağırır; [body] zaten hazır JSON gövdesidir (GeminiService tarafından
  /// kurulur, Gemini'ın beklediği ham şemayla aynı — proxy'de değişmeden
  /// `payload` olarak Gemini'a iletilir).
  Future<http.Response> send({
    required String model,
    required String body,
  }) async {
    final functionUrl = _readFunctionUrl();
    final anonKey = _readAnonKey();
    // KİMLİK: `ai-proxy` artık doğrulanmış bir kullanıcı JWT'si bekliyor ve
    // çözemezse 401 döner (fail-closed). Token yoksa ağa HİÇ çıkmadan burada
    // fırlatılır — sunucuya kimliksiz istek gitmesin.
    final accessToken = SessionToken.require();
    // `deviceId` KİMLİK OLARAK ARTIK KULLANILMIYOR (sunucu görmezden geliyor).
    // Zarfta BİLİNÇLİ olarak bırakıldı: fonksiyonun CANLIDAKİ eski sürümü bu
    // alanı hâlâ ZORUNLU görüyor ve yoksa 400 döndürüyor. İstemci, fonksiyon
    // deploy edilmeden önce yayına girerse bu alan sayesinde çalışmaya devam
    // eder. Deploy tamamlandıktan sonra kaldırılabilir (ayrı, küçük bir iş).
    final deviceId = await DeviceIdService.getOrCreate();

    final envelope = jsonEncode({
      'provider': 'gemini',
      'model': model,
      'payload': jsonDecode(body),
      'deviceId': deviceId,
      'pageCount': 1,
    });

    return _sendWithRetry(
      Uri.parse(functionUrl),
      anonKey,
      accessToken,
      envelope,
    );
  }

  Future<http.Response> _sendWithRetry(
    Uri uri,
    String anonKey,
    String accessToken,
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
                // Authorization = KULLANICI oturum token'ı (anon key DEĞİL):
                // sunucu kota kimliğini buradan çözüyor.
                'Authorization': 'Bearer $accessToken',
                // apikey = anon key olarak KALIR: Supabase API gateway'inin
                // projeyi tanıması için gerekli, kimlik taşımaz.
                'apikey': anonKey,
              },
              body: body,
            )
            .timeout(_requestTimeout);
      } on TimeoutException {
        // AYRI YAKALANIR (jenerik "bağlanılamadı" dalına DÜŞMEMELİ): zaman
        // aşımı, isteğin başarısız olduğu anlamına gelmez — yalnızca yanıtı
        // zamanında alamadığımız. Gemini üretimi tamamlayıp faturalamış
        // olabilir. isTimeout bayrağı sayesinde `PdfCardPipeline` bu sayfayı
        // yeniden DENEMEZ; aksi halde aynı sayfanın üretimi 3 kez faturalanıp
        // sayfa maliyeti üçe katlanabilirdi. Bkz. [FlashcardGenerationException
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

      // Geçici hata (5xx sunucu ya da 429 hız/kota limiti): üstel geri
      // çekilmeyle yeniden dene. Edge Function yukarı akışın (Gemini) HTTP
      // durum kodunu aynen forward ettiği için bu mantık değişmeden çalışır.
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
