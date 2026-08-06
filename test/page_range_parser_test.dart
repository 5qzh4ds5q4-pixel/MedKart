import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/page_range_parser.dart';

void main() {
  test('tek bir aralığı ayrıştırır', () {
    expect(
      PageRangeParser.parse('3-8', totalPages: 10),
      {3, 4, 5, 6, 7, 8},
    );
  });

  test('tek bir sayfayı ayrıştırır', () {
    expect(PageRangeParser.parse('5', totalPages: 10), {5});
  });

  test('virgülle ayrılmış birden fazla aralığı birleştirir', () {
    expect(
      PageRangeParser.parse('1-3, 7, 9-10', totalPages: 10),
      {1, 2, 3, 7, 9, 10},
    );
  });

  test('boşluklu girişi tolere eder', () {
    expect(
      PageRangeParser.parse(' 1 - 3 , 7 ', totalPages: 10),
      {1, 2, 3, 7},
    );
  });

  test('çakışan aralıkları tekilleştirir', () {
    expect(PageRangeParser.parse('1-5, 3-7', totalPages: 10), {
      1, 2, 3, 4, 5, 6, 7,
    });
  });

  test('boş girişte anlaşılır hata fırlatır', () {
    expect(
      () => PageRangeParser.parse('', totalPages: 10),
      throwsA(isA<PageRangeParseException>()),
    );
  });

  test('sayısal olmayan girişte anlaşılır hata fırlatır', () {
    expect(
      () => PageRangeParser.parse('abc', totalPages: 10),
      throwsA(
        isA<PageRangeParseException>().having(
          (e) => e.message,
          'message',
          contains('anlaşılamadı'),
        ),
      ),
    );
  });

  test('ters aralıkta (başlangıç > bitiş) anlaşılır hata fırlatır', () {
    expect(
      () => PageRangeParser.parse('8-3', totalPages: 10),
      throwsA(
        isA<PageRangeParseException>().having(
          (e) => e.message,
          'message',
          contains('geçersiz'),
        ),
      ),
    );
  });

  test('PDF sayfa sayısını aşan aralıkta anlaşılır hata fırlatır', () {
    expect(
      () => PageRangeParser.parse('5-15', totalPages: 10),
      throwsA(
        isA<PageRangeParseException>().having(
          (e) => e.message,
          'message',
          contains('1-10'),
        ),
      ),
    );
  });

  test('0. sayfa geçersizdir', () {
    expect(
      () => PageRangeParser.parse('0-5', totalPages: 10),
      throwsA(isA<PageRangeParseException>()),
    );
  });

  test('yanlış biçimli aralık (birden fazla tire) anlaşılır hata fırlatır', () {
    expect(
      () => PageRangeParser.parse('1-5-10', totalPages: 10),
      throwsA(isA<PageRangeParseException>()),
    );
  });

  test('fazladan virgülleri yok sayar', () {
    expect(
      PageRangeParser.parse('1-3,,5', totalPages: 10),
      {1, 2, 3, 5},
    );
  });
}
