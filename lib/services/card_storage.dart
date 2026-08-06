import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck.dart';
import '../models/exam_result.dart';
import '../models/flashcard.dart';
import '../models/study_log.dart';
import 'library_codec.dart';

/// Diske yazılan bütün veri: desteler, kartlar ve günlük çalışma geçmişi.
class LibraryData {
  const LibraryData({
    this.decks = const [],
    this.cards = const [],
    this.studyLog = const StudyLog(),
    this.examResults = const [],
  });

  final List<Deck> decks;
  final List<Flashcard> cards;

  /// Heatmap/streak için günlük çalışma sayaçları.
  final StudyLog studyLog;

  /// Tamamlanmış deneme sınavlarının geçmişi (en yeni önce).
  ///
  /// Burada durduğu için yedekleme ve bulut senkronuna kendiliğinden dahil.
  final List<ExamResult> examResults;

  bool get isEmpty => decks.isEmpty && cards.isEmpty;
}

/// Kalıcılığın soyut arayüzü.
///
/// İleride buluta/backend'e taşınacaksa bu arayüzü uygulayan yeni bir sınıf
/// yazmak yeterli.
abstract class CardStorage {
  Future<LibraryData> load();
  Future<void> save(LibraryData data);
}

/// shared_preferences tabanlı kalıcılık.
///
/// Web'de tarayıcının localStorage'ına, Android'de SharedPreferences'a yazar.
class SharedPrefsCardStorage implements CardStorage {
  /// Deste desteği gelmeden önceki kayıt: yalnızca kart dizisi.
  static const String legacyKey = 'medkart.cards.v1';

  /// Güncel kayıt: {"decks": [...], "cards": [...]}
  static const String storageKey = 'medkart.library.v2';

  /// v1 kayıtları taşınırken kartların konduğu destenin adı.
  static const String migratedDeckName = 'Kartlarım';

  @override
  Future<LibraryData> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) return _parseLibrary(raw);

      // v2 yoksa, deste öncesi kayıt var mı diye bak ve taşı.
      final legacy = prefs.getString(legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        final migrated = _migrateLegacy(legacy);
        if (!migrated.isEmpty) {
          await save(migrated);
          debugPrint('${migrated.cards.length} kart yeni deste yapısına taşındı.');
        }
        return migrated;
      }

      return const LibraryData();
    } catch (e) {
      // Okuma bütünüyle başarısızsa uygulama boş kütüphaneyle açılır.
      debugPrint('Kütüphane yüklenemedi: $e');
      return const LibraryData();
    }
  }

  @override
  Future<void> save(LibraryData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(LibraryCodec.toMap(data));
      await prefs.setString(storageKey, raw);
    } catch (e) {
      debugPrint('Kütüphane kaydedilemedi: $e');
    }
  }

  LibraryData _parseLibrary(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const LibraryData();
    return LibraryCodec.fromMap(decoded);
  }

  /// Deste öncesi kayıttaki kartları tek bir desteye toplar.
  ///
  /// Kullanıcının eski kartları ve SRS ilerlemesi korunur.
  LibraryData _migrateLegacy(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const LibraryData();

    final cards = LibraryCodec.parseList(decoded, Flashcard.fromJson, 'kart');
    if (cards.isEmpty) return const LibraryData();

    final deck = Deck(
      id: 'deck-migrated',
      name: migratedDeckName,
      createdAt: DateTime.now(),
    );

    return LibraryData(
      decks: [deck],
      cards: [for (final card in cards) card.copyWith(deckId: deck.id)],
    );
  }
}
