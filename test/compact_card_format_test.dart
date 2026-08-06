import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/services/flashcard_prompt.dart' as prompt;
import 'package:medcard/services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KOMPAKT KART BİÇİMİ (2026-08-04): model artık her kartı alan adlı bir nesne
/// yerine sırası sabit bir dizi olarak döndürüyor (çıktı token maliyeti için).
/// Bu dosya dönüşümün doğruluğunu ve — en kritiği — BOZUK/eksik dizilerde
/// çökmediğini doğrular: öğrenciye giden veri hiç değişmemeli.
///
/// Beklenen sıra:
/// [soru, kisaCevap, cevap, zorlukKodu, kartTipiKodu, oncelikKodu, konu,
///  slaytNumarasi, elYazisindanMi]

/// Tam dolu, geçerli bir kompakt kart.
List<Object?> _kart({
  Object? soru = 'Kalp kaç odacıklıdır?',
  Object? kisaCevap = 'Dört odacık',
  Object? cevap = 'Kalpte iki atriyum ve iki ventrikül vardır.',
  Object? zorluk = 'k',
  Object? kartTipi = 't',
  Object? oncelik = 'o',
  Object? konu = 'genel yapı',
  Object? slaytNumarasi,
  Object? elYazisindanMi = 'false',
}) {
  return [
    soru,
    kisaCevap,
    cevap,
    zorluk,
    kartTipi,
    oncelik,
    konu,
    slaytNumarasi,
    elYazisindanMi,
  ];
}

Flashcard? _decode(Object? item, {int? sourcePage}) =>
    prompt.flashcardFromCompactItem(item, id: 'test-id', sourcePage: sourcePage);

/// Gemini'ın gerçek yanıt zarfını taklit eder (uçtan uca testler için).
String _geminiEnvelope(Object modelJson) {
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': jsonEncode(modelJson)},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  });
}

const _validInput =
    'Kalp dört odacıklı bir kas organdır. Sağ atriyum vena cava yoluyla '
    'oksijenden fakir kanı alır ve sağ ventriküle iletir.';

