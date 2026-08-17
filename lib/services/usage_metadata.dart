/// Gemini yanıtındaki `usageMetadata` bloğunun okunması ve loglanması.
///
/// NEDEN VAR (2026-08-17): bu tarihe kadar kod tabanında HİÇBİR YERDE token
/// sayımı tutulmuyordu — `GeminiService` yanıttan yalnızca `candidates`
/// okuyup `usageMetadata`'yı atıyordu, `ai-proxy` loglamıyordu ve
/// `kullanim_kota.islenen_sayfa` token değil SAYFA sayıyor. Sonuç: bütün
/// maliyet analizleri karakter→token TAHMİNİNE dayanmak zorunda kaldı ve
/// prompt/model değişikliklerinin gerçek etkisi ölçülemedi.
///
/// ASIL TETİKLEYİCİ [UsageMetadata.cachedTokens]: v28'de prompt ön eki
/// Gemini'ın %90 indirimli ÖRTÜK CONTEXT CACHE'ine uygun hale getirildi
/// (bkz. `flashcard_prompt.dart` `buildPagePrompt` doc yorumu). Cache'in
/// GERÇEKTEN isabet edip etmediğini gösteren tek sinyal bu alan — o yüzden
/// düzeltmeyle AYNI ANDA loglanmaya başlandı, yoksa kör optimizasyon olurdu.
///
/// FİYAT/MALİYET BİLİNÇLİ OLARAK HESAPLANMIYOR: birim fiyatı ($/M token)
/// koda gömmek, bu depodaki diğer sabit rakamların başına gelen "sessizce
/// eskime" sorununu davet ederdi. Burada yalnızca ÖLÇÜLEN token sayıları ve
/// cache isabet ORANI loglanır; dolara çevirmek okuyanın işi.
library;

/// Bir Gemini yanıtının token dökümü.
class UsageMetadata {
  const UsageMetadata({
    required this.promptTokens,
    required this.cachedTokens,
    required this.outputTokens,
    required this.thoughtsTokens,
    required this.totalTokens,
  });

  /// Girdi (prompt) tokenları — önbellekten gelenler DAHİL.
  final int? promptTokens;

  /// [promptTokens]'ın önbellekten karşılanan (%90 indirimli) kısmı.
  /// Gemini bu alanı yalnızca cache isabet ettiğinde döndürür; yoksa 0.
  final int cachedTokens;

  /// Üretilen (çıktı) tokenları. Girdinin 6 katı fiyattan faturalanır.
  final int? outputTokens;

  /// Görünmez "thinking" tokenları. `thinkingBudget: 0` ile bunun 0 kalması
  /// BEKLENİR — sıfırdan büyük bir değer, thinking'in sessizce açıldığını
  /// gösterir (bkz. CLAUDE.md "Thinking modunu açma").
  final int? thoughtsTokens;

  final int? totalTokens;

  /// Girdinin yüzde kaçı önbellekten karşılandı (0-100). Girdi bilinmiyorsa
  /// null.
  int? get cacheHitPercent {
    final p = promptTokens;
    if (p == null || p <= 0) return null;
    return (cachedTokens * 100 / p).round();
  }

  /// Yanıt gövdesinden (çözülmüş JSON) okur. Blok yoksa/bozuksa null döner —
  /// ASLA fırlatmaz, ölçüm kodu üretim akışını bozmamalı.
  static UsageMetadata? tryParse(Map<dynamic, dynamic> decodedBody) {
    final usage = decodedBody['usageMetadata'];
    if (usage is! Map) return null;

    int? read(String key) {
      final v = usage[key];
      return v is num ? v.toInt() : null;
    }

    return UsageMetadata(
      promptTokens: read('promptTokenCount'),
      cachedTokens: read('cachedContentTokenCount') ?? 0,
      outputTokens: read('candidatesTokenCount'),
      thoughtsTokens: read('thoughtsTokenCount'),
      totalTokens: read('totalTokenCount'),
    );
  }

  /// Tek satırlık log biçimi.
  String describe(String etiket) {
    final hit = cacheHitPercent;
    final cacheKisim = cachedTokens > 0
        ? 'cache=$cachedTokens${hit == null ? '' : ' (%$hit)'}'
        : 'cache=YOK';
    final thoughts = thoughtsTokens;
    final thinkingKisim = (thoughts != null && thoughts > 0)
        ? ' thinking=$thoughts(!)'
        : '';
    return '[USAGE $etiket] girdi=${promptTokens ?? '?'} $cacheKisim '
        'çıktı=${outputTokens ?? '?'}$thinkingKisim '
        'toplam=${totalTokens ?? '?'}';
  }
}

/// [UsageMetadata]'yı okuyup loglar. Blok yoksa da bir satır basar — sessiz
/// kalmak "ölçüm var" yanılgısı yaratır.
///
/// NOT: Flutter web'de `print()` sunucu log'una DEĞİL TARAYICI KONSOLUNA
/// gider (bkz. CLAUDE.md "ortam notları") — bu satırları `flutter run`
/// çıktısında arama, DevTools konsolunda ara.
void logUsageMetadata(Map<dynamic, dynamic> decodedBody, String etiket) {
  final usage = UsageMetadata.tryParse(decodedBody);
  if (usage == null) {
    print('[USAGE $etiket] usageMetadata yok (yanıtta blok gelmedi)');
    return;
  }
  print(usage.describe(etiket));
}
