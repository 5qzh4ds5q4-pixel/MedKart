import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/models/pdf_page.dart';
import 'package:medcard/services/topic_scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gemini'ın gerçek yanıt zarfını taklit eder.
String _envelope(String modelText) {
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': modelText},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  });
}

List<PdfPage> _pages(int count) => [
  for (var i = 1; i <= count; i++)
    PdfPage(page: i, text: 'Sayfa $i içeriği burada, en az yirmi karakter.'),
];

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString:
          'SUPABASE_URL=https://test.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
    SharedPreferences.setMockInitialValues({});
  });

  TopicScanService serviceReturning(
    List<String> bodies, {
    List<int>? statusCodes,
  }) {
    var call = 0;
    return TopicScanService(
      retryBackoff: Duration.zero,
      client: MockClient((_) async {
        final index = call < bodies.length ? call : bodies.length - 1;
        final status = statusCodes != null
            ? (call < statusCodes.length ? statusCodes[call] : statusCodes.last)
            : 200;
        call++;
        return http.Response(
          bodies[index],
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  test('geçerli yanıtı segmentlere dönüştürür', () async {
    final service = serviceReturning([
      _envelope(
        jsonEncode([
          {'konu': 'Kemik Doku', 'ilkSayfa': 1, 'sonSayfa': 5},
          {'konu': 'Eklemler', 'ilkSayfa': 6, 'sonSayfa': 10},
        ]),
      ),
    ]);

    final segments = await service.scan(_pages(10));

    expect(segments, isNotNull);
    expect(segments, hasLength(2));
    expect(segments![0].topic, 'Kemik Doku');
    expect(segments[0].startPage, 1);
    expect(segments[0].endPage, 5);
    expect(segments[1].topic, 'Eklemler');
    expect(segments[1].startPage, 6);
    expect(segments[1].endPage, 10);
  });

  test('boşta kalan sayfalar "Sınıflandırılmamış" ile doldurulur', () async {
    final service = serviceReturning([
      _envelope(
        jsonEncode([
          {'konu': 'Eklemler', 'ilkSayfa': 2, 'sonSayfa': 4},
        ]),
      ),
    ]);

    final segments = await service.scan(_pages(5));

    expect(segments, isNotNull);
    expect(segments!.map((s) => (s.topic, s.startPage, s.endPage)), [
      ('Sınıflandırılmamış', 1, 1),
      ('Eklemler', 2, 4),
      ('Sınıflandırılmamış', 5, 5),
    ]);
  });

  test('çakışan segmentler kesilir, sayfa tekrarı olmaz', () async {
    final service = serviceReturning([
      _envelope(
        jsonEncode([
          {'konu': 'A', 'ilkSayfa': 1, 'sonSayfa': 3},
          {'konu': 'B', 'ilkSayfa': 2, 'sonSayfa': 5},
        ]),
      ),
    ]);

    final segments = await service.scan(_pages(5));

    expect(segments, isNotNull);
    expect(segments!.map((s) => (s.topic, s.startPage, s.endPage)), [
      ('A', 1, 3),
      ('B', 4, 5),
    ]);
  });

  test('HTTP hatasında null döner (kullanıcı engellenmez)', () async {
    final service = serviceReturning([''], statusCodes: [500]);

    final segments = await service.scan(_pages(3));

    expect(segments, isNull);
  });

  test('bozuk iç JSON\'da null döner', () async {
    final service = serviceReturning([_envelope('{"bu": "liste değil"}')]);

    final segments = await service.scan(_pages(3));

    expect(segments, isNull);
  });

  test('boş sayfa listesinde ağa hiç çıkmadan null döner', () async {
    final service = TopicScanService(
      client: MockClient((_) async {
        fail('Boş sayfa listesinde HTTP isteği atılmamalı');
      }),
    );

    final segments = await service.scan(const []);

    expect(segments, isNull);
  });

  test('büyük PDF birden fazla parça hâlinde taranır', () async {
    final service = serviceReturning([
      _envelope(
        jsonEncode([
          {'konu': 'İlk Blok', 'ilkSayfa': 1, 'sonSayfa': 150},
        ]),
      ),
      _envelope(
        jsonEncode([
          {'konu': 'İkinci Blok', 'ilkSayfa': 151, 'sonSayfa': 200},
        ]),
      ),
    ]);

    final segments = await service.scan(_pages(200));

    expect(segments, isNotNull);
    expect(segments!.map((s) => (s.topic, s.startPage, s.endPage)), [
      ('İlk Blok', 1, 150),
      ('İkinci Blok', 151, 200),
    ]);
  });
}
