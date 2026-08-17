import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../srs/srs_engine.dart';
import '../state/flashcard_store.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../widgets/app_shell.dart';
import '../widgets/content_shell.dart';
import '../widgets/deck_action_menu.dart';
import 'card_list_screen.dart';

/// Sol sidebar'daki "Destelerim" ekranı — tüm destelerin SADE bir listesi.
///
/// 2026-08-17'de eklendi. Öncesinde "Destelerim" ikonu "Ana Sayfa" ile AYNI
/// şeyi yapıyordu (`Navigator.popUntil` → dashboard); ayrı bir kütüphane
/// ekranı hiç yoktu (bkz. `side_nav_bar.dart`'ın eski doc yorumu).
///
/// DASHBOARD'IN DESTE IZGARASININ KOPYASI DEĞİL, BİLİNÇLİ OLARAK FARKLI:
/// dashboard (`DeckListScreen`) desteleri kart-ızgarasında, konu pili/ikon
/// rozeti/renk paletiyle GÖSTERİR — orası bir "vitrin". Burası bir LİSTE:
/// kart yok, kenarlık yok, gölge yok; yalnızca tipografi hiyerarşisi ve
/// saç teli ayraçlar. Amaç çok desteli bir kütüphanede hızlı tarama.
/// İkisini "tutarlılık" adına birbirine benzetmeye çalışmadan önce sor.
///
/// YENİ BİR HESAP İCAT EDİLMEDİ: kart sayısı `store.cardsIn`, tekrara hazır
/// sayısı `store.dueIn`, öğrenilme yüzdesi `store.deckReadiness`
/// (= `SrsEngine.isWellLearned`) — üçü de dashboard kartlarının okuduğu
/// kaynakların AYNISI. Sıralama da `store.decks`'in kendi (oluşturma) sırası,
/// dashboard ızgarasıyla aynı; burada ayrıca sıralanmıyor.
class DeckLibraryScreen extends StatelessWidget {
  const DeckLibraryScreen({super.key});

  /// Testlerin "hiç deste yok" durumunu ekrandaki başka metinlere
  /// takılmadan bulabilmesi için.
  static const ValueKey<String> emptyStateKey = ValueKey('deck-library-empty');

  /// Özet satırı ("N deste · M kart") — aynı gerekçeyle anahtarlı.
  static const ValueKey<String> summaryKey = ValueKey('deck-library-summary');

  void _openDeck(BuildContext context, Deck deck) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardListScreen(deckId: deck.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final decks = store.decks;

    return AppShell(
      active: SideNavItem.library,
      topBar: const AppShellTopBar(title: 'Destelerim'),
      body: ContentShell(
        child: decks.isEmpty
            ? _EmptyLibrary(onCreate: () => DeckActions.create(context))
            : _DeckList(store: store, decks: decks, onOpen: _openDeck),
      ),
    );
  }
}

class _DeckList extends StatelessWidget {
  const _DeckList({
    required this.store,
    required this.decks,
    required this.onOpen,
  });

  final FlashcardStore store;
  final List<Deck> decks;
  final void Function(BuildContext context, Deck deck) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMuted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final lineColor = isDark
        ? AppTheme.heroBorder
        : AppTheme.dashboardSubtleBorder;

    // `deckReadiness` KARTI OLMAYAN desteleri hiç döndürmez (bkz. CLAUDE.md
    // "Deste Hazırlığı") — o yüzden map'te olmayan deste "yüzde gösterme"
    // demektir, "%0" değil.
    final readinessByDeck = {
      for (final r in store.deckReadiness) r.deckId: r,
    };

    final totalCards = store.cards.length;

