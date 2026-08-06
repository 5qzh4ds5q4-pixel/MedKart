import 'package:flutter/material.dart';

import '../srs/srs_engine.dart';
import '../theme/app_theme.dart';

/// Konu başarı satırı: konu adı + yüzde + renkli ilerleme barı + adet.
///
/// İstatistik ekranı (SRS geçmişinden gelen [TopicStat]) ve Deneme Sınavı
/// sonuç ekranı (sınav cevaplarından kurulan [TopicStat]) ortak kullanır.
/// [unitLabel] adet satırının birimi: istatistikte "kart", sınavda "soru".
class TopicSuccessBar extends StatelessWidget {
  const TopicSuccessBar({
    super.key,
    required this.stat,
    this.unitLabel = 'kart',
    this.showLowDataStates = false,
  });

  final TopicStat stat;
  final String unitLabel;

  /// Az veriyle hesaplanmış yüzdeyi gizleyip yerine etiket göster
  /// ("Az veri" / "Henüz başlanmadı", bkz. [TopicDataState]).
  ///
  /// VARSAYILAN `false` — bilinçli. Deneme Sınavı sonuç ekranı da bu widget'ı
  /// kullanıyor ve orada [TopicStat.attempts] o konudan çıkan SORU sayısıdır;
  /// 3 soruluk bir konuyu "Az veri" diye göstermek sınav sonucunun anlamını
  /// değiştirirdi. Yalnızca istatistik ekranı `true` veriyor.
  final bool showLowDataStates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final state = showLowDataStates
        ? stat.dataState
        // Bayrak kapalıyken eski davranış bit-bit korunur: yalnızca "hiç
        // çalışılmadı" ayrımı vardı, azlık/çokluk ayrımı yoktu.
        : (stat.studied ? TopicDataState.normal : TopicDataState.notStarted);

    // Yüzdesi anlamlı olmayan konular nötr gri: renk bir başarı sinyali,
    // olmayan bir ölçüyü renklendirmek yanıltıcı olurdu.
    final Color barColor = switch (state) {
      TopicDataState.normal => stat.successPercent < 75
          ? scheme.primary
          : AppTheme.successColor(context),
      _ => scheme.outlineVariant,
    };

    final String valueLabel = switch (state) {
      TopicDataState.normal => '%${stat.successPercent}',
      TopicDataState.lowData => 'Az veri',
      TopicDataState.notStarted =>
        showLowDataStates ? 'Henüz başlanmadı' : 'henüz çalışılmadı',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat.topic,
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: state == TopicDataState.normal
                    ? barColor
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state == TopicDataState.normal ? stat.successRate : 0,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${stat.cardCount} $unitLabel',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
