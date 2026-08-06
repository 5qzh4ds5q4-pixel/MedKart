import 'dart:math';

import '../models/flashcard.dart';
import 'srs_engine.dart';

/// Tek bir çalışma oturumunun kuyruğu.
///
/// [SrsEngine] kartın günler sonrasını planlar; bu sınıf ise oturumun kendi
/// içindeki sırayı yönetir: "Bilmiyorum" denen kart hemen değil, birkaç kart
/// sonra (bkz. [minRequeueDelay]/[maxRequeueDelay]) kuyruğa geri konur ve aynı
/// oturumda tekrar sorulur. Anki'nin öğrenme kuyruğu da böyle çalışır —
/// bilinmeyen kartı ertesi güne bırakmak yerine hemen pekiştirir.
class StudySession {
  StudySession(List<Flashcard> cards, {int Function()? requeueDelay})
    : _queue = cards.map((c) => c.id).toList(),
      _cardIds = cards.map((c) => c.id).toSet(),
      _requeueDelay = requeueDelay ?? _randomRequeueDelay;

  /// "Zor" denen kartın en az kaç kart sonra tekrar sıraya gireceği.
  static const int minRequeueDelay = 5;

  /// "Zor" denen kartın en fazla kaç kart sonra tekrar sıraya gireceği.
  static const int maxRequeueDelay = 10;

  static final _random = Random();

  static int _randomRequeueDelay() =>
      minRequeueDelay + _random.nextInt(maxRequeueDelay - minRequeueDelay + 1);

  /// Sırada bekleyen kart id'leri (tekrar edenler dahil).
  final List<String> _queue;

  /// Oturumdaki benzersiz kartlar.
  final Set<String> _cardIds;

  /// "Zor" denen kartın kaç kart sonra yeniden sıraya gireceğini belirler.
  /// Testlerde sabit bir değer enjekte etmek için constructor'da override edilebilir.
  final int Function() _requeueDelay;

  /// Bu oturumda "Biliyorum" denip geçilen kartlar.
  final Set<String> _learned = {};

  /// Geri alma için verilen cevapların geçmişi.
  final List<_Step> _history = [];

  String? get currentId => _queue.isEmpty ? null : _queue.first;

  /// Geri alınabilecek bir cevap var mı?
  bool get canUndo => _history.isNotEmpty;

  bool get isFinished => _queue.isEmpty;

  /// Oturumdaki toplam kart sayısı.
  int get total => _cardIds.length;

  /// Tamamlanan (bilinen) kart sayısı.
  int get completed => _learned.length;

  /// Henüz bilinmeyen kart sayısı.
  int get remaining => total - completed;

  double get progress => total == 0 ? 1 : completed / total;

  /// Mevcut karta cevap verir ve kuyruğu ilerletir.
  ///
  /// [snapshot] kartın cevaptan önceki hâlidir; cevap geri alınırsa SRS
  /// durumu buradan geri yüklenir.
  void answer(ReviewGrade grade, {required Flashcard snapshot}) {
    if (_queue.isEmpty) return;

    final id = _queue.removeAt(0);
    _history.add(_Step(cardId: id, grade: grade, snapshot: snapshot));

    if (grade.isCorrect) {
      _learned.add(id);
    } else {
      // "Zor": aynı oturumda daha önce bilinmiş olsa bile artık bilinmiyor
      // sayılır ve kart birkaç kart sonra (bkz. [_requeueDelay]) yeniden
      // sıraya konur; kuyruk bu kadar uzun değilse sona eklenir.
      _learned.remove(id);
      final delay = _requeueDelay().clamp(minRequeueDelay, maxRequeueDelay);
      _queue.insert(min(_queue.length, delay), id);
    }
  }

  /// Son cevabı geri alır ve o kartı tekrar sıranın başına koyar.
  ///
  /// Kartın cevap öncesi hâlini döner; çağıranın bunu depoya yazması gerekir.
  /// Geri alınacak cevap yoksa null döner.
  Flashcard? undo() {
    if (_history.isEmpty) return null;

    final step = _history.removeLast();

    if (step.grade.isCorrect) {
      _learned.remove(step.cardId);
    } else {
      // "Zor" kartı kuyruğun ilerisine (requeue) koymuştu; oradan geri çekiyoruz.
      final queuedAt = _queue.lastIndexOf(step.cardId);
      if (queuedAt != -1) _queue.removeAt(queuedAt);
    }

    _queue.insert(0, step.cardId);
    return step.snapshot;
  }
}

/// Geri alma geçmişindeki tek bir adım.
class _Step {
  const _Step({
    required this.cardId,
    required this.grade,
    required this.snapshot,
  });

  final String cardId;
  final ReviewGrade grade;

  /// Kartın cevap verilmeden önceki SRS durumu.
  final Flashcard snapshot;
}
