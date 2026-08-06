import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/flashcard.dart';

/// [PdfCacheService.lookup] bir HIT döndürdüğünde taşınan sonuç: kartların
/// kendisi + o hash'in şimdiye kadar kaç kez HIT olduğu (kullanıcıya
/// "bu set daha önce N kez çalışıldı" gibi olumlu bir geri bildirim
/// göstermek için, bkz. `AddCardsScreen._showCacheHitFeedback`).
class PdfCacheHit {
  const PdfCacheHit({required this.cards, required this.hitCount});

  final List<Flashcard> cards;

  /// Sunucu tarafında atomik olarak artırılmış güncel HIT sayısı. Artırım
  /// RPC'si beklenmedik şekilde başarısız olursa `null` gelebilir — çağıran
  /// taraf bu durumda sayı GÖSTERMEMELİ (bkz. `_showCacheHitFeedback`).
  final int? hitCount;
}

/// TEST İÇİN — normalde false. true olduğunda [PdfCacheService.lookup] her
/// zaman `null` döner (hash ne olursa olsun Gemini'a her seferinde gidilir)
/// ve [PdfCacheService.save] hiçbir şey yazmaz (test kartları paylaşılan
/// önbelleği kirletmesin). Model karşılaştırma testi bitince false'a al.
///
/// DİKKAT: bu bayrak 5 ve 6 Ağustos'ta iki kez açık unutulup paylaşılan
/// önbelleği sessizce devre dışı bıraktı. `true` bırakırsan
/// `test/pdf_cache_service_test.dart` 5 test KIRMIZI verir — paket yeşile
/// dönmüyorsa ilk bakılacak yer burasıdır.
const bool kDebugBypassCache = false;

/// Paylaşılan PDF→kart önbelleği (`pdf-cache` Edge Function, `pdf_cache`
/// tablosu — TÜM kullanıcılar için ortak, kullanıcıya özel DEĞİL).
///
/// Aynı PDF (SHA-256 hash'i, dosya adından bağımsız) daha önce başka bir
/// öğrenci tarafından işlendiyse, ikinci yükleme Gemini'a hiç gitmeden bu
/// önbellekten anında karşılanır (maliyet optimizasyonu — aynı ders
/// slaytının onlarca öğrenci tarafından ayrı ayrı işlenmesini önler).
///
/// Bilinçli tasarım: bu sınıf HİÇBİR ZAMAN ana PDF→kart akışını
/// engellemez/bozmaz — env eksikse, ağ hatası olursa ya da sunucu 5xx
/// dönerse [lookup] sessizce `null` (önbellek yokmuş gibi devam), [save]
/// sessizce hiçbir şey yapmaz. Kart üretimi tamamen bu servisten bağımsız
/// çalışmaya devam eder.
class PdfCacheService {
  PdfCacheService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Görsel KAPALI (`includeImages: false`) işlemelerin cache anahtarına
  /// eklenen ayırt edici sonek. TEK yerde tanımlı — sihirli string'i başka
  /// yerde tekrarlama, [hashBytes] üzerinden kullan.
  ///
  /// Neden gerekli: aynı PDF'in görselsiz (yalnızca metin) işlenmiş sonucu,
  /// görselli işlenmiş sonuçtan daha zayıftır (el yazısı/highlight/gömülü
  /// tablo yakalanmaz). Sonek olmadan iki mod aynı cache rafını paylaşıyor
  /// ve görselsiz üretilmiş kartlar, görsel isteyen bir kullanıcıya sessizce
  /// servis edilebiliyordu.
  static const String noVisionSuffix = ':novision';

