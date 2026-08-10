import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;

import '../content/legal_content.dart';
import '../models/card_filter.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../services/auth_service.dart';
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
import 'legal_screen.dart';
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

    if (decks.isEmpty) {
      // Landing/karşılama ekranı BİREBİR eskisi gibi — AppBar'lı Scaffold,
      // sabit koyu temaya sarılı (bkz. `_EmptyState` doc yorumu). Sol
      // sidebar YOK: burada henüz gezinecek "Destelerim"/"Kendini Test Et"
      // gibi bir şey yok, o yüzden 2026-08-10 sidebar eklemesi bilinçli
      // olarak bu ekranı KAPSAMIYOR — yalnızca dolu dashboard'a eklendi.
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
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Ayarlar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const ProfileBubble(),
          ],
        ),
        body: SafeArea(child: _EmptyState(onCreate: () => _createDeck(context))),
      );

      // Landing/karşılama (boş durum) uygulamanın açık/koyu tema tercihinden
      // BAĞIMSIZ, sabit koyu marka paletiyle çizilir (bkz. `_EmptyState` doc
      // yorumu) — bu yüzden AppBar/Scaffold arka planı dahil TÜM ekran bu
      // sabit koyu temaya sarılır, deste dolu görünümü ambient temada kalır.
      return Theme(data: AppTheme.dark, child: scaffold);
    }

    // Dolu dashboard: sol sidebar + (Scaffold.appBar DEĞİL) sadeleştirilmiş
    // üst şerit — 2026-08-10, "sağ üstte sıkışık ikonlar yerine sol sabit
    // sidebar" isteği. Eskiden AppBar'da duran İstatistik/Kendini Test Et/
    // Ayarlar eylemleri artık `_SideNavBar`'a taşındı (bkz. o widget'ın
    // yorumu); Deneme Sınavı AppBar'da hiç yoktu — zaten dashboard
    // gövdesindeki "Deneme Sınavı" kısayol kartından erişiliyordu, sidebar
    // referans tasarımında da bu ikon yok, kaldırılmadı.
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDeck(context),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Deste'),
      ),
      body: SafeArea(
        child: ColoredBox(
          // Dashboard'ın sayfa zemini iki modda da AYRI, açıkça boyanmış
          // bir renk — koyu modda bu zaten ambient `AppTheme.dark`
          // yüzeyiyle (`heroBackground`) aynı değer, o yüzden koyu moda
          // görsel bir etkisi yok (bkz. "dark mode koduna dokunma").
          // Açık modda ise ambient `AppTheme.light` yüzeyinden (sıcak
          // krem) FARKLI, referans tasarımın soğuk gri-mavi zemini
          // (`dashboardBackground`) burada devreye girer.
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.heroBackground
              : AppTheme.dashboardBackground,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SideNavBar(
                onOpenQuiz: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const McqSetupScreen()),
                ),
                onOpenStats: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
                onOpenSettings: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const _DashboardTopBar(),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Koyu/açık mod ikisi de aynı kart-ızgara dashboard
                          // dilini kullanır (bkz. "medkart koyu/açık mod
                          // dashboard" referans tasarımları); yalnızca renk
                          // token'ları değişir.
                          if (Theme.of(context).brightness ==
                              Brightness.dark) {
                            return _DarkDashboardBody(
                              onCreateDeck: () => _createDeck(context),
                              onOpenDeck: (deck) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CardListScreen(deckId: deck.id),
                                ),
                              ),
                              onRenameDeck: (deck) =>
                                  _renameDeck(context, deck),
                              onDeleteDeck: (deck) =>
                                  _deleteDeck(context, deck),
                              onSetExamDate: (deck) =>
                                  _editExamDate(context, deck),
                              onClearExamDate: (deck) =>
                                  _clearExamDate(context, deck),
                            );
                          }
                          return _LightDashboardBody(
                            onCreateDeck: () => _createDeck(context),
                            onOpenDeck: (deck) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CardListScreen(deckId: deck.id),
                              ),
                            ),
                            onRenameDeck: (deck) => _renameDeck(context, deck),
                            onDeleteDeck: (deck) => _deleteDeck(context, deck),
                            onSetExamDate: (deck) =>
                                _editExamDate(context, deck),
                            onClearExamDate: (deck) =>
                                _clearExamDate(context, deck),
                          );
                        },
                      ),
                    ),
                    const _DashboardFooter(),
                  ],
                ),
              ),
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

// ============================================================================
// KOYU MOD DASHBOARD — 2026-08-10, "medkart koyu mod dashboard" referans
// tasarımından uyarlandı (bkz. kullanıcının paylaştığı DESIGN.md/screen.png).
// Yalnızca `Theme.of(context).brightness == Brightness.dark` iken gösterilir
// (bkz. `DeckListScreen.build`); açık mod `_LegacyDashboardBody`'yi kullanmaya
// devam eder, HİÇ değişmedi. Burada yeni bir state/servis/backend çağrısı
// YOK — tüm veri mevcut `FlashcardStore`/`StudySettings`/`requireAuth`'tan
// okunuyor, yalnızca görsel katman. Renk token'ları `AppTheme.dashboard*`
// (bkz. app_theme.dart) + mevcut `AppTheme.hero*` yüzey renkleri.
// ============================================================================

class _DarkDashboardBody extends StatelessWidget {
  const _DarkDashboardBody({
    required this.onCreateDeck,
    required this.onOpenDeck,
    required this.onRenameDeck,
    required this.onDeleteDeck,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final VoidCallback onCreateDeck;
  final ValueChanged<Deck> onOpenDeck;
  final ValueChanged<Deck> onRenameDeck;
  final ValueChanged<Deck> onDeleteDeck;
  final ValueChanged<Deck> onSetExamDate;
  final ValueChanged<Deck> onClearExamDate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final studySettings = context.watch<StudySettings>();
    final decks = store.decks;
    final dailyLimit = studySettings.dailyNewCardLimit;
    final priorityModeDeckIds = studySettings.priorityModeDeckIds;
    final dailyCount = store
        .dailyQueue(
          newCardLimit: dailyLimit,
          priorityModeDeckIds: priorityModeDeckIds,
        )
        .length;
    final streak = store.studyLog.currentStreak(DateTime.now());
    final paceWarning = store.examPaceWarning();
    final paceWarningDeck = paceWarning == null
        ? null
        : store.deckById(paceWarning.deckId);
    final weakestTopic = store.weakestTopicInfo;
    final readinessByDeck = {
      for (final r in store.deckReadiness) r.deckId: r,
    };

    void goStudyToday() => requireAuth(
      context,
      () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StudyScreen())),
      reason: 'Çalışmaya başlamak için giriş yap — ilerlemen kaydedilsin.',
    );

