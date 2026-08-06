import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/pdf_page.dart';
import '../models/topic_segment.dart';
import 'gemini_service.dart';
import 'gemini_transport.dart';

/// PDF'in tam (vision + metin) pipeline'ından ÖNCE çalışan ucuz ön-tarama.
///
/// Yalnızca [PdfPage.text]'in kısa bir örneğini (bkz. [sampleCharsPerPage])
/// kullanır — görsel/vision hiç gönderilmez, her sayfa için ayrı çağrı da
/// atılmaz. Amaç: PDF'teki ana konu başlıklarını sayfa aralıklarıyla tespit
/// edip kullanıcıya seçtirmek (bkz. `PdfTopicSelectionScreen`), böylece
/// istenmeyen konuların sayfaları pahalı pipeline'a hiç girmez.
///
/// Hata toleranslı: ağ/parse sorununda İSTİSNA FIRLATMAZ, `null` döner —
/// çağıran taraf bunu "tarama başarısız, eski davranışa (tüm sayfalar) düş"
/// sinyali olarak kullanır. Bu adım bir maliyet optimizasyonu, kullanıcıyı
/// asla engellememeli.
class TopicScanService {
  TopicScanService({
    http.Client? client,
    Duration retryBackoff = const Duration(seconds: 1),
    int? thinkingBudget = 0,
  }) : _transport = GeminiTransport(client: client, retryBackoff: retryBackoff),
       _thinkingBudget = thinkingBudget;

  final GeminiTransport _transport;
  final int? _thinkingBudget;

  /// Tek istekte taranacak en fazla sayfa sayısı. Çok büyük PDF'ler bu
  /// büyüklükte parçalara bölünüp ayrı ayrı taranır (yine de sayfa başına
  /// değil, parça başına tek çağrı).
  static const int maxPagesPerBatch = 150;

  /// Her sayfadan alınan örnek metnin en fazla karakter uzunluğu. Tam sayfa
  /// metni GÖNDERİLMEZ — amaç ucuz kalmak, sınıflandırmaya yetecek kadar
  /// bağlam yeterli.
  static const int sampleCharsPerPage = 200;

  static const Map<String, dynamic> _responseSchema = {
    'type': 'ARRAY',
    'items': {
      'type': 'OBJECT',
      'properties': {
        'konu': {'type': 'STRING'},
        'ilkSayfa': {'type': 'INTEGER'},
        'sonSayfa': {'type': 'INTEGER'},
      },
      'required': ['konu', 'ilkSayfa', 'sonSayfa'],
    },
  };

  /// [pages] için konu/sayfa-aralığı taraması yapar. Başarısız olursa `null`.
  Future<List<TopicSegment>?> scan(List<PdfPage> pages) async {
    if (pages.isEmpty) return null;

    try {
      final segments = <TopicSegment>[];
      for (var start = 0; start < pages.length; start += maxPagesPerBatch) {
        final batch = pages.sublist(
          start,
          (start + maxPagesPerBatch).clamp(0, pages.length),
        );
        final batchSegments = await _scanBatch(batch);
        if (batchSegments == null) return null;
        segments.addAll(batchSegments);
      }
      return _normalize(segments, totalPages: pages.length);
    } catch (e) {
      debugPrint('Konu taraması başarısız: $e');
      return null;
    }
  }

