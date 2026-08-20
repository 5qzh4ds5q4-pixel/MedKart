import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bir auth işleminin sonucu: başarı/başarısızlık + kullanıcıya gösterilecek
/// Türkçe mesaj. [message] başarısızlıkta hata, başarıda (varsa) bilgi
/// notudur (ör. "doğrulama e-postası gönderildi").
class AuthResult {
  const AuthResult.ok([this.message]) : success = true;
  const AuthResult.fail(String this.message) : success = false;

  final bool success;
  final String? message;
}

/// Supabase Auth sarmalayıcısı — AKTİF, iskelet DEĞİL.
///
/// (DÜZELTME 2026-08-20: bu yorum uzun süre "FAZ 1 — yalnızca iskelet,
/// zorunlu login kapısı YOK, anonim akış aynen sürüyor" diyordu. ESKİMİŞTİ:
/// kapı Faz 3'te geldi ve bugün üretimde çalışıyor.)
///
/// KAPI MODELİ — "bakmak serbest, yapmak üye": uygulama girişsiz açılır ve
/// gezinme/inceleme (deste listesi, kart listesi, istatistik, ayarlar, yasal
/// metinler) tamamen serbesttir. Yalnızca VERİ ÜRETEN / VERİ DIŞARI ÇIKARAN
/// eylemler `requireAuth` ile sarılıdır (bkz. `lib/utils/require_auth.dart`;
/// 18 çağrı noktası: PDF yükleme, kart üretme, deste oluşturma, çalışma,
/// MCQ, deneme sınavı, kart düzenleme, PDF/JSON dışa-içe aktarma).
///
/// AYRICA — 2026-08-20'den beri kimlik yalnızca UI kapısı değil: `ai-proxy`
/// Edge Function'ı `Authorization` başlığındaki oturum token'ını doğruluyor
/// ve çözemezse isteği 401 ile REDDEDİYOR (fail-closed). Kota sayacı da
/// artık cihaz kimliğine değil `auth.uid()`'e bağlı. Yani oturum, kart
/// üretiminin ÖN KOŞULU — bkz. `lib/services/session_token.dart`.
///
/// Supabase `main.dart`'ta .env'deki SUPABASE_URL/ANON_KEY ile başlatılır;
/// .env eksikse uygulama yine açılır, buradaki her işlem kibarca
/// "yapılandırma eksik" mesajı döner ([isConfigured] false).
///
/// E-POSTA AKIŞI = OTP KODU (2026-07-22, magic link'ten çevrildi): şifre YOK.
/// Kullanıcı e-postasını girer → [sendOtpToEmail] 6 haneli kod gönderir
/// (Supabase panelindeki e-posta şablonları {{ .Token }} kullanacak şekilde
/// ayarlandı) → [verifyOtp] kodu doğrular ve oturumu kurar. Kayıt/giriş
/// ayrımı YOK: `signInWithOtp` hesabı yoksa oluşturur (shouldCreateUser
/// varsayılanı true), varsa giriş yapar — tek akış ikisini de kapsar.
///
/// Google OAuth: kod tarafı hazır ([signInWithGoogle]) — Supabase panelinde
/// Google provider'ı + client ID ayarlanınca çalışır, kodda ek değişiklik
/// gerekmez.
class AuthService {
  AuthService({GoTrueClient? auth}) : _authOverride = auth;

  /// Testlerde sahte/yerel bir GoTrue istemcisi enjekte etmek için.
  final GoTrueClient? _authOverride;

  GoTrueClient? get _auth {
    if (_authOverride != null) return _authOverride;
    try {
      return Supabase.instance.client.auth;
    } catch (_) {
      // Supabase.initialize hiç çağrılmadı (.env eksik) — auth kullanılamaz.
      return null;
    }
  }

  /// Supabase başlatıldı mı? False ise tüm işlemler yapılandırma hatası döner.
  bool get isConfigured => _auth != null;

  /// Giriş yapmış kullanıcı; yoksa (ya da Supabase yapılandırılmadıysa) null.
  User? get currentUser => _auth?.currentUser;

  /// Giriş/çıkış olaylarını dinlemek için. Yapılandırma yoksa boş stream.
  Stream<AuthState> get authStateChanges =>
      _auth?.onAuthStateChange ?? const Stream.empty();

