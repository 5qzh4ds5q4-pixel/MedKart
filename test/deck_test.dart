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

  // ── sourcePdfHash / sourcePdfName (2026-08-21) ───────────────────────
  // ALANLAR HENÜZ HİÇBİR YERDE OKUNMUYOR (TUS eklentisi ayrı bir adım).
  // Bu grup yalnızca alanların TAŞINDIĞINI ve eski kayıtları BOZMADIĞINI
  // sabitler — özellikle copyWith/withExamDate'in onları DÜŞÜRMEDİĞİNİ.

  group('kaynak PDF kimliği', () {
    Deck stamped() => Deck(
      id: 'd1',
      name: 'Deste',
      createdAt: createdAt,
      sourcePdfHash: 'abc123',
      sourcePdfName: 'bulasici.pdf',
    );

    test('varsayılan olarak boş — mevcut desteler etkilenmez', () {
      final deck = Deck(id: 'd1', name: 'Deste', createdAt: createdAt);

      expect(deck.sourcePdfHash, isNull);
      expect(deck.sourcePdfName, isNull);
      expect(deck.hasSourcePdf, isFalse);
    });

    test('toJson/fromJson iki alanı da taşır', () {
      final restored = Deck.fromJson(stamped().toJson());

      expect(restored.sourcePdfHash, 'abc123');
      expect(restored.sourcePdfName, 'bulasici.pdf');
      expect(restored.hasSourcePdf, isTrue);
    });

    test('ESKİ kayıtlar (anahtarlar hiç yok) null döner — geriye dönük '
        'uyumlu, migration gerekmez', () {
      final restored = Deck.fromJson({
        'id': 'd1',
        'name': 'Eski deste',
        'createdAt': createdAt.toIso8601String(),
      });

      expect(restored.sourcePdfHash, isNull);
      expect(restored.sourcePdfName, isNull);
      expect(restored.hasSourcePdf, isFalse);
      expect(restored.name, 'Eski deste');
    });

    test('boş/whitespace string null a indirgenir — "kimliği var" gibi '
        'davranmasın', () {
      final restored = Deck.fromJson({
        'id': 'd1',
        'name': 'Deste',
        'createdAt': createdAt.toIso8601String(),
        'sourcePdfHash': '   ',
        'sourcePdfName': '',
      });

      expect(restored.sourcePdfHash, isNull);
      expect(restored.hasSourcePdf, isFalse);
    });

    test('copyWith(name:) kaynak PDF kimliğini DÜŞÜRMEZ', () {
      final renamed = stamped().copyWith(name: 'Yeni ad');

      expect(renamed.name, 'Yeni ad');
      expect(renamed.sourcePdfHash, 'abc123');
      expect(renamed.sourcePdfName, 'bulasici.pdf');
    });

    test('withExamDate kaynak PDF kimliğini DÜŞÜRMEZ', () {
      final withExam = stamped().withExamDate(DateTime(2026, 9, 1));

      expect(withExam.examDate, DateTime(2026, 9, 1));
      expect(withExam.sourcePdfHash, 'abc123');
      expect(withExam.sourcePdfName, 'bulasici.pdf');
    });

    test('withSourcePdf diğer alanları KORUR', () {
      final base = Deck(
        id: 'd1',
        name: 'Deste',
        createdAt: createdAt,
        examDate: DateTime(2026, 9, 1),
      );

      final result = base.withSourcePdf(hash: 'xyz', name: 'a.pdf');

      expect(result.id, 'd1');
      expect(result.name, 'Deste');
      expect(result.createdAt, createdAt);
      expect(result.examDate, DateTime(2026, 9, 1));
      expect(result.sourcePdfHash, 'xyz');
    });
  });
}
