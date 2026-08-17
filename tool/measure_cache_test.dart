// Test-only ölçüm script'i: v28'in (prompt ön ekinin sabitlenmesi) Gemini'ın
// örtük context cache'ini GERÇEKTEN açıp açmadığını canlı ölçer.
// Uygulama koduna dahil değil.
//
// NEDEN GÖRSELSİZ: üretimdeki varsayılan yol (el yazısı anahtarı AÇIK)
// istek parçalarını [inlineData(görsel), text(prompt)] sırasıyla kuruyor;
// görsel her sayfada FARKLI ve 0. pozisyonda olduğu için ön eki en baştan
// kırıyor — bu kod okumasıyla zaten kesinleşti (bkz. CLAUDE.md "Context
// caching"). Buradaki ölçümün cevapladığı soru farklı ve daha temel:
// "Ön ek sabitlendiğinde Gemini'ın cache'i bizim prompt'umuzda ÇALIŞIYOR mu?"
// Cevap evetse, görsel sırasını düzeltmek (2. adım) kanıtlanmış biçimde
// değerli demektir; hayırsa 2. adıma hiç girişmemek gerekir.
//
// ÇAĞRILAR ARDIŞIK: PdfCardPipeline concurrency: 4 ile paralel çalışıyor,
// o durumda ilk 4 istek cache dolmadan aynı anda gider. Burada ilk çağrının
// cache'i doldurup sonrakilerin isabet etmesini görmek istiyoruz.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/flashcard_prompt.dart' as prompt;
import 'package:medcard/services/gemini_service.dart';
import 'package:medcard/services/gemini_transport.dart';
import 'package:medcard/services/usage_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerçekçi uzunlukta (~1.700-1.900 karakter) sahte slayt metinleri.
/// İçerikleri FARKLI olmalı — aynı olsaydı sayfa metni de ön eke girer ve
/// ölçüm yanıltıcı olurdu.
const _sayfalar = <String>[
  'Mitral kapak sol atriyum ile sol ventrikul arasinda yer alir ve iki '
      'yaprakcigi vardir. Trikuspid kapak sag atriyum ile sag ventrikul '
      'arasindadir, uc yaprakcigi bulunur. Kapaklarin acilip kapanmasi kas '
      'gucuyle degil, odaciklar arasindaki basinc farkiyla pasif olarak olur. '
      'Basinc kapagin gerisindeki odacikta yukseldiginde kapak acilir, ters '
      'yonde basinc olustugunda kapanir; bu sayede kan tek yonde ilerler. '
      'Normal mitral kapak alani 4-6 cm2 dir. Bu alanin 2 cm2 altina inmesi '
      'mitral stenoz olarak kabul edilir ve sol atriyum basincinin artmasina '
      'yol acar. Aort kapagi sol ventrikul ile aort arasinda yer alir ve uc '
      'yariay yaprakciktan olusur. Pulmoner kapak sag ventrikul ile pulmoner '
      'arter arasindadir. Kapak yetmezliginde kan geriye kacar ve odacik '
      'hacim yuku altinda kalir; darlikta ise basinc yuku olusur. Papiller '
      'kaslar ve korda tendinealar atriyoventrikuler kapaklarin sistol '
      'sirasinda atriyuma dogru sarkmasini engeller. Bu yapilarin '
      'yirtilmasi akut kapak yetmezligine yol acar.',
  'Koroner dolasim kalp kasinin kendi kanlanmasini saglar. Sol ana koroner '
      'arter kisa bir seyirden sonra sol on inen arter ve sirkumfleks arter '
      'olarak ikiye ayrilir. Sol on inen arter sol ventrikulun on duvarini ve '
      'interventrikuler septumun on bolumunu besler. Sirkumfleks arter sol '
      'ventrikulun lateral duvarini besler. Sag koroner arter sag atriyum, '
      'sag ventrikul ve cogu insanda sinoatriyal dugum ile atriyoventrikuler '
      'dugumu besler. Koroner kan akimi esas olarak diyastolde gerceklesir; '
      'sistolde miyokard icindeki damarlar sikisir. Bu nedenle tasikardi '
      'diyastol suresini kisaltarak koroner perfuzyonu bozar. Ön duvar '
      'iskemisinde EKG de V1-V4 derivasyonlarinda degisiklik beklenir. '
      'Inferior duvar iskemisinde DII, DIII ve aVF etkilenir. Koroner '
      'arterlerin ani tikanmasi miyokard infarktusune yol acar ve etkilenen '
      'alanin buyuklugu tikanan damarin besledigi bolgeyle orantilidir.',
  'Kalbin ileti sistemi sinoatriyal dugumde baslar. Sinoatriyal dugum sag '
      'atriyumun ust kisminda, superior vena kava girisinin yaninda bulunur '
      've normal kosullarda dakikada 60-100 uyari uretir. Uyari atriyumlar '
      'boyunca yayilir ve atriyoventrikuler duguma ulasir. Atriyoventrikuler '
      'dugumde iletim yavaslar; bu gecikme atriyumlarin ventrikullerden once '
      'kasilmasini saglar ve ventrikul dolusunu artirir. Uyari daha sonra His '
      'demetine, oradan sag ve sol dallara, en sonunda Purkinje liflerine '
      'iletilir. Purkinje lifleri ventrikul kasinin hizli ve esgudumlu '
      'kasilmasini saglar. Sinoatriyal dugum calismadiginda atriyoventrikuler '
      'dugum dakikada 40-60 hizinda kacis ritmi uretir. Purkinje sisteminin '
      'kendi kacis hizi dakikada 20-40 arasindadir ve hemodinamik olarak '
      'yetersizdir.',
  'Kalp yetmezliginde kalbin debisi dokularin metabolik ihtiyacini '
      'karsilayamaz. Sistolik yetmezlikte ejeksiyon fraksiyonu dusuktur ve '
      'ventrikul kasilma gucu azalmistir. Diyastolik yetmezlikte ejeksiyon '
      'fraksiyonu korunmustur ancak ventrikul yeterince gevseyemedigi icin '
      'dolus bozulmustur. Sol kalp yetmezliginde kan akciger dolasiminda '
      'birikir ve nefes darligi, ortopne, paroksismal nokturnal dispne '
      'gorulur. Sag kalp yetmezliginde sistemik venoz basinc artar; boyun '
      'venlerinde dolgunluk, hepatomegali ve periferik odem ortaya cikar. '
      'Frank-Starling mekanizmasina gore ventrikul dolus hacmi arttikca '
      'kasilma gucu belirli bir noktaya kadar artar; bu nokta asildiginda '
      'kasilma gucu duser. Kronik yetmezlikte sempatik aktivite ve '
      'renin-anjiyotensin-aldosteron sistemi devreye girer, bu telafi '
      'mekanizmalari uzun vadede kalp kasini daha da bozar.',
];

