import 'package:flutter/material.dart';

import '../models/pdf_page.dart';
import '../models/topic_segment.dart';
import '../services/page_range_parser.dart';
import '../services/topic_scan_service.dart';
import '../utils/breakpoints.dart';
import '../widgets/content_shell.dart';

enum _SelectionMode { topic, range }

/// PDF'ten hangi sayfaların tam (vision + metin) pipeline'a gireceğini
/// seçtirir — iki yoldan biriyle:
///
/// - **Konuya Göre Seç**: kullanıcı isterse (otomatik değil, "Konuları Tara"
///   butonuyla) ucuz bir ön-tarama (bkz. [TopicScanService]) çalıştırıp
///   tespit edilen konu başlıklarından seçer.
/// - **Sayfa Aralığına Göre Seç**: serbest metinle sayfa aralığı yazar (ör.
///   "1-15, 20-25"). Bu modda HİÇBİR ağ isteği atılmaz — tarama tamamen
///   atlanır, maliyetsizdir.
///
/// Seçili sayfaların [PdfPage] listesini döner; iptal edilirse null.
class PdfTopicSelectionScreen extends StatefulWidget {
  const PdfTopicSelectionScreen({
    super.key,
    required this.pages,
    this.topicScanner,
  });

  final List<PdfPage> pages;

  /// Testlerde sahte bir tarayıcı enjekte etmek için. Verilmezse gerçek
  /// [TopicScanService] kullanılır.
  final TopicScanService? topicScanner;

  @override
  State<PdfTopicSelectionScreen> createState() =>
      _PdfTopicSelectionScreenState();
}

class _PdfTopicSelectionScreenState extends State<PdfTopicSelectionScreen> {
  late final TopicScanService _scanner =
      widget.topicScanner ?? TopicScanService();

  _SelectionMode _mode = _SelectionMode.topic;

  // ---- Konuya göre seçim durumu ----
  bool _scanStarted = false;
  bool _scanning = false;
  bool _scanFailed = false;
  List<TopicSegment>? _segments;
  Set<TopicSegment> _selectedTopics = {};

  // ---- Sayfa aralığına göre seçim durumu ----
  final TextEditingController _rangeController = TextEditingController();
  String? _rangeError;
  Set<int>? _rangePages;

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  /// Yalnızca kullanıcı açıkça isterse çağrılır — ekran açılırken OTOMATİK
  /// tetiklenmez. "Sayfa Aralığına Göre Seç" hiç kullanılmasa bile bu
  /// buton hiç basılmadıysa ağa tek bir istek dahi gitmez.
  Future<void> _startTopicScan() async {
    setState(() {
      _scanStarted = true;
      _scanning = true;
      _scanFailed = false;
    });

    final segments = await _scanner.scan(widget.pages);
    if (!mounted) return;

    setState(() {
      _scanning = false;
      if (segments == null || segments.isEmpty) {
        _scanFailed = true;
        _segments = null;
      } else {
        _segments = segments;
        _selectedTopics = segments.toSet();
      }
    });
  }

  void _onRangeChanged(String value) {
    setState(() {
      try {
        _rangePages = PageRangeParser.parse(
          value,
          totalPages: widget.pages.length,
        );
        _rangeError = null;
      } on PageRangeParseException catch (e) {
        _rangePages = null;
        _rangeError = e.message;
      }
    });
  }

  /// Aktif moda göre şu an seçili olan sayfalar. Henüz geçerli bir seçim
  /// yoksa null (buton pasif kalır).
  List<PdfPage>? get _currentSelection {
    if (_mode == _SelectionMode.topic) {
      final segments = _segments;
      if (segments == null || _selectedTopics.isEmpty) return null;

      final pageNumbers = <int>{};
      for (final s in _selectedTopics) {
        for (var p = s.startPage; p <= s.endPage; p++) {
          pageNumbers.add(p);
        }
      }
      return widget.pages.where((p) => pageNumbers.contains(p.page)).toList();
    }

    final rangePages = _rangePages;
    if (rangePages == null || rangePages.isEmpty) return null;
    return widget.pages.where((p) => rangePages.contains(p.page)).toList();
  }

