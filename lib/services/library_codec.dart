import '../models/deck.dart';
import '../models/exam_result.dart';
import '../models/flashcard.dart';
import '../models/study_log.dart';
import 'package:flutter/foundation.dart';

import 'card_storage.dart';

/// Kütüphanenin ([LibraryData]) JSON'a çevrilmesi ve okunması — hem yerel
/// depolama ([SharedPrefsCardStorage]) hem yedek dışa/içe aktarma
/// ([BackupService]) aynı mantığı paylaşsın diye tek yerde toplanır.
///
/// Okuma hoşgörülüdür: bozuk tek bir kayıt tüm listenin kaybolmasına yol açmaz.
class LibraryCodec {
  const LibraryCodec._();

  static Map<String, dynamic> toMap(LibraryData data) => {
    'decks': data.decks.map((d) => d.toJson()).toList(),
    'cards': data.cards.map((c) => c.toJson()).toList(),
    'studyLog': data.studyLog.toJson(),
    'examResults': data.examResults.map((r) => r.toJson()).toList(),
  };

  static LibraryData fromMap(Map<dynamic, dynamic> decoded) => LibraryData(
    decks: parseList(decoded['decks'], Deck.fromJson, 'deste'),
    cards: parseList(decoded['cards'], Flashcard.fromJson, 'kart'),
    studyLog: StudyLog.fromJson(decoded['studyLog']),
    // Alan yoksa (bu özellikten önceki kayıtlar) boş liste — geriye dönük
    // uyumlu, eski yedekler sorunsuz açılır.
    examResults: parseList(
      decoded['examResults'],
      ExamResult.fromJson,
      'sınav sonucu',
    ),
  );

  /// Tek bir bozuk kayıt tüm listenin kaybolmasına yol açmasın.
  static List<T> parseList<T>(
    Object? source,
    T Function(Map<String, dynamic>) fromJson,
    String label,
  ) {
    if (source is! List) return [];

    final items = <T>[];
    for (final item in source) {
      if (item is! Map) continue;
      try {
        items.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        debugPrint('Bozuk $label atlandı: $e');
      }
    }
    return items;
  }
}
