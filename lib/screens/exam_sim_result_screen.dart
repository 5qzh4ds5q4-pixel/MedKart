import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam_result.dart';
import '../services/mcq_generator.dart';
import '../srs/srs_engine.dart';
import '../state/flashcard_store.dart';
import '../utils/breakpoints.dart';
import '../widgets/content_shell.dart';
import '../widgets/topic_success_bar.dart';
import 'exam_sim_quiz_screen.dart';

/// Deneme Sınavı sonuç ekranı: toplu puan + süre + konu bazlı kırılım +
/// yanlış sorular listesi (doğru/yanlış gösterimi İLK KEZ burada yapılır,
/// sınav sırasında değil — bkz. [ExamSimQuizScreen]).
class ExamSimResultScreen extends StatefulWidget {
  const ExamSimResultScreen({
    super.key,
    required this.questions,
    required this.selections,
    required this.elapsedSeconds,
    required this.targetSeconds,
    this.deckId,
  });

  final List<McqQuestion> questions;

  /// Sınavın kapsamı deste bazlıysa o destenin id'si; deneme sınavı kütüphane
  /// geneli olduğu için normalde null (bkz. [ExamResult.deckId]). Kıyas aynı
  /// [deckId]'ye sahip bir önceki sonuçla yapılır.
  final String? deckId;

  /// Soru başına seçilen şık index'i; null = boş bırakıldı (yanlış sayılır).
  final List<int?> selections;

  final int elapsedSeconds;
  final int targetSeconds;

  @override
  State<ExamSimResultScreen> createState() => _ExamSimResultScreenState();
}

class _ExamSimResultScreenState extends State<ExamSimResultScreen> {
  /// "Yanlışları tekrar çalışmaya ekle" bir kez basılabilir.
  bool _wrongOnesQueued = false;

  /// Bu sınavdan ÖNCEKİ son sonuç — kaydetmeden önce yakalanır, yoksa null
  /// (ilk deneme) ve kıyas bloğu hiç gösterilmez.
  ExamComparison? _comparison;

