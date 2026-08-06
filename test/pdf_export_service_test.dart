import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/models/deck.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/pdf_export_service.dart';

Flashcard _card(
  String id, {
  CardPriority priority = CardPriority.oncelikli,
  CardDifficulty difficulty = CardDifficulty.orta,
  CardType cardType = CardType.temel,
  String question = 'Soru?',
  String answer = 'Cevap.',
  bool isHandwritten = false,
}) => Flashcard(
  id: id,
  question: question,
  answer: answer,
  priority: priority,
  difficulty: difficulty,
  cardType: cardType,
  topic: 'konu',
  isHandwritten: isHandwritten,
);

/// PDF'in kaç sayfa içerdiğini kaba biçimde sayar: `/Type /Page` sözlük
/// girdileri (bkz. `/Type /Pages` kök nesnesiyle karışmasın diye ardından
/// boşluk/kapanış arandı) içerik akışı sıkıştırılsa da düz metin kalır.
int _countPages(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  final regex = RegExp(r'/Type\s*/Page[^s]');
  return regex.allMatches(text).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final deck = Deck(id: 'd1', name: 'Anatomi', createdAt: DateTime(2026, 1, 1));

  test('geçerli bir PDF üretir (%PDF başlığı)', () async {
    final bytes = await PdfExportService.instance.buildPdf(
      deck: deck,
      allCards: [_card('1'), _card('2')],
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test(
    'TÜM kartlar dahil edilir: "oncelikli" VE "arkaPlan" hiçbiri atlanmaz',
    () async {
      final cards = [
        _card('1'),
        _card('2'),
        _card('3'),
        _card('4'),
        _card('5', priority: CardPriority.arkaPlan),
        _card('6', priority: CardPriority.arkaPlan),
      ];

      final bytes = await PdfExportService.instance.buildPdf(
        deck: deck,
        allCards: cards,
      );

      // 6 kart / 3 kart-başına-sayfa = 2 kart sayfası + 1 kapak = 3.
      expect(_countPages(bytes), 3);
    },
  );

  test('isHandwritten kartlar da dahil edilir', () async {
    final cards = [
      _card('1'),
      _card('2', isHandwritten: true),
    ];

    final bytes = await PdfExportService.instance.buildPdf(
      deck: deck,
      allCards: cards,
    );

    // 2 kart / 3 kart-başına-sayfa = 1 kart sayfası + 1 kapak = 2.
    expect(_countPages(bytes), 2);
  });

  test('hiç kart yoksa sadece kapak sayfası üretilir', () async {
    final bytes = await PdfExportService.instance.buildPdf(
      deck: deck,
      allCards: const [],
    );

    expect(_countPages(bytes), 1);
  });

  test(
    'kart sayısı korunur ve PDF sayfa sayısı buna göre hesaplanır '
    '(167 kart → 167 kart, sayfa sınırından bağımsız)',
    () async {
      // _cardsPerPage = 3: 167 kart → ceil(167/3)=56 kart sayfası + 1 kapak = 57.
      final cards = List.generate(167, (i) => _card('${i + 1}'));

      final bytes = await PdfExportService.instance.buildPdf(
        deck: deck,
        allCards: cards,
      );

      expect(_countPages(bytes), 57);
    },
  );

  test(
    'numberedCards: numaralandırma 1\'den başlar, desteki kart sırasıyla '
    'AYNI sırada artar, hiçbir kart atlanmaz — sayfa sınırından bağımsız',
    () {
      // Kartların gerçek PDF ikili içeriğinden metin geri okumak, gömülü TTF
      // fontun glyph eşlemesi yüzünden güvenilir değil; bu yüzden numara
      // atama mantığı [buildPdf]'in de kullandığı bu saf fonksiyon üzerinden
      // doğrudan test edilir (bkz. PdfExportService.numberedCards doc'u).
      final cards = List.generate(167, (i) => _card('kart-$i'));

      final numbered = PdfExportService.instance.numberedCards(cards);

      expect(numbered.length, 167);
      for (var i = 0; i < numbered.length; i++) {
        final (number, card) = numbered[i];
        expect(number, i + 1, reason: 'index $i için numara ${i + 1} olmalı');
        expect(card.id, 'kart-$i', reason: 'sıra desteki kart sırasıyla aynı olmalı');
      }
    },
  );

  test('Türkçe karakterli kartlar hatasız işlenir', () async {
    final bytes = await PdfExportService.instance.buildPdf(
      deck: deck,
      allCards: [
        _card(
          '1',
          question: 'Şıtma hangi vektörle bulaşır? Öğün, çiğ süt, ığdır.',
          answer: 'Anofel cinsi sivrisinek (dişi) ısırığıyla İnsan\'a bulaşır.',
        ),
      ],
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('suggestedFileName: boşluk korunur, geçersiz karakterler temizlenir', () {
    final service = PdfExportService.instance;
    expect(service.suggestedFileName('Komite 1: Kalp/Damar'), 'Komite 1- Kalp-Damar_kartlar.pdf');
    expect(service.suggestedFileName('Anatomi'), 'Anatomi_kartlar.pdf');
  });
}
