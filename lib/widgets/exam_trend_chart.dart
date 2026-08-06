import 'package:flutter/material.dart';

import '../models/exam_result.dart';

/// Grafikte tek bir deneme sınavının karşılığı.
class ExamTrendPoint {
  const ExamTrendPoint({required this.takenAt, required this.percent});

  final DateTime takenAt;

  /// 0-100 arası yüzde puan.
  final int percent;
}

/// Deneme sınavı yüzde puanlarının zaman içindeki seyri — basit çizgi grafik.
///
/// Veri kaynağı zaten var olan `LibraryData.examResults` geçmişi
/// ([ExamResult.maxHistory] = 20 kayıt); yeni bir depolama ya da yeni bir
/// hesap YOK, yüzde doğrudan [ExamResult.percent]'ten geliyor (sonuç
/// ekranındaki büyük puanla aynı formül).
///
/// Charting paketi (fl_chart vb.) BİLEREK eklenmedi — birkaç nokta + düz
/// çizgi + üç eksen etiketi için yeni bir bağımlılık taşımaya değmez, tamamı
/// [CustomPainter] ile çiziliyor.
class ExamTrendChart extends StatelessWidget {
  const ExamTrendChart({super.key, required this.results});

  /// Tüm sınav geçmişi (sıralı olmak zorunda değil — [pointsFor] sıralıyor).
  final List<ExamResult> results;

  /// Grafikte gösterilen EN FAZLA deneme sayısı; fazlası varsa en YENİLER
  /// kalır. 20 kaydın hepsini çizmek noktaları birbirine yapıştırıyordu.
  static const int maxPoints = 10;

  /// Bu sayıdan az sonuçta grafik hiç gösterilmez: tek nokta trend değildir.
  static const int minPointsToShow = 2;

  static const double _chartHeight = 170;

  // Çizim alanının kenar boşlukları: solda yüzde etiketleri, üstte son
  // noktanın değer etiketi, altta tarih etiketleri için yer.
  static const double _leftGutter = 34;
  static const double _rightPad = 16;
  static const double _topPad = 22;
  static const double _bottomPad = 20;

  /// [results] için çizilecek noktalar: kronolojik (eskiden yeniye) sırada,
  /// en fazla [maxPoints] tane (fazlaysa en yeniler).
  static List<ExamTrendPoint> pointsFor(List<ExamResult> results) {
    final sorted = [...results]..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    final shown = sorted.length > maxPoints
        ? sorted.sublist(sorted.length - maxPoints)
        : sorted;
    return [
      for (final result in shown)
        ExamTrendPoint(takenAt: result.takenAt, percent: result.percent),
    ];
  }

  /// Bölümün (başlık dahil) gösterilip gösterilmeyeceği. Çağıran ekran
  /// başlığı da bu kontrole bağlamalı — yoksa başlık boş bir alana bakar.
  static bool shouldShow(List<ExamResult> results) =>
      results.length >= minPointsToShow;

  /// Türkçe kısa ay adları — `intl` bağımlılığı eklemeden tarih etiketi için.
  /// (StudyHeatmap'te de benzer bir liste var; iki widget'ı birbirine
  /// bağlamamak için bilinçli olarak kopyalandı.)
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

