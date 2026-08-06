import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/screens/mcq_quiz_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/services/mcq_generator.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:provider/provider.dart';

class _NoopGenerator implements FlashcardGenerator {
  @override
  Future<List<Flashcard>> generate(
    String sourceText, {
    List<MediaAttachment> media = const [],
  }) async => const [];

  @override
  Future<List<Flashcard>> generateForPage(
    String pageText,
    int sourcePage, {
    String? imageBase64,
    String imageMimeType = 'image/png',
  }) async => const [];
}

final _deck = Deck(id: 'd', name: 'Deste', createdAt: DateTime(2026, 7, 20));

FlashcardStore _storeWith(List<Flashcard> cards) =>
    FlashcardStore(_NoopGenerator(), initialData: LibraryData(decks: [_deck], cards: cards));

Widget _wrap(FlashcardStore store, Widget child) =>
    ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

/// Dört şıklı tek soru; [explanation] her şıkta kullanılır.
McqQuestion _question(String explanation, {String prompt = 'Test sorusu?'}) =>
    McqQuestion(
      question: prompt,
      options: [
        McqOption(text: 'Doğru şık', explanation: explanation, sourceCardId: 'c1'),
        McqOption(text: 'Yanlış şık', explanation: explanation, sourceCardId: 'c1'),
        McqOption(text: 'Şık üç', explanation: explanation, sourceCardId: 'c1'),
        McqOption(text: 'Şık dört', explanation: explanation, sourceCardId: 'c1'),
      ],
      correctIndex: 0,
      sourceCardId: 'c1',
    );

