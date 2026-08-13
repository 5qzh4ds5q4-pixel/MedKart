import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../models/flashcard.dart';
import '../srs/srs_engine.dart';
import '../srs/study_session.dart';
import '../state/flashcard_store.dart';
import '../state/study_settings.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/card_chips.dart';
import '../widgets/content_shell.dart';
import '../widgets/edit_card_dialog.dart';
import '../widgets/topic_filter_sheet.dart';
import '../widgets/two_layer_answer.dart';

/// Çalışma ekranı: kartı göster, cevabı aç, değerlendir.
class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    this.deckId,
    this.filter,
    this.ignoreDueDate = false,
  });

  /// null ise "Bugün Çalış" modu: tüm destelerden birleşik günlük kuyruk
  /// kullanılır (bkz. [FlashcardStore.dailyQueue]).
  final String? deckId;

  /// Verilirse yalnızca filtreye uyan kartlar çalışılır (geçici alt küme).
  final CardFilter? filter;

  /// true ise tekrar zamanı/due tarihi hiç dikkate alınmaz, [filter]'a uyan
  /// TÜM kartlar gösterilir — bkz. "Hocanın Favorilerini Çalış" ([deckId]
  /// dolu, `CardListScreen`) ve "En Zayıf Konu Antrenmanı" ([deckId] null,
  /// tüm kütüphaneden [filter]'a uyanlar, `DeckListScreen`) hızlı pratik
  /// modları. `false` iken (varsayılan) her iki dalda da mevcut davranış
  /// (due/günlük limit/yoğun tekrar triage'ı) aynen korunur.
  final bool ignoreDueDate;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late StudySession _session;
  final FocusNode _focusNode = FocusNode();
  bool _showAnswer = false;
  bool _examMode = false;
  bool _handwrittenOnly = false;

  /// Bu oturuma özel konu filtresi (kalıcı değil). Dışarıdan gelen
  /// [StudyScreen.filter] konu seçtiyse başlangıç değeri oradan alınır.
  late Set<String> _selectedTopics = {...(widget.filter?.topics ?? const {})};

  /// Dışarıdan gelen deste filtresine (varsa) Sınav Modu, "Sadece Hocanın
  /// Favorileri" ve oturuma özel konu seçimini ekler. Hepsi birlikte çalışır:
  /// yalnızca o filtreden geçen kartlar arasından, seçili konu(lar)a uyanlar
  /// kalır.
  CardFilter? get _effectiveFilter {
    final base = widget.filter ?? const CardFilter();
    final filter = CardFilter(
      difficulties: base.difficulties,
      topics: _selectedTopics,
      minPage: base.minPage,
      maxPage: base.maxPage,
      examOnly: _examMode || base.examOnly,
      handwrittenOnly: _handwrittenOnly || base.handwrittenOnly,
      cardIds: base.cardIds,
    );
    return filter.isActive ? filter : null;
  }

  @override
  void initState() {
    super.initState();
    _session = _buildSession();
  }

  StudySession _buildSession() {
    final store = context.read<FlashcardStore>();
    final deckId = widget.deckId;

    final List<Flashcard> cards;
    if (deckId != null) {
      cards = store.studyQueueFor(
        deckId,
        filter: _effectiveFilter,
        ignoreDueDate: widget.ignoreDueDate,
      );
    } else if (widget.ignoreDueDate) {
      // Hızlı pratik modu, deste ayrımı olmadan (ör. "En Zayıf Konu
      // Antrenmanı"): günlük limit/yoğun-tekrar triage'ı ([dailyQueue])
      // devre dışı — [filter]'a uyan TÜM kartlar, yalnızca [sortForStudy]
      // sırasıyla.
      final all = store.cards;
      final pool = _effectiveFilter != null && _effectiveFilter!.isActive
          ? _effectiveFilter!.apply(all)
          : all;
      cards = SrsEngine.sortForStudy(pool, all);
    } else {
      cards = store.dailyQueue(
        filter: _effectiveFilter,
        newCardLimit: context.read<StudySettings>().dailyNewCardLimit,
        priorityModeDeckIds: context.read<StudySettings>().priorityModeDeckIds,
      );
    }

    return StudySession(cards);
  }

  /// Sınav Modu değişince havuz küçülür/büyür; oturum bu yeni havuzla
  /// baştan kurulur (SRS ilerlemesi etkilenmez, yalnızca bu oturumun kuyruğu).
  void _toggleExamMode(bool value) {
    setState(() {
      _examMode = value;
      _session = _buildSession();
      _showAnswer = false;
    });
  }

  /// "Sadece Hocanın Favorileri" değişince havuz küçülür/büyür; bkz.
  /// [_toggleExamMode] — aynı mantık, ayrı bir boyut.
  void _toggleHandwrittenOnly(bool value) {
    setState(() {
      _handwrittenOnly = value;
      _session = _buildSession();
      _showAnswer = false;
    });
  }

  /// Mevcut oturumun kaynak havuzundaki konu etiketleri (deste ya da tüm
  /// kütüphane), seçili filtreden bağımsız — seçenek listesi seçim yapıldıkça
  /// küçülmesin diye.
  List<String> _availableTopics(FlashcardStore store) {
    final deckId = widget.deckId;
    return deckId != null ? store.topicsIn(deckId) : store.allTopics;
  }

  /// Konu seçim penceresini açar; seçilen konu kümesiyle oturumu yeniden kurar.
  Future<void> _openTopicFilter(BuildContext context) async {
    final store = context.read<FlashcardStore>();
    final topics = _availableTopics(store);
    if (topics.isEmpty) return;

    final result = await TopicFilterSheet.show(
      context,
      topics: topics,
      initialSelection: _selectedTopics,
    );
    if (result == null || !context.mounted) return;

    setState(() {
      _selectedTopics = result;
      _session = _buildSession();
      _showAnswer = false;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Klavye kısayolları: Space/Enter = çevir, 1 = Zor, 2 = Orta, 3 = Kolay.
  ///
  /// Değerlendirme tuşları yalnızca cevap açıkken çalışır.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      setState(() => _showAnswer = !_showAnswer);
      return KeyEventResult.handled;
    }

    if (!_showAnswer) return KeyEventResult.ignored;

    final grade = switch (key) {
      LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => ReviewGrade.zor,
      LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => ReviewGrade.orta,
      LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => ReviewGrade.kolay,
      _ => null,
    };
    if (grade == null) return KeyEventResult.ignored;

    _answer(grade);
    return KeyEventResult.handled;
  }

  void _answer(ReviewGrade grade) {
    final store = context.read<FlashcardStore>();
    final id = _session.currentId;
    if (id == null) return;

    // Kartın cevap öncesi hâli saklanır ki "geri" cevabı tümüyle geri alabilsin.
    final snapshot = store.cardById(id);
    if (snapshot == null) return;

    store.reviewCard(id, grade);
    setState(() {
      _session.answer(grade, snapshot: snapshot);
      _showAnswer = false;
    });
  }

  /// Kartın düzenleme penceresini açar; kaydedilirse depoda günceller.
  /// SRS ilerlemesi ([intervalDays] vb.) `withEdits`'te dokunulmadığı için
  /// etkilenmez, oturum akışı bozulmaz.
  Future<void> _editCard(BuildContext context, Flashcard card) async {
    await requireAuth(
      context,
      () async {
        final updated = await EditCardDialog.show(context, card);
        if (updated == null || !mounted) return;
        context.read<FlashcardStore>().updateCard(updated);
      },
      reason: 'Kartları düzenlemek için giriş yapman gerekiyor.',
    );
  }

  /// Son cevabı geri alır: kart tekrar gösterilir, SRS durumu eski hâline döner.
  void _undo() {
    final store = context.read<FlashcardStore>();
    final restored = _session.undo();
    if (restored == null) return;

    store.updateCard(restored);
    setState(() {
      // Kart daha önce cevaplanmıştı; cevabı açık getirmek doğal.
      _showAnswer = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();

    if (_session.isFinished) {
      return _SessionSummary(total: _session.total);
    }

    final card = store.cardById(_session.currentId!);
    if (card == null) return _SessionSummary(total: _session.total);

    // Klavye olaylarını yakalamak için ekran odakta tutulur.
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: _buildScaffold(context, card),
    );
  }

  Widget _buildScaffold(BuildContext context, Flashcard card) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasTopics = _availableTopics(context.read<FlashcardStore>()).isNotEmpty;

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExamModeBar(
          value: _examMode,
          cardCount: _session.total,
          onChanged: _toggleExamMode,
        ),
        const SizedBox(height: AppTheme.space8),
        _HandwrittenOnlyBar(
          value: _handwrittenOnly,
          onChanged: _toggleHandwrittenOnly,
        ),
        const SizedBox(height: AppTheme.space12),
        _CardFace(
          card: card,
          showAnswer: _showAnswer,
          onTap: () => setState(() => _showAnswer = !_showAnswer),
          onEdit: () => _editCard(context, card),
        ),
        const SizedBox(height: AppTheme.space16),
        _AnswerControls(
          showAnswer: _showAnswer,
          onReveal: () => setState(() => _showAnswer = true),
          onGrade: _answer,
        ),
        const SizedBox(height: AppTheme.space12),
        const _ShortcutHint(),
      ],
    );

    final summaryPanel = _StudySummaryPanel(
      totalCards: _session.total,
      currentDifficultyLabel: card.difficulty.label,
    );

    return Scaffold(
      body: SafeArea(
        child: ContentShell(
          maxWidth: AppTheme.dashboardMaxWidth,
          child: Column(
            children: [
              _StudyTopBar(
                title: widget.deckId == null ? 'Bugün Çalış' : 'Çalışma',
                completed: _session.completed,
                total: _session.total,
                selectedTopicCount: _selectedTopics.length,
                onClose: () => Navigator.of(context).pop(),
                onOpenTopicFilter: hasTopics
                    ? () => _openTopicFilter(context)
                    : null,
                onUndo: _session.canUndo ? _undo : null,
              ),
              const SizedBox(height: AppTheme.space12),
              _SessionProgressBar(value: _session.progress, isDark: isDark),
              const SizedBox(height: AppTheme.space16),
              Expanded(
                child: ResponsiveBuilder(
                  builder: (context, size) => ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (size.isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: mainColumn),
                            const SizedBox(width: AppTheme.space24),
                            SizedBox(width: 320, child: summaryPanel),
                          ],
                        )
                      else ...[
                        mainColumn,
                        const SizedBox(height: AppTheme.space16),
                        summaryPanel,
                      ],
                    ],
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

/// Bir oturum kartını bitirmenin ortalama alacağı süre için basit, saydam bir
/// tahmin — gerçek bir ölçüme dayanmıyor (uygulamada henüz kart-başı süre
/// takibi yok), o yüzden sabit ve tek yerde belgeli tutuluyor. Yalnızca sağ
/// paneldeki "Tahmini süre" satırını besler, hiçbir SRS/kuyruk kararını
/// ETKİLEMEZ.
const int _estimatedSecondsPerCard = 45;

/// Ekranın en üstündeki bar: kapat + başlık solda; konu filtrele/geri al/
/// ilerleme sağda. Eskiden `Scaffold.appBar` (AppBar) idi — dashboard
/// mockup'ında AppBar'ın sabit yüksekliği/gölgesi yerine düz bir satır
/// isteniyor, o yüzden artık gövdenin içinde sade bir `Row`.
class _StudyTopBar extends StatelessWidget {
  const _StudyTopBar({
    required this.title,
    required this.completed,
    required this.total,
    required this.selectedTopicCount,
    required this.onClose,
    required this.onOpenTopicFilter,
    required this.onUndo,
  });

  final String title;
  final int completed;
  final int total;
  final int selectedTopicCount;
  final VoidCallback onClose;
  final VoidCallback? onOpenTopicFilter;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final badgeBg = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;

    return Row(
      children: [
        _TopBarIconButton(
          icon: Icons.close,
          tooltip: 'Çalışmayı bitir',
          background: badgeBg,
          foreground: theme.colorScheme.onSurface,
          onPressed: onClose,
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _TopBarIconButton(
          icon: Icons.topic_outlined,
          tooltip: 'Konu Filtrele',
          background: badgeBg,
          foreground: onOpenTopicFilter == null
              ? mutedColor.withValues(alpha: 0.4)
              : mutedColor,
          onPressed: onOpenTopicFilter,
          badgeCount: selectedTopicCount,
        ),
        const SizedBox(width: AppTheme.space8),
        _TopBarIconButton(
          icon: Icons.undo,
          tooltip: 'Önceki karta dön',
          background: badgeBg,
          foreground: onUndo == null
              ? mutedColor.withValues(alpha: 0.4)
              : mutedColor,
          onPressed: onUndo,
        ),
        const SizedBox(width: AppTheme.space16),
        Icon(Icons.folder_outlined, size: 20, color: mutedColor),
        const SizedBox(width: AppTheme.space8),
        Text(
          '$completed / $total',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Üst bardaki küçük kare ikon butonu — kapalı bir kutu içinde `IconButton`.
/// Widget TİPİ hâlâ gerçek `IconButton` (testler `find.byIcon`/
/// `find.widgetWithIcon(IconButton, ...)` ile aradığı için değiştirilmedi),
/// yalnızca dışına dekoratif bir kare zemin sarıldı.
class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text('$badgeCount'),
        child: Icon(icon, size: 20),
      ),
      tooltip: tooltip,
      color: foreground,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: button,
    );
  }
}

/// Oturumun ilerleme çubuğu — eskiden `AppBar.bottom`'daki amber/nötr
/// `LinearProgressIndicator` idi; artık dashboard'un mor→pembe ilerleme
/// gradyanıyla (`AppTheme.dashboardProgressGradient`) elle çizilen ince bir
/// çubuk (`_DeckReadinessBar`/stats ekranındaki AYNI desen).
class _SessionProgressBar extends StatelessWidget {
  const _SessionProgressBar({required this.value, required this.isDark});

  final double value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final track = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSubtleBorder;
    final clamped = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: track),
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.dashboardProgressGradient,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sağdaki sabit "Çalışma Özeti" paneli — toplam kart/tahmini süre/tekrar
/// aralığı + bir "İpucu" kutusu. Tamamen görsel bir özet; hiçbir değeri
/// state'e yazmaz, SRS/kuyruk kararına dokunmaz.
class _StudySummaryPanel extends StatelessWidget {
  const _StudySummaryPanel({
    required this.totalCards,
    required this.currentDifficultyLabel,
  });

  final int totalCards;

  /// Şu an gösterilen kartın zorluk etiketi (Kolay/Orta/Zor) — "Tekrar
  /// aralığı" satırı GERÇEK bir SRS aralığı ölçütü değil (uygulamada henüz
  /// kart-başı böyle bir metrik yok); mockup'taki değer o anki kartın
  /// zorluğuyla birebir eşleşiyor, o yüzden burada da AYNI gerçek alan
  /// (`Flashcard.difficulty`) tekrar kullanılıyor — uydurma bir sayı DEĞİL.
  final String currentDifficultyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final violet = isDark
        ? AppTheme.dashboardViolet
        : AppTheme.dashboardVioletDeep;
    final estimatedMinutes =
        (totalCards * _estimatedSecondsPerCard / 60).round();

    return _DashCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SummaryIconBadge(
                icon: Icons.list_alt_outlined,
                isDark: isDark,
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                'Çalışma Özeti',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          Divider(
            height: 1,
            color: isDark
                ? AppTheme.heroBorder
                : AppTheme.dashboardSubtleBorder,
          ),
          const SizedBox(height: AppTheme.space16),
          _SummaryRow(
            icon: Icons.bookmark_outline,
            iconColor: isDark ? AppTheme.dashboardPink : AppTheme.dashboardPinkHot,
            label: 'Toplam kart',
            value: '$totalCards',
            primaryColor: primaryColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: AppTheme.space12),
          _SummaryRow(
            icon: Icons.track_changes_outlined,
            iconColor: violet,
            label: 'Tahmini süre',
            value: '$estimatedMinutes dk',
            primaryColor: primaryColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: AppTheme.space12),
          _SummaryRow(
            icon: Icons.history_outlined,
            iconColor: violet,
            label: 'Tekrar aralığı',
            value: currentDifficultyLabel,
            primaryColor: primaryColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: AppTheme.space16),
          _TipBox(isDark: isDark),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.mutedColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color primaryColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: mutedColor)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: primaryColor,
          ),
        ),
      ],
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final violet = isDark
        ? AppTheme.dashboardViolet
        : AppTheme.dashboardVioletDeep;
    final tintBg = isDark
        ? AppTheme.dashboardVioletDeep.withValues(alpha: 0.16)
        : AppTheme.dashboardViolet.withValues(alpha: 0.14);
    final textColor = isDark
        ? AppTheme.textSecondaryDark
        : AppTheme.dashboardTextMuted;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: tintBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: violet),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İpucu',
                  style: TextStyle(fontWeight: FontWeight.w700, color: violet),
                ),
                const SizedBox(height: 4),
                Text(
                  'Düzenli tekrar, bilgilerin uzun vadeli kalıcı olmasını '
                  'sağlar.',
                  style: TextStyle(fontSize: 12.5, color: textColor, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Küçük kare rozet ikonu — panel başlığı ve "İpucu" kutusu için ortak.
/// Metrik satırlarındaki ikonlardan (kutu YOK, çıplak renkli ikon) BİLİNÇLİ
/// olarak farklı — mockup'ta yalnızca başlık/ipucu ikonları kare zemin
/// taşıyor.
class _SummaryIconBadge extends StatelessWidget {
  const _SummaryIconBadge({required this.icon, required this.isDark});

  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppTheme.dashboardVioletDeep.withValues(alpha: 0.22)
        : AppTheme.dashboardViolet.withValues(alpha: 0.18);
    final fg = isDark ? AppTheme.dashboardViolet : AppTheme.dashboardVioletDeep;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

/// Border YOK, yalnızca yumuşak gölge (`boxShadow`) — bu ekranın kart/panel
/// zemini. `exam_sim_screen.dart`'taki `_DashCard` ile AYNI desen (ayrı
/// dosyada private olduğu için burada tekrarlandı, import edilemez).
class _DashCard extends StatelessWidget {
  const _DashCard({required this.child, required this.isDark, this.padding});

  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.heroSurface : AppTheme.dashboardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Çalışma ekranının üstünde sade bir Sınav Modu switch'i.
///
/// Açıkken yalnızca sınav tipi kartlar ve öncelikli temel kartlar havuzda
/// kalır; kapalıyken tüm kartlar. Karmaşık bir ayar menüsüne gömülmez,
/// tek satırlık switch olarak doğrudan burada durur.
class _ExamModeBar extends StatelessWidget {
  const _ExamModeBar({
    required this.value,
    required this.cardCount,
    required this.onChanged,
  });

  final bool value;
  final int cardCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ToggleRow(
      icon: Icons.bolt,
      title: 'Sınav Modu',
      subtitle: '$cardCount kartlık klasik sınav deneyimi',
      trailingLabel: '$cardCount kart',
      value: value,
      onChanged: onChanged,
    );
  }
}

/// "Sadece Hocanın Favorileri" switch'i — [_ExamModeBar] ile AYNI görsel dil
/// (aynı yapı, yalnızca ikon/etiket farklı): açıkken yalnızca
/// [Flashcard.isHandwritten] kartlar havuzda kalır.
class _HandwrittenOnlyBar extends StatelessWidget {
  const _HandwrittenOnlyBar({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ToggleRow(
      icon: Icons.star_rounded,
      title: 'Sadece Hocanın Favorileri',
      subtitle: 'Favorilere işaretlenmiş kartlardan çalış',
      trailingLabel: null,
      value: value,
      onChanged: onChanged,
    );
  }
}

/// [_ExamModeBar]/[_HandwrittenOnlyBar] paylaşılan gövdesi — ikon rozeti hep
/// AYNI mor tonda durur (durum GÖSTERGESİ değil, sabit marka vurgusu);
/// durumu gösteren TEK şey Switch'in kendisi (kapalıyken gri, açıkken mor
/// dolu). Satırın zemini de artık `primaryContainer`/amber ile DEĞİŞMİYOR —
/// `_DashCard` ile aynı border'sız, gölgeli nötr kart.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final violet = isDark
        ? AppTheme.dashboardViolet
        : AppTheme.dashboardVioletDeep;
    final iconBadgeBg = isDark
        ? AppTheme.dashboardVioletDeep.withValues(alpha: 0.22)
        : AppTheme.dashboardViolet.withValues(alpha: 0.18);
    final cardBg = isDark ? AppTheme.heroSurface : AppTheme.dashboardSurface;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBadgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: violet),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12.5, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                if (trailingLabel != null) ...[
                  Text(
                    trailingLabel!,
                    style: TextStyle(fontSize: 13, color: mutedColor),
                  ),
                  const SizedBox(width: 8),
                ],
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: violet,
                  inactiveThumbColor: isDark
                      ? AppTheme.textTertiaryDark
                      : AppTheme.dashboardTextMuted,
                  inactiveTrackColor: isDark
                      ? AppTheme.heroNeutralFill
                      : AppTheme.dashboardSubtleBorder,
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartın kendisi: üstte soru, açılınca altında cevap.
///
/// Cevap (bkz. [TwoLayerAnswer]) iki katmanlı gösterilir: önce yalnız
/// [Flashcard.shortAnswer], "Açıklamasını gör" butonuyla altına
/// [Flashcard.answer] açılır.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.showAnswer,
    required this.onTap,
    required this.onEdit,
  });

  final Flashcard card;
  final bool showAnswer;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBadgeBg = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final violet = isDark
        ? AppTheme.dashboardViolet
        : AppTheme.dashboardVioletDeep;

    return _DashCard(
      isDark: isDark,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StudyDifficultyBadge(
                            label: card.difficulty.label,
                            isDark: isDark,
                          ),
                          if (card.isExamType) const ExamTypeChip(),
                          if (card.hasTopic) TopicChip(topic: card.topic),
                          if (card.isHandwritten) const HandwrittenFavoriteChip(),
                          if (card.isEdited) const EditedChip(),
                          if (card.flagged) const FlaggedChip(),
                        ],
                      ),
                    ),
                    // Kart çevirme dokunuşuyla karışmasın diye ayrı bir
                    // dokunma hedefi (IconButton kendi InkResponse'unda
                    // hız kazanır, ebeveyn InkWell'e sıçramaz).
                    Container(
                      decoration: BoxDecoration(
                        color: iconBadgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Düzenle',
                        color: mutedColor,
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  card.question,
                  style: theme.textTheme.headlineSmall?.copyWith(height: 1.4),
                ),
                if (showAnswer) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  // Bu widget her cevap gösterişinde yeniden mount edilir
                  // (yalnızca showAnswer=true iken ağaçta), o yüzden "Açıklamasını
                  // gör" durumu her seferinde kendiliğinden sıfırlanır.
                  TwoLayerAnswer(card: card, expandLinkColor: violet),
                  if (card.hasNote) ...[
                    const SizedBox(height: 16),
                    MnemonicNote(note: card.note),
                  ],
                ] else ...[
                  const SizedBox(height: 24),
                  Text(
                    'Cevabı görmek için karta dokun',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartın zorluk rozeti — paylaşılan `DifficultyChip` (kolay/orta/zor için
/// yeşil/amber/kırmızı semantik renk taşıyor, bkz. `card_chips.dart`) BİLİNÇLİ
/// olarak KULLANILMADI: mockup'ta bu rozet marka vurgusu (mor) taşıyor, amber
/// hiç yok. `DifficultyChip` başka ekranlarda (ör. kart listesi) hâlâ kendi
/// semantik paletiyle kullanılmaya devam ediyor — bu, o widget'ın YERİNE
/// geçmiyor, yalnızca bu ekrana özel, ayrı bir rozet.
class _StudyDifficultyBadge extends StatelessWidget {
  const _StudyDifficultyBadge({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppTheme.dashboardVioletDeep.withValues(alpha: 0.28)
        : AppTheme.dashboardViolet.withValues(alpha: 0.22);
    final fg = isDark ? AppTheme.dashboardViolet : AppTheme.dashboardVioletDeep;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Cevap kapalıyken tek buton, açıkken değerlendirme butonları.
class _AnswerControls extends StatelessWidget {
  const _AnswerControls({
    required this.showAnswer,
    required this.onReveal,
    required this.onGrade,
  });

  final bool showAnswer;
  final VoidCallback onReveal;
  final ValueChanged<ReviewGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    if (!showAnswer) {
      return ResponsiveBuilder(
        builder: (context, size) => Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: responsiveButtonWidth(size),
            child: _GradientRevealButton(onPressed: onReveal),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Zor=uyarı rengi, Orta=nötr, Kolay=başarı/yeşil. Üçü de SRS geri
    // bildirim renkleridir, marka violet/pink paletinden BİLİNÇLİ olarak
    // BAĞIMSIZDIR — kolay artık amber/primary DEĞİL, AppTheme.successColor
    // (bkz. app_theme.dart, "Günlük Hedef" halkasıyla aynı yeşil token).
    // Dokunma alanları büyük.
    return Row(
      children: [
        Expanded(
          child: _GradeButton(
            label: 'Zor',
            shortcut: '1',
            background: scheme.errorContainer,
            foreground: scheme.onErrorContainer,
            onPressed: () => onGrade(ReviewGrade.zor),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GradeButton(
            label: 'Orta',
            shortcut: '2',
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurface,
            onPressed: () => onGrade(ReviewGrade.orta),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GradeButton(
            label: 'Kolay',
            shortcut: '3',
            // successColor koyu temada AÇIK yeşil, açık temada KOYU yeşil
            // döner (bkz. app_theme.dart) — bu yüzden metin rengi de tema
            // parlaklığına göre TERSİNE seçiliyor, aksi halde kontrast düşer.
            background: AppTheme.successColor(context),
            foreground: isDark ? Colors.black : Colors.white,
            onPressed: () => onGrade(ReviewGrade.kolay),
          ),
        ),
      ],
    );
  }
}

/// "Cevabı Göster" butonu — eskiden tema varsayılanı (amber `FilledButton`)
/// idi, uygulamanın diğer birincil CTA'larıyla (`_GradientCtaButton`/
/// `_GradientStartButton`, bkz. card_list_screen.dart/exam_sim_screen.dart)
/// AYNI desenle mor→pembe gradyana çevrildi: gerçek bir `FilledButton`
/// saydam zeminle gradyan `Container`'a sarılı, testler `find.text(...)` ile
/// hâlâ bulup tıklayabiliyor.
class _GradientRevealButton extends StatelessWidget {
  const _GradientRevealButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.dashboardCtaGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Cevabı Göster'),
      ),
    );
  }
}

/// Değerlendirme butonu: etiket + küçük kısayol numarası.
class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.shortcut,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final String shortcut;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Text(
            shortcut,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: foreground.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ekranın altında sabit klavye kısayol ipucu.
class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dokunmatik cihazda fiziksel klavye yoksa ipucu gereksiz; gizle.
    final hasKeyboard =
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux;
    if (!hasKeyboard) return const SizedBox.shrink();

    return DefaultTextStyle(
      style: theme.textTheme.bodySmall!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      child: const Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 4,
        children: [
          _HintItem(keyLabel: 'Boşluk', action: 'çevir'),
          _HintItem(keyLabel: '1', action: 'Zor'),
          _HintItem(keyLabel: '2', action: 'Orta'),
          _HintItem(keyLabel: '3', action: 'Kolay'),
        ],
      ),
    );
  }
}

class _HintItem extends StatelessWidget {
  const _HintItem({required this.keyLabel, required this.action});

  final String keyLabel;
  final String action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(keyLabel, style: theme.textTheme.labelSmall),
        ),
        const SizedBox(width: 5),
        Text(action, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Oturum bitti ekranı.
class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Çalışma')),
      body: SafeArea(
        child: ContentShell(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text('Oturum tamamlandı', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  total == 0
                      ? 'Tekrar edilecek kart yoktu.'
                      : '$total kartı tamamladın. Kartlar tekrar zamanı gelince '
                            'karşına çıkacak.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                ResponsiveBuilder(
                  builder: (context, size) => SizedBox(
                    width: responsiveButtonWidth(size),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kartlara dön'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
