import 'package:flutter/material.dart';

import '../models/study_log.dart';
import '../theme/app_theme.dart';
import 'horizontal_wheel_scroll.dart';

/// Bir günün çalışma yoğunluk kademesi.
enum HeatLevel {
  /// Hiç çalışılmamış gün.
  none,

  /// Az sayıda kart (bkz. [StudyHeatmap.lowMinCount]).
  low,

  /// Orta yoğunluk (bkz. [StudyHeatmap.mediumMinCount]).
  medium,

  /// Yoğun gün (bkz. [StudyHeatmap.highMinCount]).
  high,
}

/// GitHub katkı grafiği tarzı çalışma takvimi: her kare bir gün, rengi o gün
/// çalışılan kart sayısıyla koyulaşır. Haftalar sütun, günler satır (Pzt üstte).
///
/// Yatay kaydırılabilir; en yeni hafta sağda ve başlangıçta görünür.
///
/// Yoğunluk MUTLAK eşiklere göre belirlenir ([levelFor]) — görünür aralıktaki
/// en yüksek güne göre GÖRELİ değil. Göreli ölçekte günde 3 kart çalışan biri
/// de günde 60 kart çalışan biri de en koyu tonu görürdü; mutlak eşik "yoğun
/// gün" ifadesini kullanıcılar arasında ve zaman içinde tutarlı kılar.
class StudyHeatmap extends StatelessWidget {
  const StudyHeatmap({
    super.key,
    required this.log,
    required this.now,
    this.weeks = defaultWeeks,
  });

  final StudyLog log;
  final DateTime now;

  /// Gösterilecek EN FAZLA hafta sayısı (sütun).
  ///
  /// Gerçek sütun sayısı bundan az olabilir: ızgara kullanıcının İLK ÇALIŞMA
  /// GÜNÜNDEN bugüne kadar uzanır (bkz. [weeksToShow]). 2 günlük bir hesaba
  /// 84 boş kare göstermek "burada bir şey eksik" hissi veriyordu.
  final int weeks;

  /// Varsayılan üst sınır: 12 hafta = 84 gün.
  static const int defaultWeeks = 12;

  // ---- Yoğunluk eşikleri (kart/gün) ----
  // Ayarlamak için yalnızca bu üç sayı yeter; renk seçimi [levelFor]
  // üzerinden tek yerden akar.

  /// Bu sayıdan az kart = hiç çalışılmamış sayılır.
  static const int lowMinCount = 1;

  /// "Orta" kademenin başladığı kart sayısı.
  static const int mediumMinCount = 10;

  /// "Yoğun" kademenin başladığı kart sayısı.
  static const int highMinCount = 25;

  // ---- Yoğunluk skalasındaki interpolasyon noktaları (0=açık violet,
  // 1=koyu pembe) — "low"/"medium" bu skalanın arasında bir nokta, "high"
  // skalanın ucu.
  static const double _lowT = 0.33;
  static const double _mediumT = 0.66;

  static const double _cell = 14;
  static const double _gap = 4;

  /// Bir günün kart sayısını yoğunluk kademesine çevirir (saf fonksiyon).
  static HeatLevel levelFor(int count) {
    if (count < lowMinCount) return HeatLevel.none;
    if (count < mediumMinCount) return HeatLevel.low;
    if (count < highMinCount) return HeatLevel.medium;
    return HeatLevel.high;
  }

  /// Kademenin rengini verir — sabit renk YOK, hepsi `AppTheme` dashboard
  /// token'ı. 2026-08-11 amber/gold temizliği: eskiden `scheme.primary`
  /// (uygulamanın amber marka rengi) kullanıyordu; artık açık violet'ten
  /// koyu pembeye giden bir skala (`AppTheme.dashboardViolet` →
  /// `AppTheme.dashboardPinkHot`) — dashboard'un CTA gradyanıyla (`AppTheme.
  /// dashboardCtaGradient`) AYNI iki renk ailesi, burada alfa yerine gerçek
  /// renk interpolasyonu kullanılıyor çünkü "az/çok" ekseni artık tek bir
  /// rengin koyuluğu DEĞİL, iki rengin arası.
  static Color colorForLevel(HeatLevel level, {required bool isDark}) {
    final empty = isDark ? AppTheme.heroNeutralFill : AppTheme.dashboardSurfaceElevated;
    return switch (level) {
      HeatLevel.none => empty,
      HeatLevel.low =>
        Color.lerp(AppTheme.dashboardViolet, AppTheme.dashboardPinkHot, _lowT)!,
      HeatLevel.medium =>
        Color.lerp(AppTheme.dashboardViolet, AppTheme.dashboardPinkHot, _mediumT)!,
      HeatLevel.high => AppTheme.dashboardPinkHot,
    };
  }

  /// Bir günün kare anahtarı — testler belirli bir günü bununla bulur.
  static ValueKey<String> dayKey(DateTime day) => ValueKey(
    'heatmap-${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}',
  );

  /// Bugünü işaretleyen halkanın anahtarı (ızgarada yalnızca bir tane olur).
  static const ValueKey<String> todayRingKey = ValueKey('heatmap-today-ring');

