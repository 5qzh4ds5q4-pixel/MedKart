import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../screens/card_list_screen.dart';
import '../state/flashcard_store.dart';
import '../theme/app_theme.dart';
import '../utils/require_auth.dart';
import 'deck_name_dialog.dart';

/// Bir deste üzerinde yapılabilecek işlemler (kart/satır menüsü).
///
/// 2026-08-17'de `deck_list_screen.dart`'ın private `_DeckAction` enum'undan
/// ÇIKARILDI: aynı menü orada İKİ kez (koyu ve açık deste kartı) birebir
/// kopyalanmıştı ve yeni "Destelerim" listesi üçüncü bir kopya gerektirecekti.
enum DeckAction { rename, delete, setExamDate, clearExamDate }

/// Deste kartlarının/satırlarının sağındaki "..." menüsü — TEK tanım.
///
/// Yalnızca hangi eylemin seçildiğini bildirir; işin kendisi çağıranın verdiği
/// callback'lerde (pratikte hepsi [DeckActions]'a gider). Menü İÇERİĞİ
/// (öğeler, sıralama, "Sınav tarihi belirle"/"değiştir" ayrımı) burada tek
/// yerde — üç çağıran da otomatik aynı kalır.
class DeckActionMenu extends StatelessWidget {
  const DeckActionMenu({
    super.key,
    required this.deck,
    required this.iconColor,
    required this.onRename,
    required this.onDelete,
    required this.onSetExamDate,
    required this.onClearExamDate,
  });

  final Deck deck;

  /// "..." ikonunun rengi — koyu/açık kart ve liste satırı arasındaki TEK
  /// görsel fark buydu, o yüzden parametre olarak dışarıda bırakıldı.
  final Color iconColor;

  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetExamDate;
  final VoidCallback onClearExamDate;

  @override
  Widget build(BuildContext context) {
    final examDate = deck.examDate;

    return PopupMenuButton<DeckAction>(
      tooltip: 'Deste işlemleri',
      icon: Icon(Icons.more_vert, size: 18, color: iconColor),
      padding: EdgeInsets.zero,
      iconSize: 18,
      onSelected: (action) => switch (action) {
        DeckAction.rename => onRename(),
        DeckAction.delete => onDelete(),
        DeckAction.setExamDate => onSetExamDate(),
        DeckAction.clearExamDate => onClearExamDate(),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: DeckAction.rename,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Yeniden adlandır'),
          ),
        ),
        PopupMenuItem(
          value: DeckAction.setExamDate,
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
            value: DeckAction.clearExamDate,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event_busy_outlined),
              title: Text('Sınav tarihini kaldır'),
            ),
          ),
        const PopupMenuItem(
          value: DeckAction.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('Sil'),
          ),
        ),
      ],
    );
  }
}

/// Deste eylemlerinin GERÇEK işleri (dialog + store çağrısı + navigasyon).
///
/// 2026-08-17'de `DeckListScreen`'in private metotlarından ÇIKARILDI — yeni
/// "Destelerim" ekranı (`DeckLibraryScreen`) aynı eylemleri sunuyor ve
/// özellikle silme onayının metni/eşiği iki ekranda ayrışmasın diye tek yerde
/// tutuluyor. Davranış taşınırken HİÇ değişmedi.
class DeckActions {
  const DeckActions._();

  /// Yeni deste oluşturur ve doğrudan içine girer. Giriş kapısına TABİ
  /// (bkz. CLAUDE.md "Zorunlu Login / Faz 3").
  static Future<void> create(BuildContext context) async {
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

  static Future<void> rename(BuildContext context, Deck deck) async {
    final name = await DeckNameDialog.show(context, initialName: deck.name);
    if (name == null || !context.mounted) return;

    context.read<FlashcardStore>().renameDeck(deck.id, name);
  }

  /// Deste için sınav tarihi seçtirir; bugünden önce seçilemez.
  static Future<void> editExamDate(BuildContext context, Deck deck) async {
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

  static void clearExamDate(BuildContext context, Deck deck) {
    context.read<FlashcardStore>().setDeckExamDate(deck.id, null);
  }

  static Future<void> delete(BuildContext context, Deck deck) async {
    final store = context.read<FlashcardStore>();
    final cardCount = store.cardsIn(deck.id).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('"${deck.name}" silinsin mi?'),
        content: Text(
          cardCount == 0
              ? 'Bu deste boş.'
              : 'Destedeki $cardCount kart ve tüm çalışma ilerlemen kalıcı '
                    'olarak silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    store.deleteDeck(deck.id);
  }
}

/// Sınav tarihinin kart/satırlarda gösterilen biçimi (gg.aa.yyyy).
/// `deck_list_screen.dart`'ın private `_formatExamDate`'inden taşındı.
String formatExamDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Deste satır/kartlarının paylaştığı meta cümlesi ("12 kart · 3 tekrara
/// hazır"). Metin BİLİNÇLİ olarak `_LightDeckCard._metaLine` ile birebir aynı
/// — mevcut testler bu ifadeleri arıyor, yeni bir formülasyon icat edilmedi.
String deckMetaLine({required int cardCount, required int dueCount}) {
  if (cardCount == 0) return 'Boş deste';
  if (dueCount == 0) return '$cardCount kart · bugünlük tamam';
  return '$cardCount kart · $dueCount tekrara hazır';
}

/// Deste satır/kartlarında ilerleme çubuğunun zemin (dolmamış) rengi.
Color deckProgressTrackColor(bool isDark) =>
    isDark ? AppTheme.heroNeutralFill : AppTheme.dashboardSurfaceElevated;
