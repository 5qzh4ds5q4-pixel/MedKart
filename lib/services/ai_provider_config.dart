/// Kart üretimi için hangi AI sağlayıcısının kullanılacağı.
enum AiProvider { gemini, deepseek, glm }

/// Geliştirici switch'i — kullanıcıya HİÇ gösterilmez, yalnızca burada elle
/// değiştirilir. `deepseek` yalnızca büyük/hacimli PDF'lerin mekanik akışını
/// (SRS, export, konu seçimi) ucuza/hızlıca test etmek içindir; kart İÇERİK
/// KALİTESİ değerlendirmesi her zaman `gemini` ile yapılmalı (bkz.
/// `DeepSeekService` doc yorumu). Varsayılan: `gemini` — production kullanıcı
/// akışı bunu değiştirmeden asla DeepSeek'e dokunmaz.
///
/// `glm` (2026-08-06) OpenRouter üzerinden `z-ai/glm-4.5v`'ye bağlanır ve
/// DeepSeek'ten farklı olarak GÖRSEL DESTEKLER — yani Yol A'nın vision'a
/// bağlı yetenekleri (el yazısı yakalama, slayt numarası okuma, görsel gömülü
/// tablolar) bu sağlayıcıda da çalışır.
///
/// GLM 2026-08-06'da gerçek PDF'lerle test edildi ve production seçimi
/// OLARAK ALINMADI: klinik vaka kartlarının kalitesi güçlüydü ama el yazısı/
/// vurgu güvenilirliğinde tekrarlayan sorunlar çıktı (yanlış okuma + uydurma,
/// aşırı `elYazisindanMi: true` etiketleme). Altyapısı (`glm_service.dart`,
/// `glm_transport.dart`, `ai-proxy`'nin `glm` dalı) yerinde duruyor ve
/// ileride yeniden değerlendirilebilir — yalnızca aktif seçim değil.
///
const AiProvider activeAiProvider = AiProvider.gemini;
