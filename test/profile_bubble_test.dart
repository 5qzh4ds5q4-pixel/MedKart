import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/widgets/profile_bubble.dart';

Widget _wrap() => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(appBar: AppBar(actions: const [ProfileBubble()])),
);

void main() {
  group('ProfileBubble', () {
    testWidgets('giriş yapılmamışsa boş/gri avatar ikonu gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('dokununca tam sayfa giriş ekranı açılır', (tester) async {
      await tester.pumpWidget(_wrap());

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.text('Hesap'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
    });
  });
}
