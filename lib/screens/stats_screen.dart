import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../srs/srs_engine.dart';
import '../state/flashcard_store.dart';
import '../state/study_settings.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/app_shell.dart';
import '../widgets/content_shell.dart';
import '../widgets/daily_goal_ring.dart';
import '../widgets/exam_trend_chart.dart';
import '../widgets/review_forecast_chart.dart';
import '../widgets/study_heatmap.dart';
import '../widgets/topic_success_bar.dart';
import 'study_screen.dart';

/// İstatistik ekranı: çalışma serisi (streak), günlük heatmap, deneme sınavı
/// trendi ve konu bazlı başarı oranları. Amaç kullanıcının düzenini ve zayıf
/// konusunu görmesi.
///
/// DÜZEN (2026-08-17, referans taslaktan — kart-ızgara düzenini KALDIRDI):
/// en üstte TEK dominant "bugünkü odak" kartı (en zayıf konu, bkz.
/// [FlashcardStore.weakestTopicInfo] — YENİ bir hesap İCAT EDİLMEDİ, var
/// olan "En Zayıf Konu Antrenmanı" mantığı aynen kullanıldı), altında
/// varsayılan KAPALI katlanabilir satırlar (`_CollapsibleRow`). Her satırın
/// İÇERİĞİ (StudyHeatmap, ExamTrendChart, _DeckReadinessBar, TopicSuccessBar,
/// ReviewForecastChart, metrik kartları) DEĞİŞMEDİ — yalnızca artık bir
/// ExpansionTile'ın içinde, açılana kadar gizli.
///
/// Gövde bilinçli olarak `ListView` DEĞİL `SingleChildScrollView` — önceki
/// ızgara düzeninden kalma bir tercih, hâlâ geçerli (içerik sınırlı).
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
    // Kütüphane geneli en zayıf konu — güvenilir veri yoksa null (bkz.
    // [SrsEngine.weakestReliableTopic]). Yeni bir "en zayıf" hesabı YOK,
    // deck_list_screen'deki "En Zayıf Konu Antrenmanı" ile AYNI kaynak.
    final weakestTopic = store.weakestTopicInfo;
    // weakestTopic doluyken aynı konunun başarı yüzdesi topicStats'tan
    // okunuyor (ikisi aynı `_cards` listesinden türetildiği için topic her
    // zaman orada bulunur) — burada da yeni bir hesap YOK.
    final weakestTopicPercent = weakestTopic == null
        ? null
        : topicStats
              .firstWhere((stat) => stat.topic == weakestTopic.topic)
              .successPercent;

    return AppShell(
      active: SideNavItem.stats,
      topBar: const AppShellTopBar(title: 'İstatistik'),
      body: ContentShell(
        maxWidth: AppTheme.dashboardMaxWidth,
        child: ResponsiveBuilder(
          builder: (context, size) {
            final horizontal = responsiveHorizontalPadding(size);

            final rows = <Widget>[
              _CollapsibleRow(
                icon: Icons.bar_chart_outlined,
                title: 'Genel özet',
                summary: '$streak günlük seri · ${log.total} tekrar',
                child: _MetricRow(
                  columns: _metricColumnsFor(size),
                  streak: streak,
                  total: log.total,
                  activeDays: log.activeDays,
                  today: log.countOn(today),
                  dailyGoal: dailyGoal,
                ),
              ),
              _CollapsibleRow(
                icon: Icons.calendar_month_outlined,
                title: 'Çalışma takvimi',
                summary: '${log.activeDays} aktif gün',
                child: StudyHeatmap(log: log, now: today),
              ),
              // Kartı olmayan desteler listeye hiç girmiyor; hepsi boşsa
              // (ya da hiç deste yoksa) satır tamamen gizlenir.
              if (deckReadiness.isNotEmpty)
                _CollapsibleRow(
                  icon: Icons.layers_outlined,
                  title: 'Deste hazırlığı',
                  summary:
                      '${deckReadiness.length} deste · en düşük '
                      '%${deckReadiness.first.readyPercent} hazır',
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
              // Tek deneme trend değil: 2'den az sonuçta satır hiç görünmez
              // (bkz. ExamTrendChart.shouldShow).
              if (ExamTrendChart.shouldShow(examResults))
                _CollapsibleRow(
                  icon: Icons.show_chart,
                  title: 'Deneme sınavı trendi',
                  summary: 'Son puan %${examResults.first.percent}',
                  child: ExamTrendChart(results: examResults),
                ),
              _CollapsibleRow(
                icon: Icons.my_location_outlined,
                title: 'Konu başarısı',
                summary: topicStats.isEmpty
                    ? 'Henüz veri yok'
                    : 'Tüm konular · ${topicStats.length} konu',
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
              // Hiç kart yoksa tahmin edilecek yük de yok: satır tamamen
              // gizlenir.
              if (reviewForecast != null)
                _CollapsibleRow(
                  icon: Icons.event_outlined,
                  title: 'Önümüzdeki 7 gün',
                  summary:
                      'Toplam '
                      '${reviewForecast.fold<int>(0, (sum, d) => sum + d.count)}'
                      ' kart bekleniyor',
                  child: ReviewForecastChart(days: reviewForecast),
                ),
            ];

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FocusCard(
                    weakestTopic: weakestTopic,
                    successPercent: weakestTopicPercent,
                  ),
                  const SizedBox(height: AppTheme.space24),
                  _CollapsibleSectionList(rows: rows),
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

  /// Üstteki metrik kartlarının sütun sayısı (yalnızca "Genel özet" satırı
  /// açıldığında görünür). Masaüstünde tasarımdaki gibi 4'ü yan yana; daha
  /// darda 2x2.
  static int _metricColumnsFor(ScreenSize size) => size.isDesktop ? 4 : 2;
}

/// En üstteki TEK dominant "bugünkü odak" kartı.
///
/// [weakestTopic] null ise (yeterli/güvenilir veri yok, bkz.
/// [SrsEngine.weakestReliableTopic]) basit bir bekleme mesajı gösteren
/// [_FocusEmptyCard]'a düşer — YENİ bir "en zayıf konu" tahmini İCAT EDİLMEZ.
///
/// Ekrandaki TEK amber vurgusu bilerek burada: rozet, ikon, kenarlık ve buton
/// hepsi `colorScheme.primary`. Aşağıdaki katlanabilir satırlar nötr kalıyor.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.weakestTopic, required this.successPercent});

  final WeakestTopicInfo? weakestTopic;

  /// [weakestTopic] doluyken aynı konunun `topicStats` içindeki başarı
  /// yüzdesi — bkz. [StatsScreen.build] yorumu, burada hesaplanmıyor.
  final int? successPercent;

  @override
  Widget build(BuildContext context) {
    final topic = weakestTopic;
    if (topic == null) {
      return const _FocusEmptyCard();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'BUGÜN İÇİN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.local_fire_department,
                color: scheme.primary,
                size: 26,
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  '${topic.topic} konusuna odaklan',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            '%${successPercent ?? 0} başarı · ${topic.cardCount} kart',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          FilledButton.icon(
            onPressed: () => requireAuth(
              context,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudyScreen(
                    filter: CardFilter(topics: {topic.topic}),
                    ignoreDueDate: true,
                  ),
                ),
              ),
              reason:
                  'Çalışmaya başlamak için giriş yap — ilerlemen kaydedilsin.',
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Antrenmana başla'),
          ),
        ],
      ),
    );
  }
}

/// [_FocusCard]'ın yeterli/güvenilir veri yokken düştüğü sade hâl.
class _FocusEmptyCard extends StatelessWidget {
  const _FocusEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Çalışmaya başladığında burada görünecek.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Katlanabilir bölüm listesi: köşesiz düz satırlar, aralarında ince
/// (0.5px) ayraç — KART görünümü değil, kullanıcı talimatıyla bilinçli.
class _CollapsibleSectionList extends StatelessWidget {
  const _CollapsibleSectionList({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
        );
      }
      children.add(rows[i]);
    }
    return Column(children: children);
  }
}

