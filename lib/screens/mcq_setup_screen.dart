import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../services/mcq_generator.dart';
import '../state/flashcard_store.dart';
import '../theme/app_theme.dart';
import '../utils/require_auth.dart';
import '../widgets/content_shell.dart';
import 'mcq_quiz_screen.dart';

const List<int> _questionCountOptions = [5, 10, 20];
const int _defaultQuestionCount = 10;

/// Kapsam listesinin en fazla kaplayacağı yükseklik; konu çoksa içinde kayar.
/// Kart tek ekrana sığsın diye sabit — konu sayısıyla büyümemeli.
const double _scopeListMaxHeight = 300;

/// "Kendini Test Et" (MCQ) kapsam/soru sayısı seçim ekranı.
///
/// Yalnızca havuzu kurup [McqGenerator.generate]'ı senkron çağırır — hiç AI
/// çağrısı yapılmaz. Üretilen soru listesi yeterliyse [McqQuizScreen]'e geçilir.
///
/// Kapsam TEKLİ seçimdir: "Tüm deste" ya da tam olarak bir konu. (Deneme
/// Sınavı'ndaki çoklu konu + sayfa aralığı kapsamıyla karıştırılmamalı —
/// bkz. `ExamSimSetupScreen`.)
class McqSetupScreen extends StatefulWidget {
  const McqSetupScreen({super.key, this.initialDeckId});

  /// Ekrana gelinen bağlamdaki deste (varsa) — dropdown bununla açılır.
  /// Verilmezse ya da böyle bir deste kalmadıysa ilk desteye düşülür.
  final String? initialDeckId;

  @override
  State<McqSetupScreen> createState() => _McqSetupScreenState();
}

class _McqSetupScreenState extends State<McqSetupScreen> {
  String? _deckId;
  String? _selectedTopic;
  int _questionCount = _defaultQuestionCount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final decks = context.read<FlashcardStore>().decks;
    if (decks.isEmpty) return;
    // Bağlam destesi hâlâ duruyorsa onunla aç; yoksa ilk deste.
    final contextDeck = widget.initialDeckId;
    _deckId = decks.any((d) => d.id == contextDeck)
        ? contextDeck
        : decks.first.id;
  }

  /// Deste değişince: seçili konu YENİ destede de varsa korunur, yoksa kapsam
  /// "Tüm deste"ye döner. (`ExamSimSetupScreen._onDeckChanged` ile aynı kural,
  /// tekli seçime uyarlanmış hali.)
  void _onDeckChanged(String? deckId) {
    final store = context.read<FlashcardStore>();
    setState(() {
      _deckId = deckId;
      _error = null;

      final topic = _selectedTopic;
      if (topic != null) {
        final allowed = deckId == null ? const <String>[] : store.topicsIn(deckId);
        if (!allowed.contains(topic)) _selectedTopic = null;
      }
    });
  }

  void _onScopeChanged(String? topic) {
    setState(() {
      _selectedTopic = topic;
      _error = null;
    });
  }

  void _start(BuildContext context) {
    requireAuth(
      context,
      () {
        final deckId = _deckId;
        if (deckId == null) return;

        final store = context.read<FlashcardStore>();
        final pool = _selectedTopic == null
            ? store.cardsIn(deckId)
            : store
                  .cardsIn(deckId)
                  .where((c) => c.topic == _selectedTopic)
                  .toList();

        final questions = McqGenerator.generate(pool, count: _questionCount);

        if (questions.isEmpty) {
          setState(() {
            _error =
                'Bu kapsamda yeterli soru üretilemedi. MCQ için bir konuda '
                'en az 4 kart (kısa cevabı dolu) gerekir.';
          });
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => McqQuizScreen(questions: questions),
          ),
        );
      },
      reason: 'Kendini test etmek için giriş yap.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final decks = store.decks;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kendini Test Et')),
      body: SafeArea(
        child: ContentShell(
          child: decks.isEmpty
              ? _EmptyState(theme: theme)
              : ListView(
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: AppTheme.space24),
                    _SetupCard(
                      decks: decks,
                      deckId: _deckId,
                      onDeckChanged: _onDeckChanged,
                      topics: _deckId == null
                          ? const []
                          : store.topicsIn(_deckId!),
                      selectedTopic: _selectedTopic,
                      onScopeChanged: _onScopeChanged,
                      questionCount: _questionCount,
                      onQuestionCountChanged: (count) =>
                          setState(() => _questionCount = count),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppTheme.space16),
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
                    const SizedBox(height: AppTheme.space24),
                    Center(
                      child: FilledButton.icon(
                        onPressed: _deckId == null
                            ? null
                            : () => _start(context),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Başla'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 44,
                            vertical: 18,
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space16),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Ortalanmış marka bloğu: kenarlıklı kare içinde amber pano ikonu + başlık.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(
            Icons.assignment_outlined,
            size: 26,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Text(
          'Çoktan seçmeli pratik',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Deste + kapsam + soru sayısını tek bir panelde toplayan kurulum kartı.
class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.decks,
    required this.deckId,
    required this.onDeckChanged,
    required this.topics,
    required this.selectedTopic,
    required this.onScopeChanged,
    required this.questionCount,
    required this.onQuestionCountChanged,
  });

  final List<Deck> decks;
  final String? deckId;
  final ValueChanged<String?> onDeckChanged;
  final List<String> topics;
  final String? selectedTopic;
  final ValueChanged<String?> onScopeChanged;
  final int questionCount;
  final ValueChanged<int> onQuestionCountChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Deste'),
          const SizedBox(height: AppTheme.space8),
          _DeckDropdown(decks: decks, value: deckId, onChanged: onDeckChanged),
          const SizedBox(height: AppTheme.space16),
          _FieldLabel('Kapsam'),
          const SizedBox(height: AppTheme.space8),
          _ScopePicker(
            topics: topics,
            selectedTopic: selectedTopic,
            onChanged: onScopeChanged,
          ),
          const SizedBox(height: AppTheme.space24),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: AppTheme.space24),
          _FieldLabel('Soru sayısı'),
          const SizedBox(height: AppTheme.space8),
          _QuestionCountPicker(
            value: questionCount,
            onChanged: onQuestionCountChanged,
          ),
        ],
      ),
    );
  }
}

