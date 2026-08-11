import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../services/mcq_generator.dart';
import '../state/flashcard_store.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/app_shell.dart';
import '../widgets/content_shell.dart';
import 'mcq_quiz_screen.dart';

const List<int> _questionCountOptions = [5, 10, 20];
const int _defaultQuestionCount = 10;

/// "Kendini Test Et" (MCQ) kapsam/soru sayısı seçim ekranı.
///
/// Yalnızca havuzu kurup [McqGenerator.generate]'ı senkron çağırır — hiç AI
/// çağrısı yapılmaz. Üretilen soru listesi yeterliyse [McqQuizScreen]'e geçilir.
///
/// Kapsam TEKLİ seçimdir: "Tüm deste" ya da tam olarak bir konu. (Deneme
/// Sınavı'ndaki çoklu konu + sayfa aralığı kapsamıyla karıştırılmamalı —
/// bkz. `ExamSimSetupScreen`.)
///
/// 2026-08-11: "kendini test et ekranı.png" mockup'ına göre yeniden çizildi —
/// artık deste listesindeki AYNI sol `SideNavBar`'ı gösteriyor (eskiden bu
/// ekran AppBar'lı, sidebar'sız tek sütundu) ve renkler amber'dan mor→pembe
/// dashboard paletine döndü. İş mantığı (`_onDeckChanged`, `_onScopeChanged`,
/// `_start`, `McqGenerator.generate` çağrısı, `requireAuth`) HİÇ değişmedi.
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
        final allowed = deckId == null
            ? const <String>[]
            : store.topicsIn(deckId);
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
    requireAuth(context, () {
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
        MaterialPageRoute(builder: (_) => McqQuizScreen(questions: questions)),
      );
    }, reason: 'Kendini test etmek için giriş yap.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();
    final decks = store.decks;
    final theme = Theme.of(context);

    return AppShell(
      active: SideNavItem.quiz,
      topBar: const AppShellTopBar(title: 'Kendini Test Et'),
      body: decks.isEmpty
          ? _EmptyState(theme: theme)
          : ContentShell(
              maxWidth: AppTheme.dashboardMaxWidth,
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: ResponsiveBuilder(
                  builder: (context, size) {
                    const branding = _BrandPanel();
                    final form = _SetupForm(
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
                      error: _error,
                      onStart: _deckId == null ? null : () => _start(context),
                    );

                    if (size.isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 320, child: branding),
                          const SizedBox(width: AppTheme.space32),
                          Expanded(child: form),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        branding,
                        const SizedBox(height: AppTheme.space24),
                        form,
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }
}

/// Sol markalama paneli — ikon + iki renkli başlık + açıklama + 3 özellik
/// satırı. Tamamen statik (mockup'tan birebir metin), tek dinamik nokta ikon
/// rengi: BİLİNÇLİ olarak mor (`AppTheme.dashboardVioletDeep`), eski amber
/// `scheme.primary` DEĞİL — görev tanımının "sadece ikon rengi violet olsun"
/// maddesi.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final muted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.dashboardVioletDeep, width: 2),
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            size: 30,
            color: AppTheme.dashboardVioletDeep,
          ),
        ),
        const SizedBox(height: AppTheme.space24),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Çoktan seçmeli\n',
                style: TextStyle(color: fg),
              ),
              const TextSpan(
                text: 'pratik',
                style: TextStyle(color: AppTheme.dashboardViolet),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.dashboardVioletDeep,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Text(
          'Hedefine yönelik sorularla bilgini ölç, eksiklerini keşfet ve '
          'gelişimini takip et.',
          style: TextStyle(fontSize: 14, color: muted, height: 1.5),
        ),
        const SizedBox(height: AppTheme.space24),
        const _FeatureRow(
          icon: Icons.track_changes_outlined,
          title: 'Odaklanmış çalışma',
          subtitle: 'Konulara göre filtrele ve ihtiyacın olan alana yoğunlaş.',
        ),
        const SizedBox(height: AppTheme.space16),
        const _FeatureRow(
          icon: Icons.bar_chart_rounded,
          title: 'Anında geri bildirim',
          subtitle: 'Sonuçlarını anında gör, eksiklerini hemen fark et.',
        ),
        const SizedBox(height: AppTheme.space16),
        const _FeatureRow(
          icon: Icons.emoji_events_outlined,
          title: 'Gelişimini takip et',
          subtitle: 'Düzenli pratikle ilerlemeni ölç ve hedeflerini aş.',
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final muted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.dashboardVioletDeep.withValues(
              alpha: isDark ? 0.22 : 0.12,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppTheme.dashboardVioletDeep),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Deste + kapsam + soru sayısını numaralı adımlarla toplayan kurulum kartı
/// + hata mesajı + "Başla" butonu. Kart border YOK, yalnızca yumuşak gölge —
/// dashboard tasarım sistemiyle tutarlı (bkz. `card_list_screen.dart`'taki
/// `_DashCard`/`_SummaryCard` ile AYNI desen).
class _SetupForm extends StatelessWidget {
  const _SetupForm({
    required this.decks,
    required this.deckId,
    required this.onDeckChanged,
    required this.topics,
    required this.selectedTopic,
    required this.onScopeChanged,
    required this.questionCount,
    required this.onQuestionCountChanged,
    required this.error,
    required this.onStart,
  });

  final List<Deck> decks;
  final String? deckId;
  final ValueChanged<String?> onDeckChanged;
  final List<String> topics;
  final String? selectedTopic;
  final ValueChanged<String?> onScopeChanged;
  final int questionCount;
  final ValueChanged<int> onQuestionCountChanged;
  final String? error;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepHeader(context, step: 1, title: 'Deste Seç'),
              const SizedBox(height: AppTheme.space12),
              _DeckDropdown(
                decks: decks,
                value: deckId,
                onChanged: onDeckChanged,
              ),
              const SizedBox(height: AppTheme.space24),
              _stepHeader(
                context,
                step: 2,
                title: 'Kapsam',
                subtitle: 'Hangi konulardan soru çözmek istediğini seç.',
              ),
              const SizedBox(height: AppTheme.space12),
              _ScopePicker(
                topics: topics,
                selectedTopic: selectedTopic,
                onChanged: onScopeChanged,
              ),
              const SizedBox(height: AppTheme.space24),
              _stepHeader(
                context,
                step: 3,
                title: 'Soru Sayısı',
                subtitle: 'Çözmek istediğin soru sayısını belirle.',
              ),
              const SizedBox(height: AppTheme.space12),
              _QuestionCountPicker(
                value: questionCount,
                onChanged: onQuestionCountChanged,
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppTheme.space16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTheme.space24),
        _GradientStartButton(onTap: onStart),
        const SizedBox(height: AppTheme.space16),
      ],
    );
  }

  /// Adım başlığı: numara rozeti + kalın başlık, altında opsiyonel açıklama.
  Widget _stepHeader(
    BuildContext context, {
    required int step,
    required String title,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final muted = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final badgeBg = AppTheme.dashboardVioletDeep.withValues(
      alpha: isDark ? 0.22 : 0.14,
    );
    final badgeFg = isDark
        ? AppTheme.dashboardViolet
        : AppTheme.dashboardVioletDeep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$step',
                style: TextStyle(
                  color: badgeFg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(subtitle, style: TextStyle(fontSize: 13, color: muted)),
          ),
        ],
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final outline = isDark
        ? AppTheme.heroBorder
        : AppTheme.dashboardSubtleBorder;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: outline),
    );

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Seçili deste',
        prefixIcon: const Icon(
          Icons.layers_outlined,
          color: AppTheme.dashboardVioletDeep,
        ),
        filled: true,
        fillColor: fill,
        border: border,
        enabledBorder: border,
        // Violet "glow": odaklanınca kenarlık kalınlaşıp mora dönüyor —
        // amber `scheme.primary` odak rengi yerine.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.dashboardVioletDeep,
            width: 2,
          ),
        ),
      ),
      items: [
        for (final deck in decks)
          DropdownMenuItem(value: deck.id, child: Text(deck.name)),
      ],
      onChanged: onChanged,
    );
  }
}

