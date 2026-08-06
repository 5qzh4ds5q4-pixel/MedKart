import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../srs/srs_engine.dart';
import '../state/flashcard_store.dart';
import '../state/study_settings.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/card_chips.dart';
import '../widgets/content_shell.dart';
import '../widgets/deck_name_dialog.dart';
import '../widgets/profile_bubble.dart';
import 'card_list_screen.dart';
import 'exam_sim_screen.dart';
import 'mcq_setup_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'study_screen.dart';

/// Ana ekran: destelerin listesi.
class DeckListScreen extends StatelessWidget {
  const DeckListScreen({super.key});

  Future<void> _createDeck(BuildContext context) async {
    await requireAuth(
      context,
      () async {
        final name = await DeckNameDialog.show(context);
        if (name == null || !context.mounted) return;

        final deck = context.read<FlashcardStore>().createDeck(name);
        if (!context.mounted) return;

        // Yeni deste boş; doğrudan içine girip kart eklemesi kolay olsun.
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CardListScreen(deckId: deck.id)),
        );
      },
      reason:
          'Deste oluşturmak için giriş yapman gerekiyor — destelerin ve '
          'kartların hesabında güvende kalır.',
    );
  }

  Future<void> _renameDeck(BuildContext context, Deck deck) async {
    final name = await DeckNameDialog.show(context, initialName: deck.name);
    if (name == null || !context.mounted) return;

    context.read<FlashcardStore>().renameDeck(deck.id, name);
  }

  /// Deste için sınav tarihi seçtirir; sınav tarihinden önce seçilemez.
  Future<void> _editExamDate(BuildContext context, Deck deck) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Sınav tarihini seç',
      initialDate: deck.examDate ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null || !context.mounted) return;

    context.read<FlashcardStore>().setDeckExamDate(deck.id, picked);
  }

  void _clearExamDate(BuildContext context, Deck deck) {
    context.read<FlashcardStore>().setDeckExamDate(deck.id, null);
  }

  Future<void> _deleteDeck(BuildContext context, Deck deck) async {
    final store = context.read<FlashcardStore>();
    final cardCount = store.cardsIn(deck.id).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${deck.name}" silinsin mi?'),
        content: Text(
          cardCount == 0
              ? 'Bu deste boş.'
              : 'Destedeki $cardCount kart ve tüm çalışma ilerlemen kalıcı '
                    'olarak silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    store.deleteDeck(deck.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final decks = store.decks;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('MedKart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'İstatistik',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          if (decks.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.quiz_outlined),
              tooltip: 'Kendini Test Et',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const McqSetupScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.assignment_outlined),
              tooltip: 'Deneme Sınavı',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExamSimSetupScreen()),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const ProfileBubble(),
        ],
      ),
      floatingActionButton: decks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createDeck(context),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Deste'),
            ),
      body: SafeArea(
        child: decks.isEmpty
            ? _EmptyState(onCreate: () => _createDeck(context))
            : ContentShell(
                padding: EdgeInsets.zero,
                child: ResponsiveBuilder(
                  builder: (context, size) {
                    final horizontal = responsiveHorizontalPadding(size);
                    final studySettings = context.watch<StudySettings>();
                    final dailyLimit = studySettings.dailyNewCardLimit;
                    final priorityModeDeckIds = studySettings.priorityModeDeckIds;
                    final dailyCount = store
                        .dailyQueue(
                          newCardLimit: dailyLimit,
                          priorityModeDeckIds: priorityModeDeckIds,
                        )
                        .length;
                    final paceWarning = store.examPaceWarning();
                    final paceWarningDeck = paceWarning == null
                        ? null
                        : store.deckById(paceWarning.deckId);
                    final weakestTopic = store.weakestTopicInfo;

                    return Column(
                      children: [
                        if (store.cards.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              16,
                              horizontal,
                              0,
                            ),
                            child: _DailyStudyBanner(
                              cardCount: dailyCount,
                              onTap: () => requireAuth(
                                context,
                                () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const StudyScreen(),
                                  ),
                                ),
                                reason:
                                    'Çalışmaya başlamak için giriş yap — '
                                    'ilerlemen kaydedilsin.',
                              ),
                              paceWarning: paceWarning,
                              paceWarningDeckName: paceWarningDeck?.name,
                              isPriorityModeOn: paceWarning == null
                                  ? false
                                  : studySettings.isPriorityMode(
                                      paceWarning.deckId,
                                    ),
                              onTogglePriorityMode: paceWarning == null
                                  ? null
                                  : () => context
                                        .read<StudySettings>()
                                        .setPriorityMode(
                                          paceWarning.deckId,
                                          !studySettings.isPriorityMode(
                                            paceWarning.deckId,
                                          ),
                                        ),
                            ),
                          ),
                        if (weakestTopic != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              12,
                              horizontal,
                              0,
                            ),
                            child: _WeakestTopicBanner(
                              info: weakestTopic,
                              onTap: () => requireAuth(
                                context,
                                () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StudyScreen(
                                      filter: CardFilter(
                                        topics: {weakestTopic.topic},
                                      ),
                                      ignoreDueDate: true,
                                    ),
                                  ),
                                ),
                                reason:
                                    'Çalışmaya başlamak için giriş yap — '
                                    'ilerlemen kaydedilsin.',
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              16,
                              horizontal,
                              // FAB'ın son kartı örtmemesi için.
                              96,
                            ),
                            itemCount: decks.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final deck = decks[index];
                              return _DeckTile(
                                deck: deck,
                                cardCount: store.cardsIn(deck.id).length,
                                dueCount: store.dueIn(deck.id).length,
                                onOpen: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CardListScreen(deckId: deck.id),
                                  ),
                                ),
                                onRename: () => _renameDeck(context, deck),
                                onDelete: () => _deleteDeck(context, deck),
                                onSetExamDate: () =>
                                    _editExamDate(context, deck),
                                onClearExamDate: () =>
                                    _clearExamDate(context, deck),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );

    // Landing/karşılama (boş durum) uygulamanın açık/koyu tema tercihinden
    // BAĞIMSIZ, sabit koyu marka paletiyle çizilir (bkz. `_EmptyState` doc
    // yorumu) — bu yüzden AppBar/Scaffold arka planı dahil TÜM ekran bu
    // sabit koyu temaya sarılır, deste dolu görünümü ambient temada kalır.
    return decks.isEmpty
        ? Theme(data: AppTheme.dark, child: scaffold)
        : scaffold;
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.deck,
    required this.cardCount,
    required this.dueCount,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final Deck deck;
  final int cardCount;
  final int dueCount;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetExamDate;
  final VoidCallback onClearExamDate;

  String get _subtitle {
    if (cardCount == 0) return 'Boş deste';
    if (dueCount == 0) return '$cardCount kart · bugünlük tamam';
    return '$cardCount kart · $dueCount tekrara hazır';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final examDate = deck.examDate;
    final daysLeft = examDate == null
        ? null
        : deck.daysUntilExam(DateTime.now());
    final isCramming =
        daysLeft != null &&
        daysLeft >= 0 &&
        daysLeft < SrsEngine.crammingThresholdDays;

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (dueCount > 0) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            _subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (examDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isCramming
                                ? Icons.local_fire_department
                                : Icons.event_outlined,
                            size: 14,
                            color: isCramming
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isCramming
                                  ? 'Sınav ${_formatDate(examDate)} · '
                                        'yoğun tekrar modu'
                                  : 'Sınav ${_formatDate(examDate)}'
                                        '${daysLeft != null && daysLeft >= 0 ? ' · $daysLeft gün kaldı' : ''}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isCramming
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: isCramming ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_DeckAction>(
                tooltip: 'Deste işlemleri',
                icon: const Icon(Icons.more_vert),
                iconColor: theme.colorScheme.onSurfaceVariant,
                onSelected: (action) => switch (action) {
                  _DeckAction.rename => onRename(),
                  _DeckAction.delete => onDelete(),
                  _DeckAction.setExamDate => onSetExamDate(),
                  _DeckAction.clearExamDate => onClearExamDate(),
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _DeckAction.rename,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Yeniden adlandır'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _DeckAction.setExamDate,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                        examDate == null
                            ? 'Sınav tarihi belirle'
                            : 'Sınav tarihini değiştir',
                      ),
                    ),
                  ),
                  if (examDate != null)
                    const PopupMenuItem(
                      value: _DeckAction.clearExamDate,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.event_busy_outlined),
                        title: Text('Sınav tarihini kaldır'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: _DeckAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Sil'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deste listesinin üstünde, tüm destelerden birleşik günlük kuyruğa
/// (bkz. [FlashcardStore.dailyQueue]) girişi sağlayan banner.
class _DailyStudyBanner extends StatelessWidget {
  const _DailyStudyBanner({
    required this.cardCount,
    required this.onTap,
    this.paceWarning,
    this.paceWarningDeckName,
    this.isPriorityModeOn = false,
    this.onTogglePriorityMode,
  });

  final int cardCount;
  final VoidCallback onTap;

  /// Doluysa, tempoya göre yetişmeyen bir deste var demektir (bkz.
  /// [FlashcardStore.examPaceWarning]) — banner altına bir uyarı bloğu eklenir.
  final ExamPaceWarning? paceWarning;

  /// [paceWarning] varsa o destenin adı (mesajda hangi deste olduğunu
  /// belirtmek için).
  final String? paceWarningDeckName;

  /// [paceWarning]'in destesi için Öncelikli Mod şu an açık mı?
  final bool isPriorityModeOn;

  /// `null` ise buton gösterilmez ([paceWarning] yoksa zaten hiç çağrılmaz).
  final VoidCallback? onTogglePriorityMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasCards = cardCount > 0;
    final warning = paceWarning;

    return Card(
      color: hasCards ? scheme.primaryContainer : null,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.today_outlined,
                    color: hasCards
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bugün Çalış',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: hasCards ? scheme.onPrimaryContainer : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          hasCards
                              ? '$cardCount kart hazır'
                              : 'Bugün çalışılacak kart yok',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hasCards
                                ? scheme.onPrimaryContainer.withValues(
                                    alpha: 0.8,
                                  )
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: hasCards
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 18,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${paceWarningDeckName != null ? '$paceWarningDeckName için s' : 'S'}'
                              'ınava ${warning.daysLeft} gün kaldı. Bu tempoda '
                              'yaklaşık ${warning.expectedCapacity} kart '
                              'çalışabilirsin, elinde ${warning.remainingCards} '
                              'kart var.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (onTogglePriorityMode != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onTogglePriorityMode,
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.onErrorContainer,
                            ),
                            child: Text(
                              isPriorityModeOn
                                  ? 'Normal Moda Dön'
                                  : 'Öncelikli Kartlara Odaklan',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// [_DailyStudyBanner]'ın hemen altında, kütüphanenin en zayıf konusuna
/// hızlı antrenman girişi (bkz. [FlashcardStore.weakestTopicInfo]). Yeterli/
/// güvenilir veri yoksa (`info` `null`) bu widget hiç oluşturulmaz — çağıran
/// taraf (`DeckListScreen.build`) zaten `if (weakestTopic != null)` ile korur.
class _WeakestTopicBanner extends StatelessWidget {
  const _WeakestTopicBanner({required this.info, required this.onTap});

  final WeakestTopicInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.track_changes, color: scheme.onPrimaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'En zor konun: ${info.topic}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${info.cardCount} kart · Antrenman Yap',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DeckAction { rename, delete, setExamDate, clearExamDate }

/// İlk açılış / "henüz deste yok" ekranı — uygulamanın landing/karşılama
/// anı. Bilinçli olarak uygulamanın açık/koyu tema tercihinden BAĞIMSIZ,
/// sabit koyu marka paletiyle çizilir (bkz. `AppTheme.hero*` sabitleri) —
/// tema modu ne olursa olsun ilk izlenim aynı kalsın diye. Bunun altındaki
/// `Theme(data: AppTheme.dark, ...)` sarmalayıcısı sayesinde içindeki
/// `DifficultyChip`/`ExamTypeChip`/`Card` gibi widget'lar da otomatik olarak
/// koyu paleti kullanır, ayrı ayrı renk vermeye gerek kalmaz.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ContentShell(
      child: Theme(
        data: AppTheme.dark,
        child: Builder(
          builder: (context) =>
              SingleChildScrollView(child: _LandingHero(onCreate: onCreate)),
        ),
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({required this.onCreate});

  final VoidCallback onCreate;

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space24,
          0,
          AppTheme.space24,
          AppTheme.space32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nasıl çalışır?',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.space16),
            const _HowStep(number: '1', text: 'Ders slaytını (PDF) yükle.'),
            const SizedBox(height: AppTheme.space12),
            const _HowStep(
              number: '2',
              text:
                  'Sistem sayfa sayfa okuyup soru-cevap kartı üretir; '
                  'hocanın el yazısı vurgularını da yakalar.',
            ),
            const SizedBox(height: AppTheme.space12),
            const _HowStep(
              number: '3',
              text:
                  'Aralıklı tekrar (SM-2) ile çalış — zayıf konular '
                  'kendiliğinden öne gelir.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ResponsiveBuilder(
      builder: (context, size) {
        // `ContentShell`in 760px genişlik tavanı içinde gerçek masaüstü
        // genişliğine (>900) hiç ulaşılmıyor; metin+örnek-kart yan yana
        // sığmayacağı için tasarım bilinçli olarak HER zaman tek sütun —
        // uygulamanın geri kalanının içerik-genişliği disipliniyle tutarlı.
        final isTablet = size.isAtLeastTablet;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Kartın arkasında çok soluk bir amber ışıma — koyu zeminde ince
            // bir sıcaklık katmanı, abartısız (kart içeriğine karışmaz).
            Positioned.fill(
              left: -48,
              top: -48,
              right: -48,
              bottom: -48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentAmber.withValues(alpha: 0.05),
                      AppTheme.accentAmber.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                isTablet ? AppTheme.space32 : AppTheme.space24,
              ),
              decoration: BoxDecoration(
                // Sayfa arka planıyla (`scheme.surface` == `heroBackground`)
                // aynı tonda kaybolmasın diye bir tık açık `heroSurface`.
                color: AppTheme.heroSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 60,
                    spreadRadius: -10,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Wordmark(),
                  const SizedBox(height: AppTheme.space32),
                  const _EyebrowBadge(),
                  const SizedBox(height: AppTheme.space16),
                  Text(
                    'Slaytını yükle,\nkomiteye hazır ol.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: isTablet ? 30 : 24,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(
                      'Ders notunu ve hocanın el yazısı vurgularını okur, sınav '
                      'formatında çalışma kartına çevirir.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Wrap(
                    spacing: AppTheme.space12,
                    runSpacing: AppTheme.space12,
                    children: [
                      FilledButton.icon(
                        onPressed: onCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('İlk desteni oluştur'),
                      ),
                      OutlinedButton(
                        onPressed: () => _showHowItWorks(context),
                        child: const Text('Nasıl çalışır?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space24),
                  const Wrap(
                    spacing: AppTheme.space24,
                    runSpacing: AppTheme.space12,
                    children: [
                      _StatBlock(value: 'PDF', label: 'sayfa sayfa otomatik'),
                      _StatBlock(value: 'SM-2', label: 'aralıklı tekrar'),
                      _StatBlock(value: '%100', label: 'türkçe'),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: const _DemoCardExample(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            number,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.medical_services_outlined,
            size: 16,
            color: scheme.onPrimary,
          ),
        ),
        const SizedBox(width: AppTheme.space8),
        Text(
          'medkart',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EyebrowBadge extends StatelessWidget {
  const _EyebrowBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'tıp fakültesi için üretildi',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Landing'de gösterilen sabit örnek kart — gerçek kullanıcı verisi DEĞİL,
/// yalnızca uygulamanın gerçek kart bileşenlerini (`DifficultyChip`,
/// `ExamTypeChip`, `HandwrittenIcon`) kullanan somut bir tanıtım örneği.
class _DemoCardExample extends StatelessWidget {
  const _DemoCardExample();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'brakiyal pleksus · s.4',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const HandwrittenIcon(),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            Text(
              'N. radialis hasarında görülen klinik bulgu nedir?',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: AppTheme.space12),
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: 'Düşük el (wrist drop). ',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'Ekstansör kasları inerve eder, hasarında bu '
                        'kaslar zayıflar.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            const Wrap(
              spacing: 6,
              children: [
                DifficultyChip(difficulty: CardDifficulty.orta),
                ExamTypeChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
