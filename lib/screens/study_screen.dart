import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../models/flashcard.dart';
import '../srs/srs_engine.dart';
import '../srs/study_session.dart';
import '../state/flashcard_store.dart';
import '../state/study_settings.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckId == null ? 'Bugün Çalış' : 'Çalışma'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Çalışmayı bitir',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedTopics.isNotEmpty,
              label: Text('${_selectedTopics.length}'),
              child: const Icon(Icons.topic_outlined),
            ),
            tooltip: 'Konu Filtrele',
            onPressed: _availableTopics(context.read<FlashcardStore>()).isEmpty
                ? null
                : () => _openTopicFilter(context),
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Önceki karta dön',
            onPressed: _session.canUndo ? _undo : null,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_session.completed} / ${_session.total}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _session.progress,
            minHeight: 3,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      body: SafeArea(
        child: ContentShell(
          child: Column(
            children: [
              _ExamModeBar(
                value: _examMode,
                cardCount: _session.total,
                onChanged: _toggleExamMode,
              ),
              const SizedBox(height: 8),
              _HandwrittenOnlyBar(
                value: _handwrittenOnly,
                onChanged: _toggleHandwrittenOnly,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _CardFace(
                  card: card,
                  showAnswer: _showAnswer,
                  onTap: () => setState(() => _showAnswer = !_showAnswer),
                  onEdit: () => _editCard(context, card),
                ),
              ),
              const SizedBox(height: 16),
              _AnswerControls(
                showAnswer: _showAnswer,
                onReveal: () => setState(() => _showAnswer = true),
                onGrade: _answer,
              ),
              const SizedBox(height: 10),
              const _ShortcutHint(),
            ],
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: value ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.bolt,
                size: 20,
                color: value ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sınav Modu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: value ? scheme.onPrimaryContainer : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$cardCount kart',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: value
                      ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: value ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 20,
                color: value ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sadece Hocanın Favorileri',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: value ? scheme.onPrimaryContainer : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
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

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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
                          DifficultyChip(difficulty: card.difficulty),
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
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Düzenle',
                      color: theme.colorScheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
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
                  TwoLayerAnswer(card: card),
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
            child: FilledButton(
              onPressed: onReveal,
              child: const Text('Cevabı Göster'),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Zor=uyarı rengi, Orta=nötr, Kolay=birincil. Dokunma alanları büyük.
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
            background: scheme.primary,
            foreground: scheme.onPrimary,
            onPressed: () => onGrade(ReviewGrade.kolay),
          ),
        ),
      ],
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