  /// [bytes] içeriğinin SHA-256 hex özeti — dosya ADINDAN bağımsız, yalnızca
  /// içerik bazlı (aynı PDF farklı isimle yüklense de aynı hash'i üretir).
  ///
  /// [includeImages] cache anahtarının PARÇASIDIR: `true` (varsayılan, görsel
  /// dahil) düz özeti döndürür — tüm eski (soneksiz) cache kayıtlarıyla
  /// geriye dönük uyumlu. `false` (görsel kapalı) özete [noVisionSuffix]
  /// ekler; böylece görselsiz üretilmiş sonuçlar kendi ayrı rafında kalır,
  /// iki mod birbirinin sonucunu asla ezmez/servis etmez.
  static String hashBytes(Uint8List bytes, {bool includeImages = true}) {
    final digest = sha256.convert(bytes).toString();
    return includeImages ? digest : '$digest$noVisionSuffix';
  }

  /// [hash] önbellekte varsa üretilmiş kartları (+ HIT sayacını) döner;
  /// yoksa ya da herhangi bir sorun olursa `null` (çağıran taraf normal
  /// pipeline'a devam eder).
  ///
  /// Dönen kartların `id`'si BİLEREK yeniden üretilir (önbellekteki ham
  /// id'ler asla kullanılmaz) — aynı önbellek girdisi birden fazla kez (ör.
  /// aynı kullanıcı iki kez) içe aktarılırsa yerel depoda id çakışması
  /// olmasın diye.
  Future<PdfCacheHit?> lookup(String hash) async {
    if (kDebugBypassCache) return null;

    final functionUrl = _readFunctionUrl();
    final anonKey = _readAnonKey();
    if (functionUrl == null || anonKey == null) return null;

    try {
      final response = await _client
          .post(
            Uri.parse(functionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $anonKey',
              'apikey': anonKey,
            },
            body: jsonEncode({'action': 'lookup', 'hash': hash}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['found'] != true) return null;

      final rawCards = decoded['cards'];
      if (rawCards is! List) return null;

      final stamp = DateTime.now().microsecondsSinceEpoch;
      final cards = <Flashcard>[];
      for (var i = 0; i < rawCards.length; i++) {
        final item = rawCards[i];
        if (item is! Map) continue;
        try {
          final json = Map<String, dynamic>.from(item);
          // `id` KASITLI olarak üzerine yazılıyor — bkz. sınıf yorumu.
          json['id'] = 'cache-$stamp-$i';
          cards.add(Flashcard.fromJson(json));
        } catch (_) {
          // Tek bir bozuk kayıt tüm önbellek isabetini geçersiz kılmasın.
        }
      }
      return PdfCacheHit(cards: cards, hitCount: (decoded['hit_count'] as num?)?.toInt());
    } catch (e) {
      debugPrint('pdf_cache lookup başarısız (önbellek yokmuş gibi devam): $e');
      return null;
    }
  }

  /// [hash] için üretilen [cards]'ı önbelleğe kaydeder (best-effort,
  /// fire-and-forget — başarısızlık kullanıcıya hiç yansımaz).
  ///
  /// [modelVersion]/[promptVersion] yalnızca KAYDEDİLİYOR — ileride
  /// prompt/model güncellenince eski cache girdilerini ayırt edebilmek
  /// için (bkz. `flashcard_prompt.dart` `kPromptVersion` yorumu). Okuma
  /// (lookup) tarafında şu an bu değerlere göre bir filtreleme yok.
  Future<void> save(
    String hash,
    List<Flashcard> cards, {
    String? modelVersion,
    String? promptVersion,
  }) async {
    if (kDebugBypassCache) return;

    final functionUrl = _readFunctionUrl();
    final anonKey = _readAnonKey();
    if (functionUrl == null || anonKey == null) return;

    try {
      await _client
          .post(
            Uri.parse(functionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $anonKey',
              'apikey': anonKey,
            },
            body: jsonEncode({
              'action': 'save',
              'hash': hash,
              'cards': cards.map((c) => c.toJson()).toList(),
              'model_version': modelVersion,
              'prompt_version': promptVersion,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('pdf_cache save başarısız (kartlar yine de kullanıcıya eklendi): $e');
    }
  }

  String? _readFunctionUrl() {
    final url = _readEnv('SUPABASE_URL');
    return url == null ? null : '$url/functions/v1/pdf-cache';
  }

  String? _readAnonKey() => _readEnv('SUPABASE_ANON_KEY');

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