    return ContentShell(
      padding: EdgeInsets.zero,
      maxWidth: AppTheme.dashboardMaxWidth,
      child: ResponsiveBuilder(
        builder: (context, size) {
          final horizontal = responsiveHorizontalPadding(size);
          final isWide = size.isAtLeastTablet;
          final theme = Theme.of(context);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DarkHeroRow(
                  streak: streak,
                  isWide: isWide,
                  onStartStudy: goStudyToday,
                ),
                const SizedBox(height: AppTheme.space24),
                _DarkShortcutRow(
                  isWide: isWide,
                  dailyCardCount: dailyCount,
                  onTapToday: goStudyToday,
                  onTapExam: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExamSimSetupScreen(),
                    ),
                  ),
                  onTapStats: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  ),
                ),
                if (paceWarning != null) ...[
                  const SizedBox(height: AppTheme.space16),
                  _DarkPaceWarningCard(
                    warning: paceWarning,
                    deckName: paceWarningDeck?.name,
                    isPriorityModeOn: studySettings.isPriorityMode(
                      paceWarning.deckId,
                    ),
                    onTogglePriorityMode: () => context
                        .read<StudySettings>()
                        .setPriorityMode(
                          paceWarning.deckId,
                          !studySettings.isPriorityMode(paceWarning.deckId),
                        ),
                  ),
                ],
                if (weakestTopic != null) ...[
                  const SizedBox(height: AppTheme.space16),
                  _DarkWeakestTopicCard(
                    info: weakestTopic,
                    onTap: () => requireAuth(
                      context,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudyScreen(
                            filter: CardFilter(topics: {weakestTopic.topic}),
                            ignoreDueDate: true,
                          ),
                        ),
                      ),
                      reason:
                          'Çalışmaya başlamak için giriş yap — '
                          'ilerlemen kaydedilsin.',
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space32),
                Text(
                  'Destelerim',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Toplam ${decks.length} deste',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                _DarkDeckGrid(
                  decks: decks,
                  store: store,
                  readinessByDeck: readinessByDeck,
                  columns: responsiveValue<int>(
                    size,
                    mobile: 1,
                    tablet: 2,
                    desktop: 3,
                  ),
                  onCreateDeck: onCreateDeck,
                  onOpenDeck: onOpenDeck,
                  onRenameDeck: onRenameDeck,
                  onDeleteDeck: onDeleteDeck,
                  onSetExamDate: onSetExamDate,
                  onClearExamDate: onClearExamDate,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Borderless, gölgeli kart yüzeyi — bu dashboard'daki HER kart bunun
/// üzerine kurulu (bkz. referans tasarımın "Never use a stroke or border"
/// kuralı). Genel `CardThemeData` (`app_theme.dart`) her zaman bir kenarlık
/// çiziyor, o yüzden burada `Card` widget'ı DEĞİL düz `Container` kullanılıyor.
class _DarkCard extends StatelessWidget {
  const _DarkCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.space16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.heroSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Mor→pembe gradyanlı ana CTA butonu ("Çalışmaya Başla").
class _DarkGradientButton extends StatelessWidget {
  const _DarkGradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.dashboardCtaGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppTheme.dashboardVioletDeep.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero banner + Pro Plan kartı — mobilde alt alta, tablet/masaüstünde yan
/// yana (bkz. referans tasarımın `flex md:flex-row` davranışı).
class _DarkHeroRow extends StatelessWidget {
  const _DarkHeroRow({
    required this.streak,
    required this.isWide,
    required this.onStartStudy,
  });

  final int streak;
  final bool isWide;
  final VoidCallback onStartStudy;

  @override
  Widget build(BuildContext context) {
    final hero = _DarkHeroBanner(streak: streak, onStartStudy: onStartStudy);
    const proPlan = _DarkProPlanCard();

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [hero, const SizedBox(height: AppTheme.space16), proPlan],
      );
    }

    // `IntrinsicHeight` + `stretch`: her iki kart aynı yükseklikte olsun diye
    // (referans tasarımdaki iki sütunun eşit boyda görünmesiyle aynı).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: hero),
          const SizedBox(width: AppTheme.space16),
          const SizedBox(width: 300, child: proPlan),
        ],
      ),
    );
  }
}

class _DarkHeroBanner extends StatelessWidget {
  const _DarkHeroBanner({required this.streak, required this.onStartStudy});

  final int streak;
  final VoidCallback onStartStudy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.dashboardVioletDeep.withValues(alpha: 0.20),
            AppTheme.dashboardPink.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DarkGreetingName(style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppTheme.space12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppTheme.space12,
            runSpacing: AppTheme.space8,
            children: [
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: AppTheme.dashboardOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak Günlük Seri',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                streak > 0
                    ? 'Harika gidiyorsun. Çalışmaya devam et.'
                    : 'Bugün ilk kartını çalışarak seriye başla.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          _DarkGradientButton(
            label: 'Çalışmaya Başla',
            onTap: onStartStudy,
          ),
        ],
      ),
    );
  }
}

/// "Merhaba, {ad}!" — giriş durumuna göre canlı güncellenir (bkz.
/// `ProfileBubble` ile aynı desen: kendi `AuthService` örneğini oluşturup
/// `authStateChanges`'i dinler). Ad kaynağı yok, e-postanın kullanıcı adı
/// kısmından türetiliyor; giriş yoksa/e-posta yoksa yalnızca "Merhaba!".
class _DarkGreetingName extends StatefulWidget {
  const _DarkGreetingName({this.style});

  final TextStyle? style;

  @override
  State<_DarkGreetingName> createState() => _DarkGreetingNameState();
}

class _DarkGreetingNameState extends State<_DarkGreetingName> {
  final AuthService _auth = AuthService();
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _auth.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String? _displayName(User? user) {
    final email = user?.email;
    if (email == null || email.isEmpty) return null;
    final local = email.split('@').first;
    if (local.isEmpty) return null;
    return local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName(_auth.currentUser);
    return Text(
      name == null ? 'Merhaba!' : 'Merhaba, $name!',
      style: widget.style?.copyWith(
        fontSize: 26,
        color: AppTheme.textPrimaryDark,
      ),
    );
  }
}