  /// Sonuç yalnızca bir kez kaydedilsin (hot reload / yeniden build koruması).
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    // Kayıt store'u değiştirip notifyListeners tetikliyor; build sırasında
    // olmasın diye ilk kareden sonraya bırakılıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordResult());
  }

  /// Sınavı geçmişe yazar ve varsa bir öncekiyle kıyası hesaplar.
  void _recordResult() {
    if (!mounted || _recorded) return;
    _recorded = true;

    final store = context.read<FlashcardStore>();
    // ÖNCE oku: kaydettikten sonra "son sonuç" bu sınavın kendisi olurdu.
    final previous = store.lastExamResultFor(widget.deckId);

    final current = ExamResult(
      id: 'exam-${DateTime.now().microsecondsSinceEpoch}',
      deckId: widget.deckId,
      takenAt: DateTime.now(),
      correctCount: _correctCount,
      totalQuestions: widget.questions.length,
      topicScores: _topicScores(store),
    );
    store.recordExamResult(current);

    if (previous == null) return;
    setState(() => _comparison = ExamComparison.between(previous, current));
  }

  /// Kayıt için konu bazlı doğru/toplam. [_topicBreakdown]'dan ayrı tutuldu:
  /// o ekrandaki mevcut çubukları besliyor ve davranışı değişmemeli.
  List<ExamTopicScore> _topicScores(FlashcardStore store) {
    final total = <String, int>{};
    final correct = <String, int>{};

    for (var i = 0; i < widget.questions.length; i++) {
      final topic =
          store.cardById(widget.questions[i].sourceCardId)?.topic ?? '';
      final label = topic.trim().isEmpty ? '(konusuz)' : topic;
      total[label] = (total[label] ?? 0) + 1;
      if (_isCorrect(i)) correct[label] = (correct[label] ?? 0) + 1;
    }

    return [
      for (final topic in total.keys)
        ExamTopicScore(
          topic: topic,
          correct: correct[topic] ?? 0,
          total: total[topic]!,
        ),
    ];
  }

  bool _isCorrect(int i) => widget.selections[i] == widget.questions[i].correctIndex;

  int get _correctCount =>
      [for (var i = 0; i < widget.questions.length; i++) i]
          .where(_isCorrect)
          .length;

  int get _percent => widget.questions.isEmpty
      ? 0
      : (_correctCount / widget.questions.length * 100).round();

  /// Yanlış (boş dahil) soruların index'leri, sınav sırasına göre.
  List<int> get _wrongIndexes => [
    for (var i = 0; i < widget.questions.length; i++)
      if (!_isCorrect(i)) i,
  ];

  /// Konu bazlı kırılım: konuyu sorunun kaynak kartından okur, sınavdaki
  /// doğru oranıyla [TopicStat] kurar. Sıralama [SrsEngine.topicStats] ile
  /// aynı mantık: en zayıf üstte.
  List<TopicStat> _topicBreakdown(FlashcardStore store) {
    final total = <String, int>{};
    final correct = <String, int>{};

    for (var i = 0; i < widget.questions.length; i++) {
      final topic =
          store.cardById(widget.questions[i].sourceCardId)?.topic ?? '';
      final label = topic.trim().isEmpty ? '(konusuz)' : topic;
      total[label] = (total[label] ?? 0) + 1;
      if (_isCorrect(i)) correct[label] = (correct[label] ?? 0) + 1;
    }

    final stats = [
      for (final topic in total.keys)
        TopicStat(
          topic: topic,
          cardCount: total[topic]!,
          attempts: total[topic]!,
          successRate: (correct[topic] ?? 0) / total[topic]!,
        ),
    ];

    stats.sort((a, b) {
      final byRate = a.successRate.compareTo(b.successRate);
      if (byRate != 0) return byRate;
      final byCount = b.cardCount.compareTo(a.cardCount);
      if (byCount != 0) return byCount;
      return a.topic.compareTo(b.topic);
    });

    return stats;
  }

  void _queueWrongOnes(BuildContext context) {
    final store = context.read<FlashcardStore>();
    store.pullCardsForwardToToday(
      _wrongIndexes.map((i) => widget.questions[i].sourceCardId),
    );
    setState(() => _wrongOnesQueued = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Yanlış yapılan kartlar "Bugün Çalış" kuyruğuna alındı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = widget.questions.length;
    final wrongIndexes = _wrongIndexes;
    final overTarget = widget.elapsedSeconds > widget.targetSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Sınav Sonucu')),
      body: SafeArea(
        child: ContentShell(
          child: ListView(
            children: [
              // Genel puan — büyük.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        '%$_percent',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _percent < 50
                              ? scheme.error
                              : _percent < 75
                              ? scheme.tertiary
                              : scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_correctCount / $total doğru',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      // Kullanılan süre — hedefle kıyaslı.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: overTarget
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Süre: ${ExamSimQuizScreen.formatSeconds(widget.elapsedSeconds)}'
                            ' — hedef ${ExamSimQuizScreen.formatSeconds(widget.targetSeconds)}'
                            ' (${overTarget ? 'üstünde' : 'altında'})',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: overTarget
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Önceki denemeyle kıyas — yalnızca kayıtlı bir önceki sonuç
              // varsa. İlk denemede bu blok hiç oluşturulmaz.
              if (_comparison != null) ...[
                const SizedBox(height: 16),
                _ExamComparisonCard(comparison: _comparison!),
              ],
              const SizedBox(height: 24),
              // Konu bazlı kırılım — en zayıf üstte.
              Text('Konu kırılımı', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final stat in _topicBreakdown(store))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TopicSuccessBar(stat: stat, unitLabel: 'soru'),
                ),
              if (wrongIndexes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Yanlış yaptıkların (${wrongIndexes.length})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final i in wrongIndexes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WrongAnswerCard(
                      question: widget.questions[i],
                      selectedIndex: widget.selections[i],
                    ),
                  ),
                const SizedBox(height: 8),
                ResponsiveBuilder(
                  builder: (context, size) => Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: responsiveButtonWidth(size),
                      child: FilledButton.icon(
                        onPressed: _wrongOnesQueued
                            ? null
                            : () => _queueWrongOnes(context),
                        icon: Icon(
                          _wrongOnesQueued
                              ? Icons.check
                              : Icons.playlist_add,
                        ),
                        label: Text(
                          _wrongOnesQueued
                              ? 'Çalışmaya eklendi'
                              : 'Yanlışları tekrar çalışmaya ekle',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ResponsiveBuilder(
                builder: (context, size) => Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: responsiveButtonWidth(size),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Bitir'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir önceki denemeyle kıyas bloğu: ana cümle + (varsa) en çok gelişen ve
/// gerileyen konular. Yalnızca kayıtlı bir önceki sonuç varken gösterilir.
class _ExamComparisonCard extends StatelessWidget {
  const _ExamComparisonCard({required this.comparison});

  final ExamComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Ton: gelişme birincil renkte, gerileme tertiary'de (error DEĞİL —
    // gerilemek bir hata değil, cesaret kırıcı okunmamalı), aynı seviye nötr.
    final (Color container, Color onContainer, IconData icon) =
        switch (comparison.trend) {
          ExamTrend.improved => (
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
            Icons.trending_up,
          ),
          ExamTrend.declined => (
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer,
            Icons.trending_down,
          ),
          ExamTrend.same => (
            scheme.surfaceContainerHighest,
            scheme.onSurface,
            Icons.trending_flat,
          ),
        };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: onContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  comparison.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              'Önceki deneme %${comparison.previousPercent} · '
              'bu deneme %${comparison.currentPercent}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onContainer.withValues(alpha: 0.8),
              ),
            ),
          ),
          // Konu vurguları opsiyonel: iki sınavda da bulunan ve kayda değer
          // ölçüde değişen konu yoksa hiç gösterilmez.
          for (final delta in comparison.improvedTopics)
            _TopicDeltaLine(delta: delta, color: onContainer, improved: true),
          for (final delta in comparison.declinedTopics)
            _TopicDeltaLine(delta: delta, color: onContainer, improved: false),
        ],
      ),
    );
  }
}

/// Kıyas bloğundaki tek bir konu satırı ("Kalp: %40 → %80").
class _TopicDeltaLine extends StatelessWidget {
  const _TopicDeltaLine({
    required this.delta,
    required this.color,
    required this.improved,
  });

  final ExamTopicDelta delta;
  final Color color;
  final bool improved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            improved ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${delta.topic}: %${delta.previousPercent} → '
              '%${delta.currentPercent}',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bir yanlış sorunun toplu gösterimi: soru + öğrencinin (yanlış) seçimi
/// + doğru şık + kaynak kartın açıklamalı cevabı.
class _WrongAnswerCard extends StatelessWidget {
  const _WrongAnswerCard({required this.question, required this.selectedIndex});

  final McqQuestion question;

  /// Öğrencinin seçtiği şık; null = boş bırakıldı.
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = selectedIndex;
    final explanation = question.correctOption.explanation.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.question, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cancel, size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected == null
                        ? 'Boş bırakıldı'
                        : 'Senin cevabın: ${question.options[selected].text}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Doğru cevap: ${question.correctAnswer}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  explanation,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