/// Tek bir katlanabilir satır: ikon + başlık + kısa özet metni (kapalıyken
/// görünen tek şey), açılınca [child] aynen görünür. Varsayılan KAPALI —
/// [ExpansionTile]'ın kendi varsayılanı, elle bir şey yapmaya gerek yok.
///
/// `shape`/`collapsedShape` BİLEREK saydam: [ExpansionTile]'ın kendi
/// varsayılan kenarlığı bu satırı bir "kart" gibi göstermesin diye — ayraç
/// çizgisi [_CollapsibleSectionList] tarafından satırlar ARASINA ayrıca
/// ekleniyor.
class _CollapsibleRow extends StatelessWidget {
  const _CollapsibleRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      shape: Border.all(color: Colors.transparent),
      collapsedShape: Border.all(color: Colors.transparent),
      tilePadding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
      childrenPadding: const EdgeInsets.only(bottom: AppTheme.space16),
      leading: Icon(
        icon,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        summary,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [child],
    );
  }
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
      // Alevin amberi BİLEREK duruyor: içerik değişmedi (bkz. dosya başı
      // yorumu — dominant kart artık ekranın TEK vurgusu olsa da, bu
      // metrik kartın kendi rengi eski davranışı bit-bit koruyor).
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
        // (`_counts.length`), son 30 gün değil.
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

/// Tek bir destenin hazırlık satırı: ad + yüzde + çubuk + "hazır/toplam kart".
class _DeckReadinessBar extends StatelessWidget {
  const _DeckReadinessBar({required this.readiness});

  final DeckReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final percent = readiness.readyPercent;

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
