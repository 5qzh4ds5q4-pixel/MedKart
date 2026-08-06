import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Günlük hedefe ne kadar yaklaşıldığını gösteren halka (istatistik ekranındaki
/// "Bugün" kartında). Yalnızca kullanıcı bir hedef belirlediyse gösterilir —
/// hedef yoksa çağıran taraf bu widget'ı hiç kurmaz.
///
/// Yeni bir "ilerleme" tanımı İCAT ETMEZ: doğrudan `bugün çalışılan kart` /
/// `hedef` oranıdır ve **%100'de kilitlenir** (bkz. [percentFor]) — hedefini
/// üçe katlayan kullanıcıda halka taşmaz, metin %300 demez.
///
/// Çizim elle [CustomPainter] ile; birkaç yay için charting paketi eklenmedi
/// (bkz. CLAUDE.md "Deneme Sınavı / Trend grafiği" aynı gerekçe). Tuvale
/// çizilen yay ekran okuyucuya görünmediği için widget [Semantics] ile sarılı.
class DailyGoalRing extends StatelessWidget {
  const DailyGoalRing({
    super.key,
    required this.done,
    required this.goal,
    this.size = 58,
    this.strokeWidth = 5,
  });

  /// Bugün çalışılan kart sayısı.
  final int done;

  /// Kullanıcının belirlediği günlük hedef (her zaman > 0 beklenir).
  final int goal;

  final double size;
  final double strokeWidth;

  /// Tamamlanma yüzdesi, **0-100 arasına sıkıştırılmış**. [goal] geçersizse
  /// (0/negatif) 0 döner — hedef yokken bu widget zaten kurulmaz, bu yalnızca
  /// savunma.
  static int percentFor(int done, int goal) {
    if (goal <= 0) return 0;
    if (done <= 0) return 0;
    final raw = (done / goal * 100).round();
    return raw > 100 ? 100 : raw;
  }

  /// Hedef tamamlandı mı? [percentFor] ile AYNI ölçüt (ikisi ayrışmasın).
  static bool isComplete(int done, int goal) => percentFor(done, goal) >= 100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = percentFor(done, goal);
    final color = AppTheme.successColor(context);

    return Semantics(
      container: true,
      label: 'Günlük hedef ilerlemesi: $done / $goal kart, yüzde $percent',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GoalRingPainter(
            percent: percent,
            color: color,
            trackColor: theme.colorScheme.outlineVariant,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Text(
              '%$percent',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  const _GoalRingPainter({
    required this.percent,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final int percent;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (percent <= 0) return;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12 yönünden başla
      2 * math.pi * (percent / 100),
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) =>
      old.percent != percent ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
