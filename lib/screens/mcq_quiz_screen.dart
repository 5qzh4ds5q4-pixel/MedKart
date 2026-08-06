import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../services/mcq_generator.dart';
import '../state/flashcard_store.dart';
import '../utils/breakpoints.dart';
import '../widgets/content_shell.dart';
import 'study_screen.dart';

/// "Kendini Test Et" soru akışı: [McqSetupScreen]'de senkron üretilen sabit
/// soru listesi üzerinde ilerler — burada hiç yeni soru üretilmez/AI
/// çağrılmaz. Son sorudan sonra oturum özetine düşer (bkz. [_isFinished]).
class McqQuizScreen extends StatefulWidget {
  const McqQuizScreen({super.key, required this.questions});

  final List<McqQuestion> questions;

  @override
  State<McqQuizScreen> createState() => _McqQuizScreenState();
}

class _McqQuizScreenState extends State<McqQuizScreen> {
  int _index = 0;
  int? _selectedOption;
  int _correctCount = 0;
  final List<McqQuestion> _wrong = [];

  McqQuestion get _current => widget.questions[_index];
  bool get _answered => _selectedOption != null;
  bool get _isFinished => _index >= widget.questions.length;

  void _selectOption(int optionIndex) {
    if (_answered) return;

    setState(() {
      _selectedOption = optionIndex;
      if (optionIndex == _current.correctIndex) {
        _correctCount++;
      } else {
        _wrong.add(_current);
      }
    });
  }

  void _next() {
    setState(() {
      _index++;
      _selectedOption = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return _McqSummary(
        total: widget.questions.length,
        correctCount: _correctCount,
        wrong: _wrong,
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kendini Test Et'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Testi bitir',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.questions.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _index / widget.questions.length,
            minHeight: 3,
            backgroundColor: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      body: SafeArea(
        child: ContentShell(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _current.question,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _current.options.length; i++) ...[
                  _McqOptionTile(
                    label: _current.options[i].text,
                    explanation: _current.options[i].explanation,
                    letter: String.fromCharCode(65 + i), // A/B/C/D
                    state: _optionState(i),
                    onTap: () => _selectOption(i),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
      // Sabit alt çubuk (bkz. `_StudyBar`, card_list_screen.dart — AYNI
      // görsel desen): şık açıklaması ne kadar uzun olursa olsun içerik
      // yalnızca kendi alanında kaydırılır, buton her zaman erişilebilir
      // kalır (önceden Column içinde `Spacer` ile itiliyordu ve uzun
      // açıklamalarda ekran altından taşıp erişilemez oluyordu).
      bottomNavigationBar: _answered
          ? _McqNextBar(
              isLast: _index == widget.questions.length - 1,
              onPressed: _next,
            )
          : null,
    );
  }

  _McqOptionState _optionState(int optionIndex) {
    if (!_answered) return _McqOptionState.neutral;
    if (optionIndex == _current.correctIndex) return _McqOptionState.correct;
    if (optionIndex == _selectedOption) return _McqOptionState.wrong;
    return _McqOptionState.disabled;
  }
}

/// [McqQuizScreen]'in altında sabit duran "Sonraki"/"Özeti Gör" butonu —
/// bkz. `_StudyBar` (`card_list_screen.dart`) ile AYNI görsel desen (sabit
/// alt çubuk, üstte ince ayraç çizgisi).
class _McqNextBar extends StatelessWidget {
  const _McqNextBar({required this.isLast, required this.onPressed});

  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ContentShell(
          // ZORUNLU: bu çubuk `bottomNavigationBar` slotunda. Scaffold ona
          // "gövde kadar yüksek olabilirsin" diyen SINIRLI bir kısıt verir;
          // shrinkWrapHeight olmadan ContentShell bu izni sonuna kadar
          // kullanır, alt çubuk tüm ekranı kaplar ve gövdeye (soru + şıklar)
          // 0 yükseklik kalır. `_StudyBar` bir Column içinde olduğu için bu
          // sorunu yaşamıyor — bkz. [ContentShell.shrinkWrapHeight].
          shrinkWrapHeight: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ResponsiveBuilder(
            builder: (context, size) => Align(
              alignment: Alignment.center,
              heightFactor: 1,
              child: SizedBox(
                width: responsiveButtonWidth(size),
                child: FilledButton(
                  onPressed: onPressed,
                  child: Text(isLast ? 'Özeti Gör' : 'Sonraki'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _McqOptionState { neutral, correct, wrong, disabled }

/// Tek bir şık satırı. Cevaplanmadan önce nötr, cevaplanınca doğru şık yeşil
/// (`tertiaryContainer` — amber marka renginden Material3'ün türettiği yeşil
/// ton, bkz. `app_theme.dart`), yanlış seçilen kırmızı (`errorContainer`,
/// `_GradeButton`daki "Zor" ile aynı desen) vurgulanır.
class _McqOptionTile extends StatelessWidget {
  const _McqOptionTile({
    required this.label,
    required this.explanation,
    required this.letter,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String explanation;
  final String letter;
  final _McqOptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final (background, foreground) = switch (state) {
      _McqOptionState.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
      ),
      _McqOptionState.correct => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _McqOptionState.wrong => (scheme.errorContainer, scheme.onErrorContainer),
      _McqOptionState.disabled => (
        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        scheme.onSurfaceVariant,
      ),
    };

    // Açıklama yalnızca doğru şıkkın VE (yanlışsa) öğrencinin seçtiği şıkkın
    // altında gösterilir — doğru seçildiyse ikisi zaten aynı satır olduğu
    // için açıklama bir kez görünür, tekrar etmez.
    final showExplanation =
        (state == _McqOptionState.correct || state == _McqOptionState.wrong) &&
        explanation.trim().isNotEmpty;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: state == _McqOptionState.neutral ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                    if (showExplanation) ...[
                      const SizedBox(height: 4),
                      Text(
                        explanation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (state == _McqOptionState.correct)
                Icon(Icons.check_circle, color: foreground, size: 20),
              if (state == _McqOptionState.wrong)
                Icon(Icons.cancel, color: foreground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oturum özeti: "X/N doğru" + yanlış yapılan sorular, her biri ilgili
/// kartın ana çalışma ekranına ("Bugün Çalış"/deste çalışma akışı, SM-2)
/// gitme bağlantısıyla.
class _McqSummary extends StatelessWidget {
  const _McqSummary({
    required this.total,
    required this.correctCount,
    required this.wrong,
  });

  final int total;
  final int correctCount;
  final List<McqQuestion> wrong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Test Özeti')),
      body: SafeArea(
        child: ContentShell(
          child: ListView(
            children: [
              Icon(
                correctCount == total
                    ? Icons.emoji_events_outlined
                    : Icons.check_circle_outline,
                size: 48,
                color: scheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '$correctCount / $total doğru',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              if (wrong.isNotEmpty) ...[
                Text(
                  'Yanlış yaptıkların',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final q in wrong)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WrongQuestionCard(question: q),
                  ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              ResponsiveBuilder(
                builder: (context, size) => Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: responsiveButtonWidth(size),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Bitir'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrongQuestionCard extends StatelessWidget {
  const _WrongQuestionCard({required this.question});

  final McqQuestion question;

  Future<void> _goStudyCard(BuildContext context) async {
    final store = context.read<FlashcardStore>();
    final card = store.cardById(question.sourceCardId);
    if (card == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyScreen(
          deckId: card.deckId,
          filter: CardFilter.forCard(card.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.question, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Doğru cevap: ${question.correctAnswer}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goStudyCard(context),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Bu kartı çalışmaya git'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
