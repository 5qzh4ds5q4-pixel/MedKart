import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/study_log.dart';

void main() {
  group('recentAverageDailyPace', () {
    test('yetersiz aktif gün varken null döner', () {
      final log = StudyLog({'2026-07-01': 10, '2026-07-02': 10});
      expect(log.recentAverageDailyPace(), isNull);
    });

    test('tam sınırda (minActiveDays) veri varken ortalama hesaplanır', () {
      final log = StudyLog({
        '2026-07-01': 10,
        '2026-07-02': 20,
        '2026-07-03': 30,
      });
      expect(log.recentAverageDailyPace(), 20);
    });

    test('yalnızca en güncel maxDays gün ortalamaya girer', () {
      final log = StudyLog({
        '2026-07-01': 1000, // çok eski, dışarıda kalmalı
        '2026-07-10': 10,
        '2026-07-11': 10,
        '2026-07-12': 10,
        '2026-07-13': 10,
        '2026-07-14': 10,
        '2026-07-15': 10,
        '2026-07-16': 10,
      });
      expect(log.recentAverageDailyPace(maxDays: 7), 10);
    });

    test('0 kart çalışılan günler zaten kaydedilmez, ortalamayı bozmaz', () {
      final log = StudyLog(const {'2026-07-01': 5, '2026-07-02': 15, '2026-07-03': 10});
      expect(log.recentAverageDailyPace(), 10);
    });

    test('minActiveDays parametresiyle eşik özelleştirilebilir', () {
      final log = StudyLog(const {'2026-07-01': 5});
      expect(log.recentAverageDailyPace(minActiveDays: 1), 5);
    });
  });
}
