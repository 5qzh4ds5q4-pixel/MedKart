import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../srs/srs_engine.dart';
import '../state/flashcard_store.dart';
import '../state/study_settings.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../widgets/app_shell.dart';
import '../widgets/content_shell.dart';
import '../widgets/daily_goal_ring.dart';
import '../widgets/exam_trend_chart.dart';
import '../widgets/review_forecast_chart.dart';
import '../widgets/study_heatmap.dart';
import '../widgets/topic_success_bar.dart';

/// İstatistik ekranı: çalışma serisi (streak), günlük heatmap, deneme sınavı
/// trendi ve konu bazlı başarı oranları. Amaç kullanıcının düzenini ve zayıf
/// konusunu görmesi.
///
/// DÜZEN (2026-08-04, referans tasarımdan): dikey liste yerine kart-ızgara.
/// Üstte 4 metrik kartı yan yana, altında bölümler iki sütunlu ızgarada,
/// en altta tam genişlik "Önümüzdeki 7 gün". Dar ekranda ızgara tek sütuna
/// düşer (bkz. [_columnsFor]).
///
/// Gövde bilinçli olarak `ListView` DEĞİL `SingleChildScrollView`: ızgarada
/// bölümler yan yana durduğu için tembel oluşturma bir şey kazandırmıyor
/// (içerik zaten sınırlı) ama görünmeyen sütunun hiç build edilmemesine yol
/// açıyordu.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, this.now});

  /// Testler için sabitlenebilir "bugün"; verilmezse gerçek zaman.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final dailyGoal = context.watch<StudySettings>().dailyGoal;
    final today = now ?? DateTime.now();
    final log = store.studyLog;
    final streak = log.currentStreak(today);
    final topicStats = store.topicStats;
    final examResults = store.examResults;
    final deckReadiness = store.deckReadiness;
    // Hiç kart yoksa bölüm hiç gösterilmez (null); gecikmiş kartlar ilk güne
    // toplanır — bkz. [SrsEngine.reviewForecast].
    final reviewForecast = store.cards.isEmpty
        ? null
        : SrsEngine.reviewForecast(store.cards, today);

    return AppShell(
      active: SideNavItem.stats,
      topBar: const AppShellTopBar(title: 'İstatistik'),
      body: ContentShell(
        maxWidth: AppTheme.dashboardMaxWidth,
        child: ResponsiveBuilder(
          builder: (context, size) {
            final horizontal = responsiveHorizontalPadding(size);

            // Sol sütun: takvim + hazırlık + trend. Sağ sütun: konu başarısı.
            // Tek sütuna düşen ekranlarda ikisi alt alta gelir.
            final leftSections = <Widget>[
              // subtitle YOK: StudyHeatmap kendi açıklama cümlesini zaten
              // içeride yazıyor ("Her kare bir gün..."), burada bir tane
              // daha eklemek metni ikizliyordu.
              _SectionCard(
                icon: Icons.calendar_month_outlined,
                title: 'Çalışma takvimi',
                child: StudyHeatmap(log: log, now: today),
              ),
              // Kartı olmayan desteler listeye hiç girmiyor; hepsi boşsa
              // (ya da hiç deste yoksa) bölüm başlığıyla birlikte gizlenir.
              if (deckReadiness.isNotEmpty)
                _SectionCard(
                  icon: Icons.layers_outlined,
                  title: 'Deste hazırlığı',
                  subtitle:
                      'Hazır = üst üste en az '
                      '${SrsEngine.difficultyKolayRepetitions} kez doğru '
                      'bildiğin kartlar. En az hazır deste üstte.',
                  child: Column(
                    children: [
                      for (final readiness in deckReadiness)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppTheme.space16,
                          ),
                          child: _DeckReadinessBar(readiness: readiness),
                        ),
                    ],
                  ),
                ),
              // Tek deneme trend değil: 2'den az sonuçta başlığıyla
              // birlikte tüm bölüm gizlenir (bkz. ExamTrendChart.shouldShow).
              if (ExamTrendChart.shouldShow(examResults))
                _SectionCard(
                  icon: Icons.show_chart,
                  title: 'Deneme sınavı trendi',
                  child: ExamTrendChart(results: examResults),
                ),
            ];

            final rightSections = <Widget>[
              _SectionCard(
                icon: Icons.my_location_outlined,
                title: 'Konu başarısı',
                subtitle: 'Başarı = doğru cevap oranı. En zayıf konular üstte.',
                child: topicStats.isEmpty
                    ? _EmptyTopics()
                    : Column(
                        children: [
                          for (final stat in topicStats)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.space16,
                              ),
                              child: TopicSuccessBar(
                                stat: stat,
                                showLowDataStates: true,
                              ),
                            ),
                        ],
                      ),
              ),
            ];

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MetricRow(
                    columns: _metricColumnsFor(size),
                    streak: streak,
                    total: log.total,
                    activeDays: log.activeDays,
                    today: log.countOn(today),
                    dailyGoal: dailyGoal,
                  ),
                  const SizedBox(height: AppTheme.space16),
                  _SectionGrid(
                    columns: _columnsFor(size),
                    left: leftSections,
                    right: rightSections,
                  ),
                  // Hiç kart yoksa tahmin edilecek yük de yok: bölüm
                  // başlığıyla birlikte gizlenir.
                  if (reviewForecast != null) ...[
                    const SizedBox(height: AppTheme.space16),
                    _SectionCard(
                      icon: Icons.event_outlined,
                      title: 'Önümüzdeki 7 gün',
                      subtitle:
                          'Hangi gün kaç kartın tekrara düşeceği. '
                          'Gecikmiş kartlar bugüne sayılır.',
                      child: ReviewForecastChart(days: reviewForecast),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Üstteki metrik kartlarının test anahtarları. Gerekli çünkü kart
  // ETİKETLERİ ekranda başka yerlerde de geçebiliyor (ör. "Bugün" hem bu
  // kartta hem "Önümüzdeki 7 gün" grafiğinin ilk sütununda) — testler doğru
  // kartı hedefleyebilsin diye.
  static const Key metricStreakKey = ValueKey('stats.metric.streak');
  static const Key metricTotalKey = ValueKey('stats.metric.total');
  static const Key metricActiveDaysKey = ValueKey('stats.metric.activeDays');
  static const Key metricTodayKey = ValueKey('stats.metric.today');

  /// Bölüm ızgarasının sütun sayısı: yalnızca masaüstünde iki sütun.
  /// Tablette (600-900) iki sütun ısı haritasını ve konu çubuklarını
  /// okunamayacak kadar sıkıştırıyordu.
  static int _columnsFor(ScreenSize size) => size.isDesktop ? 2 : 1;

  /// Üstteki metrik kartlarının sütun sayısı. Masaüstünde tasarımdaki gibi
  /// 4'ü yan yana; daha darda 2x2 (4'ünü alt alta dizmek ekranın tamamını
  /// yerdi ve altındaki bölümleri kaydırma dışına itiyordu).
  static int _metricColumnsFor(ScreenSize size) => size.isDesktop ? 4 : 2;
}

/// Üstteki dört metrik kartı, [columns] sütunlu satırlara bölünmüş hâlde.
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.columns,
    required this.streak,
    required this.total,
    required this.activeDays,
    required this.today,
    required this.dailyGoal,
  });

  final int columns;
  final int streak;
  final int total;
  final int activeDays;
  final int today;
  final int? dailyGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cards = <Widget>[
      // Alevin amberi BİLEREK duruyor: "Bugün" kartıyla birlikte ekranda
      // amberin izin verildiği iki yerden biri (bkz. [_StatCard] notu).
      _StatCard(
        key: StatsScreen.metricStreakKey,
        icon: Icons.local_fire_department,
        // Seri kopmuşsa alevi soluklaştır (eski davranış korundu).
        iconColor: streak == 0 ? theme.disabledColor : scheme.primary,
        label: 'Günlük seri',
        value: '$streak gün',
      ),
      _StatCard(
        key: StatsScreen.metricTotalKey,
        icon: Icons.autorenew,
        iconColor: scheme.onSurfaceVariant,
        label: 'Toplam tekrar',
        value: '$total',
      ),
      _StatCard(
        key: StatsScreen.metricActiveDaysKey,
        icon: Icons.calendar_month_outlined,
        iconColor: scheme.onSurfaceVariant,
        label: 'Aktif gün',
        // NOT: `StudyLog.activeDays` TÜM ZAMANLARDAKİ kayıtlı gün sayısıdır
        // (`_counts.length`), son 30 gün değil. Eskiden buradaki alt metin
        // bunu bilerek "son 30 gün" DEMİYORDU; alt metin tamamen kaldırıldı,
        // yani iddia hâlâ yok. Pencereli bir sayım istenirse önce StudyLog'a
        // o hesabı eklemek gerekir.
        value: '$activeDays',
      ),
      _TodayCard(today: today, goal: dailyGoal),
    ];

    return _CardGrid(columns: columns, children: cards);
  }
}

