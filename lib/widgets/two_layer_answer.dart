import 'package:flutter/material.dart';

import '../models/flashcard.dart';

/// Kartın cevabını iki katmanlı gösterir: önce [Flashcard.shortAnswer]
/// (varsa), "Açıklamasını gör" butonuyla altına [Flashcard.answer] açılır.
///
/// [Flashcard.hasShortAnswer] false olan (2026-07-19 öncesi üretilen) eski
/// kartlarda doğrudan [Flashcard.answer] gösterilir — tek katmanlı eski
/// davranış korunur. Çalışma ekranı (`StudyScreen`) ve kart listesi
/// (`FlashcardTile`) bu widget'ı PAYLAŞIR; aynı mantık iki yerde ayrı
/// yazılmaz.
class TwoLayerAnswer extends StatefulWidget {
  const TwoLayerAnswer({
    super.key,
    required this.card,
    this.singleAnswerStyle,
    this.shortAnswerStyle,
    this.expandedAnswerStyle,
  });

  final Flashcard card;

  /// [Flashcard.shortAnswer] boşken (eski kart) doğrudan gösterilen
  /// [Flashcard.answer] stili. Verilmezse [TextTheme.bodyLarge].
  final TextStyle? singleAnswerStyle;

  /// [Flashcard.shortAnswer] stili. Verilmezse [TextTheme.bodyLarge] + kalın.
  final TextStyle? shortAnswerStyle;

  /// "Açıklamasını gör" ile açılan [Flashcard.answer] stili. Verilmezse
  /// [TextTheme.bodyMedium].
  final TextStyle? expandedAnswerStyle;

  @override
  State<TwoLayerAnswer> createState() => _TwoLayerAnswerState();
}

class _TwoLayerAnswerState extends State<TwoLayerAnswer> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant TwoLayerAnswer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Farklı bir kart geldiyse açıklama tekrar kapansın; her karşılaşmada
    // önce sade kısa cevapla karşılaşılsın.
    if (oldWidget.card.id != widget.card.id) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.card;

    if (!card.hasShortAnswer) {
      return Text(
        card.answer,
        style: widget.singleAnswerStyle ?? theme.textTheme.bodyLarge,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.shortAnswer,
          style: widget.shortAnswerStyle ??
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (_expanded) ...[
          const SizedBox(height: 16),
          Text(
            card.answer,
            style: widget.expandedAnswerStyle ?? theme.textTheme.bodyMedium,
          ),
        ] else ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = true),
            icon: const Icon(Icons.expand_more, size: 18),
            label: const Text('Açıklamasını gör'),
          ),
        ],
      ],
    );
  }
}
