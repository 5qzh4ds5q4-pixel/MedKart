import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/widgets/card_chips.dart';

Color _chipBackground(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(DifficultyChip),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration as BoxDecoration).color!;
}

Widget _host(ThemeData theme) => MaterialApp(
  theme: theme,
  home: const Scaffold(
    body: DifficultyChip(difficulty: CardDifficulty.zor),
  ),
);

void main() {
  testWidgets('açık temada açık zemin paleti kullanılır', (tester) async {
    await tester.pumpWidget(_host(AppTheme.light));
    expect(_chipBackground(tester), const Color(0xFFF8E8E6));
  });

  testWidgets('koyu temada koyu zemin paleti kullanılır', (tester) async {
    await tester.pumpWidget(_host(AppTheme.dark));
    expect(_chipBackground(tester), const Color(0xFF3E2422));
  });
}
