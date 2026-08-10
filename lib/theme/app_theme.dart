import 'package:flutter/material.dart';

/// Uygulamanın TEK görsel kimlik kaynağı: renkler, tipografi skalası ve
/// spacing tokenleri burada tanımlanır. Yeni bir ekran eklerken burada
/// tanımlı token'ları kullan (`Theme.of(context).colorScheme.*`,
/// `Theme.of(context).textTheme.*`, `AppTheme.space*`) — renk/font/padding
/// değerini asla ekran dosyasına sabit yazma (bkz. CLAUDE.md).
///
/// Marka: koyu lacivert zemin + amber vurgu (landing mockup'ından, 2026-07-20).
/// İki tema da AYNI [_build] üzerinden kurulur ki buton ölçüleri, köşe
/// yarıçapları ve tipografi iki modda birebir tutarlı kalsın — yalnızca
/// renk paleti değişir.
class AppTheme {
  const AppTheme._();

  // ==========================================================================
  // Marka vurgu renkleri — her iki modda da AYNI (butonun/rozetin kendisi).
  // Metin olarak kullanılacaksa açık zeminde kontrast için _onLight varyantı
  // var (bkz. [accentAmberOnLight]/[accentPinkOnLight]).
  // ==========================================================================

  /// Birincil vurgu: CTA butonları, aktif durumlar, heatmap yoğunluğu.
  static const Color accentAmber = Color(0xFFF5B83D);

  /// İkincil vurgu: yalnızca el yazısından gelen bilgi rozeti için (bkz.
  /// `HandwrittenIcon`). Genel ikincil eylem rengi DEĞİL — dar semantik.
  static const Color accentPink = Color(0xFFED93B1);

  /// [accentAmber] açık zeminde METİN olarak kullanılırsa (buton/rozet
  /// zemini değil) WCAG AA için koyulaştırılmış hali.
  static const Color accentAmberOnLight = Color(0xFFA35F00);

  /// [accentPink] açık zeminde metin için koyulaştırılmış hali.
  static const Color accentPinkOnLight = Color(0xFFAD3E68);

  /// Başarı/tamamlanma vurgusu: hedefe ulaşma halkası ve onay ikonu.
  /// Amber marka rengiyle ÇAKIŞMASIN diye ayrı bir token — "iyi gidiyorsun"
  /// anlamı taşıyan tek renk bu, genel bir ikincil eylem rengi DEĞİL.
  /// (`colorScheme.tertiary` amber tohumundan türediği için güvenilir bir
  /// yeşil vermiyor, o yüzden elle tanımlandı.)
  static const Color accentGreen = Color(0xFF3DBE6E);

  /// [accentGreen] açık zeminde METİN olarak kullanılırsa kontrast için
  /// koyulaştırılmış hali.
  static const Color accentGreenOnLight = Color(0xFF1E7A45);

  /// Aktif temaya göre doğru yeşil tonunu verir (metin/ikon için).
  static Color successColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? accentGreen
      : accentGreenOnLight;

  // ==========================================================================
  // Koyu palet — birincil kimlik. PUBLIC: landing hero (bkz. `deck_list_
  // screen.dart`'taki `_LandingHero`) bunları BİLİNÇLİ OLARAK tema modundan
  // bağımsız sabit kullanır — marka anı, açık moda geçince rengi değişmez.
  // ==========================================================================
  static const Color heroBackground = Color(0xFF0D1321);
  static const Color heroSurface = Color(0xFF161D2E);
  static const Color heroBorder = Color(0xFF2A3245);
  static const Color heroBorderStrong = Color(0xFF3A4256);
  static const Color heroNeutralFill = Color(0xFF1E2536);
  static const Color textPrimaryDark = Color(0xFFF4F1EA);
  static const Color textSecondaryDark = Color(0xFF9AA3B5);
  static const Color textTertiaryDark = Color(0xFF6B7386);

