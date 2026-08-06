// Deste kartlarının TAMAMINI (öncelikli/arka plan/el yazısı fark etmeksizin,
// hiçbiri atlanmadan) indirilebilir bir PDF'e dönüştürür. Tamamen client-side
// (pdf paketi, saf Dart) — backend yok.
//
// TÜRKÇE KARAKTER DESTEĞİ: pdf paketinin gömülü Base14 fontları (Helvetica
// vb.) Türkçe'ye özgü ş/ğ/ı/İ gibi karakterleri içermez. Bu yüzden Noto Sans
// TTF gömülü olarak kullanılıyor (assets/fonts). Google Fonts artık bu
// aileyi "variable font" olarak sunduğundan (tek dosya, ağırlığı CSS ile
// seçiliyor) düz bir TTF okuyucu için işe yaramıyor; bunun yerine Fontsource
// paketinin sağladığı GERÇEKTEN STATİK ağırlık başına woff2 dosyaları
// woff2→sfnt açılarak (bkz. proje dışı bir kerelik dönüştürme scripti)
// buraya TTF olarak eklendi. "latin" alt kümesi ASCII + ı'yı, "latin-ext"
// alt kümesi Ğ/ğ/Ş/ş/İ gibi genişletilmiş Latin karakterleri kapsıyor; ikisi
// bir arada olmadığından her ağırlık için birincil+fallback font çifti
// kullanılıyor.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/deck.dart';
import '../models/flashcard.dart';

/// Bir kart + PDF'te göstereceği 1 tabanlı sıra numarası. Numara, gömülü
/// TTF fontun glyph eşlemesi nedeniyle üretilen PDF'in ikili içeriğinden
/// güvenilir biçimde geri okunamaz (bkz. test dosyasındaki not) — bu yüzden
/// numaralandırma [PdfExportService.numberedCards] içinde ayrı, saf bir
/// adımda üretilip doğrudan test edilir.
typedef NumberedCard = (int number, Flashcard card);

class PdfExportService {
  PdfExportService._();

  static final PdfExportService instance = PdfExportService._();

  pw.Font? _regular;
  pw.Font? _regularExt;
  pw.Font? _bold;
  pw.Font? _boldExt;

  static const int _cardsPerPage = 3;

  static final _bgDark = PdfColor.fromHex('#0f172a');
  static final _cardBg = PdfColor.fromHex('#1e293b');
  static final _textMain = PdfColor.fromHex('#f1f5f9');
  static final _textMuted = PdfColor.fromHex('#cbd5e1');
  static final _metaColor = PdfColor.fromHex('#94a3b8');
  static final _sinavAccent = PdfColor.fromHex('#818cf8');
  static final _handwrittenBg = PdfColor.fromHex('#3a2a17');
  static final _handwrittenFg = PdfColor.fromHex('#fb923c');
  static const Map<CardDifficulty, String> _difficultyHex = {
    CardDifficulty.kolay: '#22c55e',
    CardDifficulty.orta: '#f59e0b',
    CardDifficulty.zor: '#ef4444',
  };

