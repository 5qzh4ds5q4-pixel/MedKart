import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/srs/srs_engine.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:medcard/widgets/topic_success_bar.dart';

/// Eşik testleri sabiti doğrudan okur: [TopicStat.minAttemptsForPercent]
/// değiştirilirse testler yanlış sebeple kırmızıya dönmesin.
const _threshold = TopicStat.minAttemptsForPercent;

Flashcard _card(
  String id, {
  required String topic,
  int repetitions = 0,
  int lapses = 0,
}) {
  return Flashcard(
    id: id,
    question: 'q$id',
    answer: 'a$id',
    deckId: 'd1',
    topic: topic,
    repetitions: repetitions,
    lapses: lapses,
  );
}

TopicStat _stat({
  String topic = 'konu',
  int cardCount = 1,
  required int attempts,
  double successRate = 0.5,
}) {
  return TopicStat(
    topic: topic,
    cardCount: cardCount,
    attempts: attempts,
    successRate: successRate,
  );
}

Future<void> _pumpBar(
  WidgetTester tester,
  TopicStat stat, {
  bool showLowDataStates = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TopicSuccessBar(
          stat: stat,
          showLowDataStates: showLowDataStates,
        ),
      ),
    ),
  );
}

Color _barColor(WidgetTester tester) {
  final indicator = tester.widget<LinearProgressIndicator>(
    find.byType(LinearProgressIndicator),
  );
  return indicator.valueColor!.value!;
}

void main() {
  group('TopicStat.dataState', () {
    test('hiç değerlendirme yoksa henüz başlanmadı', () {
      expect(_stat(attempts: 0).dataState, TopicDataState.notStarted);
    });

    test('eşiğin altında ama en az bir değerlendirme varsa az veri', () {
      expect(_stat(attempts: 1).dataState, TopicDataState.lowData);
      expect(
        _stat(attempts: _threshold - 1).dataState,
        TopicDataState.lowData,
      );
    });

    test('eşiğe ulaşan konu normal (sınır dahil)', () {
      expect(_stat(attempts: _threshold).dataState, TopicDataState.normal);
      expect(_stat(attempts: _threshold + 10).dataState, TopicDataState.normal);
    });
  });

  group('SrsEngine.topicStats — veri durumu', () {
    test('değerlendirme sayısı lapses + repetitions üzerinden hesaplanır', () {
      final stats = SrsEngine.topicStats([
        for (var i = 0; i < _threshold; i++)
          _card('a$i', topic: 'yeterli', repetitions: 1),
        _card('b', topic: 'az', repetitions: _threshold - 1),
      ]);

      final byTopic = {for (final s in stats) s.topic: s};
      expect(byTopic['yeterli']!.dataState, TopicDataState.normal);
      expect(byTopic['az']!.dataState, TopicDataState.lowData);
    });

    test(
      'hep "Zor" cevaplanmış konu (repetitions 0, lapses var) henüz '
      'başlanmadı SAYILMAZ',
      () {
        // SM-2'de "Zor" repetitions'ı sıfırlıyor; çıplak repetitions'a
        // bakılsaydı en çok çalışılan konu "hiç başlanmamış" görünürdü.
        final stats = SrsEngine.topicStats([
          _card('1', topic: 'zorlanılan', lapses: _threshold),
          _card('2', topic: 'hiçdokunulmadı'),
        ]);

        final byTopic = {for (final s in stats) s.topic: s};
        expect(byTopic['zorlanılan']!.dataState, TopicDataState.normal);
        expect(
          byTopic['hiçdokunulmadı']!.dataState,
          TopicDataState.notStarted,
        );
      },
    );

    test('sıralama: normal (en zayıf üstte) → az veri → henüz başlanmadı', () {
      final stats = SrsEngine.topicStats([
        // Normal grup: attempts = 5.
        _card('1', topic: 'zayıf', repetitions: 2, lapses: 3), // %40
        _card('2', topic: 'güçlü', repetitions: 4, lapses: 1), // %80
        // Az veri: tek deneme, tek hata → %0. Eski sıralamada "en zayıf"
        // olarak EN ÜSTTE çıkardı; artık normal konuların ALTINDA olmalı.
        _card('3', topic: 'azveri', lapses: 1),
        _card('4', topic: 'yeni'),
      ]);

      expect(stats.map((s) => s.topic).toList(), [
        'zayıf',
        'güçlü',
        'azveri',
        'yeni',
      ]);
      expect(stats[2].successPercent, 0); // yüzdesi düşük ama üste çıkmadı
    });

    test('az veri / henüz başlanmadı grupları kendi içinde deterministik', () {
      final stats = SrsEngine.topicStats([
        _card('1', topic: 'azTek', lapses: 1),
        _card('2', topic: 'azÇift', lapses: 1),
        _card('3', topic: 'azÇift', lapses: 1),
        _card('4', topic: 'yeniTek'),
        _card('5', topic: 'yeniÇift'),
        _card('6', topic: 'yeniÇift'),
      ]);

      // Grup içinde kart sayısı fazla olan önce, sonra ada göre.
      expect(stats.map((s) => s.topic).toList(), [
        'azÇift',
        'azTek',
        'yeniÇift',
        'yeniTek',
      ]);
    });
  });

  group('TopicSuccessBar — veri durumu etiketleri', () {
    testWidgets('az veride yüzde yerine "Az veri" ve gri çubuk', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        _stat(attempts: _threshold - 1, successRate: 0),
      );

      expect(find.text('Az veri'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      final scheme = AppTheme.light.colorScheme;
      expect(_barColor(tester), scheme.outlineVariant);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0);
    });

    testWidgets('hiç çalışılmamış konuda "Henüz başlanmadı"', (tester) async {
      await _pumpBar(tester, _stat(attempts: 0, successRate: 0));

      expect(find.text('Henüz başlanmadı'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(_barColor(tester), AppTheme.light.colorScheme.outlineVariant);
    });

    testWidgets('eşiği geçen konu yüzdeyi gösterir', (tester) async {
      await _pumpBar(tester, _stat(attempts: _threshold, successRate: 0.4));

      expect(find.text('%40'), findsOneWidget);
      expect(find.text('Az veri'), findsNothing);
    });

    testWidgets('bayrak kapalıyken az veride bile yüzde gösterilir', (
      tester,
    ) async {
      // Deneme Sınavı sonuç ekranının davranışı: orada attempts = soru
      // sayısı, 1 soruluk konu da yüzdesini göstermeli.
      await _pumpBar(
        tester,
        _stat(attempts: 1, successRate: 1),
        showLowDataStates: false,
      );

      expect(find.text('%100'), findsOneWidget);
      expect(find.text('Az veri'), findsNothing);
    });
  });

  group('TopicSuccessBar — renk kademesi', () {
    testWidgets('düşük başarı kırmızı DEĞİL amber', (tester) async {
      await _pumpBar(tester, _stat(attempts: _threshold, successRate: 0.1));

      final scheme = AppTheme.light.colorScheme;
      expect(_barColor(tester), isNot(scheme.error));
      expect(_barColor(tester), scheme.primary);
    });

    testWidgets('yüksek başarı yeşil', (tester) async {
      await _pumpBar(tester, _stat(attempts: _threshold, successRate: 0.9));

      expect(_barColor(tester), AppTheme.accentGreenOnLight);
    });
  });
}
