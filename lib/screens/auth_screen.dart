import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../content/legal_content.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../state/flashcard_store.dart';
import '../utils/breakpoints.dart';
import '../widgets/content_shell.dart';
import 'legal_screen.dart';

/// Giriş ekranı (FAZ 1 — iskelet, OTP kodu akışı).
///
/// Şifre YOK; iki adım: (1) e-posta gir → "Kod Gönder", (2) e-postaya gelen
/// 6 haneli kodu gir → "Doğrula" (bkz. [AuthService.sendOtpToEmail]/
/// [AuthService.verifyOtp]). Kayıt/giriş ayrımı yok — hesap yoksa kod
/// doğrulanınca oluşur. "Google ile devam et" ayrıca durur.
///
/// Zorunlu kapı DEĞİL: yalnızca Ayarlar'daki "Hesap" girişinden açılır,
/// anonim akışa dokunmaz. Renk/tipografi tema token'larından
/// (`Theme.of(context)`, bkz. lib/theme/app_theme.dart); sabit renk yok.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService, this.reason});

  /// Testlerde sahte servis enjekte etmek için; verilmezse gerçek servis.
  final AuthService? authService;

  /// Bu ekranın hangi eylemden tetiklendiğini açıklayan kısa mesaj (bkz.
  /// `requireAuth`). Verilmezse (ör. profil baloncuğundan doğrudan açılınca)
  /// hiçbir ek mesaj gösterilmez.
  final String? reason;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// "Kodu tekrar gönder" bekleme süresi.
const int _resendCooldownSeconds = 60;

enum _OtpStep { email, code }

class _AuthScreenState extends State<AuthScreen> {
  late final AuthService _auth = widget.authService ?? AuthService();
  final SyncService _sync = SyncService();

  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  _OtpStep _step = _OtpStep.email;
  bool _loading = false;
  String? _error;
  String? _info;

  /// Yasal onay kutusu — varsayılan olarak İŞARETSİZ (kullanıcı bilinçli
  /// olarak işaretlemeden "Kod Gönder"/"Google ile devam et" çalışmaz).
  bool _legalAccepted = false;

  late final TapGestureRecognizer _termsTapRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalScreen(
      LegalContent.termsOfServiceTitle,
      LegalContent.termsOfService,
    );
  late final TapGestureRecognizer _privacyTapRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalScreen(
      LegalContent.privacyPolicyTitle,
      LegalContent.privacyPolicy,
    );