void main() {
  group('şık seçildikten sonra tüm içerik görünür kalır', () {
    /// Bir widget'ın ekranın görünür alanı içinde, sıfırdan büyük bir alan
    /// kapladığını doğrular.
    void expectOnScreen(WidgetTester tester, Finder finder, String label) {
      expect(finder, findsWidgets, reason: '$label ağaçta yok');
      final rect = tester.getRect(finder.first);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

      expect(
        rect.height,
        greaterThan(0),
        reason: '$label sıfır yükseklikte (çökmüş)',
      );
      expect(
        rect.top < screen.height && rect.bottom > 0,
        isTrue,
        reason: '$label ekran dışında: $rect (ekran: $screen)',
      );
    }

    Future<void> pumpQuiz(WidgetTester tester, McqQuestion question) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(_storeWith(const []), McqQuizScreen(questions: [question])),
      );
    }

    /// REGRESYON ÇEKİRDEĞİ: alt çubuk `bottomNavigationBar` slotunda sınırlı
    /// ama içeriğe göre belirlenmesi gereken bir yükseklik alır. ContentShell
    /// dikeyde küçülmezse çubuk TÜM ekranı kaplar, gövdeye 0 yükseklik kalır
    /// ve soru/şıklar tamamen kaybolur (yalnızca buton ortada görünür).
    void expectBodyNotCollapsed(WidgetTester tester) {
      final scrollHeight = tester
          .getSize(find.byType(SingleChildScrollView))
          .height;
      expect(
        scrollHeight,
        greaterThan(200),
        reason:
            'Gövde çökmüş (yükseklik $scrollHeight) — alt çubuk ekranı '
            'yutuyor olabilir',
      );

      final barHeight = tester
          .getSize(find.widgetWithText(FilledButton, 'Özeti Gör'))
          .height;
      final screenHeight =
          (tester.view.physicalSize / tester.view.devicePixelRatio).height;
      expect(
        barHeight,
        lessThan(screenHeight / 2),
        reason: 'Alt çubuk butonu ekranın yarısından uzun',
      );
    }

    testWidgets('kısa açıklamada soru, şıklar, açıklama ve buton birlikte görünür', (
      tester,
    ) async {
      await pumpQuiz(tester, _question('Kısa açıklama.'));

      await tester.tap(find.text('Yanlış şık'), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expectBodyNotCollapsed(tester);

      // Kısa içerik ekrana sığar: hepsi kaydırmadan görünür olmalı.
      expectOnScreen(tester, find.text('Test sorusu?'), 'soru');
      expectOnScreen(tester, find.text('Doğru şık'), 'doğru şık');
      expectOnScreen(tester, find.text('Yanlış şık'), 'yanlış şık');
      expectOnScreen(tester, find.text('Şık üç'), 'şık üç');
      expectOnScreen(tester, find.text('Şık dört'), 'şık dört');
      // Açıklama doğru + yanlış şıkta gösterilir (ikisi de aynı metin).
      expectOnScreen(tester, find.text('Kısa açıklama.'), 'açıklama');
      expectOnScreen(tester, find.text('Özeti Gör'), 'buton');
    });

    testWidgets('uzun açıklamada içerik kaybolmaz, kaydırarak erişilebilir', (
      tester,
    ) async {
      final longExplanation =
          'Bu şıkkın çok uzun bir açıklaması var, mekanizmayı ayrıntılı '
              'anlatıyor ve pek çok satıra yayılıyor. ' *
          20;

      await pumpQuiz(tester, _question(longExplanation));

      await tester.tap(find.text('Yanlış şık'), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expectBodyNotCollapsed(tester);

      // Soru ve ilk şık kaydırmadan görünür.
      expectOnScreen(tester, find.text('Test sorusu?'), 'soru');
      expectOnScreen(tester, find.text('Doğru şık'), 'doğru şık');
      expectOnScreen(tester, find.text(longExplanation), 'açıklama');

      // Uzun açıklama nedeniyle alttaki şıklar ekran dışında kalır ama
      // KAYBOLMAZ: kaydırınca görünür hale gelirler.
      for (final label in ['Yanlış şık', 'Şık üç', 'Şık dört']) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        expectOnScreen(tester, find.text(label), label);
      }

      // Buton sabit çubukta: kaydırmadan bağımsız her zaman erişilebilir.
      expectOnScreen(tester, find.text('Özeti Gör'), 'buton');
      expect(tester.takeException(), isNull);
    });

    testWidgets('şık seçilmeden ÖNCE de gövde çökmüş değil', (tester) async {
      await pumpQuiz(tester, _question('Kısa açıklama.'));

      // Cevaplanmadan alt çubuk hiç oluşturulmaz; gövde tam alanı kullanır.
      expect(find.text('Özeti Gör'), findsNothing);
      expect(
        tester.getSize(find.byType(SingleChildScrollView)).height,
        greaterThan(200),
      );
      expectOnScreen(tester, find.text('Test sorusu?'), 'soru');
      expectOnScreen(tester, find.text('Şık dört'), 'şık dört');
    });
  });

  testWidgets(
    'uzun açıklamalı şıkta overflow olmaz ve "Sonraki" butonu erişilebilir/tıklanabilir kalır',
    (tester) async {
      // Küçük bir telefon ekranı simüle et — overflow bugu düşük yükseklikte
      // daha kolay tetiklenir, düzeltmenin sağlamlığını burada kanıtlamak için.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final longExplanation =
          'Bu şıkkın çok uzun bir açıklaması var, mekanizmayı ayrıntılı '
              'anlatıyor ve pek çok satıra yayılıyor. ' *
          20;

      final question = McqQuestion(
        question: 'Uzun açıklamalı bir soru?',
        options: [
          McqOption(
            text: 'Doğru şık',
            explanation: longExplanation,
            sourceCardId: 'c1',
          ),
          McqOption(
            text: 'Yanlış şık',
            explanation: longExplanation,
            sourceCardId: 'c1',
          ),
          const McqOption(
            text: 'Şık üç',
            explanation: 'Kısa açıklama.',
            sourceCardId: 'c1',
          ),
          const McqOption(
            text: 'Şık dört',
            explanation: 'Kısa açıklama.',
            sourceCardId: 'c1',
          ),
        ],
        correctIndex: 0,
        sourceCardId: 'c1',
      );

      await tester.pumpWidget(
        _wrap(_storeWith(const []), McqQuizScreen(questions: [question])),
      );

      expect(find.text('Uzun açıklamalı bir soru?'), findsOneWidget);
      expect(find.text('Yanlış şık'), findsOneWidget);

      // Yanlış şıkkı seç: hem doğru hem yanlış şıkkın (ikisi de UZUN
      // açıklamalı) açıklaması AYNI ANDA görünür hale gelir — overflow'u
      // tetikleyen tam olarak bu senaryodur.
      await tester.ensureVisible(find.text('Yanlış şık'));
      await tester.tap(find.text('Yanlış şık'), warnIfMissed: false);
      await tester.pump();

      // Render/layout sırasında bir RenderFlex overflow hatası fırlatılmadı.
      expect(tester.takeException(), isNull);

      // Buton görünür VE gerçekten tıklanabilir (bulunamazsa/kapsam dışıysa
      // tap başarısız olurdu). Tek soruluk listede bu aynı zamanda SON
      // soru olduğu için metin "Sonraki" değil "Özeti Gör".
      expect(find.text('Özeti Gör'), findsOneWidget);
      await tester.tap(find.text('Özeti Gör'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Tek soruluk oturum bitti → özet ekranına geçti, yani buton gerçekten
      // çalıştı (erişilemez/kapalı bir buton bu geçişi tetikleyemezdi).
      expect(find.text('Test Özeti'), findsOneWidget);
    },
  );
}