  // ==========================================================================
  // Açık palet — aynı marka kimliği, açık zeminde okunur kontrastla.
  // Mockup yalnızca koyuyu tarif etti; açık mod burada aynı marka diliyle
  // (sıcak/krem ton, amber+pembe vurgu) TUTARLI kalacak şekilde türetildi.
  // ==========================================================================
  static const Color _surfaceLight = Color(0xFFFAF8F3);
  static const Color _cardSurfaceLight = Color(0xFFFFFFFF);
  static const Color _outlineLight = Color(0xFFE6E1D3);
  static const Color _neutralFillLight = Color(0xFFF1EEE5);
  static const Color _textPrimaryLight = Color(0xFF0D1321);
  static const Color _textSecondaryLight = Color(0xFF5B6472);

  // ==========================================================================
  // Dashboard (koyu mod) vurgu paleti — 2026-08-10, YALNIZCA `DeckListScreen`
  // koyu moddaki dashboard görünümünde kullanılır (bkz. `_DarkDashboardBody`).
  // Kaynak: "medkart koyu mod dashboard" referans tasarımı. Genel marka
  // amber'ıyla ÇAKIŞMASIN diye ayrı token'lar — sayfa/kart zemini hâlâ
  // [heroBackground]/[heroSurface]'ı paylaşıyor, burada yalnızca bu ekrana
  // özel mor/pembe VURGU renkleri ve gradyanlar eklendi. Genel palet
  // (amber) DEĞİŞMEDİ.
  // ==========================================================================
  static const Color dashboardViolet = Color(0xFFD2BBFF);
  static const Color dashboardVioletDeep = Color(0xFF7C3AED);
  static const Color dashboardPink = Color(0xFFFFB0CD);
  static const Color dashboardPinkHot = Color(0xFFEC4899);
  static const Color dashboardOrange = Color(0xFFFFB784);
  static const Color dashboardRed = Color(0xFFFFB4AB);

  /// Ana CTA butonu ("Çalışmaya Başla") için — koyu mor → sıcak pembe.
  static const LinearGradient dashboardCtaGradient = LinearGradient(
    colors: [dashboardVioletDeep, dashboardPinkHot],
  );

  /// İlerleme çubukları için — açık mor → açık pembe (CTA'dan daha soluk).
  static const LinearGradient dashboardProgressGradient = LinearGradient(
    colors: [dashboardViolet, dashboardPink],
  );

  /// Deste kartlarındaki kategori pili renk döngüsü — sırayla kullanılır,
  /// tek bir konuya sabit renk atamaz (yeni konular geldikçe otomatik döner).
  static const List<Color> dashboardCategoryPalette = [
    dashboardOrange,
    dashboardRed,
    dashboardViolet,
    dashboardPink,
  ];

  // ==========================================================================
  // Dashboard (açık mod) yüzey/metin paleti — 2026-08-10, "medcard light
  // mode dashboard" referans tasarımından. Koyu moddaki dashboard'ın
  // [heroBackground]/[heroSurface] ikilisine karşılık gelir, ama AMBIENT
  // açık temanın (`_surfaceLight`, sıcak krem) kendisini YENİDEN KULLANMIYOR
  // — referans tasarım bilinçli olarak soğuk gri-mavi bir zemin istiyor,
  // o yüzden ayrı bir token seti. `dashboardCtaGradient`/
  // `dashboardProgressGradient`/mor-pembe vurgu renkleri İKİ modda da AYNI
  // kalıyor (yukarıdaki `dashboardViolet*`/`dashboardPink*` zaten paylaşılıyor).
  // ==========================================================================
  static const Color dashboardBackground = Color(0xFFF8FAFC);
  static const Color dashboardSurface = Color(0xFFFFFFFF);
  static const Color dashboardSurfaceElevated = Color(0xFFF1F5F9);
  static const Color dashboardSubtleBorder = Color(0xFFE2E8F0);
  static const Color dashboardTextPrimary = Color(0xFF0F172A);
  static const Color dashboardTextMuted = Color(0xFF64748B);