/// "Tüm deste" veya belirli bir konu — TEKLİ seçim (radyo), 2 sütunlu ızgara.
/// Her seçenek kendi kenarlıklı kutusunda (mockup'taki gibi); seçili olan
/// mor kenarlık alır. Eskiden tek sütun + sabit yükseklikte kaydırılan bir
/// liste kutusuydu (`_scopeListMaxHeight`) — mockup'ta öyle değil, o kutu
/// KALDIRILDI: sayfa zaten `SingleChildScrollView` içinde, uzun konu
/// listesinde ekran uzar, bu kabul edilebilir bir davranış değişikliği.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tile(String? value, String label) {
      final selected = value == selectedTopic;
      final bg = isDark
          ? AppTheme.heroNeutralFill
          : AppTheme.dashboardSurfaceElevated;
      final fg = isDark
          ? AppTheme.textPrimaryDark
          : AppTheme.dashboardTextPrimary;
      final borderColor = selected
          ? AppTheme.dashboardVioletDeep
          : (isDark ? AppTheme.heroBorder : AppTheme.dashboardSubtleBorder);

      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        // Kart zemini renkli bir Container; RadioListTile mürekkebini en yakın
        // Material'a boyadığı için kendi (saydam) Material'ı olmadan Flutter
        // "ink splashes may be invisible" assert'i atıyor.
        child: Material(
          type: MaterialType.transparency,
          child: RadioListTile<String?>(
            title: Text(label, style: TextStyle(color: fg, fontSize: 14)),
            value: value,
            groupValue: selectedTopic,
            onChanged: onChanged,
            activeColor: AppTheme.dashboardVioletDeep,
            dense: true,
            visualDensity: VisualDensity.compact,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: tileWidth, child: tile(null, 'Tüm deste')),
            for (final topic in topics)
              SizedBox(width: tileWidth, child: tile(topic, topic)),
          ],
        );
      },
    );
  }
}

