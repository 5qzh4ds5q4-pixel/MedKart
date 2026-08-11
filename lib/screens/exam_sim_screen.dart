import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../models/flashcard.dart';
import '../services/mcq_generator.dart';
import '../state/flashcard_store.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/app_shell.dart';
import '../widgets/content_shell.dart';
import '../widgets/page_range_filter_chip.dart';
import 'exam_sim_quiz_screen.dart';

const List<int> _questionCountOptions = [10, 20, 40];
const int _defaultQuestionCount = 20;

/// Soru başına varsayılan hedef süre (dk) — "Soru sayısı" değiştikçe süre
/// önerisi bununla ölçeklenir (60 sn/soru).
const int _defaultMinutesPerQuestion = 1;

/// Süre stepper'ının adımı/alt-üst sınırı.
const int _minutesStep = 5;
const int _minMinutes = 5;
const int _maxMinutes = 180;

/// "Deneme Sınavı" kurulum ekranı — gerçek komite sınavı provası.
///
/// "Kendini Test Et"ten (McqSetupScreen) farkı: tek deste/tek konu değil,
/// TÜM kütüphane havuzundan karışık konu; kapsam [CardFilter] ile (çoklu
/// konu + sayfa aralığı) daraltılabilir. Soru üretimi aynı altyapıyı
/// ([McqGenerator.generate]) kullanır — hiç AI çağrısı yapılmaz.
///
/// 2026-08-11: dashboard tasarım sistemine göre yeniden çizildi (sol sidebar'a
/// kendi timer ikonuyla eklendi — eskiden "Kendini Test Et" ile karışıyordu).
/// İş mantığı (`_pool`, `_onDeckChanged`, `_start`, `McqGenerator.generate`
/// çağrısı, `requireAuth`) HİÇ değişmedi — yalnızca kurulum ekranının görsel
/// dili değişti; sınavın kendisi (`ExamSimQuizScreen`) ayrı bir akış, buna
/// dokunulmadı.
class ExamSimSetupScreen extends StatefulWidget {
  const ExamSimSetupScreen({super.key});

  /// Süre stepper'ının değer/±1 butonlarını test'ten bulmak için — birden
  /// fazla yerde "20" metni geçebildiğinden (soru sayısı segmenti de "20"
  /// gösterebilir) düz `find.text` yerine bu anahtarlar kullanılmalı.
  static const Key minutesValueKey = Key('examSimMinutesValue');
  static const Key minutesDecrementKey = Key('examSimMinutesDecrement');
  static const Key minutesIncrementKey = Key('examSimMinutesIncrement');

  @override
  State<ExamSimSetupScreen> createState() => _ExamSimSetupScreenState();
}

class _ExamSimSetupScreenState extends State<ExamSimSetupScreen> {
  CardFilter _filter = const CardFilter();
  int _questionCount = _defaultQuestionCount;
  String? _error;

  /// Seçili deste; `null` = "Tüm desteler" (VARSAYILAN). `null` iken ekran
  /// eskisiyle bit-bit aynı davranır: havuz da konu listesi de tüm
  /// kütüphaneden gelir.
  String? _deckId;

  /// Süre (dk). Başlangıçta soru sayısına göre önerilir; kullanıcı stepper'a
  /// dokununca ([_minutesEdited]) artık otomatik güncellenmez.
  int _minutes = _defaultQuestionCount * _defaultMinutesPerQuestion;
  bool _minutesEdited = false;

  /// Konu arama kutusu — yalnızca etiket bulutunda GÖRÜNEN konuları daraltır,
  /// kapsamı (`_pool`) etkilemez. Seçili konular arama metninden bağımsız
  /// her zaman üstte kalır.
  final TextEditingController _topicSearchController = TextEditingController();
  String _topicSearch = '';

  @override
  void dispose() {
    _topicSearchController.dispose();
    super.dispose();
  }

  void _onQuestionCountChanged(int count) {
    setState(() {
      _questionCount = count;
      _error = null;
      // Kullanıcı süreyi elle değiştirmediyse öneriyi yeni soru sayısına göre
      // güncelle; değiştirdiyse onun girdisine dokunma.
      if (!_minutesEdited) {
        _minutes = count * _defaultMinutesPerQuestion;
      }
    });
  }

