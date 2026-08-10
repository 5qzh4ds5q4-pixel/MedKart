import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_filter.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../services/file_transfer.dart';
import '../services/pdf_export_service.dart';
import '../state/flashcard_store.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/content_shell.dart';
import '../widgets/edit_card_dialog.dart';
import '../widgets/flashcard_tile.dart';
import '../widgets/horizontal_wheel_scroll.dart';
import '../widgets/page_range_filter_chip.dart';
import 'add_cards_screen.dart';
import 'study_screen.dart';

/// Liste başındaki özet kartının anahtarı — testler kartı bununla kapsamlar
/// (özetteki sayılar listedeki kart numaralarıyla çakışabildiği için düz
/// metin araması yetmiyor).
const ValueKey<String> cardListSummaryKey = ValueKey('card-list-summary');

/// Bir destenin kartları: filtrele / düzenle / sil / çalışmaya başla.
class CardListScreen extends StatefulWidget {
  const CardListScreen({super.key, required this.deckId});

  final String deckId;

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  CardFilter _filter = const CardFilter();
  bool _exportingPdf = false;

  Future<void> _editCard(BuildContext context, Flashcard card) async {
    await requireAuth(
      context,
      () async {
        final store = context.read<FlashcardStore>();
        final updated = await EditCardDialog.show(context, card);
        if (updated == null) return;

        store.updateCard(updated);
      },
      reason: 'Kartları düzenlemek için giriş yapman gerekiyor.',
    );
  }