  /// "Kodu tekrar gönder" için kalan saniye; 0 ise buton aktif.
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Google OAuth dönüşü gibi form dışı oturum değişikliklerinde ekran
    // kendini tazelesin (giriş yapılmış görünüme geçsin).
    _authSub = _auth.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  void _openLegalScreen(String title, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalScreen(title: title, content: content),
      ),
    );
  }

  void _showConsentRequiredWarning() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Devam etmek için koşulları kabul etmelisin.'),
        ),
      );
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  /// Adım 1: e-postaya 6 haneli kodu gönder. [isResend] true ise kod
  /// adımından "tekrar gönder" ile çağrılmıştır — adım değişmez.
  Future<void> _sendCode({bool isResend = false}) async {
    if (!isResend && !(_emailFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_legalAccepted) {
      _showConsentRequiredWarning();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await _auth.sendOtpToEmail(_emailController.text);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        _step = _OtpStep.code;
        _info = result.message;
        _codeController.clear();
      } else {
        _error = result.message;
      }
    });
    if (result.success) _startResendCooldown();
  }

  /// Adım 2: girilen 6 haneli kodu doğrula, oturumu kur.
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = '6 haneli kodu eksiksiz gir.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await _auth.verifyOtp(_emailController.text, code);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!result.success) _error = result.message;
    });

    final signedInUser = _auth.currentUser;
    if (result.success && signedInUser != null && mounted) {
      if (_legalAccepted) {
        await _sync.recordLegalConsent(signedInUser.id, LegalContent.version);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Giriş yapıldı.')));
      // `true` ile dönülür ki `requireAuth` bunu görüp tetikleyen eylemi
      // otomatik devam ettirebilsin.
      Navigator.of(context).pop(true);
    }
  }

  /// Kod adımından e-posta adımına geri dön (adres düzeltme).
  void _backToEmail() {
    setState(() {
      _step = _OtpStep.email;
      _error = null;
      _info = null;
      _codeController.clear();
    });
  }

  Future<void> _googleSignIn() async {
    if (!_legalAccepted) {
      _showConsentRequiredWarning();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await _auth.signInWithGoogle();

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        // Web'de sayfa Google'a yönlenir; oturum dönüşte kurulur.
        _info = 'Google girişine yönlendiriliyorsun…';
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    final result = await _auth.signOut();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.success ? null : result.message;
    });
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta adresini gir.';
    // Kaba bir biçim kontrolü; asıl doğrulama sunucuda.
    if (!email.contains('@') || !email.contains('.')) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    return null;
  }

  /// Cihazda zaten kart var mı (anonim kullanım sonrası girişte "mevcut
  /// kartların hesabına aktarılacak" notu için). `FlashcardStore` bu ekranın
  /// üstünde (ör. bir testte) hiç sağlanmamışsa sessizce `false` döner.
  bool _hasLocalCards(BuildContext context) {
    try {
      return context.read<FlashcardStore>().cards.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// [widget.reason] + (varsa) "mevcut kartların aktarılacak" notu. Reason
  /// yoksa (profil baloncuğundan doğrudan açılış) null — ek mesaj gösterilmez.
  String? _reasonMessage(BuildContext context) {
    final reason = widget.reason;
    if (reason == null) return null;
    if (!_hasLocalCards(context)) return reason;
    return '$reason\n\nMevcut kartların hesabına aktarılacak.';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Hesap')),
      body: SafeArea(
        child: ContentShell(
          child: user != null
              ? _buildSignedIn(user)
              : (_step == _OtpStep.email ? _buildEmailStep() : _buildCodeStep()),
        ),
      ),
    );
  }

  /// Giriş yapılmış görünüm: hesap bilgisi + çıkış.
  Widget _buildSignedIn(User user) {
    final theme = Theme.of(context);

    return ResponsiveBuilder(
      builder: (context, size) => ListView(
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.account_circle_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Giriş yapıldı',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            user.email ?? user.id,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            _MessageBox(text: _error!, isError: true),
          ],
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: responsiveButtonWidth(size),
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Adım 1: e-posta gir → kod gönder (+ Google seçeneği).
  Widget _buildEmailStep() {
    final theme = Theme.of(context);
    final reasonMessage = _reasonMessage(context);

    return ResponsiveBuilder(
      builder: (context, size) => ListView(
        children: [
          const SizedBox(height: 16),
          Text('Giriş Yap', style: theme.textTheme.headlineSmall),
          if (reasonMessage != null) ...[
            const SizedBox(height: 12),
            _MessageBox(text: reasonMessage, isError: false),
          ],
          const SizedBox(height: 4),
          Text(
            'E-posta adresine 6 haneli bir giriş kodu göndereceğiz — '
            'şifre gerekmez. Hesabın yoksa otomatik oluşturulur.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _emailFormKey,
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: _validateEmail,
              onFieldSubmitted: (_) => _loading ? null : _sendCode(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            _MessageBox(text: _error!, isError: true),
          ],
          if (_info != null) ...[
            const SizedBox(height: 20),
            _MessageBox(text: _info!, isError: false),
          ],
          const SizedBox(height: 20),
          _LegalConsentCheckbox(
            value: _legalAccepted,
            enabled: !_loading,
            onChanged: (value) => setState(() => _legalAccepted = value),
            termsTapRecognizer: _termsTapRecognizer,
            privacyTapRecognizer: _privacyTapRecognizer,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: responsiveButtonWidth(size),
              child: FilledButton(
                onPressed: _loading ? null : _sendCode,
                style: _legalAccepted
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kod Gönder'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'veya',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: responsiveButtonWidth(size),
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _googleSignIn,
                style: _legalAccepted
                    ? null
                    : OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                // Marka logosu asset'i eklemeden nötr bir ikon; Google'ın
                // resmî butonu istenirse asset Faz 3'te (zorunlu kapı) gelir.
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Google ile devam et'),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Adım 2: gelen 6 haneli kodu gir → doğrula.
  Widget _buildCodeStep() {
    final theme = Theme.of(context);
    final canResend = !_loading && _resendCooldown <= 0;

    return ResponsiveBuilder(
      builder: (context, size) => ListView(
        children: [
          const SizedBox(height: 16),
          Text('Kodu Gir', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${_emailController.text.trim()} adresine gönderilen 6 haneli '
            'kodu gir.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // 6 haneli kod alanı: büyük, aralıklı, ortalanmış rakamlar.
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 260,
              child: TextField(
                controller: _codeController,
                enabled: !_loading,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '______',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loading ? null : _verifyCode(),
                onChanged: (value) {
                  // 6. rakam girilince beklemeden doğrula.
                  if (value.length == 6 && !_loading) _verifyCode();
                },
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            _MessageBox(text: _error!, isError: true),
          ],
          if (_info != null) ...[
            const SizedBox(height: 20),
            _MessageBox(text: _info!, isError: false),
          ],
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: responsiveButtonWidth(size),
              child: FilledButton(
                onPressed: _loading ? null : _verifyCode,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Doğrula'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: canResend ? () => _sendCode(isResend: true) : null,
              child: Text(
                _resendCooldown > 0
                    ? 'Kodu tekrar gönder (${_resendCooldown}s)'
                    : 'Kodu tekrar gönder',
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _loading ? null : _backToEmail,
              child: const Text('E-posta adresini değiştir'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Hata (errorContainer) ya da bilgi (surfaceContainerHighest) kutusu.
class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isError ? scheme.onErrorContainer : scheme.onSurface,
        ),
      ),
    );
  }
}

/// "Kullanım Koşulları'nı ve Gizlilik Politikası'nı okudum, kabul
/// ediyorum..." onay kutusu — "Kullanım Koşulları"/"Gizlilik Politikası"
/// kelimeleri tıklanabilir (amber, `colorScheme.primary`) link; düz metin
/// kısımları bilinçli olarak tıklamaya tepki vermiyor (link tıklamasıyla
/// karışıp gesture arena çakışması yaratmasın diye) — kutuyu işaretlemenin
/// tek yolu [Checkbox]'ın kendisi.
///
/// Varsayılan olarak İŞARETSİZ gelmeli — çağıran taraf ([value]) bunu
/// garanti eder, bu widget kendi başına hiçbir zaman true ile başlamaz.
class _LegalConsentCheckbox extends StatelessWidget {
  const _LegalConsentCheckbox({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.termsTapRecognizer,
    required this.privacyTapRecognizer,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final TapGestureRecognizer termsTapRecognizer;
  final TapGestureRecognizer privacyTapRecognizer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final linkStyle = bodyStyle?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: enabled ? (v) => onChanged(v ?? false) : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text.rich(
              TextSpan(
                style: bodyStyle,
                children: [
                  TextSpan(
                    text: 'Kullanım Koşulları',
                    style: linkStyle,
                    recognizer: enabled ? termsTapRecognizer : null,
                  ),
                  const TextSpan(text: "'nı ve "),
                  TextSpan(
                    text: 'Gizlilik Politikası',
                    style: linkStyle,
                    recognizer: enabled ? privacyTapRecognizer : null,
                  ),
                  const TextSpan(
                    text: "'nı okudum, kabul ediyorum. Verilerimin "
                        'hizmetin çalışması için gerekli yurt dışı '
                        'sunuculara aktarılmasına açık rıza gösteriyorum.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
