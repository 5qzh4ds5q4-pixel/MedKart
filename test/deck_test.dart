import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';

void main() {
  final createdAt = DateTime(2026, 7, 16);

  test('sınav tarihi yoksa hasExamDate ve daysUntilExam boş döner', () {
    final deck = Deck(id: 'd1', name: 'Deste', createdAt: createdAt);

    expect(deck.hasExamDate, isFalse);
    expect(deck.daysUntilExam(DateTime(2026, 7, 20)), isNull);
  });

  test('daysUntilExam saat/dakikadan bağımsız tam gün sayısı verir', () {
    final deck = Deck(
      id: 'd1',
      name: 'Deste',
      createdAt: createdAt,
      examDate: DateTime(2026, 8, 1),
    );

    expect(deck.daysUntilExam(DateTime(2026, 7, 29, 23, 45)), 3);
    expect(deck.daysUntilExam(DateTime(2026, 8, 1, 6)), 0);
    expect(deck.daysUntilExam(DateTime(2026, 8, 2)), -1);
  });

  test('withExamDate sınav tarihini ayarlar ve null ile kaldırır', () {
    final deck = Deck(id: 'd1', name: 'Deste', createdAt: createdAt);
    final withDate = deck.withExamDate(DateTime(2026, 8, 1));

    expect(withDate.hasExamDate, isTrue);
    expect(withDate.examDate, DateTime(2026, 8, 1));

    final cleared = withDate.withExamDate(null);
    expect(cleared.hasExamDate, isFalse);
  });

  test('copyWith sınav tarihini korur', () {
    final deck = Deck(
      id: 'd1',
      name: 'Deste',
      createdAt: createdAt,
      examDate: DateTime(2026, 8, 1),
    );

    final renamed = deck.copyWith(name: 'Yeni ad');

    expect(renamed.name, 'Yeni ad');
    expect(renamed.examDate, DateTime(2026, 8, 1));
  });

  test('toJson/fromJson sınav tarihini korur', () {
    final deck = Deck(
      id: 'd1',
      name: 'Deste',
      createdAt: createdAt,
      examDate: DateTime(2026, 8, 1),
    );

    final restored = Deck.fromJson(deck.toJson());

    expect(restored.examDate, DateTime(2026, 8, 1));
  });

  test('toJson/fromJson sınav tarihi yokken null kalır', () {
    final deck = Deck(id: 'd1', name: 'Deste', createdAt: createdAt);
    final restored = Deck.fromJson(deck.toJson());

    expect(restored.examDate, isNull);
  });
}