/// Sağ üstteki "Pro Plan" kartı — TAMAMEN görsel/bilgilendirici. Uygulamada
/// henüz gerçek bir ödeme/abonelik sistemi YOK (bkz. CLAUDE.md "Bilinmeyen /
/// Henüz Kararlaştırılmamış"), o yüzden "Aktif" gibi var olmayan bir üyeliği
/// ima eden bir durum YAZILMADI — buton yalnızca bilgilendirici bir SnackBar
/// gösterir, hiçbir backend çağrısı yapmaz.
class _DarkProPlanCard extends StatelessWidget {
  const _DarkProPlanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.dashboardVioletDeep.withValues(alpha: 0.20),
            AppTheme.dashboardPink.withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // `Spacer`/`Expanded` yerine `spaceBetween`: bu kart mobilde sınırsız
      // yükseklikli bir `SingleChildScrollView` içine düşebiliyor, orada esnek
      // (`flex`) bir çocuk hata fırlatır — `mainAxisAlignment` sınırsız
      // yükseklikte etkisiz ama GÜVENLİ, masaüstünde (sabit yükseklik) butonu
      // alta iter.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.dashboardVioletDeep.withValues(
                        alpha: 0.25,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: AppTheme.dashboardViolet,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pro Plan',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimaryDark,
                          ),
                        ),
                        Text(
                          'Çok yakında',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textTertiaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space16),
              _ProFeatureRow(text: 'Sınırsız Deste', theme: theme),
              const SizedBox(height: 6),
              _ProFeatureRow(text: 'Gelişmiş İstatistikler', theme: theme),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.space16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pro Plan yakında geliyor — haber vereceğiz.',
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dashboardViolet,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Bekleme Listesine Katıl'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  const _ProFeatureRow({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.dashboardViolet,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Bugün Çalış / Deneme Sınavı / İstatistikler" üçlü kısayol satırı.
/// Mobilde alt alta, tablet/masaüstünde yan yana eşit genişlikte.
class _DarkShortcutRow extends StatelessWidget {
  const _DarkShortcutRow({
    required this.isWide,
    required this.dailyCardCount,
    required this.onTapToday,
    required this.onTapExam,
    required this.onTapStats,
  });

  final bool isWide;
  final int dailyCardCount;
  final VoidCallback onTapToday;
  final VoidCallback onTapExam;
  final VoidCallback onTapStats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _DarkShortcutTile(
        icon: Icons.local_fire_department,
        iconGradient: const LinearGradient(
          colors: [AppTheme.dashboardRed, AppTheme.dashboardPink],
        ),
        title: 'Bugün Çalış',
        subtitle: dailyCardCount > 0
            ? '$dailyCardCount kart hazır'
            : 'Bugün çalışılacak kart yok',
        onTap: onTapToday,
      ),
      _DarkShortcutTile(
        icon: Icons.edit_document,
        iconGradient: const LinearGradient(
          colors: [AppTheme.dashboardVioletDeep, AppTheme.dashboardViolet],
        ),
        title: 'Deneme Sınavı',
        subtitle: 'Moda gir',
        onTap: onTapExam,
      ),
      _DarkShortcutTile(
        icon: Icons.bar_chart_rounded,
        iconGradient: null,
        title: 'İstatistikler',
        subtitle: 'İlerlemeni gör',
        onTap: onTapStats,
      ),
    ];

    if (!isWide) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTheme.space12),
            tiles[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.space16),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _DarkShortcutTile extends StatelessWidget {
  const _DarkShortcutTile({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final LinearGradient? iconGradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DarkCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: iconGradient,
              color: iconGradient == null ? AppTheme.heroNeutralFill : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconGradient == null
                  ? AppTheme.dashboardViolet
                  : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textTertiaryDark),
        ],
      ),
    );
  }
}

/// Sınav tempo uyarısı (bkz. CLAUDE.md "Sınav Tempo Uyarısı + Öncelikli Mod")
/// — yeni tasarımda ayrı bir bileşen olarak yoktu, işlevi kaybetmemek için
/// kısayol satırının altına eklendi. `paceWarning == null` iken hiç
/// oluşturulmaz (çağıran taraf zaten `if` ile koruyor).
class _DarkPaceWarningCard extends StatelessWidget {
  const _DarkPaceWarningCard({
    required this.warning,
    required this.deckName,
    required this.isPriorityModeOn,
    required this.onTogglePriorityMode,
  });

  final ExamPaceWarning warning;
  final String? deckName;
  final bool isPriorityModeOn;
  final VoidCallback onTogglePriorityMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DarkCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: AppTheme.dashboardOrange,
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  '${deckName != null ? '$deckName için s' : 'S'}ınava '
                  '${warning.daysLeft} gün kaldı. Bu tempoda yaklaşık '
                  '${warning.expectedCapacity} kart çalışabilirsin, elinde '
                  '${warning.remainingCards} kart var.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onTogglePriorityMode,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.dashboardViolet,
              ),
              child: Text(
                isPriorityModeOn
                    ? 'Normal Moda Dön'
                    : 'Öncelikli Kartlara Odaklan',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "En zor konun" hızlı antrenman kartı (bkz. CLAUDE.md "Hocanın Favorileri
/// / En Zayıf Konu Antrenmanı"). `weakestTopic == null` iken hiç oluşmaz.
class _DarkWeakestTopicCard extends StatelessWidget {
  const _DarkWeakestTopicCard({required this.info, required this.onTap});

  final WeakestTopicInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DarkCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.track_changes, color: AppTheme.dashboardViolet),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'En zor konun: ${info.topic}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${info.cardCount} kart · Antrenman Yap',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textTertiaryDark),
        ],
      ),
    );
  }
}

