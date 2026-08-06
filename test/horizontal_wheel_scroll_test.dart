import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/widgets/horizontal_wheel_scroll.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 300, height: 50, child: child),
    ),
  );

  testWidgets('düşey fare tekerleği yatay kaydırmaya çevrilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        HorizontalWheelScroll(
          child: Row(
            children: [for (var i = 0; i < 30; i++) SizedBox(width: 50, child: Text('$i'))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.byType(SingleChildScrollView);
    final scrollable = tester.widget<SingleChildScrollView>(scrollableFinder);
    final controller = scrollable.controller!;

    expect(controller.offset, 0);

    // Fare imlecini widget üzerine getirip düşey tekerlek olayı gönder.
    final center = tester.getCenter(scrollableFinder);
    final testPointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(testPointer.addPointer(location: center));
    await tester.sendEventToBinding(
      testPointer.scroll(const Offset(0, 100)),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('kaydırma uçlarda sınırlanır (negatif ya da taşma olmaz)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        HorizontalWheelScroll(
          child: Row(
            children: [for (var i = 0; i < 30; i++) SizedBox(width: 50, child: Text('$i'))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.byType(SingleChildScrollView);
    final scrollable = tester.widget<SingleChildScrollView>(scrollableFinder);
    final controller = scrollable.controller!;

    final center = tester.getCenter(scrollableFinder);
    final testPointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(testPointer.addPointer(location: center));

    // Yukarı doğru (negatif delta) tekerlek — başlangıçta zaten 0, altına inmemeli.
    await tester.sendEventToBinding(testPointer.scroll(const Offset(0, -100)));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    // Çok büyük bir aşağı tekerlek — maxScrollExtent'i aşmamalı.
    await tester.sendEventToBinding(
      testPointer.scroll(const Offset(0, 100000)),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, controller.position.maxScrollExtent);
  });

  // 2026-08-04: kullanıcı filtre çubuğunu kaydıramadığını bildirdi. Ölçüm
  // şunu gösterdi: tekerlek ÇALIŞIYORDU, ama fareyle SÜRÜKLEME hiç
  // kaydırmıyordu (MaterialScrollBehavior.dragDevices masaüstünde `mouse`
  // içermiyor) ve kaydırılabilir olduğuna dair hiçbir işaret yoktu.
  group('sürükleyerek kaydırma ve kaydırma çubuğu', () {
    Widget longRow() => Row(
      children: [
        for (var i = 0; i < 30; i++) SizedBox(width: 50, child: Text('$i')),
      ],
    );

    ScrollController controllerOf(WidgetTester tester) => tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;

    testWidgets('FARE ile sürükleme kaydırır (regresyon testi)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(HorizontalWheelScroll(child: longRow())));
      await tester.pumpAndSettle();
      final controller = controllerOf(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-150, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(
        controller.offset,
        greaterThan(0),
        reason: 'dragDevices fareyi dışlıyorsa offset 0 kalır',
      );
    });

    testWidgets('DOKUNMA ile sürükleme çalışmaya devam eder', (tester) async {
      await tester.pumpWidget(wrap(HorizontalWheelScroll(child: longRow())));
      await tester.pumpAndSettle();
      final controller = controllerOf(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-150, 0),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
    });

    testWidgets('showScrollbar: true kalıcı kaydırma çubuğu gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(HorizontalWheelScroll(showScrollbar: true, child: longRow())),
      );
      await tester.pumpAndSettle();

      final scrollbar = find.byType(Scrollbar);
      expect(scrollbar, findsOneWidget);
      expect(tester.widget<Scrollbar>(scrollbar).thumbVisibility, isTrue);
    });

    testWidgets('varsayılanda kaydırma çubuğu eklenmez', (tester) async {
      await tester.pumpWidget(wrap(HorizontalWheelScroll(child: longRow())));
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('yatay tekerlek deltası (trackpad) da kaydırır', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(HorizontalWheelScroll(child: longRow())));
      await tester.pumpAndSettle();
      final controller = controllerOf(tester);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.addPointer(
          location: tester.getCenter(find.byType(SingleChildScrollView)),
        ),
      );
      await tester.sendEventToBinding(pointer.scroll(const Offset(80, 0)));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
    });
  });
}
