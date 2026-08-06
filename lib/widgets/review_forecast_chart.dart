import 'package:flutter/material.dart';

import '../srs/srs_engine.dart';

/// Önümüzdeki 7 günün tekrar yükü — 7 çubuklu basit bar chart.
///
/// Çubuklar düz [Container] (CustomPainter değil): sayı ve gün etiketleri
/// gerçek `Text` widget'ı olarak kalsın istiyoruz — hem ekran okuyucu görüyor
/// hem testler tuvale bakmadan doğrulayabiliyor. Yeni bir charting paketi
/// eklenmedi (bkz. `ExamTrendChart`'taki aynı karar).
class ReviewForecastChart extends StatelessWidget {
  const ReviewForecastChart({super.key, required this.days});

  /// [SrsEngine.reviewForecast] çıktısı; ilk eleman bugün.
  final List<ReviewForecastDay> days;

  /// En yoğun günün çubuğunun piksel yüksekliği; diğerleri buna oranlanır.
  static const double maxBarHeight = 90;

  /// Kartı olmayan (0) günlerde bile görünen ince taban — çubuk alanı boş
  /// kalıp ızgara dağılmasın diye.
  static const double emptyBarHeight = 3;

  /// Yoğun olmayan günlerin çubuk opaklığı (en yoğun gün tam renkte).
  static const double normalBarAlpha = 0.55;

  static const List<String> _weekdayShort = [
    'Pzt',
    'Sal',
    'Çrş',
    'Prş',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static const List<String> _weekdayLong = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  /// Çubuk altındaki kısa etiket: ilk iki gün "Bugün"/"Yarın", sonrası gün adı.
  static String shortLabel(int index, DateTime day) => switch (index) {
    0 => 'Bugün',
    1 => 'Yarın',
    _ => _weekdayShort[day.weekday - 1],
  };

  /// Alt nottaki uzun gün adı ("bugün"/"yarın" özel durumlarıyla).
  static String longLabel(int index, DateTime day) => switch (index) {
    0 => 'bugün',
    1 => 'yarın',
    _ => _weekdayLong[day.weekday - 1],
  };

  /// En yoğun günün index'i; eşitlikte en YAKIN gün kazanır (kullanıcı önce
  /// ona hazırlanmalı). Hiç kart yoksa null.
  static int? busiestIndex(List<ReviewForecastDay> days) {
    int? best;
    for (var i = 0; i < days.length; i++) {
      if (days[i].count == 0) continue;
      if (best == null || days[i].count > days[best].count) best = i;
    }
    return best;
  }

  /// Grafiğin altındaki bağlam cümlesi.
  static String captionFor(List<ReviewForecastDay> days) {
    final busiest = busiestIndex(days);
    if (busiest == null) {
      return 'Önümüzdeki ${days.length} günde tekrara düşecek kart yok.';
    }
    final day = days[busiest];
    return 'En yoğun gün: ${longLabel(busiest, day.day)}, ${day.count} kart.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busiest = busiestIndex(days);
    final maxCount = busiest == null ? 0 : days[busiest].count;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: _Bar(
                    label: shortLabel(i, days[i].day),
                    count: days[i].count,
                    // Oranlama en yoğun güne göre; o gün tam yükseklikte.
                    heightFraction: maxCount == 0 ? 0 : days[i].count / maxCount,
                    isBusiest: i == busiest,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            captionFor(days),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.count,
    required this.heightFraction,
    required this.isBusiest,
  });

  final String label;
  final int count;
  final double heightFraction;
  final bool isBusiest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // En yoğun gün tam amber, diğerleri aynı rengin daha soluk tonu — alt
    // nottaki "en yoğun gün" cümlesi grafikte de karşılık bulsun.
    final barColor = isBusiest
        ? scheme.primary
        : scheme.primary.withValues(alpha: ReviewForecastChart.normalBarAlpha);

    final height = count == 0
        ? ReviewForecastChart.emptyBarHeight
        : (heightFraction * ReviewForecastChart.maxBarHeight).clamp(
            ReviewForecastChart.emptyBarHeight,
            ReviewForecastChart.maxBarHeight,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: isBusiest ? FontWeight.w700 : FontWeight.w500,
            color: count == 0 ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: count == 0 ? scheme.outlineVariant : barColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
