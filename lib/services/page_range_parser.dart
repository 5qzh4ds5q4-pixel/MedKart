/// Kullanıcının serbest metin olarak girdiği bir sayfa aralığı geçersizse
/// fırlatılır. [message] doğrudan kullanıcıya gösterilecek kadar anlaşılırdır.
class PageRangeParseException implements Exception {
  const PageRangeParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// "1-15, 20-25" gibi serbest metin sayfa aralığı girişini sayfa numarası
/// kümesine çevirir (bkz. `PdfTopicSelectionScreen`'in sayfa aralığı sekmesi).
class PageRangeParser {
  const PageRangeParser._();

  /// [input]'u ayrıştırır. Geçersizse (boş, sayısal olmayan, ters aralık,
  /// PDF'in sayfa sayısını aşan) anlaşılır bir mesajla
  /// [PageRangeParseException] fırlatır — hiçbir zaman sessizce çökmez.
  static Set<int> parse(String input, {required int totalPages}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const PageRangeParseException(
        'Bir sayfa aralığı gir (ör. "1-15, 20-25").',
      );
    }

    final pages = <int>{};
    for (final rawPart in trimmed.split(',')) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;

      final bounds = part.split('-').map((s) => s.trim()).toList();
      if (bounds.length == 1) {
        final page = int.tryParse(bounds[0]);
        if (page == null) {
          throw PageRangeParseException(
            '"$part" anlaşılamadı. Örnek: "1-15, 20-25".',
          );
        }
        _validatePage(page, part, totalPages);
        pages.add(page);
      } else if (bounds.length == 2) {
        final start = int.tryParse(bounds[0]);
        final end = int.tryParse(bounds[1]);
        if (start == null || end == null) {
          throw PageRangeParseException(
            '"$part" anlaşılamadı. Örnek: "1-15, 20-25".',
          );
        }
        if (start > end) {
          throw PageRangeParseException(
            '"$part" geçersiz: başlangıç sayfası bitişten büyük olamaz.',
          );
        }
        _validatePage(start, part, totalPages);
        _validatePage(end, part, totalPages);
        for (var p = start; p <= end; p++) {
          pages.add(p);
        }
      } else {
        throw PageRangeParseException(
          '"$part" anlaşılamadı. Örnek: "1-15, 20-25".',
        );
      }
    }

    if (pages.isEmpty) {
      throw const PageRangeParseException('Geçerli bir sayfa bulunamadı.');
    }
    return pages;
  }

  static void _validatePage(int page, String part, int totalPages) {
    if (page < 1 || page > totalPages) {
      throw PageRangeParseException(
        '"$part" PDF\'in sayfa sayısını (1-$totalPages) aşıyor.',
      );
    }
  }
}
