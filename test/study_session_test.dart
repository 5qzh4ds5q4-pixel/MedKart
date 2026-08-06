import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/srs/srs_engine.dart';
import 'package:medcard/srs/study_session.dart';

List<Flashcard> _cards(int count) => [
  for (var i = 1; i <= count; i++)
    Flashcard(id: '$i', question: 'Soru $i', answer: 'Cevap $i'),
];

Flashcard _snap(String id) => Flashcard(id: id, question: 'S', answer: 'C');

/// Sıradaki kartı cevaplar (snapshot testlerin çoğunda önemsiz).
void _answer(StudySession session, ReviewGrade grade) {
  session.answer(grade, snapshot: _snap(session.currentId ?? '?'));
}

void main() {
  test('boş kuyrukla açılan oturum baştan bitmiştir', () {
    final session = StudySession([]);

    expect(session.isFinished, isTrue);
    expect(session.total, 0);
    expect(session.progress, 1);
  });

  test('"Biliyorum" kartı tamamlar ve sıradakine geçer', () {
    final session = StudySession(_cards(2));

    expect(session.currentId, '1');
    _answer(session, ReviewGrade.orta);

    expect(session.currentId, '2');
    expect(session.completed, 1);
    expect(session.remaining, 1);
  });

  test('"Bilmiyorum" kartı kuyruğun sonuna atar, oturumda tekrar sorulur', () {
    final session = StudySession(_cards(3));

    _answer(session, ReviewGrade.zor); // 1 → sona

    expect(session.currentId, '2');
    expect(session.completed, 0);

    _answer(session, ReviewGrade.orta); // 2
    _answer(session, ReviewGrade.orta); // 3

    // 1 numaralı kart tekrar karşımıza çıkmalı.
    expect(session.currentId, '1');
    expect(session.isFinished, isFalse);
  });

  test('bilinmeyen kart bilinene kadar oturum bitmez', () {
    final session = StudySession(_cards(1));

    _answer(session, ReviewGrade.zor);
    expect(session.isFinished, isFalse);
    expect(session.currentId, '1');

    _answer(session, ReviewGrade.orta);
    expect(session.isFinished, isTrue);
    expect(session.completed, 1);
    expect(session.progress, 1);
  });

  test('önce bilinip sonra unutulan kart tamamlanmış sayılmaz', () {
    final session = StudySession(_cards(2));

    _answer(session, ReviewGrade.orta); // 1 tamam
    expect(session.completed, 1);

    _answer(session, ReviewGrade.orta); // 2 tamam
    expect(session.isFinished, isTrue);

    // Aynı kartlarla yeni oturum: 1'i bilip sonra unutursak geri sayılmalı.
    final tekrar = StudySession(_cards(1));
    _answer(tekrar, ReviewGrade.orta);
    expect(tekrar.completed, 1);
  });

  test('ilerleme oranı tamamlanan benzersiz kart üzerinden hesaplanır', () {
    final session = StudySession(_cards(4));

    _answer(session, ReviewGrade.orta);
    expect(session.progress, 0.25);

    _answer(session, ReviewGrade.zor);
    // Bilinmeyen kart ilerlemeyi artırmaz.
    expect(session.progress, 0.25);
    expect(session.remaining, 3);
  });

  test('bitmiş oturuma verilen cevap durumu bozmaz', () {
    final session = StudySession(_cards(1));
    _answer(session, ReviewGrade.orta);

    _answer(session, ReviewGrade.orta);

    expect(session.isFinished, isTrue);
    expect(session.completed, 1);
  });

  group('gecikmeli tekrar (requeue)', () {
    test('"Bilmiyorum" kartı sabit gecikmeyle tam istenen sırada geri gelir', () {
      final session = StudySession(_cards(12), requeueDelay: () => 7);

      _answer(session, ReviewGrade.zor); // '1' → 7 kart sonrasına konur

      // '1' hemen ardından gelmemeli.
      expect(session.currentId, '2');
      for (final expected in ['2', '3', '4', '5', '6', '7', '8']) {
        expect(session.currentId, expected);
        _answer(session, ReviewGrade.orta);
      }

      // Tam 7 kart sonra '1' tekrar karşımıza çıkmalı.
      expect(session.currentId, '1');
    });

    test('kuyruk gecikme kadar uzun değilse kartı sona ekler', () {
      // 3 kartlık kuyrukta istenen gecikme (7) kuyruk uzunluğunu aşar;
      // eski davranışla aynı şekilde sona eklenmeli.
      final session = StudySession(_cards(3), requeueDelay: () => 7);

      _answer(session, ReviewGrade.zor); // 1 → sona (kuyruk kısa)

      expect(session.currentId, '2');
      _answer(session, ReviewGrade.orta); // 2
      _answer(session, ReviewGrade.orta); // 3

      expect(session.currentId, '1');
    });

    test('varsayılan (rastgele) gecikme her zaman 5-10 kart aralığında kalır', () {
      final session = StudySession(_cards(20));

      _answer(session, ReviewGrade.zor); // '1' rastgele gecikmeyle konur

      // İlk 4 kart kesinlikle '1' olamaz (minimum gecikme 5).
      for (var i = 0; i < 4; i++) {
        expect(session.currentId, isNot('1'));
        _answer(session, ReviewGrade.orta);
      }

      // Maksimum gecikme 10: '1' kuyruğun 10. index'ine konur, yani önünde
      // en fazla 10 kart vardır ve en geç 11. gösterimde karşımıza çıkar.
      // İlk döngü 4 kart tüketti; burada kalan en fazla 7 kontrol gerekir.
      var seenAgain = false;
      for (var i = 0; i < 7; i++) {
        if (session.currentId == '1') {
          seenAgain = true;
          break;
        }
        _answer(session, ReviewGrade.orta);
      }
      expect(seenAgain, isTrue);
    });
  });

  group('geri alma', () {
    test('oturum başında geri alınacak cevap yoktur', () {
      final session = StudySession(_cards(2));

      expect(session.canUndo, isFalse);
      expect(session.undo(), isNull);
      expect(session.currentId, '1');
    });

    test('"Biliyorum" geri alınınca kart tekrar sıraya döner', () {
      final session = StudySession(_cards(2));
      _answer(session, ReviewGrade.orta);

      expect(session.currentId, '2');
      expect(session.completed, 1);

      session.undo();

      expect(session.currentId, '1');
      expect(session.completed, 0);
      expect(session.remaining, 2);
      expect(session.canUndo, isFalse);
    });

    test('geri alma kartın cevap öncesi hâlini döner', () {
      final session = StudySession(_cards(1));
      final before = Flashcard(
        id: '1',
        question: 'S',
        answer: 'C',
        intervalDays: 4,
        repetitions: 2,
        easeFactor: 2.3,
        nextReview: DateTime(2026, 7, 20),
      );

      session.answer(ReviewGrade.orta, snapshot: before);
      final restored = session.undo();

      expect(restored, isNotNull);
      expect(restored!.intervalDays, 4);
      expect(restored.repetitions, 2);
      expect(restored.easeFactor, 2.3);
      expect(restored.nextReview, DateTime(2026, 7, 20));
    });

    test('"Bilmiyorum" geri alınınca kart kuyruk sonundan geri çekilir', () {
      final session = StudySession(_cards(3));
      _answer(session, ReviewGrade.zor); // 1 → sona

      expect(session.currentId, '2');

      session.undo();

      // 1 başa döndü ve kuyruğun sonunda kopyası kalmadı.
      expect(session.currentId, '1');
      _answer(session, ReviewGrade.orta); // 1
      _answer(session, ReviewGrade.orta); // 2
      _answer(session, ReviewGrade.orta); // 3
      expect(session.isFinished, isTrue);
      expect(session.total, 3);
    });

    test('ardışık geri almalar sırayla çalışır', () {
      final session = StudySession(_cards(3));
      _answer(session, ReviewGrade.orta); // 1
      _answer(session, ReviewGrade.orta); // 2

      expect(session.currentId, '3');

      session.undo();
      expect(session.currentId, '2');

      session.undo();
      expect(session.currentId, '1');
      expect(session.completed, 0);
      expect(session.canUndo, isFalse);
    });

    test('bitmiş oturumda geri alma oturumu yeniden açar', () {
      final session = StudySession(_cards(1));
      _answer(session, ReviewGrade.orta);
      expect(session.isFinished, isTrue);

      session.undo();

      expect(session.isFinished, isFalse);
      expect(session.currentId, '1');
      expect(session.progress, 0);
    });

    test('geri alınan cevap tekrar verilebilir', () {
      final session = StudySession(_cards(2));
      _answer(session, ReviewGrade.orta);
      session.undo();

      // Yanlışlıkla "Biliyorum" denmişti; bu kez "Bilmiyorum".
      _answer(session, ReviewGrade.zor);

      expect(session.completed, 0);
      expect(session.currentId, '2');
    });
  });
}
