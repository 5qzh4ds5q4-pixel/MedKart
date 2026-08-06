import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pdf_page.dart';
import '../services/ai_provider_config.dart';
import '../services/deepseek_service.dart';
import '../services/flashcard_prompt.dart';
import '../services/gemini_service.dart';
import '../services/pdf_card_pipeline.dart';
import '../services/pdf_cache_service.dart';
import '../state/flashcard_store.dart';
import '../utils/breakpoints.dart';
import '../widgets/content_shell.dart';

/// PDF sayfalarını arka planda karta çeviren ekran: ilerleme + akış + özet.
///
/// Kartlar üretildikçe destene eklenir (streaming); kullanıcı ilk kartların
/// hemen dolduğunu görür. Öğrenci teknik hiçbir şey yapmaz, sadece bekler.
class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({
    super.key,
    required this.deckId,
    required this.pages,
    this.pdfHash,
  });

  final String deckId;
  final List<PdfPage> pages;

  /// Dolu ise (yalnızca TÜM PDF, daraltılmadan işlendiğinde — bkz.
  /// `AddCardsScreen._runPdfPipeline`), işlem temiz bitince (kota hatasıyla
  /// yarıda kalmadıysa) sonuç paylaşılan önbelleğe yazılır ki bir sonraki
  /// öğrenci aynı PDF'i yüklediğinde Gemini'a hiç gitmesin.
  final String? pdfHash;

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  int _completed = 0;
  int _cardCount = 0;
  bool _running = true;
  PipelineResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final store = context.read<FlashcardStore>();
    // DeepSeek'in rate limiti Gemini free-tier'dan çok daha geniş — mekanik
    // hacim testinde daha yüksek paralellik kullanılabilir (bkz.
    // ai_provider_config.dart).
    final pipeline = PdfCardPipeline(
      concurrency: activeAiProvider == AiProvider.deepseek ? 5 : 4,
    );

    final result = await pipeline.run(
      widget.pages,
      generate: store.pageGenerator,
      onProgress: (done, total) {
        if (mounted) setState(() => _completed = done);
      },
      onCards: (cards) {
        // Üretildikçe destene ekle (akış).
        store.addCards(widget.deckId, cards);
        if (mounted) setState(() => _cardCount += cards.length);
      },
    );

    if (mounted) {
      setState(() {
        _result = result;
        _running = false;
      });
    }

    // Yalnızca temiz (kota hatasıyla yarıda kalmamış) tam-PDF çalıştırmaları
    // önbelleğe yazılır — best-effort, kullanıcıyı hiç beklemez/etkilemez.
    final hash = widget.pdfHash;
    if (hash != null && !result.quotaExhausted && result.cards.isNotEmpty) {
      final modelVersion = activeAiProvider == AiProvider.deepseek
          ? DeepSeekService.model
          : GeminiService.model;
      unawaited(
        PdfCacheService().save(
          hash,
          result.cards,
          modelVersion: modelVersion,
          promptVersion: kPromptVersion,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pages.length;

    return PopScope(
      // İşlem sürerken kazara geri çıkmayı engelle (kartlar yine kaydediliyor).
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF\'ten kart üretiliyor'),
          automaticallyImplyLeading: !_running,
        ),
        body: SafeArea(
          child: ContentShell(
            child: Center(
              child: _running
                  ? _Progress(
                      completed: _completed,
                      total: total,
                      cardCount: _cardCount,
                    )
                  : _Summary(
                      result: _result!,
                      onDone: () => Navigator.of(context).pop(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.completed,
    required this.total,
    required this.cardCount,
  });

  final int completed;
  final int total;
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : completed / total;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sayfa $completed / $total işleniyor',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio == 0 ? null : ratio,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Şu ana kadar $cardCount kart üretildi',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Kartlar üretildikçe destene ekleniyor. Bu pencereyi açık tut.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result, required this.onDone});

  final PipelineResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final quota = result.quotaExhausted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          quota ? Icons.hourglass_bottom : Icons.check_circle_outline,
          size: 56,
          color: quota ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          '${result.totalPages} sayfadan ${result.cardCount} kart üretildi',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (quota)
          _Note(
            icon: Icons.hourglass_bottom,
            emphasize: true,
            text:
                '${result.quotaMessage ?? 'Gemini API kotasına takıldık.'} '
                'İşlem burada durduruldu; şu ana kadar üretilen '
                '${result.cardCount} kart destene kaydedildi. Birazdan '
                'tekrar deneyip kalan sayfalardan devam edebilirsin.',
          ),
        if (result.emptyTextPages.isNotEmpty)
          _Note(
            icon: Icons.image_outlined,
            text:
                '${result.emptyTextPages.length} sayfadan metin çıkarılamadı '
                '(görsel ağırlıklı olabilir).',
          ),
        if (result.failedPages.isNotEmpty)
          _Note(
            icon: Icons.error_outline,
            text:
                '${result.failedPages.length} sayfa işlenemedi. Sayfalar: '
                '${result.failedPages.join(", ")}.',
          ),
        if (!quota &&
            result.emptyTextPages.isEmpty &&
            result.failedPages.isEmpty)
          _Note(
            icon: Icons.verified_outlined,
            text: 'Tüm sayfalar başarıyla işlendi.',
          ),
        const SizedBox(height: 24),
        ResponsiveBuilder(
          builder: (context, size) => SizedBox(
            width: responsiveButtonWidth(size),
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Kartlara dön'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    this.emphasize = false,
  });

  final IconData icon;
  final String text;

  /// Kota gibi kullanıcının mutlaka görmesi gereken uyarılarda vurgulu renk.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasize
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: emphasize ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