/// "Bugün" metriği: hedef varsa ilerleme halkasıyla, yoksa sade sayıyla.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.goal});

  final int today;

  /// Opsiyonel günlük hedef; `null` = kullanıcı hedef belirlememiş.
  final int? goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveGoal = goal;

    // Hedef yok: halka gösterilmez, yalnızca nazik bir ipucu verilir.
    if (effectiveGoal == null) {
      return _StatCard(
        key: StatsScreen.metricTodayKey,
        icon: Icons.check_circle_outline,
        iconColor: scheme.primary,
        label: 'Bugün',
        value: '$today kart',
        caption: 'Ayarlar\'dan günlük hedef belirleyebilirsin.',
        emphasized: true,
      );
    }

    final complete = DailyGoalRing.isComplete(today, effectiveGoal);
    return _StatCard(
      key: StatsScreen.metricTodayKey,
      icon: Icons.check_circle_outline,
      // Tamamlanınca yeşil (başarı token'ı), aksi halde amber vurgu.
      iconColor: complete ? AppTheme.successColor(context) : scheme.primary,
      label: 'Bugün',
      value: '$today kart',
      // Bu alt metin AÇIKLAMA değil VERİ (hedefe kalan) — diğer üç karttaki
      // tekrarlayan açıklamalar kaldırılırken bu bilerek bırakıldı.
      caption: complete
          ? 'Günlük hedefini tamamladın 🎉'
          : 'Günlük hedef: $today/$effectiveGoal kart',
      trailing: DailyGoalRing(done: today, goal: effectiveGoal),
      emphasized: true,
    );
  }
}

