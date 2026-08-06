import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/topic_segment.dart';

void main() {
  test('pageCount tek sayfalık segmentte 1 döner', () {
    const segment = TopicSegment(topic: 'Kalp', startPage: 3, endPage: 3);
    expect(segment.pageCount, 1);
  });

  test('pageCount aralığı doğru hesaplar', () {
    const segment = TopicSegment(topic: 'Kalp', startPage: 3, endPage: 7);
    expect(segment.pageCount, 5);
  });

  test('containsPage aralık içi/dışı sayfaları doğru ayırır', () {
    const segment = TopicSegment(topic: 'Kalp', startPage: 3, endPage: 7);

    expect(segment.containsPage(3), isTrue);
    expect(segment.containsPage(7), isTrue);
    expect(segment.containsPage(5), isTrue);
    expect(segment.containsPage(2), isFalse);
    expect(segment.containsPage(8), isFalse);
  });
}