/// Deste ızgarası: N sütun + en sonda "Yeni Deste Oluştur" kartı. Sabit
/// `mainAxisExtent` kullanılıyor (aspect-ratio DEĞİL) — uzun deste adları
/// farklı yükseklik oranlarında taşmasın diye; kart içi metinler zaten tek
/// satır + ellipsis (bkz. `_DarkDeckCard`).
class _DarkDeckGrid extends StatelessWidget {
  const _DarkDeckGrid({
    required this.decks,
    required this.store,
    required this.readinessByDeck,
    required this.columns,
    required this.onCreateDeck,
    required this.onOpenDeck,
    required this.onRenameDeck,
    required this.onDeleteDeck,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final List<Deck> decks;
  final FlashcardStore store;
  final Map<String, DeckReadiness> readinessByDeck;
  final int columns;
  final VoidCallback onCreateDeck;
  final ValueChanged<Deck> onOpenDeck;
  final ValueChanged<Deck> onRenameDeck;
  final ValueChanged<Deck> onDeleteDeck;
  final ValueChanged<Deck> onSetExamDate;
  final ValueChanged<Deck> onClearExamDate;

  /// Destenin en sık geçen kart konusu ("kategori pili" için) — deste
  /// modelinde kategori alanı yok, mevcut `Flashcard.topic` verisinden
  /// türetiliyor. Hiç konu yoksa "Genel".
  String _dominantTopic(Deck deck) {
    final counts = <String, int>{};
    for (final card in store.cardsIn(deck.id)) {
      final topic = card.topic.trim();
      if (topic.isEmpty) continue;
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Genel';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppTheme.space16,
        crossAxisSpacing: AppTheme.space16,
        mainAxisExtent: 208,
      ),
      itemCount: decks.length + 1,
      itemBuilder: (context, index) {
        if (index == decks.length) {
          return _DarkCreateDeckCard(onTap: onCreateDeck);
        }
        final deck = decks[index];
        final readiness = readinessByDeck[deck.id];
        return _DarkDeckCard(
          deck: deck,
          index: index,
          cardCount: store.cardsIn(deck.id).length,
          dueCount: store.dueIn(deck.id).length,
          readyPercent: readiness?.readyPercent ?? 0,
          category: _dominantTopic(deck),
          onOpen: () => onOpenDeck(deck),
          onRename: () => onRenameDeck(deck),
          onDelete: () => onDeleteDeck(deck),
          onSetExamDate: () => onSetExamDate(deck),
          onClearExamDate: () => onClearExamDate(deck),
        );
      },
    );
  }
}

class _DarkCreateDeckCard extends StatelessWidget {
  const _DarkCreateDeckCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DarkCard(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTheme.heroNeutralFill,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 28,
                color: AppTheme.dashboardViolet,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            Text('Yeni Deste Oluştur', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// Tek bir deste kartı — kategori pili + isim + kart sayısı + ilerleme
/// çubuğu + meta satırı, BORDER YOK (bkz. `_DarkCard`). Rename/sil/sınav
/// tarihi menüsü [_DeckAction] üzerinden aynen korunuyor (mevcut `_DeckTile`
/// ile aynı eylemler), yalnızca küçük bir `more_vert` ikonuna taşındı —
/// referans tasarımda bu menü yoktu ama işlevi kaldırmak kapsam dışı.
class _DarkDeckCard extends StatelessWidget {
  const _DarkDeckCard({
    required this.deck,
    required this.index,
    required this.cardCount,
    required this.dueCount,
    required this.readyPercent,
    required this.category,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final Deck deck;
  final int index;
  final int cardCount;
  final int dueCount;
  final int readyPercent;
  final String category;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetExamDate;
  final VoidCallback onClearExamDate;

  static const _subjectIcons = [
    Icons.biotech_outlined,
    Icons.psychology_outlined,
    Icons.medication_outlined,
    Icons.favorite_border_outlined,
    Icons.science_outlined,
  ];

  String get _metaLine {
    if (cardCount == 0) return 'Boş deste';
    if (dueCount == 0) return 'Bugünlük tamam';
    return '$dueCount kart tekrara hazır';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        AppTheme.dashboardCategoryPalette[index %
            AppTheme.dashboardCategoryPalette.length];
    final subjectIcon = _subjectIcons[index % _subjectIcons.length];
    final examDate = deck.examDate;
    final daysLeft = examDate == null
        ? null
        : deck.daysUntilExam(DateTime.now());
    final isCramming =
        daysLeft != null &&
        daysLeft >= 0 &&
        daysLeft < SrsEngine.crammingThresholdDays;

    return _DarkCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_DeckAction>(
                tooltip: 'Deste işlemleri',
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppTheme.textTertiaryDark,
                ),
                padding: EdgeInsets.zero,
                iconSize: 18,
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '$cardCount Kart',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.heroNeutralFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  subjectIcon,
                  size: 18,
                  color: AppTheme.textSecondaryDark,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (cardCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Öğrenilen',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiaryDark,
                  ),
                ),
                Text(
                  '$readyPercent%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    const ColoredBox(color: AppTheme.heroNeutralFill),
                    FractionallySizedBox(
                      widthFactor: (readyPercent / 100).clamp(0.0, 1.0),
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
            const SizedBox(height: 8),
          ],
          if (examDate != null) ...[
            Row(
              children: [
                Icon(
                  isCramming
                      ? Icons.local_fire_department
                      : Icons.event_outlined,
                  size: 12,
                  color: isCramming
                      ? AppTheme.dashboardRed
                      : AppTheme.textTertiaryDark,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isCramming
                        ? 'Sınava $daysLeft gün · yoğun tekrar'
                        : 'Sınava '
                              '${daysLeft != null && daysLeft >= 0 ? '$daysLeft gün' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isCramming ? FontWeight.w700 : null,
                      color: isCramming
                          ? AppTheme.dashboardRed
                          : AppTheme.textTertiaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          Text(
            _metaLine,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textTertiaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// KOYU/AÇIK MOD ORTAK — sol sabit sidebar navigasyonu.
// 2026-08-10, referans tasarımların (`fixed left-0 top-0 h-screen w-20`)
// eskiden AppBar'ın sağ üstüne sıkıştırılmış eylemlerini (İstatistik/
// Kendini Test Et/Ayarlar) yerine getiriyor. Yalnızca DOLU dashboard'ta
// var — boş/karşılama ekranı bu sidebar'ı hiç görmüyor (bkz.
// `DeckListScreen.build` doc yorumu).
// ============================================================================
class _SideNavBar extends StatelessWidget {
  const _SideNavBar({
    required this.onOpenQuiz,
    required this.onOpenStats,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenSettings;

  static const double width = 80;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      decoration: BoxDecoration(
        // Koyu modda kullanıcının verdiği tam hex (#13181F) — sayfa
        // zemininden (`heroBackground`, #0D1321) hafif farklı, bilinçli.
        color: isDark ? const Color(0xFF13181F) : AppTheme.dashboardSurface,
        border: isDark
            ? null
            : const Border(
                right: BorderSide(color: AppTheme.dashboardSubtleBorder),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppTheme.space16),
            Text(
              'M',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.dashboardVioletDeep,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            _SideNavIcon(
              icon: Icons.home,
              label: 'Ana Sayfa',
              active: true,
              isDark: isDark,
              // Zaten bu ekrandayız — sağlam bir "ana sayfaya dön" hedefi
              // yok, dokunma yalnızca dokunsal geri bildirim verir.
              onTap: () {},
            ),
            _SideNavIcon(
              icon: Icons.library_books_outlined,
              label: 'Destelerim',
              active: false,
              isDark: isDark,
              // Uygulamada ayrı bir "kütüphane" ekranı yok — deste ızgarası
              // zaten bu ekranın kendisinde. Ayrı bir ekran icat etmek yerine
              // (kapsam dışı) burada da aynı ekranda kalınıyor.
              onTap: () {},
            ),
            _SideNavIcon(
              icon: Icons.quiz_outlined,
              label: 'Kendini Test Et',
              active: false,
              isDark: isDark,
              onTap: onOpenQuiz,
            ),
            _SideNavIcon(
              icon: Icons.insights_outlined,
              label: 'İstatistikler',
              active: false,
              isDark: isDark,
              onTap: onOpenStats,
            ),
            const Spacer(),
            _SideNavIcon(
              icon: Icons.settings_outlined,
              label: 'Ayarlar',
              active: false,
              isDark: isDark,
              onTap: onOpenSettings,
            ),
            const SizedBox(height: AppTheme.space16),
          ],
        ),
      ),
    );
  }
}

class _SideNavIcon extends StatelessWidget {
  const _SideNavIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.dashboardVioletDeep;
    final inactiveColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final activeBackground = isDark
        ? AppTheme.dashboardVioletDeep.withValues(alpha: 0.20)
        : const Color(0xFFEDE9FE);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: label,
        // Dashboard tasarım sistemi: tooltip her iki temada da aynı SABİT
        // açık kart gibi görünüyor (isDark'a göre dallanmıyor) — OS'un
        // kendi tooltip'leri de genelde uygulama temasından bağımsız açık
        // durur, aynı desen burada bilinçli tekrarlandı. Konumlandırma
        // (sidebar'ın sağında) ekstra kod GEREKTİRMEDİ: sidebar zaten ekranın
        // sol kenarına yapışık olduğu için Tooltip'in kendi ekran-kenarı
        // kenetleme mantığı (positionDependentBox) tooltip'i otomatik olarak
        // sağa doğru iter. Hover (masaüstü/web) ve uzun basma (dokunmatik)
        // tetikleyicileri de Tooltip'in VARSAYILAN davranışı — ayrıca
        // triggerMode ayarlamaya gerek yok.
        decoration: BoxDecoration(
          color: AppTheme.dashboardSurfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: AppTheme.dashboardTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active ? activeBackground : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar'ın sağındaki sadeleştirilmiş üst şerit — eskiden AppBar'da duran
/// İstatistik/Kendini Test Et/Ayarlar ikonları artık `_SideNavBar`'da;
/// burada YALNIZCA profil balonu kalıyor. Bildirim zili BİLİNÇLİ olarak
/// EKLENMEDİ — uygulamada gerçek bir bildirim sistemi yok, işlevi olmayan
/// bir zil ikonu koymak yerine tamamen kaldırıldı (kullanıcının verdiği iki
/// seçenekten "kaldır").
class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 64,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(right: AppTheme.space16),
          child: ProfileBubble(),
        ),
      ),
    );
  }
}

// ============================================================================
// KOYU/AÇIK MOD ORTAK — sayfanın en altına sabitlenen altbilgi (footer).
// 2026-08-10, hem "koyu mod dashboard" hem "açık mod dashboard" referans
// tasarımlarında var olan "MedKart · Legal · Gizlilik · Destek · © 2026
// MedKart" satırı. `DeckListScreen.build`'te dashboard içeriğinin ALTINDA,
// `Column` + `Expanded` yapısının sabit (flex olmayan) son çocuğu olarak
// duruyor — içerik ne kadar kısa olursa olsun viewport'un en altında kalır.
// ============================================================================
class _DashboardFooter extends StatelessWidget {
  const _DashboardFooter();

  void _openLegal(BuildContext context, String title, String content) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LegalScreen(title: title, content: content)));
  }

  void _showSupportInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Destek: henüz ayrı bir kanal yok, yakında eklenecek.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = isDark ? AppTheme.textPrimaryDark : AppTheme.dashboardVioletDeep;
    final mutedColor = isDark ? AppTheme.textTertiaryDark : AppTheme.dashboardTextMuted;

    return ContentShell(
      maxWidth: AppTheme.dashboardMaxWidth,
      shrinkWrapHeight: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space24,
        vertical: AppTheme.space16,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppTheme.space24,
        runSpacing: AppTheme.space8,
        children: [
          Text(
            'MedKart',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: brandColor),
          ),
          Wrap(
            spacing: AppTheme.space16,
            children: [
              GestureDetector(
                onTap: () => _openLegal(
                  context,
                  LegalContent.termsOfServiceTitle,
                  LegalContent.termsOfService,
                ),
                child: Text('Legal', style: TextStyle(fontSize: 12, color: mutedColor)),
              ),
              GestureDetector(
                onTap: () => _openLegal(
                  context,
                  LegalContent.privacyPolicyTitle,
                  LegalContent.privacyPolicy,
                ),
                child: Text('Gizlilik', style: TextStyle(fontSize: 12, color: mutedColor)),
              ),
              GestureDetector(
                onTap: () => _showSupportInfo(context),
                child: Text('Destek', style: TextStyle(fontSize: 12, color: mutedColor)),
              ),
            ],
          ),
          Text('© 2026 MedKart', style: TextStyle(fontSize: 12, color: mutedColor)),
        ],
      ),
    );
  }
}

// ============================================================================
// AÇIK MOD DASHBOARD — 2026-08-10, "medcard light mode dashboard" referans
// tasarımından. Koyu mod (`_DarkDashboardBody`) HİÇ değiştirilmedi.
//
// Gradyan paylaşımı NÜANSLI (canlı tarayıcı testinde bulundu, dikkatli oku):
// "Çalışmaya Başla" butonu (`_DarkGradientButton`) ve isim metni
// (`_DarkGreetingName`) İKİ MODDA DA AYNEN yeniden kullanılıyor — ikisi de
// OPAK bir zemin üstünde duruyor, sorun yok. Ama hero banner'ın KENDİSİ ve
// Pro Plan kartı BİLİNÇLİ olarak KOPYALANMADI, ayrı çizildi
// (`_LightHeroBanner`/`_LightProPlanCard`): dark'ın hero'su referans
// tasarımının kendi mockup'ında YARI SAYDAM (`from-primary-container/20`) —
// koyu zeminde bu bir "glow" verirken, aynı yarı saydam gradyanı açık
// (`dashboardBackground`) zeminde birebir kullanmak soluk pembe/eflatun bir
// kart + üstünde neredeyse görünmez krem yazı üretiyordu (canlı ekran
// görüntüsüyle doğrulandı). Açık mod referansının KENDİ mockup'ı zaten
// hero'yu OPAK `accent-gradient` ile çiziyor — `_LightHeroBanner` de aynı
// şekilde `AppTheme.dashboardCtaGradient`'i OPAK kullanıyor, metin rengi
// değişmedi. Pro Plan kartı da açık mockup'ta gradyanlı bir kart DEĞİL, düz
// beyaz+kenarlıklı bir kart (yalnızca içindeki ikon rozeti gradyanlı) — bu
// yüzden `_LightProPlanCard` `_LightCard`'a benzer bir yüzey kullanıyor.
// Kısayol satırı, uyarı kartları ve deste ızgarası açık moda özel
// yüzey/metin token'larıyla (`AppTheme.dashboard{Background,Surface,
// SurfaceElevated,SubtleBorder,TextPrimary,TextMuted}`) çizildi.
//
// Metin/davranış eşleşmesi BİLİNÇLİ: "Bugün Çalış" alt yazısı, deste kartı
// meta satırı ("$cardCount kart · ..."), sınav rozeti metni ("Sınav
// {tarih}[ · N gün kaldı / · yoğun tekrar modu]") ve "En zor konun: ..."
// metinleri `deck_list_screen_test.dart`/`widget_test.dart`'taki MEVCUT
// testlerin beklediği birebir eski ifadelerle uyumlu tutuldu (bu testler
// her zaman `AppTheme.light` ile çalışır, bu yüzden bu ekranı fiilen
// doğruluyorlar). Kelimesi kelimesine değiştirme.
// ============================================================================
class _LightDashboardBody extends StatelessWidget {
  const _LightDashboardBody({
    required this.onCreateDeck,
    required this.onOpenDeck,
    required this.onRenameDeck,
    required this.onDeleteDeck,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final VoidCallback onCreateDeck;
  final ValueChanged<Deck> onOpenDeck;
  final ValueChanged<Deck> onRenameDeck;
  final ValueChanged<Deck> onDeleteDeck;
  final ValueChanged<Deck> onSetExamDate;
  final ValueChanged<Deck> onClearExamDate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final studySettings = context.watch<StudySettings>();
    final decks = store.decks;
    final dailyLimit = studySettings.dailyNewCardLimit;
    final priorityModeDeckIds = studySettings.priorityModeDeckIds;
    final dailyCount = store
        .dailyQueue(newCardLimit: dailyLimit, priorityModeDeckIds: priorityModeDeckIds)
        .length;
    final streak = store.studyLog.currentStreak(DateTime.now());
    final paceWarning = store.examPaceWarning();
    final paceWarningDeck = paceWarning == null ? null : store.deckById(paceWarning.deckId);
    final weakestTopic = store.weakestTopicInfo;
    final readinessByDeck = {for (final r in store.deckReadiness) r.deckId: r};

    void goStudyToday() => requireAuth(
      context,
      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudyScreen())),
      reason: 'Çalışmaya başlamak için giriş yap — ilerlemen kaydedilsin.',
    );

    return ContentShell(
      padding: EdgeInsets.zero,
      maxWidth: AppTheme.dashboardMaxWidth,
      child: ResponsiveBuilder(
        builder: (context, size) {
          final horizontal = responsiveHorizontalPadding(size);
          final isWide = size.isAtLeastTablet;
          final theme = Theme.of(context);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero: opak mor→pembe gradyan (`_LightHeroBanner`, bkz. o
                // sınıfın yorumu — dark'ın YARI SAYDAM hero'sunu birebir
                // yeniden kullanmak açık zeminde metni okunmaz yapıyordu).
                // CTA butonu ve isim metni yine de dark'la PAYLAŞILIYOR
                // (`_DarkGradientButton`/`_DarkGreetingName`) — ikisi de
                // opak bir zeminde zaten doğru render oluyor.
                _LightHeroRow(streak: streak, isWide: isWide, onStartStudy: goStudyToday),
                const SizedBox(height: AppTheme.space24),
                _LightShortcutRow(
                  isWide: isWide,
                  showTodayTile: store.cards.isNotEmpty,
                  dailyCardCount: dailyCount,
                  onTapToday: goStudyToday,
                  onTapExam: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ExamSimSetupScreen())),
                  onTapStats: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
                ),
                if (paceWarning != null) ...[
                  const SizedBox(height: AppTheme.space16),
                  _LightPaceWarningCard(
                    warning: paceWarning,
                    deckName: paceWarningDeck?.name,
                    isPriorityModeOn: studySettings.isPriorityMode(paceWarning.deckId),
                    onTogglePriorityMode: () => context.read<StudySettings>().setPriorityMode(
                      paceWarning.deckId,
                      !studySettings.isPriorityMode(paceWarning.deckId),
                    ),
                  ),
                ],
                if (weakestTopic != null) ...[
                  const SizedBox(height: AppTheme.space16),
                  _LightWeakestTopicCard(
                    info: weakestTopic,
                    onTap: () => requireAuth(
                      context,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudyScreen(
                            filter: CardFilter(topics: {weakestTopic.topic}),
                            ignoreDueDate: true,
                          ),
                        ),
                      ),
                      reason: 'Çalışmaya başlamak için giriş yap — ilerlemen kaydedilsin.',
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space32),
                Text(
                  'Destelerim',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    color: AppTheme.dashboardTextPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Toplam ${decks.length} deste',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.dashboardTextMuted),
                ),
                const SizedBox(height: AppTheme.space16),
                _LightDeckGrid(
                  decks: decks,
                  store: store,
                  readinessByDeck: readinessByDeck,
                  columns: responsiveValue<int>(size, mobile: 1, tablet: 2, desktop: 3),
                  onCreateDeck: onCreateDeck,
                  onOpenDeck: onOpenDeck,
                  onRenameDeck: onRenameDeck,
                  onDeleteDeck: onDeleteDeck,
                  onSetExamDate: onSetExamDate,
                  onClearExamDate: onClearExamDate,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Hero banner + Pro Plan kartı (açık mod) — mobilde alt alta, tablet/
/// masaüstünde yan yana. `_DarkHeroRow` ile aynı yerleşim mantığı ama KENDİ
/// (opak) çocuklarıyla — bkz. `_LightDashboardBody` dosya başı yorumu.
class _LightHeroRow extends StatelessWidget {
  const _LightHeroRow({
    required this.streak,
    required this.isWide,
    required this.onStartStudy,
  });

  final int streak;
  final bool isWide;
  final VoidCallback onStartStudy;

  @override
  Widget build(BuildContext context) {
    final hero = _LightHeroBanner(streak: streak, onStartStudy: onStartStudy);
    const proPlan = _LightProPlanCard();

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [hero, const SizedBox(height: AppTheme.space16), proPlan],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: hero),
          const SizedBox(width: AppTheme.space16),
          const SizedBox(width: 300, child: proPlan),
        ],
      ),
    );
  }
}

/// Açık moddaki hero banner — OPAK `dashboardCtaGradient` zemin (bkz.
/// `_LightDashboardBody` dosya başı yorumu: dark'ın yarı saydam hero'sunu
/// birebir kopyalamak açık zeminde metni okunmaz yapıyordu). CTA butonu ve
/// isim metni dark'la paylaşılıyor (`_DarkGradientButton`/
/// `_DarkGreetingName`) — ikisi de opak zeminde sorunsuz çalışıyor.
class _LightHeroBanner extends StatelessWidget {
  const _LightHeroBanner({required this.streak, required this.onStartStudy});

  final int streak;
  final VoidCallback onStartStudy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        gradient: AppTheme.dashboardCtaGradient,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DarkGreetingName(style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppTheme.space12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppTheme.space12,
            runSpacing: AppTheme.space8,
            children: [
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$streak Günlük Seri',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                streak > 0
                    ? 'Harika gidiyorsun. Çalışmaya devam et.'
                    : 'Bugün ilk kartını çalışarak seriye başla.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          _DarkGradientButton(label: 'Çalışmaya Başla', onTap: onStartStudy),
        ],
      ),
    );
  }
}

/// Sağ üstteki "Pro Plan" kartı (açık mod) — referans tasarımın kendi
/// mockup'ında bu kart gradyanlı DEĞİL, düz beyaz+kenarlıklı bir yüzey
/// (yalnızca içindeki ikon rozeti gradyanlı) — bkz. `_LightDashboardBody`
/// dosya başı yorumu. Kopya/davranış `_DarkProPlanCard` ile aynı ("Çok
/// yakında" + bilgilendirici SnackBar, gerçek abonelik sistemi yok).
class _LightProPlanCard extends StatelessWidget {
  const _LightProPlanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.dashboardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.dashboardSubtleBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.dashboardCtaGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.workspace_premium_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pro Plan',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppTheme.dashboardTextPrimary,
                          ),
                        ),
                        Text(
                          'Çok yakında',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.dashboardTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space16),
              _LightProFeatureRow(text: 'Sınırsız Deste', theme: theme),
              const SizedBox(height: 6),
              _LightProFeatureRow(text: 'Gelişmiş İstatistikler', theme: theme),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.space16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pro Plan yakında geliyor — haber vereceğiz.'),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dashboardVioletDeep,
                  side: const BorderSide(color: AppTheme.dashboardSubtleBorder),
                  backgroundColor: AppTheme.dashboardSurfaceElevated,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Bekleme Listesine Katıl'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightProFeatureRow extends StatelessWidget {
  const _LightProFeatureRow({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.dashboardVioletDeep,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.dashboardTextMuted),
          ),
        ),
      ],
    );
  }
}