/// 5 / 10 / 20 — bağımsız pil grubu. Eskiden bitişik `SegmentedButton`'dı
/// (hâlâ `ChoiceChip` — testler `.selected` property'sini okuyabiliyor),
/// ama `SegmentedButton`'ın `ButtonStyle`'ı GRADYAN zemin desteklemiyor
/// (`backgroundColor` yalnızca düz `Color` kabul ediyor) — görev tanımı
/// seçili pilin gerçek mor→pembe gradyan olmasını istediği için ayrık
/// `ChoiceChip` pillerine geçildi (her biri `card_list_screen.dart`'taki
/// gradyan-sarma deseniyle AYNI: iç chip saydam, dıştaki `Container`
/// gradyanı veriyor).
class _QuestionCountPicker extends StatelessWidget {
  const _QuestionCountPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final count in _questionCountOptions)
          _pill(count: count, selected: value == count, isDark: isDark),
      ],
    );
  }

  Widget _pill({
    required int count,
    required bool selected,
    required bool isDark,
  }) {
    final label = Text('$count');
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const padding = EdgeInsets.symmetric(horizontal: 22, vertical: 12);

    if (selected) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppTheme.dashboardCtaGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ChoiceChip(
          label: label,
          selected: true,
          showCheckmark: false,
          onSelected: (_) => onChanged(count),
          backgroundColor: Colors.transparent,
          selectedColor: Colors.transparent,
          side: BorderSide.none,
          shape: shape,
          padding: padding,
          labelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      );
    }

    final bg = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final fg = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    return ChoiceChip(
      label: label,
      selected: false,
      showCheckmark: false,
      onSelected: (_) => onChanged(count),
      backgroundColor: bg,
      side: BorderSide.none,
      shape: shape,
      padding: padding,
      labelStyle: TextStyle(
        color: fg,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );
  }
}

/// "Başla" — diğer CTA'larla (`ExamSimSetupScreen`'deki "Sınavı Başlat",
/// `CardListScreen`'deki "Çalışmaya Başla") AYNI mor→pembe gradyan, AYNI
/// desen: gerçek bir `FilledButton` saydam zeminle gradyan `Container`'a
/// sarılı (testler `.onPressed`/metin üzerinden davranışı hâlâ okuyabiliyor).
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

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          label: const Text('Başla'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
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