  // ==========================================================================
  // Spacing skalası — 4/8/12/16/24/32. Yeni bir SizedBox/EdgeInsets
  // yazarken rastgele bir sayı yerine bunlardan birini kullan.
  // ==========================================================================
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  /// İçeriğin okunaklı kalması için maksimum satır genişliği.
  /// Geniş ekranda metin uçtan uca yayılmasın diye.
  static const double contentMaxWidth = 760;

  /// Kart-ızgara (dashboard) düzenindeki ekranlar için maksimum genişlik.
  /// [contentMaxWidth] okunacak METİN sütunu içindir; yan yana 4 metrik kartı
  /// 760 px'e sıkıştırmak okunaksız olurdu. Yalnızca ızgara düzeni kullanan
  /// ekranlar (bkz. `StatsScreen`) `ContentShell(maxWidth: ...)` ile bunu
  /// ister — varsayılan hâlâ [contentMaxWidth].
  static const double dashboardMaxWidth = 1240;

  /// Mobilde parmakla rahat basılacak minimum buton yüksekliği.
  static const double minTapHeight = 52;

  static ThemeData get light => _build(
    brightness: Brightness.light,
    surface: _surfaceLight,
    cardSurface: _cardSurfaceLight,
    outline: _outlineLight,
    neutralFill: _neutralFillLight,
    textPrimary: _textPrimaryLight,
    textSecondary: _textSecondaryLight,
    onAccent: Colors.white,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    surface: heroBackground,
    cardSurface: heroSurface,
    outline: heroBorder,
    neutralFill: heroNeutralFill,
    textPrimary: textPrimaryDark,
    textSecondary: textSecondaryDark,
    onAccent: heroBackground,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color surface,
    required Color cardSurface,
    required Color outline,
    required Color neutralFill,
    required Color textPrimary,
    required Color textSecondary,
    required Color onAccent,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: accentAmber,
          brightness: brightness,
        ).copyWith(
          primary: accentAmber,
          onPrimary: onAccent,
          secondary: brightness == Brightness.dark
              ? accentPink
              : accentPinkOnLight,
          surface: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outlineVariant: outline,
          surfaceContainerHighest: neutralFill,
        );

    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: _textTheme(base.textTheme, textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        contentPadding: const EdgeInsets.all(16),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          height: 1.5,
        ),
        border: _inputBorder(outline),
        enabledBorder: _inputBorder(outline),
        focusedBorder: _inputBorder(colorScheme.primary, width: 1.6),
        errorBorder: _inputBorder(colorScheme.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, minTapHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, minTapHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Tipografi skalası (4 kademe). Yeni bir ekran/widget yazarken bunlardan
  /// birini seç, sabit `TextStyle(fontSize: ...)` icat etme:
  /// - **Başlık**: `headlineSmall` (ekran/bölüm başlığı, kart sorusu) veya
  ///   `titleLarge` (büyük rakam/istatistik).
  /// - **Gövde**: `titleMedium` (liste öğesi başlığı), `bodyLarge`/`bodyMedium`
  ///   (okunacak asıl metin).
  /// - **Küçük etiket**: `bodySmall` (ikincil/meta metin), `labelSmall`
  ///   (rozet/ipucu gibi en küçük metin).
  ///
  /// Mobilde ~%10 küçültme [responsiveFontScale] ile `ContentShell` üzerinden
  /// otomatik uygulanır — burada ayrı bir mobil skala tanımlamaya gerek yok.
  static TextTheme _textTheme(
    TextTheme base,
    Color textPrimary,
    Color textSecondary,
  ) {
    // `base` (ThemeData(colorScheme:...).textTheme) her rolü zaten
    // colorScheme.onSurface'tan (== textPrimary) türetiyor; burada yalnızca
    // boyut/ağırlık kademelendirmesi + bodySmall/labelSmall için bilinçli
    // olarak daha soluk bir varsayılan renk ekleniyor (çağıran taraf çoğu
    // yerde zaten kendi onSurfaceVariant'ını veriyor, bu yalnızca güvenli
    // varsayılan).
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
        color: textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.55,
        color: textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.55,
        color: textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.4,
        color: textSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.3,
        color: textSecondary,
      ),
    );
  }
}
