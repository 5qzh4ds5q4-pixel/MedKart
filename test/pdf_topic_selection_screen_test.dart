import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/models/pdf_page.dart';
import 'package:medcard/screens/pdf_topic_selection_screen.dart';
import 'package:medcard/services/session_token.dart';
import 'package:medcard/services/topic_scan_service.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  for (var i = 1; i <= count; i++) PdfPage(page: i, text: 'S$i içerik metni'),
];

/// Sabit iki segment döndüren gerçekçi bir tarayıcı (gerçek HTTP çağrısı).
TopicScanService _scannerReturning(List<Map<String, Object>> segmentsJson) {
  return TopicScanService(
    retryBackoff: Duration.zero,
    client: MockClient(
      (_) async => http.Response(
        _envelope(jsonEncode(segmentsJson)),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
}

/// Her çağrıda "fail" eden tarayıcı — sadece aralık modu kullanılırken hiç
/// ağa çıkılmadığını kanıtlamak için.
TopicScanService _forbiddenScanner() {
  return TopicScanService(
    client: MockClient((_) async {
      fail('Sayfa aralığı modunda tarama API çağrısı yapılmamalı');
    }),
  );
}

Widget _wrap(List<PdfPage> pages, {TopicScanService? scanner}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: PdfTopicSelectionScreen(pages: pages, topicScanner: scanner),
  );
}

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString:
          'SUPABASE_URL=https://test.supabase.co\n'
          'SUPABASE_ANON_KEY=test-anon-key',
    );
    SharedPreferences.setMockInitialValues({});
    // TopicScanService de GeminiTransport üzerinden gidiyor; transport
    // 2026-08-20'den beri oturum token'ı istiyor (bkz. SessionToken).
    debugSessionAccessTokenOverride = () => 'test-access-token';
  });

  tearDown(() => debugSessionAccessTokenOverride = null);

  group('Konuya Göre Seç', () {
    testWidgets(
      'ekran açılınca otomatik tarama yapılmaz, "Tara" butonu görünür',
      (tester) async {
        await tester.pumpWidget(_wrap(_pages(8), scanner: _forbiddenScanner()));

        expect(find.text('Konuları Tara'), findsOneWidget);
        expect(find.text('En az bir sayfa seç'), findsOneWidget);
      },
    );

    testWidgets(
      '"Tara"ya basınca konular listelenir ve varsayılan hepsi seçili',
      (tester) async {
        final scanner = _scannerReturning([
          {'konu': 'Kemik Doku', 'ilkSayfa': 1, 'sonSayfa': 5},
          {'konu': 'Eklemler', 'ilkSayfa': 6, 'sonSayfa': 8},
        ]);
        await tester.pumpWidget(_wrap(_pages(8), scanner: scanner));

        await tester.tap(find.text('Konuları Tara'));
        await tester.pumpAndSettle();

        expect(find.text('Kemik Doku'), findsOneWidget);
        expect(find.text('Eklemler'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Kart Üret (8 sayfa, ~1 dk)'),
          findsOneWidget,
        );
      },
    );

    testWidgets('bir konu kaldırılınca seçili sayfa sayısı düşer', (
      tester,
    ) async {
      final scanner = _scannerReturning([
        {'konu': 'Kemik Doku', 'ilkSayfa': 1, 'sonSayfa': 5},
        {'konu': 'Eklemler', 'ilkSayfa': 6, 'sonSayfa': 8},
      ]);
      await tester.pumpWidget(_wrap(_pages(8), scanner: scanner));

      await tester.tap(find.text('Konuları Tara'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Eklemler'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Kart Üret (5 sayfa, ~1 dk)'),
        findsOneWidget,
      );
    });

    testWidgets('tarama başarısız olursa hata mesajı gösterir, çökmez', (
      tester,
    ) async {
      final failingScanner = TopicScanService(
        retryBackoff: Duration.zero,
        client: MockClient((_) async => http.Response('', 500)),
      );
      await tester.pumpWidget(_wrap(_pages(5), scanner: failingScanner));

      await tester.tap(find.text('Konuları Tara'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Konu taraması başarısız oldu'),
        findsOneWidget,
      );
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('onaylayınca yalnızca seçili konunun sayfaları döner', (
      tester,
    ) async {
      late List<PdfPage>? result;
      final scanner = _scannerReturning([
        {'konu': 'Kemik Doku', 'ilkSayfa': 1, 'sonSayfa': 5},
        {'konu': 'Eklemler', 'ilkSayfa': 6, 'sonSayfa': 8},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<List<PdfPage>>(
                    MaterialPageRoute(
                      builder: (_) => PdfTopicSelectionScreen(
                        pages: _pages(8),
                        topicScanner: scanner,
                      ),
                    ),
                  );
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konuları Tara'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Eklemler'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Kart Üret (5 sayfa, ~1 dk)'),
      );
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.map((p) => p.page), [1, 2, 3, 4, 5]);
    });
  });

  group('Sayfa Aralığına Göre Seç', () {
    Future<void> switchToRangeTab(WidgetTester tester) async {
      await tester.tap(find.text('Sayfa Aralığına Göre Seç'));
      await tester.pumpAndSettle();
    }

    testWidgets('bu modda hiç ağ isteği atılmaz', (tester) async {
      await tester.pumpWidget(_wrap(_pages(20), scanner: _forbiddenScanner()));

      await switchToRangeTab(tester);
      await tester.enterText(find.byType(TextField), '3-8');
      await tester.pumpAndSettle();

      // _forbiddenScanner() çağrılırsa test zaten fail() ile patlar; buraya
      // sorunsuz gelmesi hiç istek atılmadığını kanıtlar.
      expect(find.text('6 sayfa seçili.'), findsOneWidget);
    });

    testWidgets('toplam sayfa sayısı gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(_pages(20)));
      await switchToRangeTab(tester);

      expect(find.text('PDF\'te toplam 20 sayfa var.'), findsOneWidget);
    });

    testWidgets('geçerli tek aralık girilince doğru sayfalar seçilir', (
      tester,
    ) async {
      late List<PdfPage>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<List<PdfPage>>(
                    MaterialPageRoute(
                      builder: (_) => PdfTopicSelectionScreen(
                        pages: _pages(20),
                        topicScanner: _forbiddenScanner(),
                      ),
                    ),
                  );
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await switchToRangeTab(tester);

      await tester.enterText(find.byType(TextField), '3-8');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Kart Üret (6 sayfa, ~1 dk)'),
      );
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.map((p) => p.page), [3, 4, 5, 6, 7, 8]);
    });

    testWidgets('birden fazla virgüllü aralık desteklenir', (tester) async {
      await tester.pumpWidget(_wrap(_pages(30)));
      await switchToRangeTab(tester);

      await tester.enterText(find.byType(TextField), '1-5, 10-12');
      await tester.pumpAndSettle();

      expect(find.text('8 sayfa seçili.'), findsOneWidget);
    });

    testWidgets('PDF sayfa sayısını aşan aralıkta anlaşılır hata gösterilir', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_pages(10)));
      await switchToRangeTab(tester);

      await tester.enterText(find.byType(TextField), '5-15');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('sayfa sayısını (1-10) aşıyor'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'En az bir sayfa seç'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('ters aralıkta (başlangıç > bitiş) anlaşılır hata gösterilir', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_pages(10)));
      await switchToRangeTab(tester);

      await tester.enterText(find.byType(TextField), '8-3');
      await tester.pumpAndSettle();

      expect(find.textContaining('geçersiz'), findsOneWidget);
    });

    testWidgets('sayısal olmayan girişte anlaşılır hata gösterilir, çökmez', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_pages(10)));
      await switchToRangeTab(tester);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pumpAndSettle();

      expect(find.textContaining('anlaşılamadı'), findsOneWidget);
    });

    testWidgets('boş girişte buton pasif kalır', (tester) async {
      await tester.pumpWidget(_wrap(_pages(10)));
      await switchToRangeTab(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'En az bir sayfa seç'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