  static const String _configMissingMessage =
      'Sunucu yapılandırması eksik — giriş şu an kullanılamıyor.';

  /// [email] adresine 6 haneli tek kullanımlık giriş kodu gönderir.
  ///
  /// Hesap yoksa oluşturulur, varsa mevcut hesaba giriş kodu gider — çağıran
  /// tarafın kayıt/giriş ayrımı yapması gerekmez.
  Future<AuthResult> sendOtpToEmail(String email) async {
    final auth = _auth;
    if (auth == null) return const AuthResult.fail(_configMissingMessage);

    try {
      await auth.signInWithOtp(email: email.trim());
      return const AuthResult.ok(
        '6 haneli doğrulama kodu e-postana gönderildi.',
      );
    } on AuthException catch (e) {
      return AuthResult.fail(_describeAuthError(e));
    } catch (e) {
      return AuthResult.fail(_describeUnknownError(e));
    }
  }

  /// [email] için gönderilen 6 haneli [token] kodunu doğrular; başarılıysa
  /// oturum kurulur ([currentUser] dolar).
  Future<AuthResult> verifyOtp(String email, String token) async {
    final auth = _auth;
    if (auth == null) return const AuthResult.fail(_configMissingMessage);

    try {
      await auth.verifyOTP(
        type: OtpType.email,
        email: email.trim(),
        token: token.trim(),
      );
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(_describeAuthError(e));
    } catch (e) {
      return AuthResult.fail(_describeUnknownError(e));
    }
  }

  /// Google ile giriş — web'de Supabase'in OAuth yönlendirmesini başlatır
  /// (sayfa Google'a gider, dönüşte oturum kurulur; sonuç bu Future'dan
  /// değil [authStateChanges] üzerinden gelir).
  Future<AuthResult> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) return const AuthResult.fail(_configMissingMessage);

    try {
      final started = await auth.signInWithOAuth(OAuthProvider.google);
      if (!started) {
        return const AuthResult.fail(
          'Google girişi başlatılamadı. Lütfen tekrar dene.',
        );
      }
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(_describeAuthError(e));
    } catch (e) {
      return AuthResult.fail(_describeUnknownError(e));
    }
  }

  Future<AuthResult> signOut() async {
    final auth = _auth;
    if (auth == null) return const AuthResult.fail(_configMissingMessage);

    try {
      await auth.signOut();
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(_describeAuthError(e));
    } catch (e) {
      return AuthResult.fail(_describeUnknownError(e));
    }
  }

  /// Supabase'in hata kodlarını kullanıcıya gösterilebilir Türkçe mesaja
  /// çevirir. Kod tanınmıyorsa genel bir mesaja düşer (İngilizce ham mesaj
  /// kullanıcıya hiç gösterilmez).
  String _describeAuthError(AuthException e) {
    switch (e.code) {
      // Supabase yanlış girilen kodu da 'otp_expired' olarak raporlar —
      // ikisini ayırt edemeyiz, mesaj iki olasılığı da söyler.
      case 'otp_expired':
        return 'Kod yanlış ya da süresi dolmuş. Kodu kontrol et veya '
            'yeni kod iste.';
      case 'otp_disabled':
        return 'E-posta ile kod girişi şu an kapalı.';
      case 'invalid_credentials':
        return 'E-posta veya kod hatalı.';
      case 'validation_failed':
      case 'email_address_invalid':
        return 'Geçerli bir e-posta adresi gir.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.';
      case 'user_not_found':
        return 'Bu e-postayla kayıtlı bir hesap bulunamadı.';
      case 'session_expired':
        return 'Oturumun süresi doldu. Tekrar giriş yap.';
      default:
        debugPrint('Auth hatası (code=${e.code}): ${e.message}');
        return 'Giriş işlemi başarısız oldu. Lütfen tekrar dene.';
    }
  }

  String _describeUnknownError(Object e) {
    debugPrint('Auth beklenmedik hata: $e');
    // SocketException/ClientException/Timeout — web'de tarayıcı ağ hataları
    // farklı tiplerle gelebildiği için tipe göre ayırmak yerine tek genel
    // ağ mesajı kullanılır.
    return 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip '
        'tekrar dene.';
  }
}