/// Açık moddaki borderless-OLMAYAN kart yüzeyi — referans tasarımın "Level 1
/// (Cards): #FFFFFF with a 1px solid border" kuralı (bkz. DESIGN.md). Koyu
/// modun `_DarkCard`'ından (border yok, güçlü gölge) BİLİNÇLİ olarak farklı;
/// o widget'a dokunulmadı, bu ayrı bir sınıf.
class _LightCard extends StatelessWidget {
  const _LightCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.space16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dashboardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dashboardSubtleBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class _LightShortcutRow extends StatelessWidget {
  const _LightShortcutRow({
    required this.isWide,
    required this.showTodayTile,
    required this.dailyCardCount,
    required this.onTapToday,
    required this.onTapExam,
    required this.onTapStats,
  });

  final bool isWide;

  /// Kütüphanede HİÇ kart yoksa "Bugün Çalış" kısayolu tümüyle gizlenir
  /// (eski `_DailyStudyBanner`'ın `if (store.cards.isNotEmpty)` korumasıyla
  /// aynı davranış — bkz. `deck_list_screen_test.dart`, "kart yokken
  /// 'Bugün Çalış' bannerı gösterilmez").
  final bool showTodayTile;

  final int dailyCardCount;
  final VoidCallback onTapToday;
  final VoidCallback onTapExam;
  final VoidCallback onTapStats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      if (showTodayTile)
        _LightShortcutTile(
          icon: Icons.local_fire_department,
          iconBackground: AppTheme.dashboardRed.withValues(alpha: 0.14),
          iconColor: const Color(0xFFDC2626),
          title: 'Bugün Çalış',
          subtitle: dailyCardCount > 0 ? '$dailyCardCount kart hazır' : 'Bugün çalışılacak kart yok',
          onTap: onTapToday,
        ),
      _LightShortcutTile(
        icon: Icons.edit_document,
        iconBackground: AppTheme.dashboardVioletDeep.withValues(alpha: 0.12),
        iconColor: AppTheme.dashboardVioletDeep,
        title: 'Deneme Sınavı',
        subtitle: 'Moda gir',
        onTap: onTapExam,
      ),
      _LightShortcutTile(
        icon: Icons.bar_chart_rounded,
        iconBackground: AppTheme.dashboardSurfaceElevated,
        iconColor: AppTheme.dashboardTextMuted,
        title: 'İstatistikler',
        subtitle: 'Haftalık özet',
        onTap: onTapStats,
      ),
    ];