void main() {
  group('pozisyon eşlemesi', () {
    test('tam dolu dizi tüm alanlara doğru sırayla yerleşir', () {
      final card = _decode(
        _kart(
          soru: 'N. axillaris hasarında ne olur?',
          kisaCevap: 'Kol abduksiyonu kaybolur',
          cevap: 'Deltoid kası inerve edemez, omuz abduksiyonu yapılamaz.',
          zorluk: 'z',
          kartTipi: 's',
          oncelik: 'a',
          konu: 'brakial pleksus',
          slaytNumarasi: '24',
          elYazisindanMi: 'true',
        ),
      );

      expect(card, isNotNull);
      expect(card!.question, 'N. axillaris hasarında ne olur?');
      expect(card.shortAnswer, 'Kol abduksiyonu kaybolur');
      expect(
        card.answer,
        'Deltoid kası inerve edemez, omuz abduksiyonu yapılamaz.',
      );
      expect(card.difficulty, CardDifficulty.zor);
      expect(card.cardType, CardType.sinav);
      expect(card.priority, CardPriority.arkaPlan);
      expect(card.topic, 'brakial pleksus');
      expect(card.sourcePage, 24);
      expect(card.isHandwritten, isTrue);
    });

    test('sabit indeksler beklenen pozisyonları gösterir', () {
      // Sıra kayarsa tüm kartlar bozulur; indeksleri kilitle.
      expect(prompt.kompaktSoruIndex, 0);
      expect(prompt.kompaktKisaCevapIndex, 1);
      expect(prompt.kompaktCevapIndex, 2);
      expect(prompt.kompaktZorlukIndex, 3);
      expect(prompt.kompaktKartTipiIndex, 4);
      expect(prompt.kompaktOncelikIndex, 5);
      expect(prompt.kompaktKonuIndex, 6);
      expect(prompt.kompaktSlaytNumarasiIndex, 7);
      expect(prompt.kompaktElYazisiIndex, 8);
      expect(prompt.kompaktAlanSayisi, 9);
    });

    test('konu etiketi küçük harfe normalize edilir (eski davranış korunur)', () {
      final card = _decode(_kart(konu: '  Koroner Dolaşım  '));
      expect(card!.topic, 'koroner dolaşım');
    });
  });

  group('kısaltma kodu eşlemesi', () {
    test('zorluk: k/o/z doğru CardDifficulty verir', () {
      expect(_decode(_kart(zorluk: 'k'))!.difficulty, CardDifficulty.kolay);
      expect(_decode(_kart(zorluk: 'o'))!.difficulty, CardDifficulty.orta);
      expect(_decode(_kart(zorluk: 'z'))!.difficulty, CardDifficulty.zor);
    });

    test('kartTipi: t/s doğru CardType verir', () {
      expect(_decode(_kart(kartTipi: 't'))!.cardType, CardType.temel);
      expect(_decode(_kart(kartTipi: 's'))!.cardType, CardType.sinav);
    });

    test('oncelik: o/a doğru CardPriority verir', () {
      expect(_decode(_kart(oncelik: 'o'))!.priority, CardPriority.oncelikli);
      expect(_decode(_kart(oncelik: 'a'))!.priority, CardPriority.arkaPlan);
    });

    test('aynı harf farklı pozisyonda farklı anlam taşır ("o")', () {
      // [3]'te "o" = orta, [5]'te "o" = oncelikli. Karışırsa bu test düşer.
      final card = _decode(_kart(zorluk: 'o', oncelik: 'o'))!;
      expect(card.difficulty, CardDifficulty.orta);
      expect(card.priority, CardPriority.oncelikli);
    });

    test('kod yerine tam kelime yazılırsa da doğru çözülür', () {
      // Model kısaltmayı unutup "kolay"/"sinav"/"arka_plan" yazarsa kart
      // bozulmasın (şema kodları dayatıyor ama savunma ucuz).
      final card = _decode(
        _kart(zorluk: 'kolay', kartTipi: 'sinav', oncelik: 'arka_plan'),
      )!;
      expect(card.difficulty, CardDifficulty.kolay);
      expect(card.cardType, CardType.sinav);
      expect(card.priority, CardPriority.arkaPlan);
    });

    test('büyük harfli/boşluklu kod da kabul edilir', () {
      final card = _decode(_kart(zorluk: ' Z ', kartTipi: 'S', oncelik: 'A'))!;
      expect(card.difficulty, CardDifficulty.zor);
      expect(card.cardType, CardType.sinav);
      expect(card.priority, CardPriority.arkaPlan);
    });

    test('tanınmayan kod kartı ATMAZ, enum varsayılanına düşer', () {
      final card = _decode(
        _kart(zorluk: 'x', kartTipi: 'x', oncelik: 'x'),
      );
      expect(card, isNotNull);
      expect(card!.difficulty, CardDifficulty.orta);
      expect(card.cardType, CardType.temel);
      // Öncelik varsayılanı bilinçli olarak "oncelikli": kart Sınav Modu'nda
      // sessizce kaybolmasın.
      expect(card.priority, CardPriority.oncelikli);
    });

    test('null kodlar varsayılanlara düşer', () {
      final card = _decode(
        _kart(zorluk: null, kartTipi: null, oncelik: null),
      )!;
      expect(card.difficulty, CardDifficulty.orta);
      expect(card.cardType, CardType.temel);
      expect(card.priority, CardPriority.oncelikli);
    });
  });

  group('elYazisindanMi', () {
    test('"true" ve native true işaretlenir', () {
      expect(_decode(_kart(elYazisindanMi: 'true'))!.isHandwritten, isTrue);
      expect(_decode(_kart(elYazisindanMi: true))!.isHandwritten, isTrue);
      expect(_decode(_kart(elYazisindanMi: '1'))!.isHandwritten, isTrue);
      expect(_decode(_kart(elYazisindanMi: 'TRUE'))!.isHandwritten, isTrue);
    });

    test('"false"/null/çöp değerlerde false kalır (rozet yanlış takılmasın)', () {
      expect(_decode(_kart(elYazisindanMi: 'false'))!.isHandwritten, isFalse);
      expect(_decode(_kart(elYazisindanMi: false))!.isHandwritten, isFalse);
      expect(_decode(_kart(elYazisindanMi: null))!.isHandwritten, isFalse);
      expect(_decode(_kart(elYazisindanMi: 'evet'))!.isHandwritten, isFalse);
    });
  });

  group('slaytNumarasi / sourcePage', () {
    test('geçerli slayt numarası fiziksel sayfayı EZER', () {
      final card = _decode(_kart(slaytNumarasi: '24'), sourcePage: 27)!;
      expect(card.sourcePage, 24);
    });

    test('native int slayt numarası da kabul edilir', () {
      final card = _decode(_kart(slaytNumarasi: 24), sourcePage: 27)!;
      expect(card.sourcePage, 24);
    });

    test('null/boş/"null" slayt numarasında fiziksel sayfaya düşülür', () {
      expect(_decode(_kart(slaytNumarasi: null), sourcePage: 27)!.sourcePage, 27);
      expect(_decode(_kart(slaytNumarasi: ''), sourcePage: 27)!.sourcePage, 27);
      expect(
        _decode(_kart(slaytNumarasi: 'null'), sourcePage: 27)!.sourcePage,
        27,
      );
    });

    test('sayıya çevrilemeyen slayt numarası yok sayılır', () {
      final card = _decode(_kart(slaytNumarasi: 'yirmi dört'), sourcePage: 27)!;
      expect(card.sourcePage, 27);
    });

    test('0/negatif slayt numarası yok sayılır', () {
      expect(_decode(_kart(slaytNumarasi: '0'), sourcePage: 27)!.sourcePage, 27);
      expect(_decode(_kart(slaytNumarasi: '-3'), sourcePage: 27)!.sourcePage, 27);
    });

    test('sourcePage verilmezse (Yol B) sourcePage null kalır', () {
      expect(_decode(_kart())!.sourcePage, isNull);
    });
  });

  group('bozuk/eksik dizide çökmez', () {
    test('dizi olmayan öğeler null döner (çağıran kartı atlar)', () {
      expect(_decode(null), isNull);
      expect(_decode('kart değil'), isNull);
      expect(_decode(42), isNull);
      expect(_decode(<String, Object?>{'soru': 'S'}), isNull);
    });

    test('boş dizi null döner', () {
      expect(_decode(<Object?>[]), isNull);
    });

    test('kısa dizi çökmez — soru/cevap varsa kart kurtarılır', () {
      // Yalnızca ilk üç eleman geldi; kalan etiketler varsayılana düşmeli.
      final card = _decode(<Object?>['Soru?', 'Kısa', 'Uzun cevap.']);
      expect(card, isNotNull);
      expect(card!.question, 'Soru?');
      expect(card.shortAnswer, 'Kısa');
      expect(card.answer, 'Uzun cevap.');
      expect(card.difficulty, CardDifficulty.orta);
      expect(card.cardType, CardType.temel);
      expect(card.priority, CardPriority.oncelikli);
      expect(card.topic, isEmpty);
      expect(card.sourcePage, isNull);
      expect(card.isHandwritten, isFalse);
    });

    test('cevap pozisyonu eksikse kart atılır', () {
      expect(_decode(<Object?>['Soru?', 'Kısa']), isNull);
    });

    test('soru veya cevap boş/null ise kart atılır', () {
      expect(_decode(_kart(soru: '')), isNull);
      expect(_decode(_kart(soru: null)), isNull);
      expect(_decode(_kart(cevap: '')), isNull);
      expect(_decode(_kart(cevap: null)), isNull);
      expect(_decode(_kart(soru: '   ')), isNull);
    });

    test('fazladan eleman gelirse yok sayılır, kart bozulmaz', () {
      final card = _decode([..._kart(), 'fazlalık', 99]);
      expect(card, isNotNull);
      expect(card!.question, 'Kalp kaç odacıklıdır?');
    });

    test('beklenmedik tipler (Map/List) o pozisyonda çökmez', () {
      final card = _decode(
        _kart(zorluk: <String, Object?>{'a': 1}, konu: <Object?>[1, 2]),
      );
      expect(card, isNotNull);
      expect(card!.difficulty, CardDifficulty.orta);
    });

    test('kısaCevap eksikse boş string olur (eski tek katmanlı davranış)', () {
      final card = _decode(_kart(kisaCevap: null))!;
      expect(card.shortAnswer, isEmpty);
      expect(card.hasShortAnswer, isFalse);
    });
  });

  group('flashcardFromItem yönlendirmesi', () {
    test('dizi gelirse kompakt çözücüye devreder', () {
      final card = prompt.flashcardFromItem(
        _kart(zorluk: 'z'),
        id: 'x',
        sourcePage: 3,
      );
      expect(card!.difficulty, CardDifficulty.zor);
      expect(card.sourcePage, 3);
    });

    test('alan adlı nesne (eski biçim) hâlâ çözülür', () {
      // Şema kompakt diziye geçti ama şemasız bir sağlayıcı nesne dönebilir.
      final card = prompt.flashcardFromItem(
        {'soru': 'S', 'cevap': 'C', 'zorluk': 'zor'},
        id: 'x',
      );
      expect(card!.question, 'S');
      expect(card.difficulty, CardDifficulty.zor);
    });

    test('eski biçimde string slaytNumarasi çökmez, sayıya çözülür', () {
      // REGRESYON: eskiden `item['slaytNumarasi'] as num?` idi; model bu alanı
      // string yazınca TypeError fırlıyordu ve çağıran döngüde kart bazlı
      // try/catch olmadığı için TÜM sayfa düşüyordu.
      final card = prompt.flashcardFromItem(
        {'soru': 'S', 'cevap': 'C', 'slaytNumarasi': '12'},
        id: 'x',
        sourcePage: 3,
      );
      expect(card!.sourcePage, 12);
    });

    test('eski biçimde çözülemeyen slaytNumarasi fiziksel sayfaya düşer', () {
      for (final raw in <Object?>['', 'null', 'on iki', true, <int>[1]]) {
        final card = prompt.flashcardFromItem(
          {'soru': 'S', 'cevap': 'C', 'slaytNumarasi': raw},
          id: 'x',
          sourcePage: 3,
        );
        expect(card!.sourcePage, 3, reason: 'girdi: $raw');
      }
    });

    test('eski biçimde native num slaytNumarasi hâlâ çalışır', () {
      final card = prompt.flashcardFromItem(
        {'soru': 'S', 'cevap': 'C', 'slaytNumarasi': 7},
        id: 'x',
        sourcePage: 3,
      );
      expect(card!.sourcePage, 7);
    });
  });

  group('uçtan uca (GeminiService)', () {
    setUp(() {
      dotenv.loadFromString(
        envString:
            'SUPABASE_URL=https://test.supabase.co\n'
            'SUPABASE_ANON_KEY=test-anon-key',
      );
      SharedPreferences.setMockInitialValues({});
    });

    GeminiService serviceReturning(String body) {
      return GeminiService(
        client: MockClient(
          (_) async => http.Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
    }

    test('Yol B (generate) kompakt yanıtı kartlara çevirir', () async {
      final service = serviceReturning(
        _geminiEnvelope([
          _kart(soru: 'Soru 1?', cevap: 'Cevap 1.', zorluk: 'k'),
          _kart(soru: 'Soru 2?', cevap: 'Cevap 2.', zorluk: 'z', oncelik: 'a'),
        ]),
      );

      final cards = await service.generate(_validInput);

      expect(cards, hasLength(2));
      expect(cards.first.question, 'Soru 1?');
      expect(cards.first.difficulty, CardDifficulty.kolay);
      expect(cards.last.difficulty, CardDifficulty.zor);
      expect(cards.last.priority, CardPriority.arkaPlan);
      expect(cards.first.id, isNot(cards.last.id));
      // Yol B'de sayfa damgası hiç yok (değişmedi).
      expect(cards.every((c) => c.sourcePage == null), isTrue);
    });

    test('Yol A (generateForPage) kompakt yanıtı sayfa damgasıyla çevirir',
        () async {
      final service = serviceReturning(
        _geminiEnvelope([
          _kart(soru: 'Sayfa sorusu?', cevap: 'Sayfa cevabı.', kartTipi: 's'),
        ]),
      );

      final cards = await service.generateForPage('Yeterince uzun metin.', 47);

      expect(cards, hasLength(1));
      expect(cards.single.cardType, CardType.sinav);
      expect(cards.single.sourcePage, 47);
    });

    test('Yol A: kompakt dizideki slaytNumarasi fiziksel sayfayı ezer',
        () async {
      final service = serviceReturning(
        _geminiEnvelope([
          _kart(slaytNumarasi: '24', elYazisindanMi: 'true'),
        ]),
      );

      final cards = await service.generateForPage(
        'Yeterince uzun metin.',
        27,
        imageBase64: 'aGVsbG8=',
      );

      expect(cards.single.sourcePage, 24);
      expect(cards.single.isHandwritten, isTrue);
    });

    test('bozuk kartlar atlanır, sağlamlar kalır (sayfa çökmez)', () async {
      final service = serviceReturning(
        _geminiEnvelope([
          _kart(soru: 'Sağlam?', cevap: 'Sağlam cevap.'),
          <Object?>[], // boş dizi
          <Object?>['Cevabı yok?'], // eksik
          'kart değil', // dizi bile değil
          _kart(soru: ''), // boş soru
        ]),
      );

      final cards = await service.generateForPage('Yeterince uzun metin.', 5);

      expect(cards, hasLength(1));
      expect(cards.single.question, 'Sağlam?');
    });
  });
}