// ---------------------------------------------------------------------------
// Sayfa başına FARKLI, geçerli bir PNG üretici.
//
// Görselli yolu ölçmek için her çağrının AYRI bir görsel taşıması ŞART:
// aynı görseli göndersek ön ek kendiliğinden eşleşir ve ölçüm yanıltıcı olur
// (üretimde her sayfanın render'ı farklıdır). Küçük ve sentetik — token
// sayısı gerçek 1024px sayfa render'ını TEMSİL ETMEZ, burada tek amaç
// "0. pozisyonda her seferinde değişen bir görsel" durumunu yaratmak.
// ---------------------------------------------------------------------------
final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int> _be32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

List<int> _chunk(String tip, List<int> veri) {
  final tipBytes = ascii.encode(tip);
  return [
    ..._be32(veri.length),
    ...tipBytes,
    ...veri,
    ..._be32(_crc32([...tipBytes, ...veri])),
  ];
}

/// [tohum]'a göre renkleri değişen, geçerli 16x16 RGB PNG.
String _pngBase64(int tohum) {
  const w = 16, h = 16;
  final ham = <int>[];
  for (var y = 0; y < h; y++) {
    ham.add(0); // filtre: none
    for (var x = 0; x < w; x++) {
      ham.addAll([
        (tohum * 73 + x * 15) & 0xFF,
        (tohum * 151 + y * 9) & 0xFF,
        (tohum * 199 + x * y) & 0xFF,
      ]);
    }
  }
  final png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ..._chunk('IHDR', [..._be32(w), ..._be32(h), 8, 2, 0, 0, 0]),
    ..._chunk('IDAT', ZLibCodec().encode(ham)),
    ..._chunk('IEND', const []),
  ];
  return base64Encode(Uint8List.fromList(png));
}