    if (!isWide) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTheme.space12),
            tiles[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.space16),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _LightShortcutTile extends StatelessWidget {
  const _LightShortcutTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _LightCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    color: AppTheme.dashboardTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.dashboardTextMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.dashboardTextMuted),
        ],
      ),
    );
  }
}

class _LightPaceWarningCard extends StatelessWidget {
  const _LightPaceWarningCard({
    required this.warning,
    required this.deckName,
    required this.isPriorityModeOn,
    required this.onTogglePriorityMode,
  });

  final ExamPaceWarning warning;
  final String? deckName;
  final bool isPriorityModeOn;
  final VoidCallback onTogglePriorityMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _LightCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_outlined, size: 18, color: Color(0xFFB45309)),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  '${deckName != null ? '$deckName için s' : 'S'}ınava '
                  '${warning.daysLeft} gün kaldı. Bu tempoda yaklaşık '
                  '${warning.expectedCapacity} kart çalışabilirsin, elinde '
                  '${warning.remainingCards} kart var.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.dashboardTextPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onTogglePriorityMode,
              style: TextButton.styleFrom(foregroundColor: AppTheme.dashboardVioletDeep),
              child: Text(isPriorityModeOn ? 'Normal Moda Dön' : 'Öncelikli Kartlara Odaklan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightWeakestTopicCard extends StatelessWidget {
  const _LightWeakestTopicCard({required this.info, required this.onTap});

  final WeakestTopicInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _LightCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.track_changes, color: AppTheme.dashboardVioletDeep),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'En zor konun: ${info.topic}',
                  style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.dashboardTextPrimary),
                ),
                Text(
                  '${info.cardCount} kart · Antrenman Yap',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.dashboardTextMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.dashboardTextMuted),
        ],
      ),
    );
  }
}