  void _adjustMinutes(int delta) {
    setState(() {
      _minutes = (_minutes + delta).clamp(_minMinutes, _maxMinutes);
      _minutesEdited = true;
      _error = null;
    });
  }

  /// Süreden hedef saniye; [_minutes] her zaman >= [_minMinutes] olduğu için
  /// [fallback] pratikte hiç kullanılmaz, güvenlik payı olarak duruyor.
  int _targetSeconds({required int fallback}) =>
      _minutes > 0 ? _minutes * 60 : fallback;

  /// Seçili destenin kartları; "Tüm desteler" iken tüm kütüphane.
  ///
  /// Kapsam (konu çipleri, sayfa aralığı, havuz sayacı) hep BUNUN üzerinden
  /// hesaplanır — deste seçiliyken diğer destelerin konuları/sayfaları hiç
  /// görünmesin diye.
  List<Flashcard> _deckCards(FlashcardStore store) =>
      _deckId == null ? store.cards : store.cardsIn(_deckId!);

  /// Seçili destede geçen konu etiketleri; "Tüm desteler" iken kütüphanenin
  /// tamamı.
  List<String> _topics(FlashcardStore store) =>
      _deckId == null ? store.allTopics : store.topicsIn(_deckId!);

  /// Kapsama giren kartlar. Filtre boşsa destenin tüm kartları — "hiçbir şey
  /// seçmezsen tüm kartlarından hazırlanır" kuralının deste ölçeğine
  /// küçültülmüş hali.
  List<Flashcard> _pool(FlashcardStore store) {
    final cards = _deckCards(store);
    return _filter.isActive ? _filter.apply(cards) : cards;
  }

  /// Deste değişince: seçili konulardan YENİ destede bulunmayanlar temizlenir
  /// (kalanlar korunur). Sayfa aralığı/zorluk gibi diğer kriterlere
  /// dokunulmaz.
  void _onDeckChanged(FlashcardStore store, String? deckId) {
    setState(() {
      _deckId = deckId;
      _error = null;

      final allowed = _topics(store).toSet();
      for (final topic in _filter.topics) {
        if (!allowed.contains(topic)) _filter = _filter.withTopic(topic, false);
      }
    });
  }

  /// PDF'ten gelen kartların (min, max) sayfa sınırı; PDF kartı yoksa ya da
  /// tek sayfadaysa null (sayfa aralığı çipi gizlenir).
  (int, int)? _pageBounds(FlashcardStore store) {
    int? lo, hi;
    for (final card in _deckCards(store)) {
      final p = card.sourcePage;
      if (p == null) continue;
      if (lo == null || p < lo) lo = p;
      if (hi == null || p > hi) hi = p;
    }
    return (lo != null && hi != null && hi > lo) ? (lo, hi) : null;
  }

  void _onFilterChanged(CardFilter filter) {
    setState(() {
      _filter = filter;
      _error = null;
    });
  }

