import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../utils/breakpoints.dart';

/// Kartın soru/cevabını düzenleme, kendi notunu ekleme ve hata bildirme
/// penceresi.
///
/// Kaydedilirse güncellenmiş [Flashcard], iptal edilirse null döner. Soru/cevap
/// AI orijinalinden değişirse orijinal metin kartta saklanır ([Flashcard.withEdits]),
/// böylece "AI orijinaline dön" ile geri alınabilir.
class EditCardDialog extends StatefulWidget {
  const EditCardDialog({super.key, required this.card});

  final Flashcard card;

  static Future<Flashcard?> show(BuildContext context, Flashcard card) {
    return showDialog<Flashcard>(
      context: context,
      builder: (_) => EditCardDialog(card: card),
    );
  }

  @override
  State<EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  late final TextEditingController _questionController;
  late final TextEditingController _shortAnswerController;
  late final TextEditingController _answerController;
  late final TextEditingController _topicController;
  late final TextEditingController _noteController;
  late CardDifficulty _difficulty;
  late bool _flagged;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.card.question);
    _shortAnswerController = TextEditingController(
      text: widget.card.shortAnswer,
    );
    _answerController = TextEditingController(text: widget.card.answer);
    _topicController = TextEditingController(text: widget.card.topic);
    _noteController = TextEditingController(text: widget.card.note);
    _difficulty = widget.card.difficulty;
    _flagged = widget.card.flagged;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _shortAnswerController.dispose();
    _answerController.dispose();
    _topicController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.of(context).pop(
      widget.card.withEdits(
        question: _questionController.text.trim(),
        answer: _answerController.text.trim(),
        shortAnswer: _shortAnswerController.text.trim(),
        difficulty: _difficulty,
        // Etiketler küçük harfte tutulur ki aynı konu tek grup olsun.
        topic: _topicController.text.trim().toLowerCase(),
        note: _noteController.text.trim(),
        flagged: _flagged,
      ),
    );
  }

  /// AI'ın orijinal soru/cevabına döner ve pencereyi kapatır.
  void _revertToOriginal() {
    Navigator.of(context).pop(widget.card.revertedToOriginal());
  }

  String? _validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName boş bırakılamaz.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Kartı düzenle'),
      // Dar ekranda dialog kenarlara yapışmasın, geniş ekranda büyümesin.
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SizedBox(
        width: responsiveDialogWidth(context, preferredWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FieldLabel('Soru'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _questionController,
                  autofocus: true,
                  maxLines: null,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => _validateNotEmpty(v, 'Soru'),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Kısa cevap'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _shortAnswerController,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'ör. "Osteoklast" — boş bırakılırsa tek '
                        'katmanlı (yalnızca aşağıdaki cevap) gösterilir',
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Cevap (açıklamalı)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _answerController,
                  maxLines: null,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => _validateNotEmpty(v, 'Cevap'),
                ),
                if (widget.card.isEdited) ...[
                  const SizedBox(height: 6),
                  _OriginalHint(
                    originalQuestion: widget.card.originalQuestion,
                    originalAnswer: widget.card.originalAnswer,
                    onRevert: _revertToOriginal,
                  ),
                ],
                const SizedBox(height: 16),
                _FieldLabel('Kendi notum / mnemonik'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  maxLines: null,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'ör. "SÜT: Sinüs, Üçlü kapak, Truncus…"',
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Zorluk'),
                const SizedBox(height: 6),
                SegmentedButton<CardDifficulty>(
                  segments: [
                    for (final d in CardDifficulty.values)
                      ButtonSegment(value: d, label: Text(d.label)),
                  ],
                  selected: {_difficulty},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _difficulty = selection.first),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Konu'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    hintText: 'ör. koroner dolaşım',
                  ),
                ),
                const SizedBox(height: 8),
                // Hata bildir: yanlış/şüpheli kartı işaretle. İşaretli kartlar
                // sonradan prompt iyileştirme için toplu incelenebilir.
                CheckboxListTile(
                  value: _flagged,
                  onChanged: (v) => setState(() => _flagged = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Bu kartta hata var'),
                  subtitle: Text(
                    'İşaretli kartlar gözden geçirilmek üzere ayrıca listelenir.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}

/// Kart düzenlenmişse AI'ın orijinal metnini gösterir ve geri dönme sunar.
class _OriginalHint extends StatelessWidget {
  const _OriginalHint({
    required this.originalQuestion,
    required this.originalAnswer,
    required this.onRevert,
  });

  final String? originalQuestion;
  final String? originalAnswer;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (originalQuestion != null) 'Soru: $originalQuestion',
      if (originalAnswer != null) 'Cevap: $originalAnswer',
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI orijinali (senin düzenlemenden önce)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(parts.join('\n'), style: theme.textTheme.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRevert,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('AI orijinaline dön'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