class _LightDeckGrid extends StatelessWidget {
  const _LightDeckGrid({
    required this.decks,
    required this.store,
    required this.readinessByDeck,
    required this.columns,
    required this.onCreateDeck,
    required this.onOpenDeck,
    required this.onRenameDeck,
    required this.onDeleteDeck,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final List<Deck> decks;
  final FlashcardStore store;
  final Map<String, DeckReadiness> readinessByDeck;
  final int columns;
  final VoidCallback onCreateDeck;
  final ValueChanged<Deck> onOpenDeck;
  final ValueChanged<Deck> onRenameDeck;
  final ValueChanged<Deck> onDeleteDeck;
  final ValueChanged<Deck> onSetExamDate;
  final ValueChanged<Deck> onClearExamDate;

  String _dominantTopic(Deck deck) {
    final counts = <String, int>{};
    for (final card in store.cardsIn(deck.id)) {
      final topic = card.topic.trim();
      if (topic.isEmpty) continue;
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Genel';
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppTheme.space16,
        crossAxisSpacing: AppTheme.space16,
        mainAxisExtent: 208,
      ),
      itemCount: decks.length + 1,
      itemBuilder: (context, index) {
        if (index == decks.length) {
          return _LightCreateDeckCard(onTap: onCreateDeck);
        }
        final deck = decks[index];
        final readiness = readinessByDeck[deck.id];
        return _LightDeckCard(
          deck: deck,
          index: index,
          cardCount: store.cardsIn(deck.id).length,
          dueCount: store.dueIn(deck.id).length,
          readyPercent: readiness?.readyPercent ?? 0,
          category: _dominantTopic(deck),
          onOpen: () => onOpenDeck(deck),
          onRename: () => onRenameDeck(deck),
          onDelete: () => onDeleteDeck(deck),
          onSetExamDate: () => onSetExamDate(deck),
          onClearExamDate: () => onClearExamDate(deck),
        );
      },
    );
  }
}

/// "Yeni Deste Oluştur" — referans tasarımın kesikli (dashed) violet
/// kenarlığı `_DashedBorderPainter` ile (yeni paket eklemeden) çiziliyor.
class _LightCreateDeckCard extends StatelessWidget {
  const _LightCreateDeckCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFFF5F3FF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: const _DashedBorderPainter(color: Color(0xFFC4B5FD), radius: 16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 28, color: AppTheme.dashboardVioletDeep),
                ),
                const SizedBox(height: AppTheme.space12),
                Text(
                  'Yeni Deste Oluştur',
                  style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.dashboardVioletDeep),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _strokeWidth = 2;
  static const double _dashWidth = 6;
  static const double _gapWidth = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _strokeWidth / 2,
      _strokeWidth / 2,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + _gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}