/// Üstteki metrik kartlarının ortak kabuğu: ikon + etiket + değer (+ opsiyonel
/// alt metin), sağda opsiyonel bir görsel (hedef halkası).
///
/// GÖRSEL AĞIRLIK (2026-08-05): dört kart artık eşit ağırlıkta DEĞİL.
/// [emphasized] olan tek kart ("Bugün") büyük rakam + amber ikon alır; diğer
/// üçü küçük rakam + nötr ikon + soluk etiketle geri çekilir. Amaç ekrandaki
/// amberi seyreltmek: bu ekranda amber yalnızca "Bugün" kartının ikonunda ve
/// seri alevinde kalır, kalan ikonlar `onSurfaceVariant`. Yeni bir metrik
/// eklerken bu ayrımı bozma — vurgulanan kart bir tane olmalı.
/// (DÜZELTME 2026-08-11: "Bugün" kartının amber KENARLIĞI kaldırıldı —
/// amber/gold temizliği, artık diğer üç kart gibi border'sız. İkonu hâlâ
/// amber, bu satır o kadarını değiştirmedi; kullanıcı yalnızca kenarlığı
/// hedef aldı.)
///
/// [caption] artık opsiyonel: rakamı tekrarlayan açıklama cümleleri
/// ("Serini koru, devam et!" gibi) kaldırıldı. Yalnızca metnin VERİ taşıdığı
/// yerde doldurulur (hedefe kalan kart sayısı).
class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.caption,
    this.trailing,
    this.emphasized = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? caption;
  final Widget? trailing;

  /// Ekrandaki baskın metrik mi? Bkz. sınıf notu.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = caption;

    // Tipografi skalasının dışına çıkmadan iki kademe: baskın kartta
    // headlineSmall (24), sakin kartlarda titleLarge (20).
    final valueStyle = emphasized
        ? theme.textTheme.headlineSmall
        : theme.textTheme.titleLarge;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: emphasized ? 30 : 22, color: iconColor),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: emphasized ? null : scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: valueStyle?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (text != null) ...[
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      text,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTheme.space8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

}

