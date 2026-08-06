import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('kayıt yokken varsayılan limit döner', () async {
    expect(
      await StudySettings.load(),
      StudySettings.defaultDailyNewCardLimit,
    );
  });

  test('kaydedilen limit sonraki açılışta okunur', () async {
    SharedPreferences.setMockInitialValues({
      StudySettings.storageKey: 30,
    });
    expect(await StudySettings.load(), 30);
  });

  test('setDailyNewCardLimit diske yazar ve dinleyicileri uyarır', () async {
    final settings = StudySettings();
    var notified = 0;
    settings.addListener(() => notified++);

    settings.setDailyNewCardLimit(15);

    expect(settings.dailyNewCardLimit, 15);
    expect(notified, 1);
    // Fire-and-forget yazımın tamamlanmasını bekle.
    await Future<void>.delayed(Duration.zero);
    expect(await StudySettings.load(), 15);
  });

  test('aralık dışı değerler sınıra sıkıştırılır', () {
    final settings = StudySettings();

    settings.setDailyNewCardLimit(0);
    expect(settings.dailyNewCardLimit, StudySettings.minDailyNewCardLimit);

    settings.setDailyNewCardLimit(9999);
    expect(settings.dailyNewCardLimit, StudySettings.maxDailyNewCardLimit);
  });

  test('aynı değer verilince dinleyiciler uyarılmaz', () {
    final settings = StudySettings(initialDailyNewCardLimit: 20);
    var notified = 0;
    settings.addListener(() => notified++);

    settings.setDailyNewCardLimit(20);

    expect(notified, 0);
  });

  group('Öncelikli Mod', () {
    test('kayıt yokken hiçbir deste açık değildir', () async {
      expect(await StudySettings.loadPriorityModeDeckIds(), isEmpty);
    });

    test('kaydedilen deste id\'leri sonraki açılışta okunur', () async {
      SharedPreferences.setMockInitialValues({
        StudySettings.priorityModeStorageKey: ['d1', 'd2'],
      });
      expect(await StudySettings.loadPriorityModeDeckIds(), {'d1', 'd2'});
    });

    test('setPriorityMode açar/kapatır, diske yazar ve dinleyicileri uyarır', () async {
      final settings = StudySettings();
      var notified = 0;
      settings.addListener(() => notified++);

      settings.setPriorityMode('d1', true);

      expect(settings.isPriorityMode('d1'), isTrue);
      expect(notified, 1);
      await Future<void>.delayed(Duration.zero);
      expect(await StudySettings.loadPriorityModeDeckIds(), {'d1'});

      settings.setPriorityMode('d1', false);

      expect(settings.isPriorityMode('d1'), isFalse);
      expect(notified, 2);
      await Future<void>.delayed(Duration.zero);
      expect(await StudySettings.loadPriorityModeDeckIds(), isEmpty);
    });

    test('zaten aynı durumdayken dinleyiciler uyarılmaz', () {
      final settings = StudySettings();
      var notified = 0;
      settings.addListener(() => notified++);

      settings.setPriorityMode('d1', false); // zaten kapalı

      expect(notified, 0);
    });

    test('diğer destelere dokunmadan tek bir desteyi açar/kapatır', () {
      final settings = StudySettings(
        initialPriorityModeDeckIds: const {'d1'},
      );

      settings.setPriorityMode('d2', true);

      expect(settings.priorityModeDeckIds, {'d1', 'd2'});
    });
  });
}