/// Karttaki alan başlığı — üç alan da aynı tipografiyi kullansın diye ayrı.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DeckDropdown extends StatelessWidget {
  const _DeckDropdown({
    required this.decks,
    required this.value,
    required this.onChanged,
  });

  final List<Deck> decks;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: [
        for (final deck in decks)
          DropdownMenuItem(value: deck.id, child: Text(deck.name)),
      ],
      onChanged: onChanged,
    );
  }
}

/// "Tüm deste" veya belirli bir konu — TEKLİ seçim (radyo).
///
/// Konu listesi [FlashcardStore.topicsIn] sırasıyla (alfabetik) gelir ve
/// yalnızca seçili destede geçen konuları içerir. Liste [_scopeListMaxHeight]
/// yüksekliğini aşarsa kendi içinde kayar.
class _ScopePicker extends StatelessWidget {
  const _ScopePicker({
    required this.topics,
    required this.selectedTopic,
    required this.onChanged,
  });

  final List<String> topics;
  final String? selectedTopic;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget tile(String? value, String label) => RadioListTile<String?>(
      title: Text(label, style: theme.textTheme.bodyMedium),
      value: value,
      groupValue: selectedTopic,
      onChanged: onChanged,
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
    );

    return Container(
      constraints: const BoxConstraints(maxHeight: _scopeListMaxHeight),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      // Kart zemini renkli bir Container; RadioListTile mürekkebini en yakın
      // Material'a boyadığı için kendi (saydam) Material'ı olmadan Flutter
      // "ink splashes may be invisible" assert'i atıyor.
      child: Material(
        type: MaterialType.transparency,
        child: Scrollbar(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              tile(null, 'Tüm deste'),
              if (topics.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Bu destede konu etiketli kart yok.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final topic in topics) ...[
                  Divider(height: 1, color: scheme.outlineVariant),
                  tile(topic, topic),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 5 / 10 / 20 — bitişik segment grubu.
class _QuestionCountPicker extends StatelessWidget {
  const _QuestionCountPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
            Icons.quiz_outlined,
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
            'Kendini Test Et, var olan kartların kısa cevaplarından şık üretir.',
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
