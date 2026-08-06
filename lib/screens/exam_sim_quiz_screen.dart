import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mcq_generator.dart';
import '../utils/breakpoints.dart';
import '../widgets/content_shell.dart';
import 'exam_sim_result_screen.dart';

/// Deneme Sınavı soru akışı — [McqQuizScreen]'den KRİTİK farkları:
///
/// - Cevap ANLIK GÖSTERİLMEZ: şık seçilince yalnızca işaretlenir; doğru/yanlış
///   ve açıklama sınav bitene kadar gizli kalır (gerçek sınav provası).
/// - Süreli: soru başına 60 sn hedef, geri sayan timer. Süre dolunca sınav
///   KESİLMEZ — tek seferlik uyarı gösterilir, timer kırmızı/negatif sayar.
/// - İleri/geri gidilebilir, cevap değiştirilebilir; "Sınavı Bitir" ile
///   topluca [ExamSimResultScreen]'e geçilir.
class ExamSimQuizScreen extends StatefulWidget {
  const ExamSimQuizScreen({
    super.key,
    required this.questions,
    required this.targetSeconds,
  });

  final List<McqQuestion> questions;

  /// Hedef süre (sn) — soru başına 60 sn (bkz. [ExamSimSetupScreen]).
  final int targetSeconds;

  /// "-mm:ss" / "mm:ss" biçiminde süre. Negatifte eksi işaretiyle sayar.
  /// Sonuç ekranı da (bkz. [ExamSimResultScreen]) bunu kullanır.
  static String formatSeconds(int seconds) {
    final sign = seconds < 0 ? '-' : '';
    final abs = seconds.abs();
    final m = (abs ~/ 60).toString().padLeft(2, '0');
    final s = (abs % 60).toString().padLeft(2, '0');
    return '$sign$m:$s';
  }

  @override
  State<ExamSimQuizScreen> createState() => _ExamSimQuizScreenState();
}

class _ExamSimQuizScreenState extends State<ExamSimQuizScreen> {
  int _index = 0;

  /// Soru başına seçilen şık index'i; null = boş bırakıldı.
  late final List<int?> _selections =
      List<int?>.filled(widget.questions.length, null);

  Timer? _timer;
  int _elapsedSeconds = 0;

  McqQuestion get _current => widget.questions[_index];
  int get _remainingSeconds => widget.targetSeconds - _elapsedSeconds;
  bool get _timeUp => _remainingSeconds < 0;
  int get _answeredCount => _selections.where((s) => s != null).length;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectOption(int optionIndex) {
    // Aynı şıkka tekrar dokunmak seçimi kaldırmaz; farklı şık seçimi değiştirir.
    setState(() => _selections[_index] = optionIndex);
  }

  void _goTo(int index) {
    setState(() => _index = index.clamp(0, widget.questions.length - 1));
  }

  Future<void> _finish() async {
    final unanswered = widget.questions.length - _answeredCount;
    if (unanswered > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sınavı bitir'),
          content: Text(
            '$unanswered soru boş bırakıldı. Boş sorular yanlış sayılır. '
            'Yine de bitirmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Devam Et'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bitir'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExamSimResultScreen(
          questions: widget.questions,
          selections: List<int?>.unmodifiable(_selections),
          elapsedSeconds: _elapsedSeconds,
          targetSeconds: widget.targetSeconds,
        ),
      ),
    );
  }

  /// Sınavdan çıkış her zaman onaya bağlı — yanlışlıkla geri basınca tüm
  /// sınav ilerlemesi kaybolmasın.
  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınavdan çık'),
        content: const Text(
          'Sınav ilerlemen kaydedilmeden silinecek. Çıkmak istiyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Sınava Dön'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _index == widget.questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deneme Sınavı'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Sınavdan çık',
          onPressed: _confirmExit,
        ),
        actions: [
          // Geri sayan timer; süre dolunca kırmızı ve negatif sayar.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: _timeUp ? scheme.error : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ExamSimQuizScreen.formatSeconds(_remainingSeconds),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _timeUp ? scheme.error : scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.questions.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            // İlerleme cevaplanmış soru sayısına göre (gezinmeye göre değil).
            value: _answeredCount / widget.questions.length,
            minHeight: 3,
            backgroundColor: scheme.outlineVariant,
          ),
        ),
      ),
      body: SafeArea(
        child: ContentShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_timeUp) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_bottom,
                        size: 18,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Süre doldu — dilediğin kadar devam edebilirsin.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _current.question,
                    style: theme.textTheme.headlineSmall?.copyWith(height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < _current.options.length; i++) ...[
                      _ExamOptionTile(
                        label: _current.options[i].text,
                        letter: String.fromCharCode(65 + i), // A/B/C/D
                        selected: _selections[_index] == i,
                        onTap: () => _selectOption(i),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Önceki'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLast ? null : () => _goTo(_index + 1),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Sonraki'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ResponsiveBuilder(
                builder: (context, size) => Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: responsiveButtonWidth(size),
                    child: FilledButton(
                      onPressed: _finish,
                      child: const Text('Sınavı Bitir'),
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

/// Sınav modu şık satırı: seçim yalnızca İŞARETLENİR — doğru/yanlış rengi ya
/// da açıklama YOK (bkz. sınıf yorumu; McqQuizScreen'in `_McqOptionTile`ından
/// bilinçli fark).
class _ExamOptionTile extends StatelessWidget {
  const _ExamOptionTile({
    required this.label,
    required this.letter,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background =
        selected ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground =
        selected ? scheme.onPrimaryContainer : scheme.onSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: foreground.withValues(alpha: 0.15),
                child: Text(
                  letter,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? foreground : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