  /// [log] ve [today] için gerçekte çizilecek hafta sayısı.
  ///
  /// İlk çalışma gününün haftasından bugünün haftasına kadar; en az 1, en
  /// fazla [maxWeeks]. Hiç çalışma yoksa null (o durumda ızgara değil boş
  /// durum mesajı gösterilir).
  static int? weeksToShow(
    StudyLog log,
    DateTime today, {
    int maxWeeks = defaultWeeks,
  }) {
    final first = log.firstStudyDay;
    if (first == null) return null;

    final firstDay = DateTime(first.year, first.month, first.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final currentMonday = todayDay.subtract(
      Duration(days: todayDay.weekday - 1),
    );

    // Hafta farkı + 1 = kapsanan hafta sayısı. Yaz saati kaymalarına karşı
    // gün farkını 7'ye bölerken yuvarlanıyor.
    final spanWeeks =
        (currentMonday.difference(firstMonday).inDays / 7).round() + 1;
    return spanWeeks.clamp(1, maxWeeks);
  }

  @override
  Widget build(BuildContext context) {
    // Hiç çalışma kaydı yoksa boş bir ızgara göstermek yerine teşvik et:
    // yeni kullanıcıya 84 boş kare "burada bir şey eksik" hissi veriyor.
    if (log.total == 0) return const _HeatmapEmptyState();

    final theme = Theme.of(context);
    final today = DateTime(now.year, now.month, now.day);
    // Izgara ilk çalışma gününden bugüne uzanır (üst sınır [weeks]).
    final shownWeeks = weeksToShow(log, today, maxWeeks: weeks) ?? weeks;
    // Bu haftanın Pazartesi'si.
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = currentMonday.subtract(
      Duration(days: (shownWeeks - 1) * 7),
    );

    final columns = <Widget>[
      for (var w = 0; w < shownWeeks; w++)
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: Column(
            children: [
              for (var d = 0; d < 7; d++)
                _dayCell(
                  theme,
                  day: firstMonday.add(Duration(days: w * 7 + d)),
                  today: today,
                ),
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Karelerin ne anlama geldiğini bir cümlede söyle — ızgara kendi
        // başına okunmuyordu.
        Text(
          'Her kare bir gün. Ne kadar soluk, o kadar az çalışılmış; '
          'ne kadar koyu, o kadar çok.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        HorizontalWheelScroll(
          reverse: true, // en yeni hafta başta görünür
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: columns,
          ),
        ),
        const SizedBox(height: 8),
        // Izgaranın hangi tarih aralığını kapsadığı.
        Text(
          '${_rangeLabel(firstMonday)} - ${_rangeLabel(today)}',
          textAlign: TextAlign.end,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        _Legend(),
      ],
    );
  }

  Widget _dayCell(
    ThemeData theme, {
    required DateTime day,
    required DateTime today,
  }) {
    // Gelecek günler: boş yer tutucu (hizayı korur, görünmez, tıklanmaz).
    if (day.isAfter(today)) {
      return const SizedBox(width: _cell, height: _cell + _gap);
    }

    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final count = log.countOn(day);
    final color = colorForLevel(levelFor(count), isDark: isDark);
    final isToday = day == today;
    final label = count == 0
        ? '${_dayLabel(day)} · çalışma yok'
        : '${_dayLabel(day)} · $count kart';

    final fill = Container(
      key: dayKey(day),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isToday ? 2 : 3),
      ),
    );

    // Bugün: mor halka + araya yüzey rengi boşluk. Boşluk şart — halka
    // "high" dolgusuyla (pembe) karışmasın diye AYRI bir renk ailesinden
    // (mor, `dashboardVioletDeep`) — eskiden ikisi de `scheme.primary`
    // (amber) olduğu için bugün 25+ kart çalışılmışsa halka dolguya
    // karışıp görünmez olurdu, boşluk o yüzden vardı; artık renkler zaten
    // ayrı ama boşluk yine de duruyor (ekstra güvenlik payı).
    final Widget cell = isToday
        ? Container(
            key: todayRingKey,
            width: _cell,
            height: _cell,
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppTheme.dashboardVioletDeep,
                width: 1.5,
              ),
            ),
            child: fill,
          )
        : SizedBox(width: _cell, height: _cell, child: fill);

    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: Tooltip(
        // Masaüstünde fareyle üzerine gelince; mobilde uzun basınca.
        message: isToday ? '$label (bugün)' : label,
        child: Builder(
          // Snackbar için StudyHeatmap'in KENDİ context'i değil, alt ağaçtaki
          // bir context gerekiyor (ScaffoldMessenger araması yukarı çıkar).
          builder: (cellContext) => GestureDetector(
            onTap: () => _showDayDetail(
              cellContext,
              isToday ? '$label (bugün)' : label,
            ),
            child: cell,
          ),
        ),
      ),
    );
  }

  /// Türkçe kısa ay adları — `intl` bağımlılığı eklemeden tarih etiketi için.
  static const List<String> _monthsShort = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  /// Tarih aralığı etiketindeki tek bir tarih: "12 Tem".
  static String _rangeLabel(DateTime day) =>
      '${day.day} ${_monthsShort[day.month - 1]}';

  /// Kareye dokununca günün özetini gösterir. Üst üste yığılmasın diye
  /// önceki snackbar kapatılır.
  static void _showDayDetail(BuildContext context, String label) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(label), duration: const Duration(seconds: 2)),
      );
  }

  static String _dayLabel(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.'
      '${day.month.toString().padLeft(2, '0')}.'
      '${day.year}';
}

/// Hiç çalışma verisi yokken ızgara yerine gösterilen teşvik mesajı.
class _HeatmapEmptyState extends StatelessWidget {
  const _HeatmapEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'Çalışmaya başladığında burada görünecek.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Eskisinden belirgin: kutular 12→16, yazı labelSmall→bodySmall.
    Widget box(HeatLevel level) => Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: StudyHeatmap.colorForLevel(level, isDark: isDark),
        borderRadius: BorderRadius.circular(4),
      ),
    );

    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Az', style: labelStyle),
        const SizedBox(width: 6),
        for (final level in HeatLevel.values) box(level),
        const SizedBox(width: 6),
        Text('Çok', style: labelStyle),
      ],
    );
  }
}