  void _start(BuildContext context) {
    requireAuth(context, () {
      final store = context.read<FlashcardStore>();
      final questions = McqGenerator.generate(
        _pool(store),
        count: _questionCount,
      );

      if (questions.isEmpty) {
        setState(() {
          _error =
              'Bu kapsamda yeterli soru üretilemedi. Soru üretimi için bir '
              'konuda en az 4 kart (kısa cevabı dolu) gerekir — kapsamı '
              'genişletmeyi dene.';
        });
        return;
      }

      // Hedef süre: kullanıcının seçtiği dakika; boş/geçersizse üretilen
      // GERÇEK soru sayısına göre (havuz yetersizse istenen sayıdan az soru
      // çıkabilir) soru başına 60 sn.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamSimQuizScreen(
            questions: questions,
            targetSeconds: _targetSeconds(fallback: questions.length * 60),
          ),
        ),
      );
    }, reason: 'Deneme sınavına girmek için giriş yapman gerekiyor.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasCards = store.cards.isNotEmpty;

    final poolCards = _pool(store);
    final poolSize = poolCards.length;
    final difficultyCounts = _difficultyCounts(poolCards);

    final topics = _topics(store);
    final selectedTopics = [
      for (final t in topics)
        if (_filter.topics.contains(t)) t,
    ];
    final unselectedTopics = [
      for (final t in topics)
        if (!_filter.topics.contains(t)) t,
    ];
    final visibleUnselectedTopics = _topicSearch.trim().isEmpty
        ? unselectedTopics
        : unselectedTopics
              .where(
                (t) =>
                    t.toLowerCase().contains(_topicSearch.trim().toLowerCase()),
              )
              .toList();
    final pageBounds = _pageBounds(store);
    final hasScopeOptions = topics.isNotEmpty || pageBounds != null;

    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final primaryColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;

    Widget label(String text) => Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: mutedColor,
      ),
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Komite sınavı provası',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Karışık konulardan çoktan seçmeli sorular; sorular mevcut '
          'kartlarından türetilir, yeni bir AI isteği gönderilmez.',
          style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
      ],
    );

    final countTimeCard = _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Soru Sayısı ve Süre', color: primaryColor),
          const SizedBox(height: AppTheme.space16),
          label('Soru sayısı'),
          const SizedBox(height: AppTheme.space8),
          _QuestionCountSegments(
            value: _questionCount,
            onChanged: _onQuestionCountChanged,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.space16),
          label('Süre'),
          const SizedBox(height: AppTheme.space8),
          _MinutesStepper(
            minutes: _minutes,
            isDark: isDark,
            onDecrement: _minutes <= _minMinutes
                ? null
                : () => _adjustMinutes(-_minutesStep),
            onIncrement: _minutes >= _maxMinutes
                ? null
                : () => _adjustMinutes(_minutesStep),
          ),
          const SizedBox(height: 6),
          Text(
            'Süre dolunca sınav bitmez, sadece uyarı verilir.',
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
        ],
      ),
    );

    final deckScopeCard = _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            'Hangi destelerden sınav olmak istersin?',
            color: primaryColor,
          ),
          const SizedBox(height: 4),
          Text(
            'Bir deste seçersen sınav yalnızca o desteden hazırlanır.',
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          const SizedBox(height: AppTheme.space16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _deckGradientChip(
                label: 'Tüm desteler',
                selected: _deckId == null,
                onTap: () => _onDeckChanged(store, null),
              ),
              for (final deck in store.decks)
                _deckGhostChip(
                  label: deck.name,
                  badge: '${store.cardsIn(deck.id).length}',
                  selected: _deckId == deck.id,
                  isDark: isDark,
                  onTap: () => _onDeckChanged(store, deck.id),
                ),
            ],
          ),
        ],
      ),
    );

    final topicScopeCard = _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Sınav Kapsamını Özelleştir', color: primaryColor),
          const SizedBox(height: 4),
          Text(
            _deckId == null
                ? 'Hiçbir şey seçmezsen sınav tüm kartlarından hazırlanır.'
                : 'Hiçbir şey seçmezsen sınav bu destenin tüm kartlarından '
                      'hazırlanır.',
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          const SizedBox(height: AppTheme.space16),
          if (!hasScopeOptions)
            Text(
              'Konu etiketli ya da PDF kaynaklı kart yok — sınav tüm '
              'kartlardan hazırlanır.',
              style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
            )
          else ...[
            _TopicSearchField(
              controller: _topicSearchController,
              isDark: isDark,
              onChanged: (v) => setState(() => _topicSearch = v),
            ),
            if (selectedTopics.isNotEmpty) ...[
              const SizedBox(height: AppTheme.space12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in selectedTopics)
                    _topicChip(
                      topic: topic,
                      selected: true,
                      isDark: isDark,
                      onToggle: (v) =>
                          _onFilterChanged(_filter.withTopic(topic, v)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.space12),
            if (visibleUnselectedTopics.isEmpty && unselectedTopics.isNotEmpty)
              Text(
                'Aramanla eşleşen konu yok.',
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in visibleUnselectedTopics)
                    _topicChip(
                      topic: topic,
                      selected: false,
                      isDark: isDark,
                      onToggle: (v) =>
                          _onFilterChanged(_filter.withTopic(topic, v)),
                    ),
                  if (pageBounds != null)
                    PageRangeFilterChip(
                      filter: _filter,
                      bounds: pageBounds,
                      onChanged: _onFilterChanged,
                    ),
                ],
              ),
            if (_filter.isActive) ...[
              const SizedBox(height: AppTheme.space8),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: const Text('Temizle'),
                  onPressed: () => _onFilterChanged(const CardFilter()),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppTheme.space12),
          Text(
            poolSize == 0
                ? 'Bu kapsamda hiç kart yok.'
                : 'Kapsamda $poolSize kart var.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: poolSize == 0 ? AppTheme.dashboardRed : mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final summaryPanel = _ExamSummaryPanel(
      questionCount: _questionCount,
      minutes: _minutes,
      topicCount: _filter.topics.length,
      difficultyCounts: difficultyCounts,
      error: _error,
      isDark: isDark,
      onStart: poolSize == 0 ? null : () => _start(context),
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        countTimeCard,
        const SizedBox(height: AppTheme.space16),
        deckScopeCard,
        const SizedBox(height: AppTheme.space16),
        topicScopeCard,
      ],
    );

    return AppShell(
      active: SideNavItem.exam,
      topBar: const AppShellTopBar(title: 'Deneme Sınavı'),
      body: ContentShell(
        maxWidth: AppTheme.dashboardMaxWidth,
        child: !hasCards
            ? _EmptyState(theme: theme)
            : ResponsiveBuilder(
                builder: (context, size) => ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    header,
                    const SizedBox(height: AppTheme.space24),
                    if (size.isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: leftColumn),
                          const SizedBox(width: AppTheme.space24),
                          SizedBox(width: 320, child: summaryPanel),
                        ],
                      )
                    else ...[
                      leftColumn,
                      const SizedBox(height: AppTheme.space16),
                      summaryPanel,
                    ],
                    const SizedBox(height: AppTheme.space32),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Havuzdaki kartların zorluk dağılımı — sağ paneldeki "tahmini zorluk"
/// barını besler.
Map<CardDifficulty, int> _difficultyCounts(List<Flashcard> cards) {
  final counts = {for (final d in CardDifficulty.values) d: 0};
  for (final card in cards) {
    counts[card.difficulty] = (counts[card.difficulty] ?? 0) + 1;
  }
  return counts;
}

/// "Tüm desteler" — DAİMA `AppTheme.dashboardCtaGradient` zeminli, tek
/// gradyanlı chip. Seçim durumu Flutter'ın kendi checkmark'ıyla (beyaz)
/// gösterilir. Chip'in kendi zemini (`backgroundColor`/`selectedColor`)
/// BİLİNÇLİ olarak saydam — asıl rengi dıştaki `Container`'ın gradyanı verir,
/// bu sayede widget hâlâ gerçek bir `ChoiceChip` (testler `.selected`
/// property'sini doğrudan okuyabilir).
Widget _deckGradientChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: AppTheme.dashboardCtaGradient,
      borderRadius: BorderRadius.circular(20),
    ),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.transparent,
      selectedColor: Colors.transparent,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
      pressElevation: 0,
    ),
  );
}

