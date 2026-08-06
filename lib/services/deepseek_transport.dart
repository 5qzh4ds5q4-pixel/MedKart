import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'device_id_service.dart';
import 'flashcard_generator.dart';

/// DeepSeek'e giden ağ isteğinden sorumlu tek yer — [GeminiTransport]'ın
/// DeepSeek eşleniği: aynı Edge Function (`ai-proxy`, `provider: 'deepseek'`)
/// üzerinden proxy'lenir, aynı retry/backoff disiplini.
///
/// SADECE mekanik/hacim testi için var (bkz. [DeepSeekService] doc yorumu).
/// DeepSeek API anahtarı da İSTEMCİDE HİÇ YOK, yalnızca Edge Function'da
/// Supabase Secret olarak duruyor.
class DeepSeekTransport {
  DeepSeekTransport({
    http.Client? client,
    Duration retryBackoff = const Duration(seconds: 1),
  }) : _client = client ?? http.Client(),
       _retryBackoff = retryBackoff;

  final http.Client _client;
  final Duration _retryBackoff;

  /// [GeminiTransport.maxAttempts] ile aynı: geçici hatalarda toplam deneme
  /// sayısı (ilk deneme dahil).
  static const int maxAttempts = 4;

  /// [body] zaten hazır JSON gövdesidir (DeepSeekService tarafından kurulur,
  /// DeepSeek'in `/chat/completions` şemasıyla aynı — proxy'de değişmeden
  /// `payload` olarak iletilir).
  Future<http.Response> send({required String body}) async {
    final functionUrl = _readFunctionUrl();
    final anonKey = _readAnonKey();
    final deviceId = await DeviceIdService.getOrCreate();

    final envelope = jsonEncode({
      'provider': 'deepseek',
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
            .timeout(const Duration(seconds: 120));
      } on http.ClientException catch (e) {
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
