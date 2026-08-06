import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../models/flashcard.dart';
import '../services/mcq_generator.dart';
import '../state/flashcard_store.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/content_shell.dart';
import '../widgets/page_range_filter_chip.dart';
import 'exam_sim_quiz_screen.dart';

const List<int> _questionCountOptions = [10, 20, 40];
const int _defaultQuestionCount = 20;

/// "Deneme Sınavı" kurulum ekranı — gerçek komite sınavı provası.
///
/// "Kendini Test Et"ten (McqSetupScreen) farkı: tek deste/tek konu değil,
/// TÜM kütüphane havuzundan karışık konu; kapsam [CardFilter] ile (çoklu
/// konu + sayfa aralığı) daraltılabilir. Soru üretimi aynı altyapıyı
/// ([McqGenerator.generate]) kullanır — hiç AI çağrısı yapılmaz.
class ExamSimSetupScreen extends StatefulWidget {
  const ExamSimSetupScreen({super.key});

  @override
  State<ExamSimSetupScreen> createState() => _ExamSimSetupScreenState();
}

/// Soru başına varsayılan hedef süre (dk) — "Soru sayısı" değiştikçe süre
/// önerisi bununla ölçeklenir (60 sn/soru).
const int _defaultMinutesPerQuestion = 1;

class _ExamSimSetupScreenState extends State<ExamSimSetupScreen> {
  CardFilter _filter = const CardFilter();
  int _questionCount = _defaultQuestionCount;
  String? _error;

  /// Seçili deste; `null` = "Tüm desteler" (VARSAYILAN). `null` iken ekran
  /// eskisiyle bit-bit aynı davranır: havuz da konu listesi de tüm
  /// kütüphaneden gelir.
  String? _deckId;

  /// Elle girilen süre (dk). Başlangıçta soru sayısına göre önerilir; kullanıcı
  /// alana dokununca ([_minutesEdited]) artık otomatik güncellenmez.
  late final TextEditingController _minutesController = TextEditingController(
    text: '${_questionCount * _defaultMinutesPerQuestion}',
  );
  bool _minutesEdited = false;

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  void _onQuestionCountChanged(int count) {
    setState(() {
      _questionCount = count;
      _error = null;
      // Kullanıcı süreyi elle değiştirmediyse öneriyi yeni soru sayısına göre
      // güncelle; değiştirdiyse onun girdisine dokunma.
      if (!_minutesEdited) {
        _minutesController.text = '${count * _defaultMinutesPerQuestion}';
      }
    });
  }

  /// Elle girilen dakikadan hedef saniye; boş/geçersizse (0 dk) [fallback]
  /// döner (soru başına 60 sn).
  int _targetSeconds({required int fallback}) {
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    return minutes > 0 ? minutes * 60 : fallback;
  }

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
    requireAuth(
      context,
      () {
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

        // Hedef süre: kullanıcının elle girdiği dakika; boş/geçersizse
        // üretilen GERÇEK soru sayısına göre (havuz yetersizse istenen
        // sayıdan az soru çıkabilir) soru başına 60 sn.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamSimQuizScreen(
              questions: questions,
              targetSeconds: _targetSeconds(fallback: questions.length * 60),
            ),
          ),
        );
      },
      reason: 'Deneme sınavına girmek için giriş yapman gerekiyor.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final theme = Theme.of(context);
    final hasCards = store.cards.isNotEmpty;
    final poolSize = _pool(store).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Deneme Sınavı')),
      body: SafeArea(
        child: ContentShell(
          child: !hasCards
              ? _EmptyState(theme: theme)
              : ResponsiveBuilder(
                  builder: (context, size) => ListView(
                    children: [
                      Text(
                        'Komite sınavı provası',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Karışık konulardan çoktan seçmeli sorular; sorular '
                        'mevcut kartlarından türetilir, yeni bir AI isteği '
                        'gönderilmez.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Soru sayısı', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final count in _questionCountOptions)
                            ChoiceChip(
                              label: Text('$count'),
                              selected: _questionCount == count,
                              onSelected: (_) => _onQuestionCountChanged(count),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Süre', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Sınav süresini dakika olarak gir. Süre dolunca sınav '
                        'bitmez, sadece uyarı verilir.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _minutesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onChanged: (_) => setState(() {
                            _minutesEdited = true;
                            _error = null;
                          }),
                          decoration: const InputDecoration(
                            suffixText: 'dakika',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Deste', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Bir deste seçersen sınav yalnızca o desteden '
                        'hazırlanır.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Tüm desteler'),
                            selected: _deckId == null,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) => _onDeckChanged(store, null),
                          ),
                          for (final deck in store.decks)
                            ChoiceChip(
                              label: Text(deck.name),
                              selected: _deckId == deck.id,
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (_) => _onDeckChanged(store, deck.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Kapsam', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        // "Tüm desteler" iken metin eskisiyle birebir aynı.
                        _deckId == null
                            ? 'Hiçbir şey seçmezsen sınav tüm kartlarından '
                                  'hazırlanır.'
                            : 'Hiçbir şey seçmezsen sınav bu destenin tüm '
                                  'kartlarından hazırlanır.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ScopeCard(
                        filter: _filter,
                        topics: _topics(store),
                        pageBounds: _pageBounds(store),
                        poolSize: poolSize,
                        onChanged: _onFilterChanged,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: responsiveButtonWidth(size),
                          child: FilledButton(
                            onPressed:
                                poolSize == 0 ? null : () => _start(context),
                            child: const Text('Sınavı Başlat'),
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

/// Kapsam seçimi: konu çipleri (çoklu seçim) + sayfa aralığı + kapsam sayacı.
class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.filter,
    required this.topics,
    required this.pageBounds,
    required this.poolSize,
    required this.onChanged,
  });

  final CardFilter filter;
  final List<String> topics;
  final (int, int)? pageBounds;
  final int poolSize;
  final ValueChanged<CardFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScopeOptions = topics.isNotEmpty || pageBounds != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasScopeOptions)
              Text(
                'Konu etiketli ya da PDF kaynaklı kart yok — sınav tüm '
                'kartlardan hazırlanır.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final topic in topics)
                    FilterChip(
                      label: Text(topic),
                      selected: filter.topics.contains(topic),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (v) => onChanged(filter.withTopic(topic, v)),
                    ),
                  if (pageBounds != null)
                    PageRangeFilterChip(
                      filter: filter,
                      bounds: pageBounds!,
                      onChanged: onChanged,
                    ),
                  if (filter.isActive)
                    ActionChip(
                      avatar: const Icon(Icons.close, size: 16),
                      label: const Text('Temizle'),
                      onPressed: () => onChanged(const CardFilter()),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              poolSize == 0
                  ? 'Bu kapsamda hiç kart yok.'
                  : 'Kapsamda $poolSize kart var.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: poolSize == 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
