import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/deck.dart';
import '../models/exam_result.dart';
import '../models/flashcard.dart';
import '../models/study_log.dart';
import 'card_storage.dart';
import 'library_codec.dart';

/// Kullanıcı-bazlı bulut senkronu (Faz 2).
///
/// `kullanici_kutuphane` tablosuna doğrudan yazar/okur (pdf_cache'in aksine
/// Edge Function YOK — RLS zaten `auth.uid() = user_id` ile kilitli, bkz.
/// migration). Zorunlu login kapısı olmadığı için bu servis her zaman
/// [AuthService.currentUser] doluyken çağrılır; hata durumunda (ağ yok,
/// yetki yok, Supabase yapılandırılmadı) sessizce `null`/no-op döner —
/// lokal kullanım hiçbir zaman bu servise bağımlı değildir.
class SyncService {
  SyncService({SupabaseClient? client}) : _clientOverride = client;

  /// Testlerde sahte bir istemci enjekte etmek için.
  final SupabaseClient? _clientOverride;

  static const String _table = 'kullanici_kutuphane';

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      // Supabase.initialize hiç çağrılmadı (.env eksik).
      return null;
    }
  }

  bool get isConfigured => _client != null;

  /// [userId]'nin bulut kütüphanesini indirir. Satır yoksa (ilk giriş) ya da
  /// herhangi bir sorun olursa `null` döner — çağıran taraf lokal veriye
  /// dokunmadan devam eder.
  Future<LibraryData?> downloadLibrary(String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final row = await client
          .from(_table)
          .select('library_data')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;

      final raw = row['library_data'];
      if (raw is! Map) return null;
      return LibraryCodec.fromMap(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('Kütüphane buluttan indirilemedi: $e');
      return null;
    }
  }

  /// Lokal [data]'yı [userId] için buluta yazar (upsert). Başarısızlık
  /// sessizce yutulur — kullanıcının lokal çalışması hiç etkilenmez.
  Future<void> uploadLibrary(String userId, LibraryData data) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from(_table).upsert({
        'user_id': userId,
        'library_data': LibraryCodec.toMap(data),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Kütüphane buluta yazılamadı: $e');
    }
  }

  /// Kullanıcının yasal onayını (KVKK/Kullanım Koşulları) [userId] için
  /// kaydeder — `kullanici_kutuphane` tablosundaki `kvkk_onay_tarihi`/
  /// `kvkk_metin_surumu` sütunlarına upsert edilir (bkz. migration
  /// `20260724010000_add_legal_consent_columns.sql`). `library_data` alanı
  /// KASITLI OLARAK gönderilmez: bu satır zaten varsa (ör. senkron akışı
  /// önce çalıştıysa) mevcut kütüphaneyi EZMEZ; satır henüz yoksa tablonun
  /// `library_data` sütunundaki varsayılan boş değer kullanılır. Başarısızlık
  /// (ör. migration henüz deploy edilmediyse) sessizce yutulur — onay akışı
  /// hiçbir zaman giriş/kayıt işlemini bloklamamalı.
  Future<void> recordLegalConsent(String userId, String textVersion) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from(_table).upsert({
        'user_id': userId,
        'kvkk_onay_tarihi': DateTime.now().toIso8601String(),
        'kvkk_metin_surumu': textVersion,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Yasal onay kaydedilemedi: $e');
    }
  }

  /// [local] ve [remote] kütüphanelerini hiçbir kart/deste/çalışma günü
  /// kaybolmayacak şekilde birleştirir (saf fonksiyon, ağ/IO yok).
  ///
  /// - Desteler AYNI İSİMLE birleşir (farklı cihazlarda aynı deste adıyla
  ///   oluşturulmuş olabilir); farklı isimliler ayrı kalır.
  /// - Kartlar önce [Flashcard.id] ile eşleştirilir; eşleşmeyenler için
  ///   (question + sourcePage) ikilisi yedek kimlik sayılır (aynı PDF'ten
  ///   iki cihazda bağımsız üretilmiş "aynı" kart farklı id taşıyabilir).
  ///   İki tarafta da varsa SM-2 bakımından DAHA İLERİ olan (repetitions
  ///   yüksek, eşitse nextReview'ü geç olan) tutulur.
  /// - `studyLog` gün bazlı BÜYÜK sayım alınarak birleşir.
  /// - `examResults` id bazlı birleşir (iki cihazda girilen denemeler
  ///   toplanır), en yeni önce sıralanır ve geçmiş sınırına kırpılır.
  static LibraryData mergeLibraries(LibraryData local, LibraryData remote) {
    final deckMerge = _mergeDecks(local.decks, remote.decks);
    final cards = _mergeCards(local.cards, remote.cards, deckMerge.remap);
    final studyLog = _mergeStudyLog(local.studyLog, remote.studyLog);
    final examResults = _mergeExamResults(
      local.examResults,
      remote.examResults,
      deckMerge.remap,
    );
    return LibraryData(
      decks: deckMerge.decks,
      cards: cards,
      studyLog: studyLog,
      examResults: examResults,
    );
  }

  /// Sınav sonuçları BİRLEŞTİRİLMEZ, TOPLANIR: her sonuç geçmişte olmuş
  /// bağımsız bir olay, iki tarafta çakışan bir "durum" değil. Aynı id iki
  /// kez gelirse (aynı kayıt senkronla gidip gelmiş) tek kopya tutulur.
  static List<ExamResult> _mergeExamResults(
    List<ExamResult> local,
    List<ExamResult> remote,
    Map<String, String> deckRemap,
  ) {
    final byId = <String, ExamResult>{};
    for (final result in [...local, ...remote]) {
      // Deste birleşmesinde id değiştiyse sonucu hayatta kalan desteye taşı.
      final deckId = result.deckId;
      byId[result.id] = deckId == null
          ? result
          : ExamResult(
              id: result.id,
              deckId: deckRemap[deckId] ?? deckId,
              takenAt: result.takenAt,
              correctCount: result.correctCount,
              totalQuestions: result.totalQuestions,
              topicScores: result.topicScores,
            );
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return merged.length > ExamResult.maxHistory
        ? merged.sublist(0, ExamResult.maxHistory)
        : merged;
  }

  static _DeckMerge _mergeDecks(List<Deck> local, List<Deck> remote) {
    final survivorsByName = <String, Deck>{};
    final remap = <String, String>{};

    void ingest(Deck deck) {
      final existing = survivorsByName[deck.name];
      if (existing == null) {
        survivorsByName[deck.name] = deck;
        remap[deck.id] = deck.id;
        return;
      }
      remap[deck.id] = existing.id;
      if (!existing.hasExamDate && deck.hasExamDate) {
        survivorsByName[deck.name] = existing.withExamDate(deck.examDate);
      }
    }

    for (final deck in local) {
      ingest(deck);
    }
    for (final deck in remote) {
      ingest(deck);
    }

    return _DeckMerge(survivorsByName.values.toList(), remap);
  }

  static List<Flashcard> _mergeCards(
    List<Flashcard> local,
    List<Flashcard> remote,
    Map<String, String> deckRemap,
  ) {
    Flashcard remapDeck(Flashcard card) {
      final newDeckId = deckRemap[card.deckId];
      return newDeckId == null ? card : card.copyWith(deckId: newDeckId);
    }

    final localList = local.map(remapDeck).toList();
    final remoteList = remote.map(remapDeck).toList();
    final remoteById = {for (final c in remoteList) c.id: c};

    final result = <Flashcard>[];
    final unmatchedLocal = <Flashcard>[];
    final matchedRemoteIds = <String>{};

    for (final card in localList) {
      final match = remoteById[card.id];
      if (match == null) {
        unmatchedLocal.add(card);
      } else {
        result.add(_moreAdvanced(card, match));
        matchedRemoteIds.add(card.id);
      }
    }

    final remoteRemaining = remoteList
        .where((c) => !matchedRemoteIds.contains(c.id))
        .toList();

    for (final card in unmatchedLocal) {
      final key = _cardKey(card);
      final matchIndex = remoteRemaining.indexWhere(
        (c) => _cardKey(c) == key,
      );
      if (matchIndex == -1) {
        result.add(card);
      } else {
        result.add(_moreAdvanced(card, remoteRemaining[matchIndex]));
        remoteRemaining.removeAt(matchIndex);
      }
    }

    result.addAll(remoteRemaining);
    return result;
  }

  static String _cardKey(Flashcard card) =>
      '${card.question.trim()} ${card.sourcePage}';

  /// SM-2 bakımından daha ileri olanı (öğrencinin emeğini) korur.
  static Flashcard _moreAdvanced(Flashcard a, Flashcard b) {
    if (a.repetitions != b.repetitions) {
      return a.repetitions > b.repetitions ? a : b;
    }
    final aNext = a.nextReview;
    final bNext = b.nextReview;
    if (aNext == null && bNext == null) return a;
    if (aNext == null) return b;
    if (bNext == null) return a;
    return aNext.isAfter(bNext) ? a : b;
  }

  static StudyLog _mergeStudyLog(StudyLog local, StudyLog remote) {
    final merged = <String, dynamic>{...local.toJson()};
    remote.toJson().forEach((day, count) {
      final existing = (merged[day] as num?)?.toInt() ?? 0;
      final incoming = (count as num?)?.toInt() ?? 0;
      merged[day] = existing > incoming ? existing : incoming;
    });
    return StudyLog.fromJson(merged);
  }
}

class _DeckMerge {
  const _DeckMerge(this.decks, this.remap);

  final List<Deck> decks;

  /// Eski deste id'sinden (hem local hem remote) hayatta kalan desteye harita.
  final Map<String, String> remap;
}