  void _deleteCard(BuildContext context, Flashcard card) {
    final store = context.read<FlashcardStore>();
    final removedIndex = store.deleteCard(card.id);
    if (removedIndex == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Kart silindi.'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => store.restoreCard(removedIndex, card),
          ),
        ),
      );
  }

  void _addCards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddCardsScreen(deckId: widget.deckId)),
    );
  }

  void _startStudying(BuildContext context) {
    requireAuth(
      context,
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyScreen(
            deckId: widget.deckId,
            filter: _filter.isActive ? _filter : null,
          ),
        ),
      ),
      reason: 'Çalışmaya başlamak için giriş yap — ilerlemen kaydedilsin.',
    );
  }

  /// "Hocanın Favorilerini Çalış" hızlı pratik modu: yalnızca
  /// [Flashcard.isHandwritten] kartlar, due tarihi kısıtı olmadan (istenildiği
  /// an tekrar edilebilir ekstra pratik — bkz. [FlashcardStore.studyQueueFor]
  /// `ignoreDueDate`). Mevcut normal çalışma akışına dokunmaz, ayrı bir giriş.
  void _startHandwrittenPractice(BuildContext context) {
    requireAuth(
      context,
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyScreen(
            deckId: widget.deckId,
            filter: const CardFilter(handwrittenOnly: true),
            ignoreDueDate: true,
          ),
        ),
      ),
      reason: 'Çalışmaya başlamak için giriş yap — ilerlemen kaydedilsin.',
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Destenin TÜM kartlarını (öncelik/zorluk/kaynak fark etmeksizin, hiçbiri
  /// atlanmadan) PDF olarak indirir. JSON yedeğin yerini almaz, ona ek gelir.
  Future<void> _exportPdf(BuildContext context, Deck deck) async {
    await requireAuth(
      context,
      () async {
        if (!fileTransferSupported) {
          _snack(context, 'PDF indirme yalnızca web sürümünde çalışır.');
          return;
        }

        final store = context.read<FlashcardStore>();
        final allCards = store.cardsIn(widget.deckId);
        if (allCards.isEmpty) {
          _snack(context, 'İndirilecek kart yok.');
          return;
        }

        setState(() => _exportingPdf = true);
        try {
          final bytes = await PdfExportService.instance.buildPdf(
            deck: deck,
            allCards: allCards,
          );
          await downloadBytes(
            PdfExportService.instance.suggestedFileName(deck.name),
            bytes,
            mimeType: 'application/pdf',
          );
          if (context.mounted) {
            _snack(context, 'PDF indirildi (${allCards.length} kart).');
          }
        } catch (e) {
          if (context.mounted) _snack(context, 'PDF üretilemedi.');
        } finally {
          if (mounted) setState(() => _exportingPdf = false);
        }
      },
      reason: 'Dışa aktarmak için giriş yap.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FlashcardStore>();

    final deck = store.deckById(widget.deckId);
    // Deste silinmişse (ör. geri gelindiğinde) ekranı kapat.
    if (deck == null) return const Scaffold(body: SizedBox.shrink());

    final allCards = store.cardsIn(widget.deckId);
    final topics = store.topicsIn(widget.deckId);
    final cards = _filter.isActive ? _filter.apply(allCards) : allCards;
    // "Hocanın Favorilerini Çalış" butonu yalnızca anlamlı bir pratik oturumu
    // oluşturacak kadar (>=3) el yazısı kart varsa gösterilir.
    final handwrittenCount = allCards.where((c) => c.isHandwritten).length;

    // PDF'ten gelen kartların sayfa aralığı (sayfa filtresi için).
    int? loPage, hiPage;
    for (final c in allCards) {
      final p = c.sourcePage;
      if (p == null) continue;
      if (loPage == null || p < loPage) loPage = p;
      if (hiPage == null || p > hiPage) hiPage = p;
    }
    final (int, int)? pageBounds =
        (loPage != null && hiPage != null && hiPage > loPage)
        ? (loPage, hiPage)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(deck.name),
        actions: [
          IconButton(
            onPressed: _exportingPdf ? null : () => _exportPdf(context, deck),
            icon: _exportingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF Olarak İndir',
          ),
          IconButton(
            onPressed: () => _addCards(context),
            icon: const Icon(Icons.add),
            tooltip: 'Kart ekle',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        // `bottom: false` VERİLMEDİ — Scaffold, `bottomNavigationBar`
        // doluyken body'ye sızan MediaQuery alt boşluğunu zaten kendisi
        // sıfırlıyor (çifte boşluk riski yok); boş durumda (bottomNavigationBar
        // null) bu SafeArea'nın alt kenarı hâlâ gerekli.
        child: allCards.isEmpty
            ? _EmptyState(onAddCards: () => _addCards(context))
            : Column(
                children: [
                  _FilterBar(
                    filter: _filter,
                    topics: topics,
                    pageBounds: pageBounds,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                  if (handwrittenCount >= 3)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _HandwrittenPracticeBanner(
                        cardCount: handwrittenCount,
                        onTap: () => _startHandwrittenPractice(context),
                      ),
                    ),
                  Expanded(
                    child: cards.isEmpty
                        ? _NoMatchState(
                            onClear: () =>
                                setState(() => _filter = const CardFilter()),
                          )
                        : ContentShell(
                            padding: EdgeInsets.zero,
                            child: ResponsiveBuilder(
                              builder: (context, size) {
                                final horizontal =
                                    responsiveHorizontalPadding(size);

                                return ListView.separated(
                                  padding: EdgeInsets.fromLTRB(
                                    horizontal,
                                    16,
                                    horizontal,
                                    16,
                                  ),
                                  itemCount: cards.length + 1,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _SummaryCard(
                                        totalCards: allCards.length,
                                        filterOptionCount:
                                            CardDifficulty.values.length +
                                            topics.length,
                                        // Dağılım HER ZAMAN destenin tamamından:
                                        // filtre değiştikçe oynamayan sabit bir
                                        // referans olsun diye.
                                        allCards: allCards,
                                      );
                                    }

                                    final card = cards[index - 1];
                                    return FlashcardTile(
                                      card: card,
                                      index: index - 1,
                                      onEdit: () => _editCard(context, card),
                                      onDelete: () => _deleteCard(context, card),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
      // 2026-08-10: eskiden bu Column'un son çocuğuydu — dar/uzun içerikte
      // (ör. son kartın "Açıklamasını gör" açılması) listenin son öğesini
      // gizleme riski taşıyordu. Scaffold'un KENDİ `bottomNavigationBar`
      // katmanı içeriğin üzerine binmeyeceğini garanti eder (Scaffold body'ye
      // ayrılan yüksekliği bu alanı çıkararak hesaplar) — Positioned/Stack
      // yerine bu tercih edildi, aynı sonucu daha az karmaşıklıkla verir.
      bottomNavigationBar: allCards.isEmpty
          ? null
          : _StudyBar(
              dueCount: store.dueIn(widget.deckId, filter: _filter).length,
              filtered: _filter.isActive,
              enabled: cards.isNotEmpty,
              onPressed: () => _startStudying(context),
            ),
    );
  }

}

/// Liste başındaki özet kartı: "Kartların hazır" + üç istatistik bloğu.
///
/// [totalCards] ve seviye dağılımı DESTENİN TAMAMINDAN gelir — aktif filtre
/// bu kartı değiştirmez, sabit bir referans olarak durur. [filterOptionCount]
/// da seçili filtre sayısı değil, MEVCUT filtre seçeneği sayısıdır
/// (zorluk + konu).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCards,
    required this.filterOptionCount,
    required this.allCards,
  });

  final int totalCards;
  final int filterOptionCount;
  final List<Flashcard> allCards;

  /// Bu genişliğin altında istatistikler başlığın altına iner (tek sütun).
  static const double _wideLayoutMinWidth = 620;


  /// Destenin zorluk dağılımı: "Kolay 8 · Orta 32 · Zor 8".
  static String distributionLabel(List<Flashcard> cards) {
    final counts = <CardDifficulty, int>{};
    for (final card in cards) {
      counts[card.difficulty] = (counts[card.difficulty] ?? 0) + 1;
    }
    return [
      for (final d in CardDifficulty.values) '${d.label} ${counts[d] ?? 0}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final heading = Row(
      children: [
        const _ReadyBadge(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kartların hazır',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "PDF'lerden oluşturulan kartlar çalışmaya hazır.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final stats = [
      _Stat(
        icon: Icons.style_outlined,
        label: 'Toplam kart',
        value: '$totalCards',
      ),
      _Stat(
        icon: Icons.filter_list,
        label: 'Seçili filtreler',
        value: '$filterOptionCount',
      ),
      _Stat(
        icon: Icons.donut_small_outlined,
        label: 'Seviye dağılımı',
        value: distributionLabel(allCards),
        emphasizeValue: false,
      ),
    ];

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: cardListSummaryKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Border YOK, bilinçli: dashboard tasarım sistemiyle tutarlı olsun
        // diye — bkz. `AppTheme` dashboard token'ları. Koyu modda karşılığı
        // olan `AppTheme.dashboardSurface` (beyaz) tanımsız olduğu için en
        // yakın MEVCUT koyu yüzey token'ı (`heroSurface`) kullanılıyor; yeni
        // bir renk TANIMLANMADI.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _wideLayoutMinWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 20),
                Wrap(spacing: 24, runSpacing: 16, children: stats),
              ],
            );
          }

          // Hem başlık hem istatistikler ESNEK: `ContentShell` içeriği 760px
          // ile sınırladığı için sabit genişliklerde satır taşıyordu. Yer
          // daralınca metinler alt satıra iner, taşma olmaz.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: heading),
              for (final stat in stats) ...[
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: scheme.outlineVariant,
                ),
                Expanded(flex: 3, child: stat),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Çerçeveli daire + belge ikonu, köşesinde onay rozeti. Vurgu rengi BİLİNÇLİ
/// olarak `scheme.primary` (uygulama markasının amberi) DEĞİL, dashboard
/// tasarım sisteminin mor vurgusu (`AppTheme.dashboardVioletDeep`) — bu
/// ekranın diğer dashboard öğeleriyle (gradyan banner, filtre pilleri) aynı
/// vurgu ailesinde kalsın diye.
class _ReadyBadge extends StatelessWidget {
  const _ReadyBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringSurface = isDark ? AppTheme.heroSurface : AppTheme.dashboardSurface;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.dashboardVioletDeep, width: 2),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 26,
              color: AppTheme.dashboardVioletDeep,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.dashboardVioletDeep,
                shape: BoxShape.circle,
                // Daire kenarlığıyla çakışmasın diye kart zemini kadar halka.
                border: Border.all(color: ringSurface, width: 2),
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Özet kartındaki tek bir istatistik bloğu: ikon + etiket, altında değer.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasizeValue = true,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Sayısal değerler büyük/kalın; dağılım gibi uzun metinler normal.
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            // Dar sütunda etiket alt satıra insin, satırı taşırmasın.
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: emphasizeValue
              ? theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Üstteki filtre çubuğu: zorluk + konu çoklu seçimi (yatay kaydırılır).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.topics,
    required this.pageBounds,
    required this.onChanged,
  });

  final CardFilter filter;
  final List<String> topics;

  /// PDF'ten gelen kartların (min, max) sayfa sınırı; yoksa null (çip gizlenir).
  final (int, int)? pageBounds;
  final ValueChanged<CardFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: HorizontalWheelScroll(
        // Çipler ekrana sığmadığında kullanıcı kaydırabileceğini görsün.
        showScrollbar: true,
        // Alt boşluk kaydırma çubuğuna yer açar (çiplerin üstüne binmesin).
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Row(
          children: [
            // Görseldeki gibi kenarlıklı kare içinde: çubuğun ne olduğunu
            // anlatan bir işaret (tıklanabilir bir eylem DEĞİL — filtreyi
            // temizleme işi "Temizle" çipinde).
            _FilterBadge(active: filter.isActive),
            const SizedBox(width: 8),
            for (final d in CardDifficulty.values) ...[
              _chip(
                context: context,
                label: d.label,
                selected: filter.difficulties.contains(d),
                onSelected: (v) => onChanged(filter.withDifficulty(d, v)),
              ),
              const SizedBox(width: 6),
            ],
            for (final t in topics) ...[
              _chip(
                context: context,
                label: t,
                selected: filter.topics.contains(t),
                onSelected: (v) => onChanged(filter.withTopic(t, v)),
              ),
              const SizedBox(width: 6),
            ],
            if (pageBounds != null) ...[
              PageRangeFilterChip(
                filter: filter,
                bounds: pageBounds!,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
            ],
            if (filter.isActive)
              ActionChip(
                avatar: const Icon(Icons.close, size: 16),
                label: const Text('Temizle'),
                onPressed: () => onChanged(const CardFilter()),
              ),
          ],
        ),
      ),
    );
  }

  /// Zorluk/konu pili — border YOK, `dashboardSurfaceElevated` zemin (bkz.
  /// görev tanımı). Koyu modda `AppTheme.dashboardSurfaceElevated` (açık mod
  /// token'ı) yerine en yakın MEVCUT koyu "elevated" yüzeyi (`heroNeutralFill`)
  /// kullanılıyor — yeni bir renk TANIMLANMADI, hepsi `AppTheme`'de zaten var.
  Widget _chip({
    required BuildContext context,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide.none,
      backgroundColor: unselectedBg,
      selectedColor: selectedBg,
      labelStyle: TextStyle(
        color: selected ? selectedFg : unselectedFg,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

/// Filtre çubuğunun solundaki kenarlıklı kare işaret. Filtre etkinken amber.
class _FilterBadge extends StatelessWidget {
  const _FilterBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Icon(
        Icons.filter_list,
        size: 18,
        color: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

/// Listenin altında sabit duran çalışma butonu.
///
/// Buton her zaman aktiftir: tekrar zamanı gelmemiş olsa bile kullanıcı
/// istediğinde çalışabilir. [dueCount] yalnızca kaç kartın tekrara hazır
/// olduğunu belirtir.
class _StudyBar extends StatelessWidget {
  const _StudyBar({
    required this.dueCount,
    required this.filtered,
    required this.enabled,
    required this.onPressed,
  });

  final int dueCount;
  final bool filtered;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = filtered
        ? (dueCount > 0 ? 'Filtreyle Çalış ($dueCount)' : 'Filtreyle Çalış')
        : (dueCount > 0 ? 'Çalışmaya Başla ($dueCount)' : 'Çalışmaya Başla');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ContentShell(
          // `bottomNavigationBar` slotu Scaffold'dan "gövde kadar yüksek
          // olabilirsin" izni alır; shrinkWrapHeight olmadan ContentShell bu
          // izni sonuna kadar kullanıp TÜM ekranı kaplar, gövdeye 0 yükseklik
          // kalır (bkz. content_shell.dart doc yorumu — buradaki gerçek
          // regresyonun kök nedeniydi).
          shrinkWrapHeight: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ResponsiveBuilder(
            builder: (context, size) => SizedBox(
              width: responsiveButtonWidth(size),
              child: FilledButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Hocanın Favorilerini Çalış" hızlı pratik moduna giriş — yalnızca destede
/// en az 3 el yazısı kart varken gösterilir (bkz. `_CardListScreenState.
/// _startHandwrittenPractice`). 2026-08-10: artık amber `primaryContainer`
/// DEĞİL, dashboard'un mor→pembe CTA gradyanı (`AppTheme.dashboardCtaGradient`
/// — dashboard'daki "Çalışmaya Başla" butonuyla AYNI, zaten mevcut token) —
/// iki modda da aynı, opak bir gradyan olduğu için ayrıca light/dark dalı
/// gerekmiyor.
class _HandwrittenPracticeBanner extends StatelessWidget {
  const _HandwrittenPracticeBanner({
    required this.cardCount,
    required this.onTap,
  });

  final int cardCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.dashboardCtaGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hocanın Favorilerini Çalış',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$cardCount kart',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtre sonucu boş olduğunda gösterilir.
class _NoMatchState extends StatelessWidget {
  const _NoMatchState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentShell(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('Bu filtreyle kart yok', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Seçtiğin zorluk ve konu birlikte hiçbir karta uymuyor.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Filtreyi temizle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddCards});

  final VoidCallback onAddCards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentShell(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.style_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('Bu deste boş', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Ders notunu yapıştır, yapay zekâ kartları üretsin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddCards,
              icon: const Icon(Icons.add),
              label: const Text('Kart Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
