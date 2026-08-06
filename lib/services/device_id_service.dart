import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Anonim cihaz kimliği: projede henüz kullanıcı hesabı/login olmadığı için
/// Supabase Edge Function'daki `kullanim_kota` sayacının "kullanıcı_id"si
/// olarak kullanılan, ilk açılışta üretilip yerelde saklanan rastgele bir
/// UUID v4.
///
/// Bu bir kimlik DOĞRULAMASI değil — yalnızca aynı cihazın istekleri aynı
/// kota satırında toplansın diye. Auth eklenince gerçek kullanıcı_id'ye
/// taşınabilir (bkz. CLAUDE.md "Bilinmeyen / Henüz Kararlaştırılmamış").
class DeviceIdService {
  static const String _storageKey = 'medkart.deviceId.v1';

  static String? _cached;

  /// Kalıcı cihaz kimliğini döner; yoksa üretip kaydeder.
  static Future<String> getOrCreate() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_storageKey);
    if (id == null || id.isEmpty) {
      id = _generateUuidV4();
      await prefs.setString(_storageKey, id);
    }
    _cached = id;
    return id;
  }

  static String _generateUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx

    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
