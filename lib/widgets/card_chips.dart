import 'package:flutter/material.dart';

import '../models/flashcard.dart';

/// Zorluk rozeti. Renkler doygunluğu düşük tutuldu — kart listesi uzun süre
/// bakılacak, rozetler metnin önüne geçmemeli.
///
/// Açık ve koyu tema için ayrı palet: koyu temada açık zeminli rozetler parlak
/// yama gibi durmasın diye zemin koyulaşır, metin açılır (kontrast WCAG AA üstü).
class DifficultyChip extends StatelessWidget {
  const DifficultyChip({super.key, required this.difficulty});

  final CardDifficulty difficulty;

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
    return _Chip(background: bg, foreground: fg, label: difficulty.label);
  }
}

/// Konu (tag) rozeti.
class TopicChip extends StatelessWidget {
  const TopicChip({super.key, required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Chip(
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
      label: topic,
    );
  }
}

/// Kart AI orijinalinden düzenlendiğinde gösterilen ince rozet.
class EditedChip extends StatelessWidget {
  const EditedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Chip(
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
      label: 'düzenlendi',
      icon: Icons.edit_outlined,
    );
  }
}

/// Kullanıcı "hata var" diye işaretlediğinde gösterilen uyarı rozeti.
class FlaggedChip extends StatelessWidget {
  const FlaggedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Chip(
      background: theme.colorScheme.errorContainer,
      foreground: theme.colorScheme.onErrorContainer,
      label: 'hata bildirildi',
      icon: Icons.flag_outlined,
    );
  }
}

/// Senaryo-tabanlı ("sınav tipi") kartlarda gösterilen rozet.
class ExamTypeChip extends StatelessWidget {
  const ExamTypeChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _Chip(
      background: isDark ? const Color(0xFF2A2E52) : const Color(0xFFE8E9FA),
      foreground: isDark ? const Color(0xFFB6BBF5) : const Color(0xFF3F4494),
      label: 'sınav tipi',
      icon: Icons.medical_information_outlined,
    );
  }
}

/// Kartın kaynak PDF sayfasını gösteren çip ("s. 47").
class SourcePageChip extends StatelessWidget {
  const SourcePageChip({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Chip(
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
      label: 's. $page',
      icon: Icons.description_outlined,
    );
  }
}

/// Kartın bilgisi öncelikle el yazısından geldiğinde meta satırında gösterilen
/// küçük kalem ikonu. Bilinçli olarak yalnızca ikon — etiket metni yok; soru/
/// cevap metni temiz kalsın diye uyarı burada, tooltip'te verilir.
class HandwrittenIcon extends StatelessWidget {
  const HandwrittenIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message:
          'Bu bilgi el yazısından okunmuştur — doğruluğunu slaytınızla '
          'karşılaştırın.',
      child: Icon(
        Icons.edit_outlined,
        size: 16,
        color: theme.colorScheme.secondary,
      ),
    );
  }
}

/// El yazısı/highlight kaynaklı ("hocanın favorisi") kartlarda gösterilen
/// belirgin rozet — bkz. [HandwrittenIcon] (aynı [Flashcard.isHandwritten]
/// bayrağını kullanır, ama burada tek başına ikon değil görünür bir etiket
/// olarak). Amber vurgu için özel bir palet TANIMLAMAZ — uygulamanın marka
/// rengi zaten amber (`AppTheme.accentAmber`) `colorScheme.primary`'nin
/// tohumu, o yüzden `primaryContainer`/`onPrimaryContainer` token'ları
/// doğrudan amber render eder.
class HandwrittenFavoriteChip extends StatelessWidget {
  const HandwrittenFavoriteChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Chip(
      background: theme.colorScheme.primaryContainer,
      foreground: theme.colorScheme.onPrimaryContainer,
      label: 'Hocanın Favorisi',
      icon: Icons.star_rounded,
    );
  }
}

/// Kullanıcının kendi notu / mnemoniği: cevabın altında ampul ikonuyla.
class MnemonicNote extends StatelessWidget {
  const MnemonicNote({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.background,
    required this.foreground,
    required this.label,
    this.icon,
  });

  final Color background;
  final Color foreground;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: foreground),
                const SizedBox(width: 4),
                text,
              ],
            ),
    );
  }
}
