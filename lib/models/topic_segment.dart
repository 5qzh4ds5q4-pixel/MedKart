/// PDF ön-taramasında tespit edilen bir konu bloğu: ardışık sayfa aralığı +
/// başlık (bkz. `TopicScanService`).
///
/// Kullanıcı bu segmentlerden seçtiklerini işaretler; yalnızca seçili
/// segmentlerin sayfa aralığındaki sayfalar tam (vision + metin) pipeline'a
/// girer.
class TopicSegment {
  const TopicSegment({
    required this.topic,
    required this.startPage,
    required this.endPage,
  });

  final String topic;

  /// 1 tabanlı, dahil.
  final int startPage;

  /// 1 tabanlı, dahil.
  final int endPage;

  int get pageCount => endPage - startPage + 1;

  bool containsPage(int page) => page >= startPage && page <= endPage;
}
