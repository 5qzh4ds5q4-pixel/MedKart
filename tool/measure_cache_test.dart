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
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/flashcard_prompt.dart' as prompt;
import 'package:medcard/services/gemini_service.dart';
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
    print('  cache=<sayı> (%oran)  -> cache İSABET ETTİ, v28 çalışıyor');
    print('  cache=YOK             -> isabet yok');
    print('girdi=<sayı> değerini yerel karakter sayısıyla karşılaştırıp');
    print('karakter→token oranını kalibre et (varsayımımız 3,7).');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