  Future<void> _ensureFonts() async {
    if (_regular != null) return;
    _regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular-latin.ttf'),
    );
    _regularExt = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular-latin-ext.ttf'),
    );
    _bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold-latin.ttf'),
    );
    _boldExt = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold-latin-ext.ttf'),
    );
  }

  pw.TextStyle get _bodyStyle =>
      pw.TextStyle(font: _regular, fontFallback: [_regularExt!], fontSize: 10.5, color: _textMuted);

  pw.TextStyle get _questionStyle =>
      pw.TextStyle(font: _bold, fontFallback: [_boldExt!], fontSize: 13, color: _textMain);

  pw.TextStyle get _metaStyle =>
      pw.TextStyle(font: _regular, fontFallback: [_regularExt!], fontSize: 8.5, color: _metaColor);

  pw.TextStyle get _numberStyle =>
      pw.TextStyle(font: _bold, fontFallback: [_boldExt!], fontSize: 12, color: _metaColor);

  /// [Flashcard.hasShortAnswer] kartlarda soru altında öne çıkan kısa cevap.
  pw.TextStyle get _shortAnswerStyle =>
      pw.TextStyle(font: _bold, fontFallback: [_boldExt!], fontSize: 10.5, color: _textMain);

  /// Kısa cevabın altındaki "Açıklama:" başlığı.
  pw.TextStyle get _explanationLabelStyle =>
      pw.TextStyle(font: _bold, fontFallback: [_boldExt!], fontSize: 8, color: _metaColor);

  pw.TextStyle get _handwrittenBadgeStyle => pw.TextStyle(
    font: _bold,
    fontFallback: [_boldExt!],
    fontSize: 7,
    color: _handwrittenFg,
  );

  /// [Flashcard.isHandwritten] kartlarda numaranın yanına konan küçük rozet.
  /// Yalnızca numara/başlık satırında durur — soru metnine karışmaz.
  pw.Widget _handwrittenBadge() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 2),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: pw.BoxDecoration(
        color: _handwrittenBg,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text('Hoca vurgusu', style: _handwrittenBadgeStyle),
    );
  }

  /// [allCards]'ın her elemanına, listedeki 0 tabanlı konumuna göre 1'den
  /// başlayan bir sıra numarası verir. Ayrı, saf bir adım olarak tutulur ki
  /// numaralandırma mantığı PDF ikili çıktısına bakmadan doğrudan test
  /// edilebilsin (gömülü TTF font glyph eşlemesi yüzünden üretilen PDF'in
  /// içeriğinden metin geri okumak güvenilir değil).
  @visibleForTesting
  List<NumberedCard> numberedCards(List<Flashcard> allCards) => [
    for (var i = 0; i < allCards.length; i++) (i + 1, allCards[i]),
  ];

  /// [deck]'in [allCards]'ının TAMAMINI PDF baytlarına dönüştürür — öncelik/
  /// zorluk/el yazısı kaynağı fark etmeksizin hiçbir kart filtrelenmez. Her
  /// kart [numberedCards] ile 1'den başlayan bir numarayla damgalanır.
  Future<Uint8List> buildPdf({
    required Deck deck,
    required List<Flashcard> allCards,
  }) async {
    await _ensureFonts();

    final cards = numberedCards(allCards);

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _coverPage(deck, allCards),
      ),
    );

    for (var i = 0; i < cards.length; i += _cardsPerPage) {
      final pageCards = cards.skip(i).take(_cardsPerPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _cardsPage(pageCards),
        ),
      );
    }

    return doc.save();
  }

  /// Dosya sisteminde geçersiz karakterleri temizlenmiş dosya adı üretir.
  /// Boşluklar KORUNUR (istenen biçim: "[deck_adı]_kartlar.pdf").
  String suggestedFileName(String deckName) {
    final safe = deckName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    return '${safe.isEmpty ? 'deste' : safe}_kartlar.pdf';
  }

  pw.Widget _coverPage(Deck deck, List<Flashcard> cards) {
    final total = cards.length;
    final sinav = cards.where((c) => c.isExamType).length;
    final kolay = cards.where((c) => c.difficulty == CardDifficulty.kolay).length;
    final orta = cards.where((c) => c.difficulty == CardDifficulty.orta).length;
    final zor = cards.where((c) => c.difficulty == CardDifficulty.zor).length;

    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      color: _bgDark,
      padding: const pw.EdgeInsets.all(48),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            deck.name,
            style: pw.TextStyle(
              font: _bold,
              fontFallback: [_boldExt!],
              fontSize: 26,
              color: _textMain,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('MedKart · Kart Özeti', style: _metaStyle),
          pw.SizedBox(height: 32),
          _summaryLine('Toplam kart', '$total'),
          _summaryLine('Sınav tipi kart', '$sinav'),
          pw.SizedBox(height: 12),
          _summaryLine('Kolay', '$kolay', color: PdfColor.fromHex(_difficultyHex[CardDifficulty.kolay]!)),
          _summaryLine('Orta', '$orta', color: PdfColor.fromHex(_difficultyHex[CardDifficulty.orta]!)),
          _summaryLine('Zor', '$zor', color: PdfColor.fromHex(_difficultyHex[CardDifficulty.zor]!)),
        ],
      ),
    );
  }

  pw.Widget _summaryLine(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Container(
            width: 10,
            height: 10,
            margin: const pw.EdgeInsets.only(right: 8),
            decoration: pw.BoxDecoration(
              color: color ?? _textMuted,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Text('$label: ', style: _bodyStyle),
          pw.Text(value, style: _questionStyle.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  static const double _pagePadding = 24;
  static const double _cardGap = 16;

  /// Sabit kart yüksekliği: her zaman "sayfa başına 3 kart" varsayımıyla
  /// hesaplanır. Böylece son sayfada 3'ten az kart kalsa bile kartlar aynı
  /// boyutta kalır — tek kart tüm sayfaya gerilip boş alanı doldurmaz.
  double get _cardHeight {
    final contentHeight = PdfPageFormat.a4.height - _pagePadding * 2;
    return (contentHeight - _cardGap * (_cardsPerPage - 1)) / _cardsPerPage;
  }

  pw.Widget _cardsPage(List<NumberedCard> cards) {
    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      color: _bgDark,
      padding: const pw.EdgeInsets.all(_pagePadding),
      child: pw.Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) pw.SizedBox(height: _cardGap),
            pw.SizedBox(height: _cardHeight, child: _cardBlock(cards[i])),
          ],
        ],
      ),
    );
  }

  pw.Widget _cardBlock(NumberedCard entry) {
    final (number, card) = entry;
    final difficultyColor = PdfColor.fromHex(_difficultyHex[card.difficulty]!);
    final isExam = card.isExamType;

    // pdf paketinde borderRadius + Border aynı BoxDecoration'da birlikte
    // kullanılamıyor (yalnızca uniform Border'a izin var). Sınav tipi mor
    // aksanı bu yüzden ayrı bir sol şerit olarak Row'a ekleniyor, kartın
    // kendi köşe yuvarlaması buna dokunmuyor.
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (isExam)
          pw.Container(width: 4, color: _sinavAccent)
        else
          pw.SizedBox(width: 4),
        pw.Expanded(child: _cardSurface(card, difficultyColor, number)),
      ],
    );
  }

  pw.Widget _cardSurface(Flashcard card, PdfColor difficultyColor, int number) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _cardBg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Zorluk şeridi.
          pw.Container(
            height: 6,
            decoration: pw.BoxDecoration(
              color: difficultyColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1, right: 6),
                    child: pw.Text('$number.', style: _numberStyle),
                  ),
                  if (card.isHandwritten) ...[
                    _handwrittenBadge(),
                    pw.SizedBox(width: 6),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(card.question, style: _questionStyle),
                            pw.SizedBox(height: 6),
                            if (card.hasShortAnswer) ...[
                              pw.Text(card.shortAnswer, style: _shortAnswerStyle),
                              pw.SizedBox(height: 4),
                              pw.Text('Açıklama:', style: _explanationLabelStyle),
                              pw.SizedBox(height: 2),
                              pw.Text(card.answer, style: _bodyStyle),
                            ] else
                              pw.Text(card.answer, style: _bodyStyle),
                          ],
                        ),
                        pw.Text(_metaLine(card), style: _metaStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine(Flashcard card) {
    final parts = <String>[];
    if (card.hasTopic) parts.add(card.topic);
    if (card.hasSourcePage) parts.add('s.${card.sourcePage}');
    parts.add('${card.difficulty.label} · ${card.cardType.label}');
    return parts.join(' · ');
  }
}