/// Bölümleri iki sütuna dağıtır; [columns] 1 ise hepsini alt alta dizer
/// (sol sütunun içeriği önce gelir — okuma sırası korunur).
class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.columns,
    required this.left,
    required this.right,
  });

  final int columns;
  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    if (columns < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spaced([...left, ...right]),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(left),
          ),
        ),
        const SizedBox(width: AppTheme.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(right),
          ),
        ),
      ],
    );
  }

  static List<Widget> _spaced(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(height: AppTheme.space16));
      out.add(items[i]);
    }
    return out;
  }
}

/// Eşit genişlikte kartları [columns] sütunlu satırlara böler. Bir satırdaki
/// kartlar `Row` sayesinde otomatik aynı yüksekliği alır; son satır eksik
/// kalırsa boş yer tutucuyla doldurulur ki kartlar genişlemesin.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final slice = children.sublist(
        start,
        (start + columns).clamp(0, children.length),
      );
      final cells = <Widget>[];
      for (var i = 0; i < columns; i++) {
        if (i > 0) cells.add(const SizedBox(width: AppTheme.space16));
        cells.add(
          Expanded(child: i < slice.length ? slice[i] : const SizedBox()),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppTheme.space16));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Bir istatistik bölümünün kart kabuğu: ikon + başlık (+ açıklama) + içerik.
/// Bölümlerin İÇERİĞİ değişmedi, yalnızca ızgaraya yerleşecek bir kaba alındı.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = subtitle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // NÖTR, bilerek: amber bu ekranda yalnızca "Bugün" kartında
                // ve seri alevinde kalıyor (bkz. [_StatCard] notu).
                Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: AppTheme.space4),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.space16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tek bir destenin hazırlık satırı: ad + yüzde + çubuk + "hazır/toplam kart".
///
/// Görsel dil [TopicSuccessBar] ile aynı (aynı çubuk yüksekliği/yarıçapı);
/// ayrı bir widget olmasının tek sebebi alt metnin "3/10 kart" biçiminde iki
/// sayı taşıması — [TopicSuccessBar] tek sayı gösteriyor ve onun davranışını
/// değiştirmek istemedik.
///
/// NOT (2026-08-05): renk eşikleri artık [TopicSuccessBar] ile AYNI DEĞİL.
/// Orada kırmızı kaldırıldı (amber → yeşil kademe), burada duruyor: bu iş
/// yalnızca "Konu başarısı" bölümünü kapsıyordu. Birleştirmek ayrı bir karar.
class _DeckReadinessBar extends StatelessWidget {
  const _DeckReadinessBar({required this.readiness});

  final DeckReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final percent = readiness.readyPercent;

    // 2026-08-11 amber/gold temizliği: eskiden hazırlık yüzdesine göre
    // KIRMIZI/tertiary/primary (amber) arasında dallanıyordu ("Konu
    // başarısı"ndan AYRI, bilinçli olarak kırmızıyı koruyordu — bkz. eski
    // not). Kullanıcı bu çubuğu doğrudan mor→pembe TEK bir gradyana
    // çevirmeyi istedi; artık dallanma YOK, `TopicSuccessBar`'ın semantik
    // (durum) renkleriyle KARIŞTIRILMASIN — o widget'a dokunulmadı.
    final percentColor = isDark
        ? AppTheme.dashboardViolet
        : AppTheme.dashboardVioletDeep;
    final trackColor = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                readiness.deckName,
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '%$percent hazır',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: percentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 8, color: trackColor),
              FractionallySizedBox(
                widthFactor: readiness.readyRate.clamp(0.0, 1.0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.dashboardProgressGradient,
                  ),
                  child: SizedBox(height: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${readiness.readyCards}/${readiness.totalCards} kart',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyTopics extends StatelessWidget {
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
      child: Text(
        'Kartlara konu etiketi ekledikçe burada konu bazlı başarın görünecek.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
