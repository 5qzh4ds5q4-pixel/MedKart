import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/study_log.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/widgets/study_heatmap.dart';

/// [counts] gün-ofseti (bugünden geriye) → kart sayısı.
StudyLog _logRelativeTo(DateTime today, Map<int, int> counts) {
  final map = <String, int>{};
  counts.forEach((daysAgo, count) {
    final day = today.subtract(Duration(days: daysAgo));
    final key =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    map[key] = count;
  });
  return StudyLog(map);
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Belirli bir günün karesinin gerçek dolgu rengi.
Color _cellColor(WidgetTester tester, DateTime day) {
  final container = tester.widget<Container>(
    find.byKey(StudyHeatmap.dayKey(day)),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  final today = DateTime(2026, 7, 31);

  group('levelFor — yoğunluk kademeleri', () {
    test('0 kart hiç çalışılmamış sayılır', () {
      expect(StudyHeatmap.levelFor(0), HeatLevel.none);
    });

    test('düşük aralık (1-9)', () {
      expect(StudyHeatmap.levelFor(1), HeatLevel.low);
      expect(StudyHeatmap.levelFor(5), HeatLevel.low);
      expect(StudyHeatmap.levelFor(9), HeatLevel.low);
    });

    test('orta aralık (10-24)', () {
      expect(StudyHeatmap.levelFor(10), HeatLevel.medium);
      expect(StudyHeatmap.levelFor(24), HeatLevel.medium);
    });

    test('yüksek aralık (25+)', () {
      expect(StudyHeatmap.levelFor(25), HeatLevel.high);
      expect(StudyHeatmap.levelFor(200), HeatLevel.high);
    });

    test('sınırlar eşik sabitleriyle tutarlı', () {
      // Eşikler değişirse bu test de doğru kalır — sabitlere bağlı yazıldı.
      expect(
        StudyHeatmap.levelFor(StudyHeatmap.mediumMinCount - 1),
        HeatLevel.low,
      );
      expect(
        StudyHeatmap.levelFor(StudyHeatmap.mediumMinCount),
        HeatLevel.medium,
      );
      expect(
        StudyHeatmap.levelFor(StudyHeatmap.highMinCount - 1),
        HeatLevel.medium,
      );
      expect(StudyHeatmap.levelFor(StudyHeatmap.highMinCount), HeatLevel.high);
    });

    test('kademeler birbirinden FARKLI renk üretir', () {
      final colors = {
        for (final level in HeatLevel.values)
          StudyHeatmap.colorForLevel(level, isDark: false),
      };
      expect(colors, hasLength(HeatLevel.values.length));
    });

    test('en yüksek kademe tam koyu pembe, boş gün nötr yüzey', () {
      // 2026-08-11 amber/gold temizliği: eskiden `scheme.primary` (amber)
      // ve `scheme.surfaceContainerHighest` idi.
      expect(
        StudyHeatmap.colorForLevel(HeatLevel.high, isDark: false),
        AppTheme.dashboardPinkHot,
      );
      expect(
        StudyHeatmap.colorForLevel(HeatLevel.none, isDark: false),
        AppTheme.dashboardSurfaceElevated,
      );
    });
  });

  group('ızgara render', () {
    testWidgets('her yoğunluk seviyesi doğru rengi alır', (tester) async {
      final log = _logRelativeTo(today, {
        1: 3, // düşük
        2: 15, // orta
        3: 40, // yüksek
        // 4 gün önce hiç kayıt yok → none
      });

      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      // Kıyas AppTheme.light'ın gerçek brightness'ıyla yapılır.
      final isDark =
          Theme.of(tester.element(find.byType(StudyHeatmap))).brightness ==
          Brightness.dark;

      expect(
        _cellColor(tester, today.subtract(const Duration(days: 1))),
        StudyHeatmap.colorForLevel(HeatLevel.low, isDark: isDark),
      );
      expect(
        _cellColor(tester, today.subtract(const Duration(days: 2))),
        StudyHeatmap.colorForLevel(HeatLevel.medium, isDark: isDark),
      );
      expect(
        _cellColor(tester, today.subtract(const Duration(days: 3))),
        StudyHeatmap.colorForLevel(HeatLevel.high, isDark: isDark),
      );
      expect(
        _cellColor(tester, today.subtract(const Duration(days: 4))),
        StudyHeatmap.colorForLevel(HeatLevel.none, isDark: isDark),
      );
    });

    testWidgets('yoğunluk MUTLAK eşiğe göre, en yüksek güne göre değil', (
      tester,
    ) async {
      // Tek başına en yüksek gün 3 kart. Göreli ölçekte bu "en koyu" olurdu;
      // mutlak eşikte "düşük" kalmalı.
      final log = _logRelativeTo(today, {1: 3, 2: 2});

      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      final isDark =
          Theme.of(tester.element(find.byType(StudyHeatmap))).brightness ==
          Brightness.dark;

      expect(
        _cellColor(tester, today.subtract(const Duration(days: 1))),
        StudyHeatmap.colorForLevel(HeatLevel.low, isDark: isDark),
      );
      expect(
        _cellColor(tester, today.subtract(const Duration(days: 1))),
        isNot(StudyHeatmap.colorForLevel(HeatLevel.high, isDark: isDark)),
      );
    });

    testWidgets('eski veride pencere 12 haftada sınırlanır', (tester) async {
      // İlk çalışma bir yıl önce: üst sınır devreye girmeli.
      final log = _logRelativeTo(today, {365: 4, 0: 5});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      expect(StudyHeatmap.defaultWeeks, 12);
      // Pencerenin en eski günü ızgarada var, bir öncesi yok.
      final oldest = today
          .subtract(Duration(days: today.weekday - 1))
          .subtract(const Duration(days: (StudyHeatmap.defaultWeeks - 1) * 7));
      expect(find.byKey(StudyHeatmap.dayKey(oldest)), findsOneWidget);
      expect(
        find.byKey(
          StudyHeatmap.dayKey(oldest.subtract(const Duration(days: 1))),
        ),
        findsNothing,
      );
    });

    testWidgets('gelecek günler için kare çizilmez', (tester) async {
      final log = _logRelativeTo(today, {0: 5});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      expect(find.byKey(StudyHeatmap.dayKey(today)), findsOneWidget);
      expect(
        find.byKey(StudyHeatmap.dayKey(today.add(const Duration(days: 1)))),
        findsNothing,
      );
    });
  });

  group('yeni hesap — ızgara küçük render edilir', () {
    test('weeksToShow ilk çalışma gününe göre hesaplanır', () {
      // 2026-07-31 Cuma; haftanın Pazartesi'si 2026-07-27.
      expect(
        StudyHeatmap.weeksToShow(_logRelativeTo(today, {1: 3}), today),
        1,
        reason: 'dün başlamış hesap: tek hafta',
      );
      expect(
        StudyHeatmap.weeksToShow(_logRelativeTo(today, {0: 3}), today),
        1,
        reason: 'bugün başlamış hesap: tek hafta',
      );
      // 10 gün önce = önceki haftanın içinde → 2 hafta.
      expect(
        StudyHeatmap.weeksToShow(_logRelativeTo(today, {10: 3}), today),
        2,
      );
      // 30 hafta önce başlamış ama üst sınır 12.
      expect(
        StudyHeatmap.weeksToShow(_logRelativeTo(today, {210: 3}), today),
        StudyHeatmap.defaultWeeks,
      );
    });

    test('hiç çalışma yoksa null (boş durum mesajı gösterilecek)', () {
      expect(StudyHeatmap.weeksToShow(const StudyLog(), today), isNull);
    });

    test('maxWeeks parametresi üst sınırı daraltır', () {
      expect(
        StudyHeatmap.weeksToShow(
          _logRelativeTo(today, {365: 3}),
          today,
          maxWeeks: 4,
        ),
        4,
      );
    });

    testWidgets('2 günlük hesapta 84 kare değil, tek hafta çizilir', (
      tester,
    ) async {
      final log = _logRelativeTo(today, {1: 6, 0: 3});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      // Bu haftanın Pazartesi'si ızgarada var...
      final monday = today.subtract(Duration(days: today.weekday - 1));
      expect(find.byKey(StudyHeatmap.dayKey(monday)), findsOneWidget);
      // ...önceki hafta HİÇ çizilmez (eski davranışta 84 kare vardı).
      expect(
        find.byKey(
          StudyHeatmap.dayKey(monday.subtract(const Duration(days: 1))),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          StudyHeatmap.dayKey(monday.subtract(const Duration(days: 7))),
        ),
        findsNothing,
      );
    });
  });

  group('bugün işareti', () {
    testWidgets('halka yalnızca bugünün karesinde ve tek tane', (tester) async {
      final log = _logRelativeTo(today, {2: 5, 1: 5, 0: 5});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      expect(find.byKey(StudyHeatmap.todayRingKey), findsOneWidget);

      // Halka bugünün karesini SARIYOR (dünkünü değil).
      expect(
        find.descendant(
          of: find.byKey(StudyHeatmap.todayRingKey),
          matching: find.byKey(StudyHeatmap.dayKey(today)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(StudyHeatmap.todayRingKey),
          matching: find.byKey(
            StudyHeatmap.dayKey(today.subtract(const Duration(days: 1))),
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('halka rengi mor ve dolgudan ayrı', (tester) async {
      // Bugün 40 kart = "yüksek" → dolgu `dashboardPinkHot`. Halka AYRI bir
      // renk ailesinden (mor, `dashboardVioletDeep`) — 2026-08-11 amber/gold
      // temizliği: eskiden ikisi de `scheme.primary` (amber) idi.
      final log = _logRelativeTo(today, {0: 40});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      final ring = tester.widget<Container>(
        find.byKey(StudyHeatmap.todayRingKey),
      );
      final decoration = ring.decoration! as BoxDecoration;
      final scheme = Theme.of(
        tester.element(find.byType(StudyHeatmap)),
      ).colorScheme;

      expect(decoration.border!.top.color, AppTheme.dashboardVioletDeep);
      // Halka ile dolgu arasındaki boşluk yüzey renginde.
      expect(decoration.color, scheme.surface);
    });

    testWidgets('bugüne dokununca "(bugün)" bilgisi de gösterilir', (
      tester,
    ) async {
      final log = _logRelativeTo(today, {0: 7});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      await tester.tap(
        find.byKey(StudyHeatmap.todayRingKey),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(find.text('31.07.2026 · 7 kart (bugün)'), findsOneWidget);
    });
  });

  group('anlaşılırlık metinleri', () {
    testWidgets('açıklama cümlesi ızgarayla birlikte gösterilir', (
      tester,
    ) async {
      final log = _logRelativeTo(today, {0: 5});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      expect(
        find.text(
          'Her kare bir gün. Ne kadar soluk, o kadar az çalışılmış; '
          'ne kadar koyu, o kadar çok.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tarih aralığı etiketi gerçek tarihleri gösterir', (
      tester,
    ) async {
      // İlk çalışma 10 gün önce → 2 haftalık pencere, 20 Tem Pazartesi'den.
      final log = _logRelativeTo(today, {10: 4, 0: 2});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      expect(find.text('20 Tem - 31 Tem'), findsOneWidget);
    });

    testWidgets('boş durumda açıklama ve tarih aralığı gösterilmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(StudyHeatmap(log: const StudyLog(), now: today)),
      );

      expect(find.textContaining('Her kare bir gün'), findsNothing);
      expect(find.textContaining(' - '), findsNothing);
    });
  });

  group('boş durum', () {
    testWidgets('hiç çalışma verisi yokken teşvik mesajı gösterilir', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(StudyHeatmap(log: const StudyLog(), now: today)),
      );

      expect(
        find.text('Çalışmaya başladığında burada görünecek.'),
        findsOneWidget,
      );
      // Izgara ve açıklama (legend) hiç çizilmez.
      expect(find.byKey(StudyHeatmap.dayKey(today)), findsNothing);
      expect(find.text('Az'), findsNothing);
    });

    testWidgets('tek bir çalışma günü bile varsa ızgara gösterilir', (
      tester,
    ) async {
      final log = _logRelativeTo(today, {0: 1});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      expect(
        find.text('Çalışmaya başladığında burada görünecek.'),
        findsNothing,
      );
      expect(find.byKey(StudyHeatmap.dayKey(today)), findsOneWidget);
      expect(find.text('Az'), findsOneWidget);
    });
  });

  group('kareye dokunma', () {
    testWidgets('çalışılan gün: tarih ve kart sayısı snackbar ile gösterilir', (
      tester,
    ) async {
      final log = _logRelativeTo(today, {1: 14});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      await tester.tap(
        find.byKey(StudyHeatmap.dayKey(today.subtract(const Duration(days: 1)))),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(find.text('30.07.2026 · 14 kart'), findsOneWidget);
    });

    testWidgets('boş gün: "çalışma yok" bilgisi gösterilir', (tester) async {
      final log = _logRelativeTo(today, {0: 5});
      await tester.pumpWidget(_wrap(StudyHeatmap(log: log, now: today)));

      await tester.tap(
        find.byKey(StudyHeatmap.dayKey(today.subtract(const Duration(days: 2)))),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(find.text('29.07.2026 · çalışma yok'), findsOneWidget);
    });
  });
}