    return ResponsiveBuilder(
      builder: (context, size) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    key: DeckLibraryScreen.summaryKey,
                    '${decks.length} deste · $totalCards kart',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                _GhostAction(
                  icon: Icons.add,
                  label: 'Yeni deste',
                  onTap: () => DeckActions.create(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: lineColor),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: decks.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 1, color: lineColor),
              itemBuilder: (context, index) {
                final deck = decks[index];
                final readiness = readinessByDeck[deck.id];
                return _DeckRow(
                  deck: deck,
                  cardCount: store.cardsIn(deck.id).length,
                  dueCount: store.dueIn(deck.id).length,
                  readyPercent: readiness?.readyPercent,
                  // Dar ekranda ilerleme çubuğu + yüzde + "..." menüsü deste
                  // adını ezecek kadar yer kaplıyor; mobilde çubuk düşer,
                  // yüzde metni kalır (bilgi kaybı yok, yalnızca süs gider).
                  showProgressBar: !size.isMobile,
                  onOpen: () => onOpen(context, deck),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek deste satırı — kart/kenarlık/gölge YOK, yalnızca tipografi + sağda
/// ince ilerleme göstergesi. Ayraçlar satırın kendisinde değil,
/// [ListView.separated] tarafında.
class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.deck,
    required this.cardCount,
    required this.dueCount,
    required this.readyPercent,
    required this.showProgressBar,
    required this.onOpen,
  });

  final Deck deck;
  final int cardCount;
  final int dueCount;

  /// `null` = destenin hiç kartı yok, yüzde göstermenin anlamı yok.
  final int? readyPercent;

  final bool showProgressBar;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final textMuted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    final examDate = deck.examDate;
    final daysLeft = examDate == null ? null : deck.daysUntilExam(DateTime.now());
    final isCramming =
        daysLeft != null &&
        daysLeft >= 0 &&
        daysLeft < SrsEngine.crammingThresholdDays;
    // Yoğun tekrar uyarısı için semantik hata rengi — dashboard kartlarındaki
    // ham hex yerine token (iki temada da okunur).
    final examColor = isCramming ? theme.colorScheme.error : textMuted;

    final percent = readyPercent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space8,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      deck.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deckMetaLine(cardCount: cardCount, dueCount: dueCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textMuted,
                      ),
                    ),
                    if (examDate != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCramming
                                ? Icons.local_fire_department
                                : Icons.event_outlined,
                            size: 12,
                            color: examColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isCramming
                                  ? 'Sınav ${formatExamDate(examDate)} · yoğun tekrar modu'
                                  : 'Sınav ${formatExamDate(examDate)}'
                                        '${daysLeft != null && daysLeft >= 0 ? ' · $daysLeft gün kaldı' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: isCramming
                                    ? FontWeight.w700
                                    : null,
                                color: examColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (percent != null) ...[
                const SizedBox(width: AppTheme.space16),
                _ReadinessIndicator(
                  percent: percent,
                  showBar: showProgressBar,
                  isDark: isDark,
                  textColor: textPrimary,
                  labelColor: textMuted,
                ),
              ],
              const SizedBox(width: AppTheme.space4),
              DeckActionMenu(
                deck: deck,
                iconColor: textMuted,
                onRename: () => DeckActions.rename(context, deck),
                onDelete: () => DeckActions.delete(context, deck),
                onSetExamDate: () => DeckActions.editExamDate(context, deck),
                onClearExamDate: () => DeckActions.clearExamDate(context, deck),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sağdaki "%N öğrenildi" göstergesi — dashboard deste kartlarıyla AYNI
/// gradyan token'ı (`dashboardProgressGradient`), yalnızca daha ince.
class _ReadinessIndicator extends StatelessWidget {
  const _ReadinessIndicator({
    required this.percent,
    required this.showBar,
    required this.isDark,
    required this.textColor,
    required this.labelColor,
  });

  final int percent;
  final bool showBar;
  final bool isDark;
  final Color textColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '%$percent',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        if (showBar) ...[
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 64,
              height: 4,
              child: Stack(
                children: [
                  ColoredBox(color: deckProgressTrackColor(isDark)),
                  FractionallySizedBox(
                    widthFactor: (percent / 100).clamp(0.0, 1.0),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppTheme.dashboardProgressGradient,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 2),
          Text(
            'öğrenildi',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: labelColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Başlık satırındaki sessiz "Yeni deste" eylemi. Dashboard'daki büyük
/// `FloatingActionButton` bilinçli olarak TEKRARLANMADI — bu ekranın işi
/// listelemek, oluşturma burada ikincil bir eylem.
class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark
        ? AppTheme.textSecondaryDark
        : AppTheme.dashboardTextMuted;
    final border = isDark
        ? AppTheme.heroBorder
        : AppTheme.dashboardSubtleBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hiç deste yokken. Bu ekrana bu durumda ulaşmak MÜMKÜN: boş durumdaki
/// karşılama ekranından İstatistik/Ayarlar'a girip oradaki sidebar üzerinden
/// buraya gelinebiliyor (karşılama ekranının kendisinde sidebar yok).
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final textMuted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    return Center(
      key: DeckLibraryScreen.emptyStateKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_books_outlined, size: 36, color: textMuted),
          const SizedBox(height: AppTheme.space16),
          Text(
            'Henüz deste yok',
            style: theme.textTheme.titleMedium?.copyWith(color: textPrimary),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'İlk desteni oluştur, ders notunu yükleyip kartlarını üret.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
          ),
          const SizedBox(height: AppTheme.space24),
          _GhostAction(
            icon: Icons.add,
            label: 'Yeni deste',
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}