/// Belirli bir deste — "ghost" (border yok, düz zemin) chip + kart sayısı
/// rozeti. Seçili/seçilmemiş renk çifti `card_list_screen.dart`'taki
/// `_FilterBar._chip` ile AYNI (dashboard'un tek "seçili filtre" dili).
Widget _deckGhostChip({
  required String label,
  required String badge,
  required bool selected,
  required bool isDark,
  required VoidCallback onTap,
}) {
  final unselectedBg = isDark
      ? AppTheme.heroNeutralFill
      : AppTheme.dashboardSurfaceElevated;
  final unselectedFg = isDark
      ? AppTheme.textTertiaryDark
      : AppTheme.dashboardTextMuted;
  final selectedBg = isDark
      ? AppTheme.dashboardVioletDeep.withValues(alpha: 0.22)
      : AppTheme.dashboardViolet.withValues(alpha: 0.18);
  final selectedFg = isDark
      ? AppTheme.dashboardViolet
      : AppTheme.dashboardVioletDeep;
  final fg = selected ? selectedFg : unselectedFg;

  return ChoiceChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ],
    ),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    backgroundColor: unselectedBg,
    selectedColor: selectedBg,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    labelStyle: TextStyle(
      color: fg,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    ),
  );
}

/// Konu etiketi bulutundaki tek bir pil — seçiliyken gradyan dolgu + kaldırma
/// ikonu (üstteki "seçili konular" satırı ve alttaki bulut AYNI fonksiyonu
/// paylaşır, yalnızca `selected`e göre iki farklı görünüm üretir), değilken
/// ghost (soluk zemin). Her iki hâl de gerçek bir `FilterChip` — testler
/// hem `find.widgetWithText(FilterChip, topic)` hem `.selected` property'sini
/// önceki davranışla birebir aynı şekilde okuyabilir.
Widget _topicChip({
  required String topic,
  required bool selected,
  required bool isDark,
  required ValueChanged<bool> onToggle,
}) {
  if (selected) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.dashboardCtaGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: FilterChip(
        label: Text(topic),
        selected: true,
        showCheckmark: false,
        onSelected: onToggle,
        onDeleted: () => onToggle(false),
        backgroundColor: Colors.transparent,
        selectedColor: Colors.transparent,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        deleteIcon: const Icon(
          Icons.close_rounded,
          size: 16,
          color: Colors.white,
        ),
        deleteIconColor: Colors.white,
      ),
    );
  }
  final bg = isDark
      ? AppTheme.heroNeutralFill
      : AppTheme.dashboardSurfaceElevated;
  final fg = isDark ? AppTheme.textTertiaryDark : AppTheme.dashboardTextMuted;
  return FilterChip(
    label: Text(topic),
    selected: false,
    showCheckmark: false,
    backgroundColor: bg,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w500),
    onSelected: onToggle,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
    );
  }
}

