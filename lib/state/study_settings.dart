import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının günlük çalışma tercihlerini tutar ve kalıcı kaydeder.
///
/// Tercihler:
/// - [dailyNewCardLimit]: günde en fazla kaç yeni (hiç çalışılmamış) kart
///   kuyruğa girsin. Bkz. [FlashcardStore.dailyQueue].
/// - [dailyGoal]: OPSİYONEL günlük çalışma hedefi (bkz. o alanın yorumu).
/// - [priorityModeDeckIds]: Öncelikli Mod açık desteler.
///
/// Hepsi cihaz bazlı (`shared_preferences`), bulut senkronuna dahil değil.
class StudySettings extends ChangeNotifier {
  StudySettings({
    int initialDailyNewCardLimit = defaultDailyNewCardLimit,
    Set<String> initialPriorityModeDeckIds = const {},
    int? initialDailyGoal,
  }) : _dailyNewCardLimit = initialDailyNewCardLimit,
       _priorityModeDeckIds = {...initialPriorityModeDeckIds},
       _dailyGoal = _normalizeGoal(initialDailyGoal);

  static const String storageKey = 'medkart.dailyNewCardLimit.v1';

  /// Günlük hedef kendi anahtarında saklanır — [storageKey]'den (yeni kart
  /// limiti) TAMAMEN AYRI bir kavram: limit kuyruğa kaç YENİ kart gireceğini
  /// belirler, hedef ise yalnızca istatistik ekranındaki ilerleme halkasını
  /// besler ve hiçbir kuyruk/SRS davranışını etkilemez.
  static const String dailyGoalStorageKey = 'medkart.dailyGoal.v1';

  /// Öncelikli Mod açık olan desteler — bkz. [priorityModeDeckIds]. Cihaz
  /// bazlı (bulut senkronuna dahil değil), o yüzden kendi anahtarıyla ayrı
  /// saklanır.
  static const String priorityModeStorageKey =
      'medkart.priorityModeDeckIds.v1';

  static const int defaultDailyNewCardLimit = 20;
  static const int minDailyNewCardLimit = 1;
  static const int maxDailyNewCardLimit = 200;

  static const int minDailyGoal = 1;
  static const int maxDailyGoal = 500;

  int _dailyNewCardLimit;
  int get dailyNewCardLimit => _dailyNewCardLimit;

  int? _dailyGoal;

  /// Kullanıcının OPSİYONEL günlük çalışma hedefi (kart sayısı).
  ///
  /// `null` = hedef belirlenmemiş (VARSAYILAN). Bu durumda istatistik
  /// ekranındaki "Bugün" kartı halka göstermez, yalnızca sayıyı yazar —
  /// hedef bir zorunluluk değil, isteyenin açtığı bir motivasyon aracı.
  /// Hiçbir kuyruk/SRS davranışını etkilemez.
  int? get dailyGoal => _dailyGoal;

  bool get hasDailyGoal => _dailyGoal != null;

  /// Geçersiz (null/0/negatif) değerleri "hedef yok"a, aralık dışını sınıra
  /// çeker. Diskten okunan bozuk bir değer de buradan geçer.
  static int? _normalizeGoal(int? value) {
    if (value == null || value <= 0) return null;
    return value.clamp(minDailyGoal, maxDailyGoal);
  }

  final Set<String> _priorityModeDeckIds;

  /// Öncelikli Mod açık olan destelerin id'leri (bkz.
  /// [FlashcardStore.dailyQueue] `priorityModeDeckIds` parametresi). Cihaz
  /// bazlı bir tercih — bulut senkronuna DAHİL DEĞİL.
  Set<String> get priorityModeDeckIds => Set.unmodifiable(_priorityModeDeckIds);

  bool isPriorityMode(String deckId) => _priorityModeDeckIds.contains(deckId);

  /// Açılışta diskteki tercihi okur. Kayıt yoksa/okunamıyorsa varsayılan döner.
  static Future<int> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(storageKey) ?? defaultDailyNewCardLimit;
    } catch (e) {
      debugPrint('Günlük kart limiti yüklenemedi: $e');
      return defaultDailyNewCardLimit;
    }
  }

  /// Limiti günceller ve kalıcı yazar. Geçerli aralığın ([minDailyNewCardLimit]
  /// - [maxDailyNewCardLimit]) dışındaki değerler sınıra sıkıştırılır.
  void setDailyNewCardLimit(int value) {
    final clamped = value.clamp(minDailyNewCardLimit, maxDailyNewCardLimit);
    if (clamped == _dailyNewCardLimit) return;

    _dailyNewCardLimit = clamped;
    notifyListeners();
    _persist();
  }

  void _persist() {
    // Arayüz diske yazmayı beklemesin; hata olursa yalnızca loglanır.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(storageKey, _dailyNewCardLimit))
        .catchError((Object e) {
          debugPrint('Günlük kart limiti kaydedilemedi: $e');
          return false;
        });
  }

  /// Açılışta diskteki günlük hedefi okur. Kayıt yoksa/okunamıyorsa `null`
  /// (hedef belirlenmemiş) döner — hedef opsiyonel olduğu için "kayıt yok"
  /// bir hata değil, normal varsayılan durum.
  static Future<int?> loadDailyGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _normalizeGoal(prefs.getInt(dailyGoalStorageKey));
    } catch (e) {
      debugPrint('Günlük hedef yüklenemedi: $e');
      return null;
    }
  }

  /// Günlük hedefi günceller ve kalıcı yazar. `null` (ya da 0/negatif) vermek
  /// hedefi TEMİZLER — kullanıcı alanı boş bırakabilsin diye.
  void setDailyGoal(int? value) {
    final normalized = _normalizeGoal(value);
    if (normalized == _dailyGoal) return;

    _dailyGoal = normalized;
    notifyListeners();
    _persistDailyGoal();
  }

  void _persistDailyGoal() {
    final goal = _dailyGoal;
    SharedPreferences.getInstance()
        .then(
          (prefs) => goal == null
              // Hedef kaldırıldıysa anahtarı da sil: bir dahaki açılışta
              // "kayıt yok" = "hedef yok" olarak okunsun.
              ? prefs.remove(dailyGoalStorageKey)
              : prefs.setInt(dailyGoalStorageKey, goal),
        )
        .catchError((Object e) {
          debugPrint('Günlük hedef kaydedilemedi: $e');
          return false;
        });
  }

  /// Açılışta diskteki Öncelikli Mod tercihlerini okur. Kayıt yoksa/
  /// okunamıyorsa boş küme (hiçbir deste açık değil) döner.
  static Future<Set<String>> loadPriorityModeDeckIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(priorityModeStorageKey) ?? const []).toSet();
    } catch (e) {
      debugPrint('Öncelikli Mod tercihleri yüklenemedi: $e');
      return const {};
    }
  }

  /// [deckId] için Öncelikli Mod'u açar/kapatır ve kalıcı yazar.
  void setPriorityMode(String deckId, bool enabled) {
    final changed = enabled
        ? _priorityModeDeckIds.add(deckId)
        : _priorityModeDeckIds.remove(deckId);
    if (!changed) return;

    notifyListeners();
    _persistPriorityMode();
  }

  void _persistPriorityMode() {
    SharedPreferences.getInstance()
        .then(
          (prefs) => prefs.setStringList(
            priorityModeStorageKey,
            _priorityModeDeckIds.toList(),
          ),
        )
        .catchError((Object e) {
          debugPrint('Öncelikli Mod tercihleri kaydedilemedi: $e');
          return false;
        });
  }
}
