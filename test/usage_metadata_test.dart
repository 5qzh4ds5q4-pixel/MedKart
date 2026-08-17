import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/usage_metadata.dart';

void main() {
  group('UsageMetadata.tryParse', () {
    test('tam bir usageMetadata bloğunu okur', () {
      final body =
          jsonDecode('''
        {
          "candidates": [],
          "usageMetadata": {
            "promptTokenCount": 7688,
            "cachedContentTokenCount": 6101,
            "candidatesTokenCount": 1080,
            "totalTokenCount": 8768
          }
        }
      ''')
              as Map<String, dynamic>;

      final usage = UsageMetadata.tryParse(body)!;
      expect(usage.promptTokens, 7688);
      expect(usage.cachedTokens, 6101);
      expect(usage.outputTokens, 1080);
      expect(usage.totalTokens, 8768);
    });

    test('cachedContentTokenCount yoksa 0 sayılır (cache isabet etmemiş)', () {
      final body = {
        'usageMetadata': {
          'promptTokenCount': 7688,
          'candidatesTokenCount': 1080,
        },
      };

      final usage = UsageMetadata.tryParse(body)!;
      expect(usage.cachedTokens, 0);
      expect(usage.cacheHitPercent, 0);
    });

    test('usageMetadata bloğu hiç yoksa null döner', () {
      expect(UsageMetadata.tryParse({'candidates': []}), isNull);
    });

    test('usageMetadata Map değilse null döner (fırlatmaz)', () {
      expect(UsageMetadata.tryParse({'usageMetadata': 'bozuk'}), isNull);
    });

    test('sayı olmayan alanlar null olur, çökmez', () {
      final usage = UsageMetadata.tryParse({
        'usageMetadata': {'promptTokenCount': 'çok', 'candidatesTokenCount': 5},
      })!;
      expect(usage.promptTokens, isNull);
      expect(usage.outputTokens, 5);
    });
  });

  group('cacheHitPercent', () {
    test('girdinin önbellekten karşılanan oranını verir', () {
      const usage = UsageMetadata(
        promptTokens: 7688,
        cachedTokens: 6101,
        outputTokens: 1080,
        thoughtsTokens: 0,
        totalTokens: 8768,
      );
      // 6101 / 7688 = %79 — v28 sonrası BEKLENEN mertebe.
      expect(usage.cacheHitPercent, 79);
    });

    test('girdi 0/bilinmiyorsa null döner (sıfıra bölme yok)', () {
      const bilinmiyor = UsageMetadata(
        promptTokens: null,
        cachedTokens: 0,
        outputTokens: null,
        thoughtsTokens: null,
        totalTokens: null,
      );
      expect(bilinmiyor.cacheHitPercent, isNull);

      const sifir = UsageMetadata(
        promptTokens: 0,
        cachedTokens: 0,
        outputTokens: null,
        thoughtsTokens: null,
        totalTokens: null,
      );
      expect(sifir.cacheHitPercent, isNull);
    });
  });

  group('describe', () {
    test('cache isabet ettiğinde oranı da yazar', () {
      const usage = UsageMetadata(
        promptTokens: 7688,
        cachedTokens: 6101,
        outputTokens: 1080,
        thoughtsTokens: 0,
        totalTokens: 8768,
      );
      final satir = usage.describe('s.12');
      expect(satir, contains('s.12'));
      expect(satir, contains('cache=6101'));
      expect(satir, contains('%79'));
    });

    test('cache isabet etmediğinde açıkça "YOK" yazar', () {
      const usage = UsageMetadata(
        promptTokens: 7688,
        cachedTokens: 0,
        outputTokens: 1080,
        thoughtsTokens: 0,
        totalTokens: 8768,
      );
      expect(usage.describe('s.1'), contains('cache=YOK'));
    });

    test('thinking tokenı sıfırdan büyükse dikkat çeker', () {
      const usage = UsageMetadata(
        promptTokens: 100,
        cachedTokens: 0,
        outputTokens: 50,
        thoughtsTokens: 900,
        totalTokens: 1050,
      );
      // thinkingBudget: 0 iken bu ASLA olmamalı — log gözden kaçmasın.
      expect(usage.describe('s.1'), contains('thinking=900(!)'));
    });

    test('thinking 0 iken satırı kirletmez', () {
      const usage = UsageMetadata(
        promptTokens: 100,
        cachedTokens: 0,
        outputTokens: 50,
        thoughtsTokens: 0,
        totalTokens: 150,
      );
      expect(usage.describe('s.1'), isNot(contains('thinking')));
    });
  });
}
