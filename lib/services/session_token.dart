import 'package:supabase_flutter/supabase_flutter.dart';

import 'flashcard_generator.dart';

/// Testlerde gerçek Supabase'e hiç dokunmadan oturum token'ını sabitlemek
/// için. `null` ise (üretimde HER ZAMAN böyledir) gerçek
/// `Supabase.instance.client.auth.currentSession` okunur.
///
/// `require_auth.dart`'taki [debugRequireAuthSignedInOverride] ile AYNI desen:
/// testler `setUp`'ta atayıp `tearDown`'da MUTLAKA `null`'a döndürmeli.
/// Fonksiyon `null` DÖNDÜRÜRSE "oturum yok" demektir (override'ın kendisinin
/// null olmasından farklı) — bu ayrım sayesinde testler hem "girişli" hem
/// "girişsiz" durumu taklit edebilir.
String? Function()? debugSessionAccessTokenOverride;

/// `ai-proxy`'ye gönderilecek `Authorization` token'ının TEK kaynağı.
///
/// **NEDEN ANON KEY DEĞİL:** 2026-08-20'den beri `ai-proxy` kota kimliğini
/// gövdedeki `deviceId`'den değil, bu token'dan çözülen `auth.uid()`'den
/// alıyor ve token'ı doğrulayamazsa isteği **401 ile reddediyor**
/// (fail-closed, bkz. `supabase/functions/ai-proxy/index.ts`). Anon key de
/// geçerli bir JWT'dir ama `sub` (kullanıcı id) claim'i taşımaz — sunucu onu
/// kabul etmez.
///
/// Üç transport (gemini/deepseek/glm) bu yardımcıyı paylaşır ki davranışları
/// BİREBİR aynı kalsın; birine token eklenip diğerine unutulması, o
/// sağlayıcının tüm isteklerinin sessizce 401'e düşmesi demek olurdu.
class SessionToken {
  const SessionToken._();

  /// Geçerli oturumun access token'ı; oturum yoksa (ya da Supabase hiç
  /// başlatılmadıysa) `null`.
  static String? current() {
    final override = debugSessionAccessTokenOverride;
    if (override != null) return override();
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      // Supabase.initialize hiç çağrılmadı (.env eksik) — oturum kavramı yok.
      return null;
    }
  }

  /// Token'ı döner; yoksa kullanıcıya gösterilebilir Türkçe bir hata
  /// FIRLATIR — ağa BOŞ/kimliksiz istek çıkmasın diye.
  ///
  /// Pratikte buraya düşülmemeli: AI çağrısı yapan her akış zaten
  /// `requireAuth` kapısının ardında (bkz. CLAUDE.md "Zorunlu Login / Faz 3").
  /// Bu savunmacı bir dal — oturumun istek sırasında sona ermesi ya da
  /// ileride kapısız bir çağrı noktası eklenmesi gibi durumlar için.
  ///
  /// TASARIM NOTU: [FlashcardGenerationException] `isQuota`/`isTimeout`
  /// bayrakları olmadan fırlatılıyor, yani `PdfCardPipeline` bunu SIRADAN bir
  /// sayfa hatası sayar ve sayfa başına birkaç kez yeniden dener. Denemeler
  /// ağa çıkmadığı için BEDAVA ve hızlı; ama çok sayfalı bir PDF'te "tüm
  /// sayfalar işlenemedi" özeti çıkar. Bunu "kota gibi tüm işlemi durdur"
  /// davranışına çevirmek `FlashcardGenerationException`'a yeni bir bayrak
  /// (ör. `isAuth`) + pipeline'da yeni bir dal gerektirir — bilinçli olarak
  /// yapılmadı, çünkü bu dal `requireAuth` sayesinde pratikte ölü.
  static String require() {
    final token = current();
    if (token == null || token.isEmpty) {
      throw const FlashcardGenerationException(
        'Oturumun bulunamadı ya da süresi dolmuş. Kart üretmek için giriş '
        'yapman gerekiyor — çıkıp tekrar giriş yap.',
      );
    }
    return token;
  }
}
