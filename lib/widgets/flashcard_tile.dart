import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import 'card_chips.dart';
import 'two_layer_answer.dart';

/// Listede tek bir kart: soru üstte, cevap altında, sağda işlem menüsü.
class FlashcardTile extends StatelessWidget {
  const FlashcardTile({
    super.key,
    required this.card,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final Flashcard card;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 10),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      card.question,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                // Doğrudan görünen ikonlar — kebab menüsüne gömülmez.
                IconButton(
                  tooltip: 'Düzenle',
                  icon: const Icon(Icons.edit_outlined),
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline),
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: onDelete,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, right: 8, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TwoLayerAnswer(
                    card: card,
                    singleAnswerStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    shortAnswerStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    expandedAnswerStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (card.hasNote) ...[
                    const SizedBox(height: 10),
                    MnemonicNote(note: card.note),
                  ],
                  const SizedBox(height: 12),
                  // Wrap: dar ekranda rozetler alt satıra iner, taşma olmaz.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      DifficultyChip(difficulty: card.difficulty),
                      if (card.isExamType) const ExamTypeChip(),
                      if (card.hasTopic) TopicChip(topic: card.topic),
                      if (card.hasSourcePage)
                        SourcePageChip(page: card.sourcePage!),
                      if (card.isHandwritten) ...[
                        const HandwrittenIcon(),
                        const HandwrittenFavoriteChip(),
                      ],
                      if (card.isEdited) const EditedChip(),
                      if (card.flagged) const FlaggedChip(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