  Future<List<TopicSegment>?> _scanBatch(List<PdfPage> pages) async {
    final firstPage = pages.first.page;
    final lastPage = pages.last.page;

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(pages, firstPage: firstPage, lastPage: lastPage)},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
        'temperature': 0.2,
        'maxOutputTokens': 4096,
        if (_thinkingBudget != null)
          'thinkingConfig': {'thinkingBudget': _thinkingBudget},
      },
    });

    final response = await _transport.send(model: GeminiService.model, body: body);
    if (response.statusCode != 200) return null;

    return _parse(response.body, firstPage: firstPage, lastPage: lastPage);
  }

  String _buildPrompt(
    List<PdfPage> pages, {
    required int firstPage,
    required int lastPage,
  }) {
    final buffer = StringBuffer();
    for (final p in pages) {
      final sample = p.text.trim();
      final snippet = sample.length > sampleCharsPerPage
          ? sample.substring(0, sampleCharsPerPage)
          : sample;
      buffer.writeln('--- Sayfa ${p.page} ---');
      buffer.writeln(snippet.isEmpty ? '(metin yok)' : snippet);
    }

    return '''
Aşağıda bir ders slaytının $firstPage-$lastPage arası sayfalarından kısa metin örnekleri var (her sayfadan yalnızca ilk birkaç satır). Görevin bu sayfaları ANA KONU BAŞLIKLARINA göre ardışık gruplara ayırmak.

KURALLAR:
- Sayfa $firstPage'den $lastPage'e kadar HER sayfa mutlaka bir gruba dahil olsun, hiçbir sayfayı dışarıda bırakma.
- Gruplar sayfa numarasına göre ARDIŞIK olsun (bir grup bitmeden yeni grup başlamasın; aynı konuya ait sayfalar birbirinden kopmasın).
- Konu adı kısa olsun (1-4 kelime), üst düzey ders başlığını yansıtsın (ör. "Kemik Doku", "Eklemler", "Kas Kasılması").
- Bir sayfanın örneği çok kısa/anlamsız olsa bile (başlık/ajanda/geçiş sayfası gibi) en yakın komşu konuya dahil et, ayrı "boş" grup açma.
- Yanıtın yalnızca istenen şemadaki JSON dizisi olsun.

SAYFA ÖRNEKLERİ:
${buffer.toString()}
''';
  }

  /// Yanıtı hoşgörülü ayrıştırır: sorun olursa (boş/bozuk/beklenmedik tip)
  /// istisna fırlatmadan `null` döner.
  List<TopicSegment>? _parse(
    String body, {
    required int firstPage,
    required int lastPage,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['error'] != null) return null;

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final candidate = candidates.first;
    if (candidate is! Map) return null;

    final rawText = _extractText(Map<String, dynamic>.from(candidate));
    if (rawText == null || rawText.trim().isEmpty) return null;

    Object? inner;
    try {
      inner = jsonDecode(rawText);
    } catch (_) {
      return null;
    }
    if (inner is! List) return null;

    final segments = <TopicSegment>[];
    for (final item in inner) {
      if (item is! Map) continue;
      final topic = (item['konu'] as Object?)?.toString().trim() ?? '';
      final start = (item['ilkSayfa'] as num?)?.toInt();
      final end = (item['sonSayfa'] as num?)?.toInt();
      if (topic.isEmpty || start == null || end == null) continue;

      final lo = start <= end ? start : end;
      final hi = start <= end ? end : start;
      segments.add(
        TopicSegment(
          topic: topic,
          startPage: lo.clamp(firstPage, lastPage),
          endPage: hi.clamp(firstPage, lastPage),
        ),
      );
    }
    return segments;
  }

  String? _extractText(Map<String, dynamic> candidate) {
    final content = candidate['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List) return null;

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      if (part['text'] is String) buffer.write(part['text'] as String);
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  /// Ham segmentleri sayfa numarasına göre sıralar, çakışmaları keser (bir
  /// sonrakini öncekinin bitişinden sonra başlatır) ve model tarafından hiç
  /// kapsanmayan sayfaları "Sınıflandırılmamış" segmentiyle doldurur — hiçbir
  /// sayfa sessizce kaybolmasın diye.
  List<TopicSegment> _normalize(
    List<TopicSegment> raw, {
    required int totalPages,
  }) {
    if (totalPages <= 0) return const [];

    final sorted = [...raw]..sort((a, b) => a.startPage.compareTo(b.startPage));

    final result = <TopicSegment>[];
    var nextExpectedPage = 1;

    for (final segment in sorted) {
      final start = segment.startPage < nextExpectedPage
          ? nextExpectedPage
          : segment.startPage;
      final end = segment.endPage;
      if (start > end || start > totalPages) continue;

      if (start > nextExpectedPage) {
        result.add(
          TopicSegment(
            topic: 'Sınıflandırılmamış',
            startPage: nextExpectedPage,
            endPage: start - 1,
          ),
        );
      }

      result.add(
        TopicSegment(
          topic: segment.topic,
          startPage: start,
          endPage: end.clamp(start, totalPages),
        ),
      );
      nextExpectedPage = end.clamp(start, totalPages) + 1;
    }

    if (nextExpectedPage <= totalPages) {
      result.add(
        TopicSegment(
          topic: 'Sınıflandırılmamış',
          startPage: nextExpectedPage,
          endPage: totalPages,
        ),
      );
    }

    return result;
  }
}