/// Kategori pilinin açık moddaki (soluk zemin + koyulaştırılmış metin) renk
/// çifti — bkz. referans tasarımın "Chips (Badges): light-tinted background
/// ... with darkened text for legibility" kuralı. Koyu modun
/// `AppTheme.dashboardCategoryPalette`'i (pastel tonlar, koyu zemin üstünde
/// metin olarak kullanılıyor) açık zeminde okunmaz olurdu, o yüzden ayrı.
class _CategoryColors {
  const _CategoryColors({required this.background, required this.text});

  final Color background;
  final Color text;
}

const List<_CategoryColors> _lightCategoryPalette = [
  _CategoryColors(background: Color(0xFFFEF3C7), text: Color(0xFF92400E)), // amber
  _CategoryColors(background: Color(0xFFFFE4E6), text: Color(0xFFBE123C)), // gül
  _CategoryColors(background: Color(0xFFEDE9FE), text: Color(0xFF6D28D9)), // mor
  _CategoryColors(background: Color(0xFFFCE7F3), text: Color(0xFFA21CAF)), // fuşya
];

/// [_DeckTile] eski sınıfıyla aynı biçim — sınav rozeti (bkz.
/// `_LightDeckCard`) ve testler (`deck_list_screen_test.dart`) bu formatı
/// birebir bekliyor, değiştirme.
String _formatExamDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Deste kartı (açık mod) — kategori pili + isim + kart sayısı + ilerleme
/// çubuğu + meta satırı, 1px kenarlıklı beyaz yüzey (bkz. `_LightCard`).
/// Metin formülleri (meta satırı, sınav rozeti) BİLİNÇLİ olarak eski
/// `_DeckTile` ile birebir aynı — bkz. sınıf başı dosya yorumu.
class _LightDeckCard extends StatelessWidget {
  const _LightDeckCard({
    required this.deck,
    required this.index,
    required this.cardCount,
    required this.dueCount,
    required this.readyPercent,
    required this.category,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final Deck deck;
  final int index;
  final int cardCount;
  final int dueCount;
  final int readyPercent;
  final String category;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetExamDate;
  final VoidCallback onClearExamDate;

  static const _subjectIcons = [
    Icons.biotech_outlined,
    Icons.psychology_outlined,
    Icons.medication_outlined,
    Icons.favorite_border_outlined,
    Icons.science_outlined,
  ];

  /// Eski `_DeckTile._subtitle` ile birebir aynı — testler bunu bekliyor.
  String get _metaLine {
    if (cardCount == 0) return 'Boş deste';
    if (dueCount == 0) return '$cardCount kart · bugünlük tamam';
    return '$cardCount kart · $dueCount tekrara hazır';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _lightCategoryPalette[index % _lightCategoryPalette.length];
    final subjectIcon = _subjectIcons[index % _subjectIcons.length];
    final examDate = deck.examDate;
    final daysLeft = examDate == null ? null : deck.daysUntilExam(DateTime.now());
    final isCramming =
        daysLeft != null && daysLeft >= 0 && daysLeft < SrsEngine.crammingThresholdDays;

    return _LightCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colors.text,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_DeckAction>(
                tooltip: 'Deste işlemleri',
                icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.dashboardTextMuted),
                padding: EdgeInsets.zero,
                iconSize: 18,
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
                        examDate == null ? 'Sınav tarihi belirle' : 'Sınav tarihini değiştir',
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 17,
                        color: AppTheme.dashboardTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.dashboardSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(subjectIcon, size: 18, color: AppTheme.dashboardTextMuted),
              ),
            ],
          ),
          const Spacer(),
          if (cardCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Öğrenilen',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.dashboardTextMuted),
                ),
                Text(
                  '$readyPercent%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dashboardTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    const ColoredBox(color: AppTheme.dashboardSurfaceElevated),
                    FractionallySizedBox(
                      widthFactor: (readyPercent / 100).clamp(0.0, 1.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(gradient: AppTheme.dashboardProgressGradient),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (examDate != null) ...[
            Row(
              children: [
                Icon(
                  isCramming ? Icons.local_fire_department : Icons.event_outlined,
                  size: 12,
                  color: isCramming ? const Color(0xFFDC2626) : AppTheme.dashboardTextMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isCramming
                        ? 'Sınav ${_formatExamDate(examDate)} · yoğun tekrar modu'
                        : 'Sınav ${_formatExamDate(examDate)}'
                              '${daysLeft != null && daysLeft >= 0 ? ' · $daysLeft gün kaldı' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isCramming ? FontWeight.w700 : null,
                      color: isCramming ? const Color(0xFFDC2626) : AppTheme.dashboardTextMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          Text(
            _metaLine,
            style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.dashboardTextMuted),
          ),
        ],
      ),
    );
  }
}
