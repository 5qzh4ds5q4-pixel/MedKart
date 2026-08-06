/// Günlük çalışma geçmişi: hangi gün kaç kart çalışıldı.
///
/// Heatmap (GitHub katkı grafiği tarzı) ve streak (ardışık gün zinciri) için
/// yeterli en hafif kayıt. Her "Zor/Orta/Kolay" cevabı o günün sayacını bir
/// artırır. Günler yerel saatle, gün başına normalize edilir.
class StudyLog {
  const StudyLog([this._counts = const {}]);

  /// Gün (yyyy-MM-dd) -> o gün çalışılan kart sayısı.
  final Map<String, int> _counts;

  /// Gün anahtarı: yerel tarih, saat/dakika atılır.
  static String _key(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// [day] gününde çalışılan kart sayısı.
  int countOn(DateTime day) => _counts[_key(day)] ?? 0;

  /// Toplam çalışılan kart sayısı (tüm günler).
  int get total => _counts.values.fold(0, (a, b) => a + b);

  /// Kayıt bulunan gün sayısı (aktif gün).
  int get activeDays => _counts.length;

  /// Çalışma kaydı bulunan EN ESKİ gün; hiç kayıt yoksa null.
  ///
  /// Gün anahtarları `yyyy-MM-dd` olduğu için sözlük sırası = tarih sırası.
  /// Isı haritası ızgarasını yeni hesaplarda küçültmek için kullanılır (bkz.
  /// `StudyHeatmap`): 2 günlük bir hesaba 84 boş kare göstermemek için.
  DateTime? get firstStudyDay {
    if (_counts.isEmpty) return null;
    final earliest = _counts.keys.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    return DateTime.tryParse(earliest);
  }

  /// Son [maxDays] AKTİF (en az bir kart çalışılmış) günün ortalama günlük
  /// kart sayısı — sınav tempo tahmini için (bkz. `SrsEngine.examPaceWarning`).
  ///
  /// [_counts] zaten yalnızca sayacı >0 olan günleri tutuyor (bkz. sınıf
  /// yorumu), bu yüzden burada ayrıca 0'ları elemeye gerek yok — en güncel
  /// [maxDays] kaydın ortalaması alınır. Toplam aktif gün sayısı
  /// [minActiveDays]'ten azsa (yeterli veri yok) tahmin yapmadan `null` döner.
  double? recentAverageDailyPace({int maxDays = 7, int minActiveDays = 3}) {
    if (_counts.length < minActiveDays) return null;

    final recentKeys = (_counts.keys.toList()..sort()).reversed.take(maxDays);
    final sum = recentKeys.fold<int>(0, (a, key) => a + _counts[key]!);
    return sum / recentKeys.length;
  }

  /// [now] gününün sayacını bir artırıp yeni bir [StudyLog] döner (değişmez).
  StudyLog recordStudy(DateTime now) {
    final key = _key(now);
    return StudyLog({..._counts, key: (_counts[key] ?? 0) + 1});
  }

  /// Bugüne kadar kesintisiz ardışık çalışma günü sayısı.
  ///
  /// Bugün henüz çalışılmadıysa zincir kopmuş sayılmaz: düne kadar sayılır
  /// (gün içinde kullanıcıya tolerans). Bugün ve dün de boşsa 0.
  int currentStreak(DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if (countOn(day) == 0) {
      day = day.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (countOn(day) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Map<String, dynamic> toJson() => {..._counts};

  factory StudyLog.fromJson(Object? json) {
    if (json is! Map) return const StudyLog();
    final counts = <String, int>{};
    json.forEach((key, value) {
      final count = (value as num?)?.toInt();
      if (key is String && count != null && count > 0) counts[key] = count;
    });
    return StudyLog(counts);
  }
}