void main() {
  // `GeminiTransport.send` -> `DeviceIdService.getOrCreate` SharedPreferences
  // kullanıyor; binding + mock değer olmadan "Binding has not yet been
  // initialized" ile patlıyor. deviceId yalnızca proxy ZARFINA giriyor,
  // Gemini'ye giden `payload`'a DEĞİL — yani her koşuda taze bir UUID olması
  // cache ölçümünü etkilemez (yalnızca kota sayacı taze bir kovaya yazar).
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test binding'i `HttpOverrides.global`'ı mock'layıp TÜM HTTP isteklerine
  // 400 döndürüyor. Bu script'in tek amacı GERÇEK ağ çağrısı yapmak, o yüzden
  // override kaldırılıyor. (Normal test paketinde bunu ASLA yapma — testler
  // ağa çıkmamalı; bu dosya `tool/` altında, pakete dahil değil.)
  HttpOverrides.global = null;

  test('v28 context cache canlı ölçümü (GÖRSELSİZ, gerçek API)', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: File('.env').readAsStringSync());

    // Ölçümün anlamlı olması için ön ekin gerçekten sabit olduğunu ÖNCE
    // yerel olarak doğrula — API'ye boşuna para harcamayalım.
    final p1 = prompt.buildPagePrompt(_sayfalar[0], 1, hasImage: false);
    final p2 = prompt.buildPagePrompt(_sayfalar[1], 2, hasImage: false);
    var ortak = 0;
    while (ortak < p1.length &&
        ortak < p2.length &&
        p1.codeUnitAt(ortak) == p2.codeUnitAt(ortak)) {
      ortak++;
    }
    print('=== ÖN KOŞUL ===');
    print('Yerel ortak ön ek: $ortak karakter '
        '(~${(ortak / 3.7).round()} token tahmini)');
    expect(
      ortak,
      greaterThan(15000),
      reason: 'v28 geri alınmış olabilir — ön ek beklenenden kısa',
    );

    final service = GeminiService();

    print('\n=== ÇAĞRILAR (ardışık) ===');
    print('Beklenti: 1. çağrı cache=YOK (cache\'i dolduruyor), '
        '2-4. çağrılar cache=<sayı>\n');

    for (var i = 0; i < _sayfalar.length; i++) {
      final sayfaNo = i + 1;
      final kartlar = await service.generateForPage(
        _sayfalar[i],
        sayfaNo,
        // GÖRSEL YOK — bkz. dosya başı yorumu.
      );
      print('  -> s.$sayfaNo: ${kartlar.length} kart üretildi');
      print('');
    }

    print('=== NASIL OKUNUR ===');
    print('Yukarıdaki [USAGE s.N] satırlarına bak:');
    print('  cache=<sayı> (%oran)  -> cache İSABET ETTİ');
    print('  cache=YOK             -> isabet yok');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('v29 context cache canlı ölçümü (GÖRSELLİ = üretim varsayılanı)', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: File('.env').readAsStringSync());

    final service = GeminiService();

    print('\n=== GÖRSELLİ YOL (her sayfada FARKLI görsel) ===');
    print('v28\'de bu yolda cache HİÇ çalışmıyordu: görsel contents\'in 0.');
    print('parçasıydı ve her sayfada değiştiği için ön eki en baştan kırıyordu.');
    print('v29\'da statik blok systemInstruction\'a taşındı — system instruction');
    print('prompt\'un ÖN EKİ olduğu için görselden ETKİLENMEMESİ bekleniyor.\n');

    for (var i = 0; i < _sayfalar.length; i++) {
      final sayfaNo = i + 1;
      final kartlar = await service.generateForPage(
        _sayfalar[i],
        sayfaNo,
        imageBase64: _pngBase64(sayfaNo), // HER SAYFADA FARKLI
        imageMimeType: 'image/png',
      );
      print('  -> s.$sayfaNo: ${kartlar.length} kart üretildi');
      print('');
    }

    print('=== BEKLENTİ ===');
    print('1. çağrı cache=YOK (dolduruyor), 2-4. çağrılar cache=<sayı>.');
    print('Eğer 2-4 de cache=YOK ise systemInstruction ön eke girmiyor');
    print('demektir ve v29 yaklaşımı ÇALIŞMIYOR.');
  }, timeout: const Timeout(Duration(minutes: 5)));

  // Görselli yolda cache çalışmadığı görülürse SEBEBİNİ ayırt etmek için:
  // görsel contents'in SONUNA konursa cache açılıyor mu? Açılıyorsa sorun
  // görselin KONUMU (çözüm: parça sırası). Açılmıyorsa multimodal istekler
  // örtük cache'e hiç girmiyor demektir (çözüm: yalnızca AÇIK cache).
  test('TEŞHİS: görsel contents\'in SONUNDA (sıra etkisi izole)', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: File('.env').readAsStringSync());

    final transport = GeminiTransport();

    print('\n=== TEŞHİS: [metin, görsel] sırası ===');
    for (var i = 0; i < _sayfalar.length; i++) {
      final sayfaNo = i + 1;
      final body = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': prompt.buildPageSystemInstruction(hasImage: true)},
          ],
        },
        'contents': [
          {
            'parts': [
              // GÖRSEL SONDA — üretimdekinin TERSİ sıra.
              {'text': prompt.buildPageUserContent(_sayfalar[i], sayfaNo)},
              {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': _pngBase64(sayfaNo),
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': prompt.responseSchema,
          'temperature': 0.4,
          'maxOutputTokens': GeminiService.maxOutputTokens,
          'thinkingConfig': {'thinkingBudget': 0},
        },
      });

      final response = await transport.send(
        model: GeminiService.model,
        body: body,
      );
      if (response.statusCode != 200) {
        print('  s.$sayfaNo HTTP ${response.statusCode}');
        continue;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map) logUsageMetadata(decoded, 'teshis-s.$sayfaNo');
    }

    print('\nSONUÇ: cache=<sayı> ise sorun görselin KONUMU (sıra düzeltilebilir).');
    print('       cache=YOK ise multimodal istekler örtük cache\'e hiç girmiyor.');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
