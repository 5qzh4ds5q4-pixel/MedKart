import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';

/// İçeriği ortalar ve okunaklı bir genişlikte tutar.
///
/// Dar ekranda (telefon) içerik tam genişliği kullanır, geniş ekranda
/// (masaüstü/web) uçtan uca yayılmak yerine ortada toplanır.
///
/// Uygulamanın hemen hemen her ekranı gövdesini bununla sarıyor — bu yüzden
/// tipografinin mobilde küçültülmesi ([responsiveFontScale]) de merkezi
/// olarak burada uygulanıyor; tek tek ekranların kendi font boyutunu
/// ölçeklemesi gerekmiyor.
class ContentShell extends StatelessWidget {
  const ContentShell({
    super.key,
    required this.child,
    this.padding,
    this.shrinkWrapHeight = false,
    this.maxWidth = AppTheme.contentMaxWidth,
  });

  final Widget child;

  /// Verilmezse ekran genişliğine göre otomatik seçilir.
  final EdgeInsets? padding;

  /// İçeriğin ortalanacağı azami genişlik. Varsayılan [AppTheme.contentMaxWidth]
  /// (okunacak metin sütunu). Kart-ızgara düzenindeki ekranlar
  /// [AppTheme.dashboardMaxWidth] verir — bkz. o token'ın yorumu.
  final double maxWidth;

  /// Dikeyde içeriğin boyuna göre küçülsün mü?
  ///
  /// Varsayılan `false` = eski davranış: ortalama widget'ı DİKEYDE DE mevcut
  /// alanın tamamını kaplar. Ekran gövdesi için doğrusu budur.
  ///
  /// `true` VERİLMESİ GEREKEN yer: `Scaffold.bottomNavigationBar` gibi
  /// yüksekliği SINIRLI ama içeriğe göre belirlenmesi gereken slotlar.
  /// Scaffold alt çubuğa "gövde kadar yüksek olabilirsin" diyen bir kısıt
  /// verir; varsayılan davranışta ortalama widget'ı bu izni sonuna kadar
  /// kullanıp TÜM EKRANI kaplar ve gövdeye 0 yükseklik kalır (ekran bomboş
  /// görünür, yalnızca alt çubuğun içeriği ekranın ortasında durur).
  ///
  /// Bir `Column` içindeki alt çubuklarda (bkz. `_StudyBar`,
  /// card_list_screen.dart) bu sorun ÇIKMAZ: Column esnek olmayan
  /// çocuklarına sınırsız dikey kısıt verdiği için ortalama widget'ı zaten
  /// içeriğine göre küçülür. İki yer aynı görünse de kısıt ortamları farklı.
  final bool shrinkWrapHeight;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size) {
        final effectivePadding =
            padding ??
            EdgeInsets.symmetric(
              horizontal: responsiveHorizontalPadding(size),
              vertical: 16,
            );

        final mediaQuery = MediaQuery.of(context);
        final scale = responsiveFontScale(size);

        // `Center` == `Align(alignment: center)`; heightFactor null iken
        // (varsayılan) dikeyde mevcut alanı doldurur, 1.0 iken çocuğunun
        // boyunu alır. Yatay hizalama/genişlik davranışı iki durumda da aynı.
        return Align(
          alignment: Alignment.center,
          heightFactor: shrinkWrapHeight ? 1.0 : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: effectivePadding,
              child: scale == 1.0
                  ? child
                  : MediaQuery(
                      data: mediaQuery.copyWith(
                        textScaler: TextScaler.linear(
                          mediaQuery.textScaler.scale(1) * scale,
                        ),
                      ),
                      child: child,
                    ),
            ),
          ),
        );
      },
    );
  }
}
