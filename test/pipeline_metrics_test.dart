import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/pdf_card_pipeline.dart';
import 'package:medcard/services/pipeline_metrics_service.dart';

Flashcard _card(String id) =>
    Flashcard(id: id, question: 'S-$id', answer: 'C-$id');

PipelineResult _result({
  int totalPages = 10,
  List<int> emptyText = const [],
  List<int> emptyResult = const [],
  List<int> failed = const [],
  int cards = 0,
  bool quota = false,
}) => PipelineResult(
  totalPages: totalPages,
  cards: [for (var i = 0; i < cards; i++) _card('$i')],
  emptyTextPages: emptyText,
  emptyResultPages: emptyResult,
  failedPages: failed,
  quotaExhausted: quota,
);

void main() {
  group('PipelineMetricsService.buildRow', () {
    test('sayfa sonucu kategorilerini ayrı ayrı yazar', () {
      final row = PipelineMetricsService.buildRow(
        _result(
          totalPages: 10,
          emptyText: [9],
          emptyResult: [1, 4],
          failed: [7],
          cards: 24,
        ),
        userId: 'u1',
        pdfHash: 'abc',
        visionEnabled: true,
        modelVersion: 'gemini-3.5-flash',
        promptVersion: 'v28',
      );

      expect(row['toplam_sayfa'], 10);
      expect(row['metin_yok_sayfa'], 1);
      expect(row['hatali_sayfa'], 1);
      expect(row['bos_donen_sayfa'], 2);
      expect(row['kart_ureten_sayfa'], 6);
      expect(row['uretilen_kart'], 24);
      expect(row['bos_sayfa_no'], [1, 4]);
      expect(row['user_id'], 'u1');
      expect(row['pdf_hash'], 'abc');
      expect(row['gorsel_acik'], true);
      expect(row['model_version'], 'gemini-3.5-flash');
      expect(row['prompt_version'], 'v28');
      expect(row['kota_kesildi'], false);
    });

    test(
      'paydalar toplamı toplam_sayfa\'ya eşit — oran hesabı bu eşitliğe '
      'dayanıyor, yeni bir kategori eklersen bu test kırılır',
      () {
        for (final r in [
          _result(totalPages: 10, emptyResult: [2], cards: 9),
          _result(totalPages: 6, emptyText: [1, 2], failed: [3], cards: 3),
          _result(
            totalPages: 8,
            emptyText: [8],
            emptyResult: [1, 2, 3],
            failed: [4],
            cards: 5,
          ),
          _result(totalPages: 3),
        ]) {
          final row = PipelineMetricsService.buildRow(r, userId: 'u');
          final toplam =
              (row['metin_yok_sayfa'] as int) +
              (row['hatali_sayfa'] as int) +
              (row['bos_donen_sayfa'] as int) +
              (row['kart_ureten_sayfa'] as int);
          expect(toplam, row['toplam_sayfa']);
        }
      },
    );

    test('hiç kart üretmeyen çalıştırma da kaydedilebilir (tüm sayfalar boş)', () {
      final row = PipelineMetricsService.buildRow(
        _result(totalPages: 4, emptyResult: [1, 2, 3, 4]),
        userId: 'u',
      );

      expect(row['bos_donen_sayfa'], 4);
      expect(row['kart_ureten_sayfa'], 0);
      expect(row['uretilen_kart'], 0);
    });

    test('daraltılmış çalıştırmada pdf_hash null kalır', () {
      final row = PipelineMetricsService.buildRow(
        _result(totalPages: 2, cards: 3),
        userId: 'u',
      );

      expect(row['pdf_hash'], isNull);
      expect(row.containsKey('pdf_hash'), isTrue);
    });

    test('kota kesintisi işaretlenir', () {
      final row = PipelineMetricsService.buildRow(
        _result(totalPages: 5, failed: [3], cards: 4, quota: true),
        userId: 'u',
      );

      expect(row['kota_kesildi'], true);
    });
  });

  test('Supabase yapılandırılmadıysa record() sessizce no-op (fırlatmaz)', () async {
    // Supabase.initialize hiç çağrılmadı → _client null → hiçbir şey olmaz.
    await expectLater(
      PipelineMetricsService().record(_result(totalPages: 1)),
      completes,
    );
  });
}
