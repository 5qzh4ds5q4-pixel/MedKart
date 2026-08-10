import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../theme/app_theme.dart';
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

  /// Soru/cevap/not/konu alanlarının ortak görünümü — 2026-08-10 dashboard
  /// tasarım sistemine uyum: kenarlık YOK, yalnızca dolgu rengiyle ayrışır;
  /// odaklanınca ince mor bir parıltı (glow) belirir. [pill] `true` iken
  /// (yalnızca "Konu" alanı) köşeler tam yuvarlanır — etiket/pil görünümü.
  InputDecoration _fieldDecoration(
    BuildContext context, {
    String? hintText,
    bool pill = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF1E2330)
        : AppTheme.dashboardSurfaceElevated;
    final glow = AppTheme.dashboardVioletDeep.withValues(alpha: 0.30);
    final radius = BorderRadius.circular(pill ? 999 : 12);
    final errorColor = Theme.of(context).colorScheme.error;

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: glow, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final modalBackground = isDark
        ? const Color(0xFF13181F)
        : AppTheme.dashboardSurface;

    return AlertDialog(
      backgroundColor: modalBackground,
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
                  decoration: _fieldDecoration(context),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Kısa cevap'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _shortAnswerController,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    context,
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
                  decoration: _fieldDecoration(context),
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
                  decoration: _fieldDecoration(
                    context,
                    hintText: 'ör. "SÜT: Sinüs, Üçlü kapak, Truncus…"',
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Zorluk'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final d in CardDifficulty.values) ...[
                      if (d != CardDifficulty.values.first)
                        const SizedBox(width: 8),
                      Expanded(
                        child: _DifficultyPillButton(
                          difficulty: d,
                          selected: _difficulty == d,
                          onTap: () => setState(() => _difficulty = d),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel('Konu'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _topicController,
                  decoration: _fieldDecoration(
                    context,
                    hintText: 'ör. koroner dolaşım',
                    pill: true,
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
        _GradientSaveButton(onPressed: _save),
      ],
    );
  }
}

/// Zorluk seçimi (Kolay/Orta/Zor) — dolu (filled) pill stili. Seçili pill
/// [DifficultyChip] ile AYNI renk paletini kullanır (bkz. `card_chips.dart`)
/// ki bu diyalogdaki seçim rengi ile kart listesindeki rozet rengi birebir
/// eşleşsin; paylaşımlı bir sabite çıkarmak yerine BİLİNÇLİ olarak burada
/// tekrarlandı (bu widget'a özel, paylaşılan dosyaya dokunmadan). Seçili
/// OLMAYAN pill'ler "ghost": renksiz, soluk zemin + soluk metin — seçim tek
/// bakışta belirgin olsun diye.
class _DifficultyPillButton extends StatelessWidget {
  const _DifficultyPillButton({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final CardDifficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  static const Map<CardDifficulty, (Color bg, Color fg)> _lightPalette = {
    CardDifficulty.kolay: (Color(0xFFE7F2EC), Color(0xFF2C6A4F)),
    CardDifficulty.orta: (Color(0xFFFAF0DC), Color(0xFF8A6510)),
    CardDifficulty.zor: (Color(0xFFF8E8E6), Color(0xFF9A3B32)),
  };

  static const Map<CardDifficulty, (Color bg, Color fg)> _darkPalette = {
    CardDifficulty.kolay: (Color(0xFF1E3A2C), Color(0xFF8FD4AE)),
    CardDifficulty.orta: (Color(0xFF3A3320), Color(0xFFE6C36B)),
    CardDifficulty.zor: (Color(0xFF3E2422), Color(0xFFE79A90)),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = (isDark ? _darkPalette : _lightPalette)[difficulty]!;
    final ghostColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final ghostFill = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);

    return Material(
      color: selected ? bg : ghostFill,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            difficulty.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? fg : ghostColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Kaydet" butonu — dashboard'ın CTA gradyanıyla (bkz. `AppTheme.
/// dashboardCtaGradient`, `deck_list_screen.dart`'taki `_DarkGradientButton`
/// ile AYNI renkler) aynı görsel dil, ama o widget'a bağımlı olmadan (dosyalar
/// arası private sınıf paylaşımı yok) burada ayrıca tanımlandı. Şekil
/// BİLİNÇLİ olarak pill DEĞİL — uygulamanın genel `filledButtonTheme`'iyle
/// aynı 12px köşe, çünkü bu bir dialog aksiyon butonu (hero CTA değil),
/// diğer dialoglardaki butonlarla tutarlı kalsın diye.
class _GradientSaveButton extends StatelessWidget {
  const _GradientSaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.dashboardCtaGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: const Text(
            'Kaydet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
