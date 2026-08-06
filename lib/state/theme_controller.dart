import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının açık/koyu tema tercihini tutar ve kalıcı kaydeder.
///
/// İlk açılışta tercih yoksa [ThemeMode.system] ile cihazın ayarına uyulur;
/// kullanıcı toggle'a basınca seçim ([ThemeMode.light]/[ThemeMode.dark])
/// diske yazılır ve sonraki açılışlarda korunur.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.system})
    : _mode = initialMode;

  static const String storageKey = 'medkart.themeMode.v1';

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  /// Açılışta diskteki tercihi okur. Kayıt yoksa/okunamıyorsa [system] döner.
  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _parse(prefs.getString(storageKey));
    } catch (e) {
      debugPrint('Tema tercihi yüklenemedi: $e');
      return ThemeMode.system;
    }
  }

  /// Temayı belirli bir moda ayarlar ve kalıcı yazar.
  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    _persist();
  }

  /// Toggle butonu için: o an ekranda görünen parlaklığın tersine geçer.
  ///
  /// [isCurrentlyDark] çağıran taraftan gelir (mod [system] iken cihaz
  /// parlaklığı da hesaba katılabilsin diye), böylece tek dokunuşta beklenen
  /// yöne geçilir.
  void toggle({required bool isCurrentlyDark}) {
    setMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  void _persist() {
    // Arayüz diske yazmayı beklemesin; hata olursa yalnızca loglanır.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(storageKey, _mode.name))
        .catchError((Object e) {
          debugPrint('Tema tercihi kaydedilemedi: $e');
          return false;
        });
  }

  static ThemeMode _parse(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