  void _confirm() {
    final selection = _currentSelection;
    if (selection == null || selection.isEmpty) return;
    Navigator.of(context).pop(selection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = _currentSelection;
    final hasSelection = selection != null && selection.isNotEmpty;
    // Kaba tahmin: ~4 sayfa eşzamanlı, sayfa başına ~3 sn (bkz. AddCardsScreen).
    final estMinutes = hasSelection
        ? ((selection.length / 4) * 3 / 60).ceil().clamp(1, 999)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Kart Üretilecek Sayfaları Seç')),
      body: SafeArea(
        child: ContentShell(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: SegmentedButton<_SelectionMode>(
                  segments: const [
                    ButtonSegment(
                      value: _SelectionMode.topic,
                      label: Text('Konuya Göre Seç'),
                      icon: Icon(Icons.topic_outlined),
                    ),
                    ButtonSegment(
                      value: _SelectionMode.range,
                      label: Text('Sayfa Aralığına Göre Seç'),
                      icon: Icon(Icons.filter_list_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selected) =>
                      setState(() => _mode = selected.first),
                ),
              ),
              Expanded(
                child: _mode == _SelectionMode.topic
                    ? _buildTopicTab(theme)
                    : _buildRangeTab(theme),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ResponsiveBuilder(
                  builder: (context, size) => Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: responsiveButtonWidth(size),
                      child: FilledButton(
                        onPressed: hasSelection ? _confirm : null,
                        child: Text(
                          hasSelection
                              ? 'Kart Üret (${selection.length} sayfa, '
                                    '~$estMinutes dk)'
                              : 'En az bir sayfa seç',
                        ),
                      ),
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

  Widget _buildTopicTab(ThemeData theme) {
    if (!_scanStarted) {
      return _TopicTabMessage(
        icon: Icons.travel_explore_outlined,
        text:
            'PDF\'teki ana konu başlıklarını tespit etmek için kısa bir '
            'tarama gerekir (yalnızca metin örneği, görsel/vision '
            'kullanılmaz — düşük maliyetli).',
        action: FilledButton.icon(
          onPressed: _startTopicScan,
          icon: const Icon(Icons.search),
          label: const Text('Konuları Tara'),
        ),
      );
    }

    if (_scanning) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_scanFailed) {
      return _TopicTabMessage(
        icon: Icons.error_outline,
        iconColor: theme.colorScheme.error,
        text:
            'Konu taraması başarısız oldu. "Sayfa Aralığına Göre Seç" '
            'sekmesini kullanabilir ya da tekrar deneyebilirsin.',
        action: OutlinedButton(
          onPressed: _startTopicScan,
          child: const Text('Tekrar Dene'),
        ),
      );
    }

    final segments = _segments!;
    final allSelected = _selectedTopics.length == segments.length;

    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Tümünü Seç'),
          value: allSelected,
          onChanged: (v) => setState(
            () => _selectedTopics = (v ?? false) ? segments.toSet() : {},
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: segments.length,
            itemBuilder: (context, index) {
              final segment = segments[index];
              return CheckboxListTile(
                title: Text(segment.topic),
                subtitle: Text(
                  segment.startPage == segment.endPage
                      ? 'Sayfa ${segment.startPage}'
                      : 'Sayfa ${segment.startPage}-${segment.endPage} '
                            '(${segment.pageCount} sayfa)',
                ),
                value: _selectedTopics.contains(segment),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _selectedTopics.add(segment);
                  } else {
                    _selectedTopics.remove(segment);
                  }
                }),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRangeTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PDF\'te toplam ${widget.pages.length} sayfa var.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rangeController,
            decoration: InputDecoration(
              labelText: 'Sayfa aralığı',
              hintText: 'ör. 1-15, 20-25',
              errorText: _rangeError,
            ),
            onChanged: _onRangeChanged,
          ),
          const SizedBox(height: 10),
          if (_rangePages != null)
            Text(
              '${_rangePages!.length} sayfa seçili.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Konu sekmesinin boş/hata durumlarında ortalanmış ikon + metin + eylem.
class _TopicTabMessage extends StatelessWidget {
  const _TopicTabMessage({
    required this.icon,
    required this.text,
    required this.action,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final Widget action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: iconColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
