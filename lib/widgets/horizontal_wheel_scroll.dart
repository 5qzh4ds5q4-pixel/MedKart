import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Masaüstü/web'de yatay kaydırmayı gerçekten kullanılabilir kılan sarmalayıcı.
///
/// Üç ayrı eksikliği birlikte kapatır — biri bile eksik kalırsa kullanıcı
/// "kaydıramıyorum" der:
/// 1. **Düşey tekerlek:** Flutter'da yatay bir [SingleChildScrollView]
///    yalnızca YATAY tekerlek deltasına tepki verir; sıradan bir farenin
///    ürettiği düşey delta ile hiç kaymaz. [_onPointerSignal] düşey deltayı
///    yatay kaydırmaya çevirir.
/// 2. **Fare ile sürükleme:** [MaterialScrollBehavior.dragDevices] masaüstünde
///    `PointerDeviceKind.mouse` İÇERMEZ — yani kullanıcı çipleri fareyle
///    tutup sürüklediğinde hiçbir şey olmaz (ölçüldü: 2026-08-04, offset
///    değişmiyordu). [_DragAnyDeviceScrollBehavior] bunu açar.
/// 3. **Görünürlük:** kaydırılabilir olduğu belli olmuyordu; [showScrollbar]
///    ile kalıcı bir kaydırma çubuğu gösterilir.
class HorizontalWheelScroll extends StatefulWidget {
  const HorizontalWheelScroll({
    super.key,
    required this.child,
    this.padding,
    this.reverse = false,
    this.showScrollbar = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool reverse;

  /// Kalıcı (her zaman görünür) kaydırma çubuğu. Kaydırılabilirliğin fark
  /// edilmesi gereken yerlerde (filtre çubuğu) açılır; ısı haritası gibi
  /// zaten kendi ipuçları olan yerlerde kapalı bırakılır.
  final bool showScrollbar;

  @override
  State<HorizontalWheelScroll> createState() => _HorizontalWheelScrollState();
}

/// Fareyle sürükleyerek kaydırmayı açar. Varsayılan davranış masaüstünde
/// yalnızca dokunma/kalem kabul ediyor.
class _DragAnyDeviceScrollBehavior extends MaterialScrollBehavior {
  const _DragAnyDeviceScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

class _HorizontalWheelScrollState extends State<HorizontalWheelScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;

    final position = _controller.position;
    if (!position.hasContentDimensions) return;

    // Yatay tekerlek/trackpad hareketi varsa onu kullan, yoksa düşey deltayı
    // yatay kaydırmaya çevir (sıradan fare yalnızca dy üretir).
    final delta = event.scrollDelta;
    final amount = delta.dx.abs() > delta.dy.abs() ? delta.dx : delta.dy;

    final target = (_controller.offset + amount).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == _controller.offset) return;

    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    Widget scrollView = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      reverse: widget.reverse,
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.showScrollbar) {
      scrollView = Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: scrollView,
      );
    }

    return ScrollConfiguration(
      behavior: const _DragAnyDeviceScrollBehavior(),
      child: Listener(onPointerSignal: _onPointerSignal, child: scrollView),
    );
  }
}
