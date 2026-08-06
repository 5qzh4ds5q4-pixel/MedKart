import 'package:flutter/widgets.dart';

/// Uygulamanın TEK merkezi kırılma noktası tanımı. Her ekran/widget genişliğe
/// göre karar verirken (padding, font, tek/çok sütun, buton genişliği) bunu
/// kullanır — kendi 600/900 sabitini tekrar yazmaz.
///
/// - [mobile]: <600px — tek sütun, tam genişlik buton, küçültülmüş padding/font.
/// - [tablet]: 600-900px — tek sütun ama geniş padding, orta boy font.
/// - [desktop]: >900px — uygunsa çok sütunlu yerleşim, geniş padding.
enum ScreenSize {
  mobile,
  tablet,
  desktop;

  bool get isMobile => this == ScreenSize.mobile;
  bool get isTablet => this == ScreenSize.tablet;
  bool get isDesktop => this == ScreenSize.desktop;

  /// Mobil DEĞİL (tablet ya da masaüstü) — "geniş ekran" kısayolu.
  bool get isAtLeastTablet => this != ScreenSize.mobile;
}

/// Kırılma noktası genişlikleri (px). `width < tabletBreakpoint` tablet,
/// `width < desktopBreakpoint` mobil sayılır — bkz. [screenSizeForWidth].
const double tabletBreakpoint = 600;
const double desktopBreakpoint = 900;

/// Bir genişliği [ScreenSize]'a çevirir. Hem [MediaQuery] genişliği hem
/// [LayoutBuilder] `constraints.maxWidth` ile kullanılabilir.
ScreenSize screenSizeForWidth(double width) {
  if (width < tabletBreakpoint) return ScreenSize.mobile;
  if (width < desktopBreakpoint) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

/// [MediaQuery] üzerinden ekran genişliğine göre [ScreenSize] döner.
/// Bir `LayoutBuilder`'ın içinde değilsen (ör. AppBar, dialog) bunu kullan;
/// bir yerleşimin genişliği ebeveynce kısıtlanıyorsa (ör. bir Card içi)
/// bunun yerine [ResponsiveBuilder]/`constraints.maxWidth` tercih et.
ScreenSize screenSizeOf(BuildContext context) =>
    screenSizeForWidth(MediaQuery.sizeOf(context).width);

/// Üç kırılma noktasına göre bir değer seçer — tekrarlanan
/// `if (isMobile) a else if (isTablet) b else c` bloklarının yerine.
T responsiveValue<T>(
  ScreenSize size, {
  required T mobile,
  required T tablet,
  required T desktop,
}) {
  switch (size) {
    case ScreenSize.mobile:
      return mobile;
    case ScreenSize.tablet:
      return tablet;
    case ScreenSize.desktop:
      return desktop;
  }
}

/// Ekranların gövdesinde kullanılan standart yatay/dikey padding.
/// Mobilde küçük, tablette orta, masaüstünde geniş.
EdgeInsets responsivePagePadding(ScreenSize size) => EdgeInsets.symmetric(
  horizontal: responsiveValue(size, mobile: 16, tablet: 28, desktop: 32),
  vertical: responsiveValue(size, mobile: 12, tablet: 16, desktop: 20),
);

/// Yalnızca yatay padding gerektiğinde (ör. mevcut `ContentShell` deseniyle
/// birebir uyumlu tutmak için).
double responsiveHorizontalPadding(ScreenSize size) =>
    responsiveValue(size, mobile: 16, tablet: 24, desktop: 24);

/// Sabit büyük font boyutlarının mobilde taşmaması için çarpan. Var olan bir
/// `fontSize` değerine çarpılır (`fontSize * responsiveFontScale(size)`).
double responsiveFontScale(ScreenSize size) =>
    responsiveValue(size, mobile: 0.9, tablet: 1.0, desktop: 1.0);

/// Yan yana içerik (iki sütun/grid) için kaç sütun kullanılacağı. Mobilde
/// her zaman 1 (tek sütun); tablet/masaüstünde çağıran ekranın uygun gördüğü
/// sütun sayısı kullanılır (varsayılan: tablet 1, masaüstü 2).
int responsiveColumnCount(
  ScreenSize size, {
  int tablet = 1,
  int desktop = 2,
}) => responsiveValue(size, mobile: 1, tablet: tablet, desktop: desktop);

/// Bir birincil eylem butonunun genişliği: mobilde tam genişlik (ekranı
/// doldurur), tablet/masaüstünde içerik genişliği (`null` → Row/Wrap içinde
/// doğal boyut alır, stretch edilmez).
double? responsiveButtonWidth(ScreenSize size) =>
    size.isMobile ? double.infinity : null;

/// Bir dialog içeriği için güvenli genişlik: [preferredWidth] mümkünse
/// kullanılır, ama ekran onu (kenar boşluklarıyla) sığdıramayacak kadar
/// dar ise (mobil) ekrana göre küçültülür — sabit `SizedBox(width: 420)` gibi
/// değerlerin dar telefonlarda taşmasını önler.
double responsiveDialogWidth(
  BuildContext context, {
  required double preferredWidth,
  double horizontalInset = 40,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final available = screenWidth - horizontalInset;
  return preferredWidth < available ? preferredWidth : available;
}

/// Tekrarlanan `LayoutBuilder(builder: (context, constraints) { final isNarrow
/// = constraints.maxWidth < 600; ... })` deseninin yerine geçen ortak widget.
/// Ebeveyn tarafından kısıtlanan genişliğe göre [ScreenSize] hesaplar ve
/// [builder]'a verir.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          builder(context, screenSizeForWidth(constraints.maxWidth)),
    );
  }
}