  /// Eksen etiketindeki tarih: "12 Tem".
  static String shortDate(DateTime day) =>
      '${day.day} ${_monthsShort[day.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final points = pointsFor(results);
    // Savunma amaçlı: çağıran taraf [shouldShow] ile zaten eliyor.
    if (points.length < minPointsToShow) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Son ${points.length} deneme · yüzde puanın',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Tuvale çizilen etiketler ekran okuyucuya görünmez; özeti burada
          // metin olarak veriyoruz.
          Semantics(
            // container: alt ağaç (CustomPaint) hiç semantik düğüm üretmiyor;
            // olmadan bu etiket için de düğüm oluşmuyor.
            container: true,
            label:
                'Deneme sınavı trendi: ${points.first.percent} yüzdeden '
                '${points.last.percent} yüzdeye.',
            child: SizedBox(
              height: _chartHeight,
              child: CustomPaint(
                size: Size.infinite,
                painter: _ExamTrendPainter(
                  points: points,
                  lineColor: scheme.primary,
                  gridColor: scheme.outlineVariant,
                  labelColor: scheme.onSurfaceVariant,
                  dotBorderColor: scheme.surfaceContainerHighest,
                  axisLabelStyle:
                      theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ) ??
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  valueLabelStyle:
                      theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ) ??
                      TextStyle(
                        fontSize: 11,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Izgara + çizgi + noktalar + eksen etiketleri. Renklerin tamamı dışarıdan
/// (tema token'larından) geliyor — painter'ın içinde sabit renk YOK.
class _ExamTrendPainter extends CustomPainter {
  _ExamTrendPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.dotBorderColor,
    required this.axisLabelStyle,
    required this.valueLabelStyle,
  });

  final List<ExamTrendPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color dotBorderColor;
  final TextStyle axisLabelStyle;
  final TextStyle valueLabelStyle;

  /// Y ekseninde çizgi + etiket konan yüzdeler.
  static const List<int> _gridPercents = [0, 50, 100];

  static const double _dotRadius = 3.5;
  static const double _lastDotRadius = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      ExamTrendChart._leftGutter,
      ExamTrendChart._topPad,
      size.width - ExamTrendChart._rightPad,
      size.height - ExamTrendChart._bottomPad,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    _paintGrid(canvas, plot);

    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(_xFor(plot, i), _yFor(plot, points[i].percent)),
    ];

    // Çizgi ince: grafik verinin kendisini değil eğilimini anlatıyor.
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (final offset in offsets) {
      canvas.drawCircle(offset, _dotRadius, dotPaint);
    }

    // Son nokta vurgulanır: panel rengiyle bir halka çizip üzerine daha büyük
    // bir daire koyuyoruz — çizgi noktanın içinden geçtiğinde bile ayrışsın.
    final last = offsets.last;
    canvas.drawCircle(
      last,
      _lastDotRadius + 2,
      Paint()..color = dotBorderColor,
    );
    canvas.drawCircle(last, _lastDotRadius, dotPaint);

    _paintDateLabels(canvas, plot, offsets);
    _paintLastValueLabel(canvas, plot, last);
  }

  void _paintGrid(Canvas canvas, Rect plot) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final percent in _gridPercents) {
      final y = _yFor(plot, percent);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      final label = _textPainter('%$percent', axisLabelStyle);
      // Gutter'da sağa yaslı, çizgiyle dikey ortalı.
      label.paint(
        canvas,
        Offset(plot.left - 6 - label.width, y - label.height / 2),
      );
    }
  }

  /// Yalnızca ilk ve son tarih yazılır — her noktaya tarih koymak 10 denemede
  /// etiketleri üst üste bindiriyordu.
  void _paintDateLabels(Canvas canvas, Rect plot, List<Offset> offsets) {
    final first = _textPainter(
      ExamTrendChart.shortDate(points.first.takenAt),
      axisLabelStyle,
    );
    first.paint(canvas, Offset(plot.left, plot.bottom + 6));

    final last = _textPainter(
      ExamTrendChart.shortDate(points.last.takenAt),
      axisLabelStyle,
    );
    last.paint(canvas, Offset(plot.right - last.width, plot.bottom + 6));
  }

  /// Son denemenin yüzdesi noktanın üstünde; kenardan taşmaması için x
  /// kırpılıyor.
  void _paintLastValueLabel(Canvas canvas, Rect plot, Offset last) {
    final label = _textPainter('%${points.last.percent}', valueLabelStyle);
    final x = (last.dx - label.width / 2).clamp(
      plot.left,
      plot.right - label.width,
    );
    final y = (last.dy - _lastDotRadius - 4 - label.height).clamp(
      0.0,
      plot.bottom,
    );
    label.paint(canvas, Offset(x, y));
  }

  TextPainter _textPainter(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  double _xFor(Rect plot, int index) => points.length == 1
      ? plot.center.dx
      : plot.left + plot.width * index / (points.length - 1);

  double _yFor(Rect plot, int percent) =>
      plot.bottom - plot.height * (percent.clamp(0, 100) / 100);

  @override
  bool shouldRepaint(_ExamTrendPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.dotBorderColor != dotBorderColor ||
        oldDelegate.points.length != points.length) {
      return true;
    }
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i].percent != points[i].percent ||
          oldDelegate.points[i].takenAt != points[i].takenAt) {
        return true;
      }
    }
    return false;
  }
}
