import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pdf_page.dart';
import '../services/file_transfer.dart';
import '../services/flashcard_generator.dart';
import '../services/pdf_cache_service.dart';
import '../services/pdf_text.dart';
import '../state/flashcard_store.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/content_shell.dart';
import 'pdf_import_screen.dart';
import 'pdf_topic_selection_screen.dart';

const String _pdfUploadReason =
    'Kart üretmek için giriş yapman gerekiyor — kartların ve çalışma '
    'ilerlemen hesabında güvende kalır.';

/// Bir desteye ders notu yapıştırıp ve/veya görsel/PDF ekleyip kart üretme ekranı.
class AddCardsScreen extends StatefulWidget {
  const AddCardsScreen({super.key, required this.deckId});

  final String deckId;

  @override
  State<AddCardsScreen> createState() => _AddCardsScreenState();
}

class _AddCardsScreenState extends State<AddCardsScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<MediaAttachment> _media = [];
  final PdfCacheService _pdfCache = PdfCacheService();
  bool _extractingPdf = false;

  /// "Bu notta el yazısı/işaretleme var mı?" — varsayılan Evet (güvenli
  /// taraf): kullanıcı açıkça "Hayır" demedikçe vision (görsel) pipeline'ı
  /// aynen çalışmaya devam eder. "Hayır" seçilirse sayfa görüntüsü hiç
  /// render edilmez/gönderilmez, yalnızca pdf.js metni gider (bkz.
  /// [_runPdfPipeline], `web/pdf_extract.js`).
  bool _hasHandwriting = true;

  @override
  void initState() {
    super.initState();
    // Buton durumu ve karakter sayacı metne bağlı; her değişimde tazele.
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  /// Görsel/PDF ekleme: görseller medya listesine eklenir (Yol B — genel
  /// prompt); PDF'ler ise medyaya HİÇ eklenmez, sayfa-bazlı otomatik
  /// pipeline'a (Yol A) yönlendirilir. PDF için tek giriş noktası bu —
  /// Yol B'nin tek-istek modu sourcePage damgalayamaz ve kapsamı zayıf
  /// (5 sayfa PDF'te tüm doküman için "5-15 kart" tavanına çarpar).
  Future<void> _addMedia() async {
    if (!fileTransferSupported) {
      _showError('Görsel/PDF ekleme yalnızca web sürümünde çalışır.');
      return;
    }

    List<({Uint8List bytes, String mimeType, String name})> picked;
    try {
      picked = await pickMediaFiles();
    } catch (e) {
      _showError('Dosya seçilemedi.');
      return;
    }
    if (picked.isEmpty || !mounted) return;

    final pdfs = picked.where((f) => f.mimeType == 'application/pdf').toList();
    final images = picked.where((f) => f.mimeType != 'application/pdf').toList();

    if (images.isNotEmpty) {
      setState(() {
        for (final f in images) {
          _media.add(
            MediaAttachment(bytes: f.bytes, mimeType: f.mimeType, name: f.name),
          );
        }
      });
    }

    if (pdfs.isEmpty) return;

    await requireAuth(
      context,
      () async {
        if (pdfs.length > 1) {
          _showError(
            'Aynı anda yalnızca 1 PDF işlenebilir. İlk PDF (${pdfs.first.name}) '
            'işleniyor; diğerlerini ayrı ayrı ekle.',
          );
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '"${pdfs.first.name}" otomatik sayfa-sayfa kart üretimine '
                'yönlendiriliyor…',
              ),
            ),
          );
        await _runPdfPipeline(pdfs.first.bytes, pdfs.first.name);
      },
      reason: _pdfUploadReason,
    );
  }

  void _removeMedia(int index) => setState(() => _media.removeAt(index));

  /// Otomatik PDF akışı: PDF seç → sayfa metnini çıkar → uyar → pipeline ekranı.
  Future<void> _importPdf() async {
    if (!fileTransferSupported || !pdfSupported) {
      _showError('Otomatik PDF işleme yalnızca web sürümünde çalışır.');
      return;
    }

    await requireAuth(
      context,
      () async {
        final ({Uint8List bytes, String name})? picked;
        try {
          picked = await pickPdfFile();
        } catch (e) {
          _showError('PDF seçilemedi.');
          return;
        }
        if (picked == null || !mounted) return;

        await _runPdfPipeline(picked.bytes, picked.name);
      },
      reason: _pdfUploadReason,
    );
  }

  /// PDF baytlarından sayfa metni çıkarıp pipeline ekranına geçer. Hem
  /// [_importPdf] (özel buton) hem [_addMedia] (genel "Görsel/PDF ekle"
  /// üzerinden PDF seçildiğinde) tarafından paylaşılır.
  ///
  /// Önce dosyanın SHA-256 hash'i (içerik bazlı, ad bağımsız) paylaşılan
  /// önbellekte aranır — bulunursa Gemini'a HİÇ gidilmeden (pdf.js
  /// çıkarımı/konu seçimi bile atlanarak) kartlar anında eklenir. Önbellek
  /// yalnızca TÜM PDF (sayfa aralığı/konu ile daraltılmamış) işlendiğinde
  /// geçerlidir — kullanıcı alt küme seçerse bu çalışma ne önbellekten okur
  /// ne de yazar (bilinçli kapsam sınırı, bkz. CLAUDE.md/proje notları).
  Future<void> _runPdfPipeline(Uint8List bytes, String name) async {
    if (!pdfSupported) {
      _showError('Otomatik PDF işleme yalnızca web sürümünde çalışır.');
      return;
    }

    // includeImages anahtarın PARÇASI: görsel kapalı işleme, görsel açık
    // işlemeden ayrı bir cache rafı kullanır (bkz. PdfCacheService.hashBytes)
    // — görselsiz üretilmiş zayıf sonuç, görsel isteyen kullanıcıya sessizce
    // servis edilmesin. Aynı hash aşağıda save tarafına da (pdfHash) gider.
    final hash = PdfCacheService.hashBytes(bytes, includeImages: _hasHandwriting);
    final cached = await _pdfCache.lookup(hash);
    if (cached != null && cached.cards.isNotEmpty) {
      if (!mounted) return;
      context.read<FlashcardStore>().addCards(widget.deckId, cached.cards);
      _showCacheHitFeedback(cached.hitCount);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _extractingPdf = true);
    List<PdfPage> pages;
    try {
      pages = await extractPdfPages(bytes, includeImages: _hasHandwriting);
    } catch (e) {
      if (mounted) {
        _showError('PDF okunamadı. Dosya bozuk olabilir veya internet gerekli.');
      }
      return;
    } finally {
      if (mounted) setState(() => _extractingPdf = false);
    }
    if (!mounted) return;

    if (pages.isEmpty) {
      _showError('PDF\'ten sayfa çıkarılamadı.');
      return;
    }

    // Hangi sayfaların işleneceğini kullanıcı seçer (konuya göre ya da
    // sayfa aralığına göre); konu taraması yalnızca kullanıcı o sekmede
    // açıkça isterse çalışır (bkz. PdfTopicSelectionScreen).
    final selected = await Navigator.of(context).push<List<PdfPage>>(
      MaterialPageRoute(
        builder: (_) => PdfTopicSelectionScreen(pages: pages),
      ),
    );
    if (selected == null || !mounted) return;

    // Yalnızca TÜM PDF işlendiyse (daraltma yoksa) sonucu önbelleğe yazmaya
    // aday — bkz. yukarıdaki doc yorumu.
    final isFullPdf = selected.length == pages.length;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfImportScreen(
          deckId: widget.deckId,
          pages: selected,
          pdfHash: isFullPdf ? hash : null,
        ),
      ),
    );
    // Kartlar eklendi; destenin listesine dön.
    if (mounted) Navigator.of(context).pop();
  }

  /// Cache HIT olduğunda gösterilen olumlu/motive edici geri bildirim.
  /// Bilinçli olarak "önbellek" gibi teknik kelime kullanmaz — kullanıcıya
  /// hız/kolaylık hissi verir. [hitCount] `>= 10` ise kaç kez çalışıldığını
  /// da ekler; daha küçük/bilinmeyen (`null`, RPC artırımı başarısız oldu)
  /// değerlerde sayı hiç gösterilmez.
  void _showCacheHitFeedback(int? hitCount) {
    final theme = Theme.of(context);
    final message = (hitCount != null && hitCount >= 10)
        ? '⚡ Bu set daha önce işlenmiş — anında hazır! ($hitCount kez çalışıldı)'
        : '⚡ Bu set daha önce işlenmiş — anında hazır!';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
  }

  Future<void> _generate() async {
    final store = context.read<FlashcardStore>();
    FocusScope.of(context).unfocus();

    final createdCount = await store.generateInto(
      widget.deckId,
      _controller.text,
      media: _media,
    );
    if (!mounted) return;

    if (createdCount == null) {
      _showError(store.errorMessage ?? 'Kartlar üretilemedi.');
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$createdCount kart üretildi.')));

    // Kartlar destenin listesinde görünsün.
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          showCloseIcon: true,
          closeIconColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<FlashcardStore>();
    final isBusy = store.isGenerating;
    final hasInput = _controller.text.trim().isNotEmpty || _media.isNotEmpty;
    final deckName = store.deckById(widget.deckId)?.name ?? 'Deste';

    return Scaffold(
      appBar: AppBar(title: const Text('Kart Ekle')),
      body: SafeArea(
        child: ContentShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ders notu ve/veya slayt ekle',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Kartlar "$deckName" destesine eklenecek.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // El yazısı/işaretleme sorusu: "Hayır" seçilirse sayfa
              // görüntüsü hiç render edilmez/gönderilmez (yalnızca metin) —
              // daha hızlı ve ucuz. Varsayılan Evet (güvenli taraf).
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bu notta el yazısı/işaretleme var mı?'),
                subtitle: Text(
                  _hasHandwriting
                      ? 'Evet — sayfa görüntüsü de gönderilir (el yazısı/'
                            'highlight yakalanır, biraz daha yavaş/maliyetli).'
                      : 'Hayır — yalnızca metin gönderilir (daha hızlı, '
                            'görsel işaretler kaçabilir).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _hasHandwriting,
                onChanged: (isBusy || _extractingPdf)
                    ? null
                    : (value) => setState(() => _hasHandwriting = value),
              ),
              const SizedBox(height: 12),

              // Büyük PDF → otomatik, sayfa sayfa kart üretimi.
              // Mobilde tam genişlik, masaüstünde içerik genişliğinde.
              ResponsiveBuilder(
                builder: (context, size) => Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: responsiveButtonWidth(size),
                    child: FilledButton.tonalIcon(
                      onPressed: (isBusy || _extractingPdf) ? null : _importPdf,
                      icon: _extractingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _extractingPdf
                            ? 'PDF okunuyor…'
                            : 'Ders PDF\'i yükle (otomatik)',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Büyük PDF\'i (ör. 100+ sayfa) seç; her sayfadan otomatik kart '
                'üretilir. Başka bir şey yapman gerekmez.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const _OrDivider(),

              _MediaSection(
                media: _media,
                enabled: !isBusy && !_extractingPdf,
                onAdd: _addMedia,
                onRemove: _removeMedia,
              ),
              const SizedBox(height: 16),

              // Expanded: klavye açıldığında alan küçülür, TextField kendi
              // içinde kaydırılabilir kalır — taşma olmaz.
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !isBusy,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: _media.isEmpty
                        ? 'Örneğin: "Kalp, dört odacıklı bir kas organdır. '
                              'Sağ atriyum vena cava superior ve inferior yoluyla '
                              'sistemik dolaşımdan gelen kanı alır..."'
                        : 'İstersen slayta ek olarak buraya not da yazabilirsin '
                              '(zorunlu değil).',
                  ),
                ),
              ),
              const SizedBox(height: 10),

              _CharacterCounter(
                length: _controller.text.trim().length,
                hasMedia: _media.isNotEmpty,
              ),
              const SizedBox(height: 14),

              ResponsiveBuilder(
                builder: (context, size) => Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: responsiveButtonWidth(size),
                    child: FilledButton(
                      onPressed: (isBusy || !hasInput) ? null : _generate,
                      child: isBusy
                          ? const _ButtonProgress(label: 'Kartlar üretiliyor…')
                          : const Text('Kart Üret'),
                    ),
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

/// Görsel/PDF ekleme butonu ve eklenen dosyaların listesi.
class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.media,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<MediaAttachment> media;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveBuilder(
          builder: (context, size) => SizedBox(
            width: responsiveButtonWidth(size),
            child: OutlinedButton.icon(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Görsel / PDF ekle'),
            ),
          ),
        ),
        if (media.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < media.length; i++)
                _AttachmentChip(
                  attachment: media[i],
                  onRemove: enabled ? () => onRemove(i) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, required this.onRemove});

  final MediaAttachment attachment;
  final VoidCallback? onRemove;

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatSize(attachment.sizeBytes),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Kaldır',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'veya elle ekle',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _CharacterCounter extends StatelessWidget {
  const _CharacterCounter({required this.length, required this.hasMedia});

  final int length;
  final bool hasMedia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 50 karakter altı metin (ek yokken) istek atmadan reddediliyor.
    final isTooShort = !hasMedia && length > 0 && length < 50;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isTooShort ? 'Biraz daha uzun bir metin gerekli' : '',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        Text(
          '$length karakter',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
