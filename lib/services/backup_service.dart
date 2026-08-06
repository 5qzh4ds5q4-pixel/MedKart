import 'dart:convert';

import '../models/deck.dart';
import 'card_storage.dart';
import 'library_codec.dart';

/// Kütüphanenin JSON yedeğini üretir ve okur.
///
/// Amaç veri kaybına karşı taşınabilir bir yedek. [export] bütün kütüphaneyi
/// (desteler, kartlar, SRS ilerlemesi, çalışma geçmişi) TEK dosyaya çevirir;
/// [exportDeck] ise tek bir desteyi kendi dosyasına çevirir (Ayarlar'daki
/// dışa aktarma 2026-08-05'ten beri deste başına ayrı dosya indirir). İkisi
/// de aynı zarfı kullanır, [tryImport] ikisini de açar. Saf
/// ([BuildContext]/IO'suz) tutulur ki testlerle doğrulanabilsin; dosya
/// indir/seç işi platform şimine bırakılır.
class BackupService {
  const BackupService._();

  /// Yedek dosyasının kimliği ve biçim sürümü.
  static const String appTag = 'medkart';
  static const int formatVersion = 2;

  /// [data]'yı okunabilir (girintili) JSON metnine çevirir.
  static String export(LibraryData data) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': appTag,
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      ...LibraryCodec.toMap(data),
    });
  }

  /// [data] içinden YALNIZCA [deck]'i ve o desteye ait kartları içeren bir
  /// yedek üretir (deste başına ayrı dosya için — bkz. Ayarlar > "Yedeği dışa
  /// aktar"). Zarf [export] ile BİREBİR aynı biçimde (app/version/decks/cards)
  /// olduğundan [tryImport] bu dosyaları da sorunsuz açar.
  ///
  /// `studyLog` ve `examResults` BİLEREK dahil edilmez: ikisi de kütüphane
  /// GENELİ veridir (gün bazlı çalışma sayaçları / karışık-konu deneme sınavı
  /// geçmişi), tek bir desteye ait değildir — her deste dosyasına kopyalamak
  /// hem dosyaları şişirir hem "bu dosya bu destenin verisi" beklentisini
  /// bozar.
  static String exportDeck(LibraryData data, Deck deck) {
    return export(
      LibraryData(
        decks: [deck],
        cards: data.cards.where((c) => c.deckId == deck.id).toList(),
      ),
    );
  }

  /// JSON metnini kütüphaneye çözer. Geçersiz/yabancı dosyada null döner.
  ///
  /// "Geçerli" sayılması için MedKart yedeği görünmesi yeterlidir: en az
  /// `decks` veya `cards` listesi içermeli. Bozuk tek kayıtlar atlanır.
  static LibraryData? tryImport(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      return null;
    }

    if (decoded is! Map) return null;
    // Yanlış dosyaya karşı basit koruma: bizim biçimimize benziyor mu?
    final looksLikeBackup =
        decoded['app'] == appTag ||
        decoded['decks'] is List ||
        decoded['cards'] is List;
    if (!looksLikeBackup) return null;

    return LibraryCodec.fromMap(decoded);
  }

  /// İndirilecek dosya için önerilen ad (tarih damgalı).
  static String suggestedFileName([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'medkart-yedek-${d.year}${two(d.month)}${two(d.day)}.json';
  }

  /// Deste bazlı dosya adı: `medkart-<deste-adi>-YYYYAAGG.json`. Deste adı
  /// dosya adına güvenli hâle getirilir (bkz. [_fileSafeName]).
  static String suggestedDeckFileName(String deckName, [DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'medkart-${_fileSafeName(deckName)}-'
        '${d.year}${two(d.month)}${two(d.day)}.json';
  }

  /// Deste adını dosya adına güvenli hâle getirir: Türkçe karakterler ASCII'ye
  /// sadeleştirilir, harf/rakam dışı her şey tek tireye iner. Ad tamamen
  /// elenirse (yalnızca sembol vb.) 'deste' kullanılır.
  ///
  /// Türkçe harfler `toLowerCase`'ten ÖNCE eşlenir: 'İ'.toLowerCase() Dart'ta
  /// "i + birleşen nokta" (iki code point) üretir ve regex'ten kaçar.
  static String _fileSafeName(String name) {
    const turkish = {
      'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i',
      'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u',
    };
    final mapped =
        name.split('').map((ch) => turkish[ch] ?? ch).join().toLowerCase();
    final safe = mapped
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return safe.isEmpty ? 'deste' : safe;
  }
}