/// Konu arama kutusu — yalnızca etiket bulutunu daraltır, `CardFilter`'a
/// dokunmaz. Border yok, dolgu zemin — dashboard input dili.
class _TopicSearchField extends StatelessWidget {
  const _TopicSearchField({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final fg = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final hint = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: fg, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Konu ara...',
        hintStyle: TextStyle(color: hint),
        prefixIcon: Icon(Icons.search, size: 20, color: hint),
        filled: true,
        fillColor: bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// 10 / 20 / 40 — bitişik segment grubu (`SegmentedButton`, `mcq_setup_
/// screen.dart`'taki `_QuestionCountPicker` ile aynı desen, dashboard
/// renkleriyle).
class _QuestionCountSegments extends StatelessWidget {
  const _QuestionCountSegments({
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final fg = isDark ? AppTheme.textTertiaryDark : AppTheme.dashboardTextMuted;

    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<int>(
        segments: [
          for (final count in _questionCountOptions)
            ButtonSegment(value: count, label: Text('$count')),
        ],
        selected: {value},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: SegmentedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          selectedBackgroundColor: AppTheme.dashboardVioletDeep,
          selectedForegroundColor: Colors.white,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        ),
      ),
    );
  }
}

/// "- 20 +" süre stepper'ı — serbest metin girişi YOK (bilinçli, dashboard
/// tasarımı stepper istedi). [_minutesStep] adımlarla [_minMinutes]/
/// [_maxMinutes] arasında hareket eder.
class _MinutesStepper extends StatelessWidget {
  const _MinutesStepper({
    required this.minutes,
    required this.isDark,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int minutes;
  final bool isDark;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final primary = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final muted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    return Row(
      children: [
        _StepButton(
          key: ExamSimSetupScreen.minutesDecrementKey,
          icon: Icons.remove_rounded,
          onTap: onDecrement,
          isDark: isDark,
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$minutes',
            key: ExamSimSetupScreen.minutesValueKey,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ),
        _StepButton(
          key: ExamSimSetupScreen.minutesIncrementKey,
          icon: Icons.add_rounded,
          onTap: onIncrement,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        Text('dakika', style: TextStyle(color: muted, fontSize: 13)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final fg = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? fg.withValues(alpha: 0.35) : fg,
          ),
        ),
      ),
    );
  }
}

/// Sağda sabit duran "Sınav Özeti" paneli — soru sayısı/süre/konu sayısı,
/// tahmini zorluk barı, hata mesajı (varsa) ve "Sınavı Başlat" butonu.
/// Masaüstünde sol sütunun yanında sabit genişlikte durur; dar ekranda sol
/// sütunun altına, aynı bileşen olarak düşer (bkz. `ExamSimSetupScreen.
/// build`).
class _ExamSummaryPanel extends StatelessWidget {
  const _ExamSummaryPanel({
    required this.questionCount,
    required this.minutes,
    required this.topicCount,
    required this.difficultyCounts,
    required this.error,
    required this.isDark,
    required this.onStart,
  });

  final int questionCount;
  final int minutes;
  final int topicCount;
  final Map<CardDifficulty, int> difficultyCounts;
  final String? error;
  final bool isDark;
  final VoidCallback? onStart;

  static const Map<CardDifficulty, Color> _difficultyColors = {
    CardDifficulty.kolay: AppTheme.accentGreen,
    CardDifficulty.orta: AppTheme.dashboardOrange,
    CardDifficulty.zor: AppTheme.dashboardRed,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final primary = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final trackColor = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final total = difficultyCounts.values.fold<int>(0, (a, b) => a + b);

    Widget summaryRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: muted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Sınav Özeti', color: primary),
          const SizedBox(height: AppTheme.space12),
          summaryRow('Soru sayısı', '$questionCount soru'),
          summaryRow('Süre', '$minutes dk'),
          summaryRow(
            'Seçili konu',
            topicCount == 0 ? 'Tümü' : '$topicCount konu',
          ),
          const SizedBox(height: AppTheme.space12),
          Text('Tahmini zorluk', style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? ColoredBox(color: trackColor)
                  : Row(
                      children: [
                        for (final d in CardDifficulty.values)
                          if ((difficultyCounts[d] ?? 0) > 0)
                            Expanded(
                              flex: difficultyCounts[d]!,
                              child: ColoredBox(color: _difficultyColors[d]!),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'Bu kapsamda kart yok.'
                : 'Kolay ${difficultyCounts[CardDifficulty.kolay] ?? 0} · '
                      'Orta ${difficultyCounts[CardDifficulty.orta] ?? 0} · '
                      'Zor ${difficultyCounts[CardDifficulty.zor] ?? 0}',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          if (error != null) ...[
            const SizedBox(height: AppTheme.space16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _GradientStartButton(onTap: onStart),
          ),
        ],
      ),
    );
  }
}

/// "Sınavı Başlat" — gerçek bir `FilledButton` (testler `.onPressed`
/// property'sini önceki gibi okuyabilir), zemini dıştaki gradyan
/// `Container`'dan geliyor (bkz. `_deckGradientChip` doc yorumu, aynı
/// desen). Pasifken gradyan soluklaştırılır — düz gri yerine markanın kendi
/// renginin soluk hâli.
class _GradientStartButton extends StatelessWidget {
  const _GradientStartButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final gradient = enabled
        ? AppTheme.dashboardCtaGradient
        : LinearGradient(
            colors: [
              AppTheme.dashboardVioletDeep.withValues(alpha: 0.35),
              AppTheme.dashboardPinkHot.withValues(alpha: 0.35),
            ],
          );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        child: const Text('Sınavı Başlat'),
      ),
    );
  }
}

/// Bu ekrandaki üç kartın (Soru Sayısı/Süre, Deste, Kapsam) ve sağ özet
/// panelinin ORTAK kabuğu — border YOK, yalnızca yumuşak gölge (dashboard
/// tasarım sistemiyle tutarlı, `card_list_screen.dart`'taki `_SummaryCard`
/// ile AYNI dekorasyon).
class _DashCard extends StatelessWidget {
  const _DashCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Önce bir deste ve kart oluştur.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Deneme Sınavı, var olan kartlarından karışık konulu çoktan '
            'seçmeli bir sınav hazırlar.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
