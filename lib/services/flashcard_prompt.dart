import '../models/flashcard.dart';

/// Kart üretim prompt'unun ve şemasının PAYLAŞILAN, sağlayıcıdan bağımsız
/// kısmı. [GeminiService] ve [DeepSeekService] (ve gelecekte eklenecek her
/// sağlayıcı) kart İÇERİĞİ/kalite kurallarını buradan alır — kopyala-yapıştır
/// yerine tek ortak fonksiyon, iki sağlayıcı arasında tutarsızlık olmasın.
///
/// Bu dosyadaki metinler [GeminiService]'in eski `_buildPrompt`/
/// `_buildPagePrompt` özel üyelerinden BİREBİR aynı içerikle taşındı — davranış
/// değişmedi, sadece paylaşılabilir hale geldi.

/// Bu dosyadaki kural bloklarından HERHANGİ biri (ya da [buildGeneralPrompt]/
/// [buildPagePrompt]'un kendisi) değiştiğinde ELLE artır. `pdf_cache`
/// tablosuna kaydedilen kartların hangi prompt sürümüyle üretildiğini
/// işaretlemek için kullanılıyor (bkz. `PdfCacheService.save`) — böylece
/// ileride eski cache girdilerini güncel prompttan üretilmemiş diye ayırt
/// edebiliriz. Şimdilik yalnızca KAYDEDİLİYOR, okuma/lookup tarafında bu
/// değere göre bir filtreleme YOK.
const String kPromptVersion = 'v27';

/// Klinik/patolojik konularda AI'a ek olarak senaryo-tabanlı ("sınav
/// tipi") kart ürettiren ortak kural bloğu; hem [buildGeneralPrompt] hem
/// [buildPagePrompt] tarafından paylaşılır.
const String sinavTipiKurali = '''
SINAV TİPİ KART (KLİNİK/PATOLOJİK HER BİLGİ İÇİN ZORUNLU — SEÇİCİ DAVRANMA):
- Klinik/patolojik bağlamı olan HER bilgi için (kırık-sinir ilişkisi, kas/doku hasarı-bulgu ilişkisi, biyopsi/muayene bulgusuyla tanınabilecek her yapı, hastalık-bulgu ilişkisi) normal karta EK olarak MUTLAKA bir "sınav tipi" kart da üret. Bunlardan bazılarını seçip gerisini atlama: sayfada böyle N tane ayrı ilişki varsa N tane sınav tipi kart olmalı, hepsi.
- ÖZELLİKLE: sayfada birden fazla sinir/kas/yapının hasar-bulgu ilişkisi tek tek listeleniyorsa (ör. bir tabloda 5 farklı sinir ve her birinin klinik bulgusu), HER BİRİ için ayrı bir sınav tipi kart üret — birkaçını örnek diye seçip diğerlerini atlamak YANLIŞ.
- Bu kart kısa bir hasta/durum tarifiyle başlasın (2-3 cümle: yaş/cinsiyet, şikayet, muayene bulgusu gibi), ardından soruyu sorsun. Cevap aynı bilgiye dayansın ama soru doğrudan olmasın — önce senaryodan çıkarım gerektirsin.
- Düz tanım/liste bilgisinde (ör. "el bileğinde kaç kemik var") sınav tipi kart ÜRETME; zorlama, gerek yoksa üretme.''';

/// [sinavTipiKurali]'nin somut önce/sonra örneği — kuralın SOYUT tarifinin
/// yeterince ikna edici olmadığı gerçek vakalarda modelin "zayıf" (düz tanım
/// sorup geçen) kart üretmeye devam etmesi üzerine eklendi. [kartEtiketleriKurali]
/// içindeki BİÇİM ÖRNEĞİ'nden bilinçli olarak AYRI: o örnek yalnızca ÇIKTI
/// BİÇİMİNİ (dizi/pozisyon) gösterir, bu örnek İÇERİK KALİTESİNİ gösterir —
/// ikisi karıştırılmasın diye ayrı bloklarda tutuluyor.
const String icerikKalitesiOrnegi = '''
İÇERİK KALİTESİ ÖRNEĞİ (aynı kaynak bilgiden iki farklı kart):
Kaynak bilgi: "Bruselloz, kaynamamış süt ve taze peynir tüketimiyle bulaşır."

ZAYIF kart (BUNU YAPMA — sadece tanım sorup geçiyor):
Soru: "Bruselloz nasıl bulaşır?" Cevap: "Kaynamamış süt ve taze peynir tüketimiyle."

GÜÇLÜ kart (BUNU YAP — aynı bilgiyi klinik vakaya dönüştürüyor):
Soru: "40 yaşında çiftçi hastada 3 haftadır süren ateş, terleme ve eklem ağrısı var. Kırsal bölgede yaşayan akrabasından aldığı taze keçi peyniri düzenli tükettiği öğreniliyor. Kan kültüründe hangi etken üremesi beklenir?" Cevap: "Brucella (Bruselloz)"

Sayfada klinik/patolojik bir ilişki varsa (kırık-sinir, bulaş yolu-hastalık, tablo satırı gibi), HER ZAMAN güçlü kart formatını tercih et — zayıf format yalnızca gerçekten başka çıkarım yapılamayan, salt isimlendirme bilgisinde kabul edilebilir.''';

/// Cevapların açıklayıcılığı için ortak kural; hem [buildGeneralPrompt] hem
/// [buildPagePrompt] tarafından paylaşılır.
const String cevapSadeligiKurali =
    'Cevaplar tek kelimelik veya tek cümlelik hatırlatıcılar OLMASIN; '
    'dersi hiç dinlememiş bir öğrenci bile cevabı okuyunca konuyu '
    'anlayabilsin. Cevap yapısı: (1) doğrudan cevabı ver, (2) NEDEN öyle '
    'olduğunu gösteren kısa bir açıklama/mekanizma ekle, (3) varsa önemli '
    'bir ayrım ya da somut örnek belirt. Ama gereksiz uzatma: cevap 2-4 '
    'cümleyi geçmesin — amaç öğretmek, spaced repetition\'da her '
    'tekrarda paragraf okutmamak. Kullandığın bir terimi açıklamadan '
    'bırakma; kısaca ne olduğunu da belirt. Hedef: "dersi kaçırılan anı '
    'telafi eder" ile "her tekrarda bunaltmaz" arasında denge.';

/// İki katmanlı cevap kuralı ("cevap" + "kisaCevap"); hem [buildGeneralPrompt]
/// hem [buildPagePrompt] tarafından paylaşılır.
const String ikiKatmanliCevapKurali = '''
İKİ AYRI CEVAP ÜRET — BİRİ DİĞERİNİN KISALTMASI DEĞİL:
- "cevap": açıklamalı tam cevap, yukarıdaki kurala göre (mekanizma/neden-sonuç, terimler açıklanmış, 2-4 cümle). Bu alanın uzunluğu/kalitesi "kisaCevap"tan bağımsız, HİÇ değişmesin.
- "kisaCevap": "Kısaca cevap ne?" sorusunun net yanıtı, 3-8 kelime. "cevap"ı kısaltarak elde ETME — soruyu baştan "bu sorunun tek satırlık doğrudan yanıtı ne olurdu" diye ayrıca düşün. Tam cümle olmak zorunda değil, gereksiz kelime taşımasın.''';

/// Zorluk etiketi kalibrasyonu; hem [buildGeneralPrompt] hem [buildPagePrompt]
/// tarafından paylaşılır.
const String zorlukKurali = '''
ZORLUK KALİBRASYONU (komite sınavı standardına göre — ÖNCEKİ SÜRÜM BİR KADEME DÜŞÜKTÜ):
- "kolay": YALNIZCA tek bir terimin doğrudan tanımını hatırlamayı gerektiren kartlar (ör. "virülans nedir?"). Bunlar bile gerçek komite sınavı düzeyindedir; "kolay" demek "önemsiz" demek değildir.
- "orta": Birden fazla kavramı ilişkilendiren, bir mekanizmayı veya neden-sonuç ilişkisini açıklamayı gerektiren kartlar.
- "zor": Bir hasta/durum senaryosu + ayırıcı tanı gerektiren, ya da bir formül/sayısal hesap gerektiren kartlar. Bunlar TUS düzeyidir.
- İki ayrı bilgiyi yan yana koymak TEK BAŞINA "orta" için yeterli değildir; aralarında gerçek bir mekanizma/neden-sonuç ilişkisi kurulmalı, yoksa "kolay" kabul et.''';

/// Kaynak sadakati kuralı: model kaynaktaki hatayı "düzeltmeye" çalışmasın;
/// hem [buildGeneralPrompt] hem [buildPagePrompt] tarafından paylaşılır.
const String kaynakSadakatiKurali =
    'Kaynak slayttaki bilgiyi AYNEN aktar. Slaytta bir yazım hatası, '
    'kısaltma hatası veya bilgi hatası olsa bile DÜZELTME — slaytta ne '
    'yazıyorsa kartta da o olsun. Kendi bilginle kaynağı "düzeltmeye" '
    'çalışma. Örnek: slaytta "CTC" yazıyorsa, doğrusu "CTL" olsa bile '
    'kartta "CTC" yaz. Amaç: öğrenci slaytta göreceği bilginin AYNISINI '
    'kartta görsün.';

/// Kartlarda kullanılacak standart YAZIM biçimleri; hem [buildGeneralPrompt]
/// hem [buildPagePrompt] tarafından paylaşılır.
///
/// [kaynakSadakatiKurali] ile ÇELİŞMEZ — bilinçli, dar bir istisnadır: bu
/// kural içeriği değil YALNIZCA yazım biçimini (tire/boşluk/büyük-küçük harf,
/// İngilizce→Türkçe çeviri tutarlılığı) düzeltir. Kaynaktaki bilgi/kısaltma
/// HATALARI hâlâ düzeltilmez. Liste KAPALIDIR; modelin buradan yola çıkıp
/// başka "düzeltmeler" yapmasını engellemek için prompt'ta da açıkça
/// söyleniyor.
const String terminolojiStandardiKurali = '''
TERMİNOLOJİ YAZIM STANDARDI (yalnızca aşağıdaki KAPALI liste):
- Kaynakta farklı yazılmış olsa bile, kartta bu terimleri şu standart biçimde yaz:
  "MHC Sınıf I" ve "MHC Sınıf II" (İngilizce "Class I"/"Class II" değil), "CTLA-4" ("CTLA4" değil), "PD-1" ("PD 1" değil), "PD-L1" ("PDL 1" değil), "IFN-γ" ("IFN y" değil), "proteazom" ("proteozom" değil).
- Bu YALNIZCA yazım biçimidir (tire/boşluk/büyük-küçük harf ve İngilizce→Türkçe çeviri tutarlılığı); bilginin kendisini DEĞİŞTİRMEZ.
- Liste KAPALIDIR: burada olmayan hiçbir terimi "düzeltme"/standartlaştırma, kaynakta nasıl yazıyorsa öyle bırak (bkz. kaynak sadakati kuralı).''';

/// Kart metninin güncellik/otorite iddiası taşımasını yasaklayan ortak kural;
/// hem [buildGeneralPrompt] hem [buildPagePrompt] tarafından paylaşılır.
/// Sebep: kaynak slayt eski olabilir, kart onun adına "güncel kılavuz" iddiası
/// üstlenmemeli.
///
/// (2026-08-14, v26→v27 GÜNCELLEMESİ): v26'da "yerine kaynağa atıf yap"
/// tavsiyesi [kaynakReferansiGizlemeKurali] ile ÇELİŞTİĞİ gerekçesiyle
/// KALDIRILMIŞTI. Bu YANLIŞ bir düzeltmeydi — kullanıcı geri bildirdi:
/// tedavi/kılavuz bilgisinde "slayta göre" bir STİL tercihi değil, eski/
/// güncel-olmayan bir kaynaktaki tedavi bilgisini kesin bir gerçekmiş gibi
/// sunmayı önleyen bir GÜVENLİK ÖNLEMİDİR. v27'de tavsiye GERİ GETİRİLDİ ve
/// [kaynakReferansiGizlemeKurali]'ne bir İSTİSNA maddesi eklendi — artık iki
/// kural ÇAKIŞMIYOR, KAPSAMLARI AYRIK: bu kural tedavi/kılavuz/güncel pratik
/// bilgisini kapsar (kaynağa atıf ZORUNLU), [kaynakReferansiGizlemeKurali]
/// geri kalan HER ŞEYİ (stabil/mekanizma bilgisi) kapsar (kaynağa atıf YASAK).
const String guncellikDiliYasagiKurali = '''
GÜNCELLİK/OTORİTE DİLİ YASAK (tedavi ve kılavuz sorularında):
- Kaynak materyal güncel olmayabilir; kart onun adına güncellik iddiası ÜSTLENMEZ. Soru ya da cevapta "güncel kılavuzlara göre", "günümüzde kabul edilen", "bugün önerilen", "birinci basamak tedavi", "standart tedavi" gibi GÜNCELLİK/OTORİTE iddia eden ifadeler ASLA kullanma.
- Bunun yerine kaynağa atıf yapan bir dil kullan: "slayta göre", "bu kaynakta belirtildiği üzere", "kaynakta vurgulanan". Bu kuralın gerektirdiği "slayta göre" ifadesi, KAYNAK REFERANSI GİZLEME KURALI'nın istisnasıdır — orada YASAKLANAN ifade, burada ZORUNLUDUR.
- Kötü örnek: "Güncel kılavuzlara göre X tedavisi önceliklidir."
- İyi örnek: "Slayta göre X tedavisi vurgulanmaktadır."''';

/// Kart metninde (soru kökü, şıklar VE açıklama/cevap dahil HER ALAN) kaynağa
/// doğrudan atıf yapılmasını yasaklayan kural; hem [buildGeneralPrompt] hem
/// [buildPagePrompt] tarafından paylaşılır. Kullanıcı talimatıyla 2026-08-14'te
/// (v26) eklendi; aynı gün (v27) [guncellikDiliYasagiKurali] ile kapsam
/// çakışmasını gidermek için bir İSTİSNA maddesi eklendi.
///
/// [guncellikDiliYasagiKurali] İLE ARTIK ÇELİŞMİYOR — KAPSAMLARI AYRIK: bu
/// kural tedavi/kılavuz/güncel pratik DIŞINDAKİ (stabil/mekanizma) bilgiyi
/// kapsar; [guncellikDiliYasagiKurali] tedavi/kılavuz bilgisini kapsar ve
/// orada "slayta göre" ZORUNLUDUR (bkz. aşağıdaki İSTİSNA maddesi — ayrım
/// ölçütü zamanla değişebilirlik: tedavi/doz/kılavuz önerisi mi, yoksa
/// tanım/anatomi/patofizyoloji gibi stabil bilgi mi).
///
/// [elYazisiKurali]'ndaki "el yazısı"/"görselde" atıf yasağıyla KARIŞTIRILMAMALI
/// — o DAR bir kural, yalnızca bilginin el yazısından/görselden geldiğini
/// söylemeyi yasaklar. Bu kural GENEL: slayt/tablo/sunum/ders/kaynak gibi HER
/// TÜR kaynak referansını kapsar (yukarıdaki tedavi/kılavuz istisnası hariç).
const String kaynakReferansiGizlemeKurali = '''
KAYNAK REFERANSI GİZLEME (soru kökü, şıklar VE açıklama/cevap dahil HER ALAN):
- Kartlar HER ZAMAN kaynaktaki bilgiye dayanarak üretilir, bu değişmez. Ancak üretilen METİNDE kaynağa atıf yapan hiçbir ifade KULLANILMAZ: "slayta göre", "slaytta belirtildiği gibi", "kaynağa göre", "verilen bilgiye göre", "yukarıdaki tabloya göre", "tabloda belirtilen", "sunuma göre", "derse göre" ve benzerleri KESİNLİKLE YASAK.
- Bunun yerine bilgi doğrudan tıbbi/bilimsel bir OLGU olarak sunulur — sanki bağımsız bir TUS kaynağından geliyormuş gibi.
- İSTİSNA: Bu kural, TEDAVİ/KILAVUZ/GÜNCEL PRATİK içeren kartlara (GÜNCELLİK/OTORİTE DİLİ YASAK kuralının kapsadığı alan) UYGULANMAZ. O tür kartlarda "slayta göre" ifadesi ZORUNLU kalmaya devam eder — çünkü bu, eski/güncel olmayan bir kaynaktan gelen tedavi bilgisini kesin bir gerçekmiş gibi sunmayı önleyen bir güvenlik önlemidir, stil tercihi değildir. Ayrım ölçütü: bu bilgi zamanla değişebilir mi (tedavi, doz, birinci basamak seçimi, kılavuz önerisi) yoksa stabil/mekanizma bilgisi mi (tanım, anatomi, patofizyoloji, bulaş yolu gibi zamanla değişmeyen bilgi)? İlki için "slayta göre" zorunlu kalır, ikincisi için bu kural geçerlidir.
- Kötü örnek (soru): "Slayta göre listeriozis etkenini taşıyan canlı grupları hangileridir?"
- İyi örnek (soru): "Listeriozis etkenini taşıyan canlı gruplar hangileridir?"
- Kötü örnek (açıklama): "Slayttaki tabloya göre listeriozis etkenini taşıyanlar..."
- İyi örnek (açıklama): "Listeriozis etkenini pek çok memeli hayvan, kuşlar ve bazen insan taşır. Geniş bir rezervuar çeşitliliğine sahiptir."''';

/// Sınav Modu filtresinin dayandığı "oncelik" etiketi için ortak kural;
/// hem [buildGeneralPrompt] hem [buildPagePrompt] tarafından paylaşılır.
const String oncelikKurali = '''
ÖNCELİK ETİKETİ (Sınav Modu filtresi için — HER KARTA ZORUNLU):
- Karar sorusu: "Bu bilgi sınavda bir şıkkı BAŞKA bir şıktan ayırt ettirir mi?" Cevabın net bir "evet" değilse "arka_plan" ver. Bir bilginin doğru olması ve derste anlatılmış olması onu tek başına "oncelikli" YAPMAZ.
- "oncelikli": GERÇEKTEN ayırt edici, karşılaştırmalı ya da sık sorulan sayısal/işlevsel bir sonuç taşıyan bilgi — iki yapı/durum arasındaki fark ve bu farkın sonucu, işlevsel sonucu olan bir özellik, sık sorulan sayısal değer/eşik/formül, ya da bir sınıflandırmanın/listenin sınavda tek başına sorulabilecek bir maddesi.
- "arka_plan": Tek başına sınav sorusu olma ihtimali düşük bilgi. Örnekler:
  - bir yapının salt Latince/İngilizce adı; salt kavram tanıtımı/isimlendirme ("X'e ... denir" düzeyinde, ayırt edici özellik içermeyen bilgi);
  - bir sürecin/yapının yalnızca VAR OLDUĞUNU belirten cümle ("...da görülür", "...süreci de vardır" — nasıl/neden/sonuç bilgisi olmadan);
  - birden fazla alt maddesi olan bir listenin, diğer maddelerle KARŞILAŞTIRILMAYAN ve tek başına ayırt edici olmayan tek bir maddesinin parçası olan bilgi;
  - ders akışını bağlayan giriş/özet/geçiş cümleleri; apaçık/tartışmasız arka plan bilgisi.
- Belirli bir yüzde tutturmaya ÇALIŞMA — her kartı kendi başına yukarıdaki karar sorusuyla değerlendir. Ama neredeyse her karta "oncelikli" veriyorsan ayrımı uygulamıyorsun demektir; bu etiket ancak "arka_plan" gerçekten kullanılırsa işe yarar.
- "sinav" tipi kartlar için de bu etiketi doldur ama önemsiz — filtre onları zaten hep gösterir.''';

/// Bir kartın el yazısından geldiğini modele işaretlettiren ortak kural;
/// yalnızca görsel eklendiğinde ([buildGeneralPrompt] hasMedia,
/// [buildPagePrompt] hasImage) prompt'a eklenir. Şemadaki "elYazisindanMi"
/// alanı doğrudan [Flashcard.isHandwritten]'a taşınır; UI bunu meta
/// satırında bir ikonla gösterir — SORU/CEVAP METNİNE HİÇBİR UYARI YAZILMAZ.
const String elYazisiKurali = '''
EL YAZISI İŞARETİ (kart dizisinin son elemanı, "elYazisindanMi"):
- KARAR KRİTERİ — bu elemanı doldurmadan önce MUTLAKA şunu sor: "Bu öğe slaydın GERİ KALANINDAN farklı, SONRADAN eklenmiş gibi mi duruyor; yoksa slaydın TUTARLI, baştan tasarlanmış bir parçası mı?" Yalnızca birincisi "true"dur. Renkli ya da kalın olması TEK BAŞINA hiçbir şey ifade etmez; belirleyici olan, o öğenin slaydın kendi tasarım diline UYUP UYMADIĞIDIR.
- "true" YAP — yalnızca şu üç durumda:
  1. Gerçek el yazısı: kalemle/parmakla sonradan eklenmiş, düzensiz, basılı fontla uyuşmayan bir yazı.
  2. Slaydın geri kalanından BELİRGİN ŞEKİLDE FARKLI, sonradan eklenmiş görünen bir işaret: metnin üzerine çizilmiş daire/ok, elle çekilmiş altı çizili vurgu, sarı fon gibi tipik "highlighter" (fosforlu kalem) izi.
  3. Bir kutu/çerçeve ile SONRADAN vurgulanmış gibi duran, slaydın geri kalanındaki tasarım diliyle tutarsız bir öğe.
- "false" YAP — aşağıdakiler VURGU DEĞİL, slaydın normal tasarımıdır; bunları asla "true" işaretleme:
  1. Slaydın kendi başlık/alt başlık renk şeması (ör. tüm başlıklar mor, tüm terimler mavi ise bu slaydın standart tasarımıdır, vurgu değildir).
  2. Kalın/renkli yazılmış ama slayt boyunca TUTARLI bir stil kullanan metin (ör. her teknik terim aynı renkte).
  3. Tablo başlıkları ve ders materyallerinde yaygın olan standart biçimlendirme (bold terim tanımları gibi).
- Kart tamamen basılı metinden veya net görüntüden geliyorsa "false" yap.
- Görsel eklenmemişse her zaman "false" yap.
- EMİN DEĞİLSEN "false" YAP. Bu işaret, öğrencinin dikkatini gerçekten sonradan vurgulanmış birkaç noktaya çekmek içindir; her renkli/kalın öğeye "true" verirsen işaret anlamını yitirir ve hiçbir işe yaramaz.
- ÖNEMLİ: el yazısından geldiğini veya bunun bir uyarı gerektirdiğini SORU ya da CEVAP metnine YAZMA. Hiçbir uyarı/not cümlesi ekleme — metin tamamen temiz kalsın, işaretleme yalnızca elYazisindanMi elemanıyla yapılır.
- KAYNAĞA ATIF YASAK: soru ya da cevapta kaynağın NE olduğuna veya NEREDEN geldiğine dair hiçbir ifade kullanma — "el yazısı", "el yazısıyla eklenen", "görseldeki", "görselde", "resimde", "slaytın köşesinde", "slaytta not düşülen", "yazılan not" gibi kelime/kalıplar YASAK. Soru doğrudan bilginin kendisini sorsun, kaynağını değil.
  Kötü örnek: "Slaytın köşesine el yazısıyla eklenen not neydi?"
  İyi örnek: "Bulaşıcı hastalık epidemiyolojisinde vurgulanan iki temel önlem kategorisi nedir?"''';

/// El yazısı NET OKUNAMADIĞINDA ne yapılacağını söyleyen kural; [elYazisiKurali]'nın
/// hemen ardından, yalnızca görsel eklendiğinde prompt'a girer.
///
/// [kaynakSadakatiKurali] İLE AYNI ŞEY DEĞİL — bilinçli olarak ayrı bir blok:
/// orada kaynak NETTİR ama hatalıdır (ve düzeltilmeden aynen aktarılır); burada
/// kaynağın KENDİSİ okunamıyor. Gerçek vaka: model belirsiz bir el yazısı
/// kelimeyi yanlış okuyup ("tanımlar" → "Fonlar") bu yanlış okumanın üzerine
/// tamamen uydurma bir açıklama inşa etti. Yani hata kaynağı sadakat değil,
/// OKUMA belirsizliğinin tahminle kapatılmasıydı.
///
/// TEK ÇIKIŞ YOLU BİLİNÇLİ: taslakta ikinci bir seçenek daha vardı ("el
/// yazısının var olduğunu ama okunamadığını belirten gözlem kartı üret"), ama
/// böyle bir kart [elYazisiKurali]'ndaki KAYNAĞA ATIF YASAĞI'nı ("el yazısı",
/// "görselde" gibi ifadeler soru/cevap metninde YASAK) ihlal etmeden
/// yazılamazdı — model iki kuraldan birini çiğnemek zorunda kalırdı. Kullanıcı
/// kararı: seçenek kaldırıldı, geriye tek davranış kaldı — okunamayan notu
/// ATLA. Geri eklemek istersen önce atıf yasağına dar bir muafiyet yazmak
/// gerekir.
const String belirsizElYazisiKurali = '''
BELİRSİZ/OKUNAKSIZ EL YAZISI — YORUMLAMA, TAHMİN ETME:
- Ekli görüntüdeki bir el yazısı/not TAM OLARAK net okunamıyorsa (harfler belirsiz, kelime emin olunamayacak kadar bulanık ya da süslüyse): o SPESİFİK kelimeyi/ifadeyi YORUMLAMAYA veya TAHMİN ETMEYE çalışma.
- Yapman gereken tek şey var: o el yazısı notunu YOK SAY ve yalnızca sayfanın net okunabilir (basılı) içeriğinden kart üret. Okunamayan not hakkında ayrıca bir kart da AÇMA.
- ASLA net olmayan bir okumaya dayanarak kesin bir "bilgi" uydurma. Yanlış okunan bir kelimeden yeni bir açıklama İNŞA ETMEK, kaynak sadakati kuralının en ciddi ihlalidir.
  Kötü örnek: El yazısıyla yazılmış, harfleri belirsiz bir kelimeyi "Fonlar" diye yorumlayıp bunun üzerine finansal bir açıklama uydurmak.
  İyi örnek: Belirsiz kelimeyi atlayıp, sayfanın net basılı metninden kart üretmek.''';

/// [kartEtiketleriKurali]'nın (ÇIKTI BİÇİMİ bölümü) HEMEN ÖNÜNE, yalnızca
/// görsel eklendiğinde konan tek satırlık hatırlatma.
///
/// NEDEN AYRI BİR BLOK: ayrımın ayrıntılı hâli zaten [elYazisiKurali]'nda var
/// ve iki kez güçlendirildi, ama model bazı PDF'lerde hâlâ kalın/madde işaretli
/// düz metni el yazısı sanıp aşırı işaretliyordu — ayrıntılı kural prompt'un
/// ORTASINDA kalıyor. Bu satır, modelin çıktıyı üretmeye en yakın olduğu yerde
/// aynı kararı kısa ve sert biçimde tekrarlar. Yeni bir tanım GETİRMEZ,
/// [elYazisiKurali]'ndaki ayrımın özetidir; o kural değişirse burası da
/// hizalanmalı.
const String etiketlemeSonHatirlatmasi =
    '**SON HATIRLATMA — elYazisindanMi alanı: Kalın yazı, madde işareti, '
    'renkli başlık veya tablo formatı = ASLA el yazısı değildir. Bu alan '
    'yalnızca gerçekten SONRADAN elle eklenmiş bir işaret için true olur. '
    'Şüphedeysen false yaz.**\n\n'
    '**SON HATIRLATMA — derinlik: Yukarıdaki temkinlilik kuralları içerik '
    'UYDURMAYI önlemek içindir, seni BASİTLEŞTİRMEYE zorlamaz. Sayfa '
    'klinik bir ilişki/tablo/sayısal veri içeriyorsa, sinavTipiKurali\'ne '
    'göre HER biri için sınav tipi kart üretmeyi ve zorlukKurali\'ne göre '
    'gerçek zorluk seviyesini (kolay/orta/zor karışık) uygulamayı ASLA '
    'atlama.**';

/// Slayt kendi üzerinde numaralandırılmışsa o numarayı okutup "slaytNumarasi"
/// alanına yazdıran kural; yalnızca [buildPagePrompt]'a, yalnızca görsel
/// eklendiğinde (hasImage) eklenir. Sebep: [PdfPage.page] PDF'in fiziksel
/// yaprak sırasıdır (`pdf_extract.js`'teki `i`, pdf.js'in saydığı) — PDF'in
/// başında kapak/boş sayfa varsa bu, slaytın kendi numarasından kayar
/// (ör. slaytın 24. sayfası dosyanın 27. fiziksel yaprağı olabilir). Bu alan
/// doluysa [flashcardFromItem] onu fiziksel sıraya TERCİHEN kullanır.
const String slaytNumarasiKurali = '''
SLAYT NUMARASI (kart dizisinin $kompaktSlaytNumarasiIndex. indeksli elemanı, "slaytNumarasi"):
- Ekli görüntüde, slaytın kendi üzerinde YAZILI OLAN sayfa numarasını ara (genelde köşede/altta küçük bir rakam).
- Net ve emin şekilde okuyabiliyorsan bu sayıyı slaytNumarasi elemanına yaz (ör. "12").
- Okuyamıyorsan, sayfada böyle bir numara yoksa ya da emin değilsen o elemanı null bırak — TAHMİN ETME. Elemanı ATLAMA, yerine null yaz.''';

/// Her kart için istenen alanları ve KOMPAKT (dizi) çıktı biçimini anlatan
/// ortak footer; hem [buildGeneralPrompt] (Yol B) hem [buildPagePrompt]
/// (Yol A) tarafından BİREBİR paylaşılır — biri güncellenip diğerinin
/// unutulmaması için tek yerde tutulur.
///
/// KOMPAKT BİÇİM (2026-08-04): Kartlar artık alan adlı NESNE değil, sırası
/// sabit 9 elemanlı DİZİ olarak isteniyor. Sebep tamamen maliyet: çıktı
/// tokenları girdinin 6 katı fiyattan faturalanıyor ve her kartta 9 alan adı
/// + uzun enum değerleri (`"elYazisindanMi": false` gibi) tekrar tekrar
/// yazılıyordu. Kartın İÇERİĞİNE dair hiçbir kural değişmedi; öğrenciye
/// gösterilen veri de değişmedi — [flashcardFromCompactItem] diziyi aynı
/// [Flashcard] alanlarına geri çeviriyor.
const String kartEtiketleriKurali = '''
ÇIKTI BİÇİMİ — HER KART BİR NESNE DEĞİL, $kompaktAlanSayisi ELEMANLI BİR DİZİDİR (ZORUNLU):
Yanıtın "dizilerden oluşan bir dizi" olsun. ALAN ADI YAZMA; her kartta eleman SIRASI sabittir. Hiçbir elemanı atlama — bilmiyorsan ya da istenmemişse o pozisyona null yaz, yoksa sıra kayar ve kart bozulur.

SIRA:
[0] soru — Türkçe soru metni.
[1] kisaCevap — yukarıdaki İKİ AYRI CEVAP kuralına göre 3-8 kelimelik doğrudan yanıt.
[2] cevap — açıklamalı tam cevap (2-4 cümle, gerekçesiyle); Türkçe yaz.
[3] zorluk kodu — yukarıdaki ZORLUK KALİBRASYONU kuralına göre "k"=kolay, "o"=orta, "z"=zor.
[4] kartTipi kodu — "s"=sinav (soru kısa bir hasta/durum senaryosuyla başlayıp oradan bilgiye geri gidiyorsa), "t"=temel (soru bilgiyi doğrudan soruyorsa).
[5] oncelik kodu — yukarıdaki ÖNCELİK ETİKETİ kuralına göre "o"=oncelikli, "a"=arka_plan.
[6] konu — kartın ait olduğu alt konu, 1-3 kelime (örnek: "kapaklar", "koroner dolaşım", "ileti sistemi"). Aynı alt konudaki kartlarda BİREBİR AYNI etiketi kullan; küçük harfle yaz.
[7] slaytNumarasi — YALNIZCA yukarıda slaytın kendi numarasını okumanı isteyen ayrı bir kural verildiyse doldur; böyle bir kural yoksa ya da numarayı net okuyamıyorsan null yaz.
[8] elYazisindanMi — yukarıdaki EL YAZISI İŞARETİ kuralına göre "true"/"false" (görsel yoksa her zaman "false").

DİKKAT: [3] ve [5] AYRI kod kümeleridir. "o" [3]. pozisyonda "orta", [5]. pozisyonda "oncelikli" demektir; karıştırma.

BİÇİM ÖRNEĞİ (yalnızca biçimi göstermek için — içeriğini kopyalama):
[
  ["Kalp kapaklarının açılıp kapanmasını sağlayan mekanizma nedir?","Odacıklar arası basınç farkı","Kapaklar kas gücüyle değil, iki odacık arasındaki basınç farkıyla pasif olarak açılıp kapanır. Basınç kapağın gerisindeki odacıkta yükseldiğinde kapak açılır, ters yönde basınç oluşunca kapanır; bu sayede kan tek yönde ilerler.","o","t","o","kapaklar",null,"false"],
  ["55 yaşında hastada eforla artan göğüs ağrısı ve EKG'de ön duvar iskemisi saptanıyor. Hangi arterin darlığı beklenir?","Sol ön inen arter (LAD)","LAD sol ventrikülün ön duvarını ve interventriküler septumun ön bölümünü besler; bu alanın iskemisi EKG'de ön duvar derivasyonlarında değişiklik yapar. Bu nedenle ön duvar iskemisinde ilk düşünülecek damar LAD'dir.","z","s","o","koroner dolaşım","12","true"]
]

Yanıtına başka hiçbir metin, açıklama, başlık veya markdown ekleme.''';

/// Sayfanın hem ham metni hem render edilmiş görüntüsü modele birlikte
/// gönderildiğinde ikisinin nasıl birleştirileceğini anlatan blok.
/// [buildPagePrompt]'a yalnızca [hasImage] true iken eklenir (yalnızca
/// vision destekleyen sağlayıcılarda anlamlıdır).
const String metinVeGorselBirlikteKurali = '''
SAYFANIN HEM METNİ HEM GÖRÜNTÜSÜ EKLİ — İKİSİNİ BİRLİKTE KULLAN:
- Aşağıdaki metni terminoloji (Latince/tıbbi terimler) ve tablo/liste yapısını doğru okumak için referans al.
- Ekli GÖRÜNTÜDE SONRADAN EKLENMİŞ bir vurgu/not varsa, bunları EN ÖNCELİKLİ bilgi olarak işle: önce bunlardan kart üret. Bu işaretler öğrencinin kendi notu/vurgusudur ve sınavda çıkacak kritik noktalar olarak kabul et.
  - "Sonradan eklenmiş" ölçütü, aşağıdaki EL YAZISI İŞARETİ kuralındaki KARAR KRİTERİNİN AYNISIDIR: öğe slaydın geri kalanından farklı, sonradan eklenmiş gibi mi duruyor (gerçek el yazısı, üzerine çizilmiş daire/ok, fosforlu kalem izi, tasarım diliyle tutarsız kutu/çerçeve), yoksa slaydın baştan tasarlanmış bir parçası mı? Bu iki kural aynı ayrımı kullanır: birinde vurgu sayılan öğe diğerinde de vurgudur, birinde sayılmayan diğerinde de sayılmaz.
  - Slaydın KENDİ TUTARLI TASARIM DİLİNE ait renkli/kalın metin (tüm başlıkların aynı renkte olması, her teknik terimin aynı renkte yazılması, tablo başlıkları, bold terim tanımları) bu öncelik kuralına GİRMEZ. Onları normal içerik gibi ele al ve yukarıdaki ÖNCELİKLENDİR bölümünün ölçütleriyle (ayırt edicilik, karşılaştırma, sayısal değer, sınıflandırma) değerlendir. Bir şeyin renkli ya da kalın olması onu tek başına öncelikli YAPMAZ.
- Görüntüde metin katmanında olmayan bir tablo/şema varsa (renkli/görsel olarak gömülü) her satırı/ilişkiyi ayrı kart olarak işle, atlama.
- Metinde olup görüntüde net görünmeyen (ör. kesik/bulanık) bir kısımdan kart üretmekten çekinme — metin zaten güvenilir kaynak; sadece görüntüden okuduğun ek bilgide (el yazısı vb.) emin olmadığın kısmı atla.
- Sonuçta metin ve görüntüyü BİRLEŞTİREREK kapsamlı kart üret; aynı bilgiyi hem metinden hem görüntüden görüyorsan tekrar kart üretme.''';

// ---------------------------------------------------------------------------
// KOMPAKT KART BİÇİMİ — sabit pozisyonlar ve kısaltma kodları
// ---------------------------------------------------------------------------
// Model her kartı alan adlı bir nesne yerine sırası sabit bir DİZİ olarak
// döndürür (bkz. [kartEtiketleriKurali]). Pozisyonlar burada tek yerde
// tanımlı: prompt metni de, [flashcardFromCompactItem] de bu sabitleri
// kullanır, böylece sıra tek bir yerden değiştirilebilir.

/// Kompakt kart dizisindeki eleman sayısı (şemada min/maxItems olarak da
/// dayatılır).
const int kompaktAlanSayisi = 9;

const int kompaktSoruIndex = 0;
const int kompaktKisaCevapIndex = 1;
const int kompaktCevapIndex = 2;
const int kompaktZorlukIndex = 3;
const int kompaktKartTipiIndex = 4;
const int kompaktOncelikIndex = 5;
const int kompaktKonuIndex = 6;
const int kompaktSlaytNumarasiIndex = 7;
const int kompaktElYazisiIndex = 8;

/// Zorluk kısaltmaları → [CardDifficulty.parse]'ın anladığı tam değerler.
const Map<String, String> kompaktZorlukKodlari = {
  'k': 'kolay',
  'o': 'orta',
  'z': 'zor',
};

/// Kart tipi kısaltmaları → [CardType.parse]'ın anladığı tam değerler.
const Map<String, String> kompaktKartTipiKodlari = {
  't': 'temel',
  's': 'sinav',
};

/// Öncelik kısaltmaları → [CardPriority.parse]'ın anladığı tam değerler.
/// DİKKAT: "o" burada "oncelikli", [kompaktZorlukKodlari]'nda "orta" demek —
/// aynı harf farklı pozisyonda farklı anlam taşıyor, karıştırma.
const Map<String, String> kompaktOncelikKodlari = {
  'o': 'oncelikli',
  'a': 'arka_plan',
};

/// Gemini'ın döndürmesi gereken şema (`generationConfig.responseSchema`).
/// Yalnızca Gemini structured-output alanı bunu doğrudan kullanır; biçim
/// (pozisyonlar/kodlar) diğer sağlayıcılar için de referans kaynağıdır.
///
/// KOMPAKT: her kart artık OBJECT değil, [kompaktAlanSayisi] elemanlı bir
/// ARRAY.
///
/// `minItems`/`maxItems` BİLEREK YOK (2026-08-04): uzunluğu şemada kilitlemek
/// sıra kaymasına karşı yapısal bir garanti olurdu, ama Gemini'ın bu iki alanı
/// nested ARRAY'de kabul ettiği canlı doğrulanamadı (hesabın kredisi tükenmiş)
/// ve reddedilseydi tüm istekler 400 ile ölürdü. Kullanıcının bilinçli kararı:
/// canlı testte risk alma. Eleman sayısı yalnızca prompt'ta dayatılıyor (bkz.
/// [kartEtiketleriKurali] — "hiçbir elemanı atlama, bilmiyorsan null yaz") ve
/// [flashcardFromCompactItem] kısa/uzun diziyi zaten çökmeden karşılıyor.
/// Kredi yüklenip biçim canlıda doğrulandıktan sonra ek güvenlik olarak
/// geri eklenebilir.
///
/// NEDEN HEPSİ STRING: Gemini'ın şema alt kümesi heterojen ("tuple") dizi
/// desteklemiyor — bir ARRAY'in tek bir `items` şeması olabilir, pozisyon
/// başına farklı tip verilemez. Bu yüzden `elYazisindanMi` ve
/// `slaytNumarasi` de STRING olarak isteniyor ("true"/"12"). Bu bir kayıp
/// değil: [flashcardFromCompactItem] hem string hem native bool/int kabul
/// eder, yani şema ileride gevşetilirse ayrıştırma tarafı değişmez.
/// `nullable: true` yalnızca [kompaktSlaytNumarasiIndex] için gerekli ama
/// tek `items` şeması olduğundan hepsine uygulanıyor (zararsız — boş gelen
/// bir pozisyon zaten hoşgörülü karşılanıyor).
///
/// CANLI DOĞRULANMADI (2026-08-04): Gemini hesabının kredisi tükendiği için
/// (her istek 429 "prepayment credits are depleted") bu şemanın API tarafından
/// kabul edildiği gerçek bir çağrıyla teyit EDİLEMEDİ. Bu yüzden şema
/// kasıtlı olarak en sade hâlinde tutuldu (yalnızca `type` + `items` +
/// `nullable`) — hepsi Gemini'ın en temel şema alanları.
const Map<String, dynamic> responseSchema = {
  'type': 'ARRAY',
  'items': {
    'type': 'ARRAY',
    'items': {'type': 'STRING', 'nullable': true},
  },
};

/// Yol B (yapıştırılan metin ve/veya görsel ek) için genel prompt.
String buildGeneralPrompt(String sourceText, {required bool hasMedia}) {
  final hasText = sourceText.trim().isNotEmpty;

  final String kaynak;
  if (hasMedia && hasText) {
    kaynak = 'ekli görsel ders slayt(lar)ından VE aşağıya yapıştırılan '
        'nottan (ikisi aynı konuysa birleştir, tekrar üretme)';
  } else if (hasMedia) {
    kaynak = 'ekli görsel ders slayt(lar)ından';
  } else {
    kaynak = 'aşağıdaki Türkçe ders notundan';
  }

  final mediaKurali = hasMedia
      ? '\n- Ekli görseldeki tüm metni, başlıkları, madde işaretlerini, '
            'tablo ve diyagram etiketlerini dikkatle oku. Bulanık/kesik/okunamayan '
            'bir kısımdan kart ÜRETME; yalnızca net okuduğun içerikten üret.'
      : '';

  final notBlogu = hasText
      ? '\n\nYAPIŞTIRILAN NOT:\n"""\n${sourceText.trim()}\n"""'
      : '';

  return '''
Sen tıp fakültesinde sınav sorusu hazırlayan deneyimli bir eğitmensin. $kaynak öğrenciyi sınava hazırlayacak flashcard'lar üret.

SORU SEVİYESİ — EN ÖNEMLİ KURAL:
Basit tanım ve hatırlama soruları ("X nedir?", "Y kaç tanedir?") sınavda ayrıştırıcı değildir. Kartların çoğunluğu bilgiyi İLİŞKİLENDİREN ve muhakeme gerektiren tipte olmalı. Şu tiplerden yararlan:
- Yapı-işlev ilişkisi: bir yapının özelliği hangi işlevsel gereksinimden kaynaklanıyor?
- Karşılaştırma ve ayrım: iki yapı arasındaki fark nedir, bu farkın işlevsel sonucu nedir?
- Sıralama ve akış: bir maddenin/uyarının izlediği yolu sırayla say.
- Neden-sonuç: bir durum neden bir başkasına yol açar?
- Klinik çıkarım: bir yapı bozulursa/tıkanırsa ne olur ve neden?

KURALLAR:
- Yalnızca kaynakta verilen bilgiden çıkarılabilen sorular sor; dışarıdan bilgi ekleme, uydurma.$mediaKurali
- KAYNAK EĞİTİM İÇERİĞİ DEĞİLSE BOŞ dizi [] döndür. Kaynak hiçbir şekilde bir ders/eğitim materyali değilse — kişisel bir not, ders materyaliyle alakasız bir fotoğraf, okunamayan/bozuk bir görüntü, ya da başka herhangi bir tıbbi/akademik olmayan içerikse — KESİNLİKLE boş dizi [] döndür. Kart üretmek zorunda değilsin.
- ASLA inandırıcı görünen, konuyla "ilgili olabilecek" bir bilgi UYDURMA. Emin değilsen, ya da içerik gerçek bir ders materyaline benzemiyorsa, HİÇBİR KART ÜRETME — bu, yanlış bir kart üretmekten HER ZAMAN daha güvenlidir. Boş dizi döndürmek başarısızlık değildir; uydurma kart üretmek ise ciddi bir hatadır.
  Kötü örnek: Kaynakta olmayan ama "tipik ders içeriği gibi görünen" bir bilgi uydurup ondan kart üretmek (ör. tıbbi hiçbir şey içermeyen, alakasız bir el yazısı fotoğrafından "bulaşıcı hastalık kontrolü" kartı çıkarmak).
  İyi örnek: İçerik ders materyaline benzemiyorsa ya da konuyla hiç alakası yoksa boş dizi [] döndürüp hiçbir şey üretmemek.
- En fazla 1-2 kart temel tanım düzeyinde olabilir; gerisi ilişkisel/uygulama düzeyinde olsun.
- Cevaplar sınavda yeterli olacak kadar bilgi içersin (2-4 cümle) ve gerekçeyi açıklasın. $cevapSadeligiKurali
- Latince/İngilizce tıbbi terimleri kaynakta geçtiği gibi koru.
- $kaynakSadakatiKurali
- Kaynakta GERÇEKTEN yeterli içerik varsa, içerdiği bilgi miktarına göre 5-20 kart üret, zorlama şişirme (sınav tipi kartlar bu sayıya dahildir; klinik ilişki sayısı fazlaysa üst sınır olarak düşünme). Bu sayı bir ALT SINIR DEĞİLDİR: kaynak eğitim içeriği değilse ya da hiçbir test edilebilir bilgi taşımıyorsa BU SAYI GEÇERLİ DEĞİLDİR — yukarıdaki kural gereği boş dizi [] döndür.
- Soru ve cevapları Türkçe yaz.

$zorlukKurali

$sinavTipiKurali

$icerikKalitesiOrnegi

$oncelikKurali

$terminolojiStandardiKurali

$guncellikDiliYasagiKurali

$kaynakReferansiGizlemeKurali

$ikiKatmanliCevapKurali
${hasMedia ? '\n$elYazisiKurali\n\n$belirsizElYazisiKurali\n' : ''}
HER KART İÇİN:
${hasMedia ? '$etiketlemeSonHatirlatmasi\n\n' : ''}$kartEtiketleriKurali$notBlogu
''';
}

/// Yol A (PDF sayfa pipeline'ı) için sayfa-bazlı prompt.
String buildPagePrompt(String pageText, int pageNumber, {bool hasImage = false}) {
  final goruntuBlogu = hasImage ? '\n\n$metinVeGorselBirlikteKurali' : '';
  return '''
Sen tıp fakültesinde sınav sorusu hazırlayan deneyimli bir eğitmensin. Aşağıda bir ders slaytının TEK BİR SAYFASININ metni var (sayfa $pageNumber). SADECE bu sayfadaki bilgiden sınav odaklı flashcard üret.

KESİN KURALLAR:
- Yalnızca bu sayfada AÇIKÇA yazan (veya ekliyse görüntüdeki) bilgiden kart üret. Sayfada olmayanı ekleme, uydurma. Emin değilsen kart üretme.
- Sayfa test edilecek bilgi içermiyorsa BOŞ dizi [] döndür. Kart üretmek zorunda değilsin. Böyle sayfalara örnekler: başlık/ajanda/geçiş/telif sayfası VE kapanış/teşekkür slaydı (ör. "Teşekkür ederim", "Sorularınız?", kaynakça/referans listesi, sadece yazar/kurum bilgisi). "Teşekkür ederim" yazan bir slayttan ASLA kart üretme — bu içerik değil, kapanıştır.
- BU KURAL YALNIZCA DERS SLAYDI TÜRLERİYLE (başlık/ajanda/teşekkür) SINIRLI DEĞİLDİR. Sayfa ya da görsel HİÇBİR ŞEKİLDE bir ders/eğitim içeriği değilse — kişisel bir not, ders materyaliyle alakasız bir fotoğraf, okunamayan/bozuk bir görüntü, ya da başka herhangi bir tıbbi/akademik olmayan içerikse — KESİNLİKLE boş dizi [] döndür.
- ASLA inandırıcı görünen, konuyla "ilgili olabilecek" bir bilgi UYDURMA. Emin değilsen, ya da içerik gerçek bir ders materyaline benzemiyorsa, HİÇBİR KART ÜRETME — bu, yanlış bir kart üretmekten HER ZAMAN daha güvenlidir. Boş dizi döndürmek başarısızlık değildir; uydurma kart üretmek ise ciddi bir hatadır.
  Kötü örnek: Kaynakta olmayan ama "tipik ders içeriği gibi görünen" bir bilgi uydurup ondan kart üretmek (ör. tıbbi hiçbir şey içermeyen, alakasız bir el yazısı fotoğrafından "bulaşıcı hastalık kontrolü" kartı çıkarmak).
  İyi örnek: İçerik ders materyaline benzemiyorsa ya da konuyla hiç alakası yoksa boş dizi [] döndürüp hiçbir şey üretmemek.
- ÖNEMLİ AYRIM: Yukarıdaki "emin değilsen üretme" ilkesi YALNIZCA bir kartın içeriğinin kaynakta GERÇEKTEN var olup olmadığıyla ilgilidir (uydurma riski). Bu ilke, bir kartın ZORLUĞUNU ya da TİPİNİ (sınav tipi/temel) güvenli/basit tutmak için KULLANILMAZ — sayfa gerçekten klinik/patolojik bir ilişki içeriyorsa, aşağıdaki sinavTipiKurali ve zorlukKurali TAM GÜÇLE geçerlidir, "temkinli olayım" diye düz/basit kart üretmeyi tercih etme.
- Terminolojiyi (Latince/tıbbi/teknik) sayfadaki gibi koru.
- $kaynakSadakatiKurali$goruntuBlogu

ÖNCELİKLENDİR (sınav tetikleyicileri):
- Ayırt edici/karşılaştırma bilgileri (iki şey arasındaki fark ve işlevsel sonucu).
- "en sık / en önemli / ilk basamak / en tehlikeli" gibi ifadeler.
- Sınıflandırma ve listeler ("X'in 4 nedeni", basamaklar).
- Sayısal değerler, normal aralıklar ve eşikler.
Düz tanım kartını yalnızca sayfada başka değerli bilgi yoksa üret.

TABLO VE SAYISAL VERİ — ASLA ATLAMA:
- Sayfada (metinde ya da ekli görüntüde) bir tablo varsa, kart üretmeye başlamadan ÖNCE tablonun veri satırlarını (sütun başlığı değil, her biri ayrı bir öğe/kavram olan satırları) tek tek zihninde say. Örneğin 5 satırlık bir tabloda 5 ayrı öğe vardır; kart sayın bu sayının altına düşerse eksik bırakmışsındır.
- EN SIK YAPILAN HATA — DİKKAT: Tablonun sadece İLK ve SON satırı hatırlanıp ORTADAKİ satırlar atlanıyor (bir tür "ilk/son öğeyi hatırlama" hatası). Bunun tam tersini yap: tablonun ortasındaki satırlara en az ilk ve son satır kadar özen göster, aralarında hiçbirini "zaten örtük geçti" diyerek atlama.
- Bir tablodaki her satır, konu ilerleyen sayfalarda tekrar geçse bile, MUTLAKA kendi başına en az bir kart üretmeli. "İleride değinilecek" varsayımıyla bir satırı atlama — okuyucu kartları sırayla değil karışık göreceği için, her satırın bağımsız bir kartı olmalı.
- Bir satırın bilgisi başka bir kartta dolaylı/yan bilgi olarak geçmesi YETERLİ DEĞİL — o satır için AYRICA kendi doğrudan kartı olmalı.
- ÇOKLU ÖĞE SATIRLARINDA EŞLEŞTİRMEYİ BOZMA: Bir satırda/hücrede birden fazla ilaç/öğe aynı hedefi paylaşıyor ama HER BİRİNİN kendine özgü ayrı bir endikasyonu/özelliği varsa, bunları TEK bir birleşik cevapta harmanlama. İki yoldan birini seç: (a) her ilaç/öğe için AYRI kart üret (kendi endikasyonuyla), ya da (b) tek kartta kalacaksan cevapta her öğeyi KENDİ endikasyonuyla eşleştir. "Hepsi şu dört durumda kullanılır" gibi genelleyici tek liste ASLA yapma — bu, kaynakta olmayan bir bilgi üretmektir.
  Kötü örnek: "Cetuximab, Panitumumab, Nimotuzumab → kolorektal, meme, akciğer, baş-boyun" (yanlış: her ilaç farklı alt kümeyi kapsıyor).
  İyi örnek: "Cetuximab → kolorektal/meme/akciğer; Panitumumab → kolorektal; Nimotuzumab → baş-boyun" (ya da üçü için ayrı ayrı üç kart).
- Sayısal değerleri, formülleri ve normal aralıkları asla atlama — bunlar sınavda en sık sorulan bilgilerdir.
- Bir sayfada birden fazla kart-değer bilgisi varsa hepsini işle, sadece 1-2 taneyle yetinme. Tabloda N satır varsa üretilen kart sayısını N'in altına düşürme.
- SAYFADA BİRDEN FAZLA TABLO/BAŞLIKLI BÖLÜM VARSA HİÇBİRİNİ KOMPLE ATLAMA: sayfada iki veya daha fazla ayrı tablo ya da alt başlık varsa (ör. önce bir tablo, sonra farklı bir başlık altında ikinci bir tablo), her BÖLÜMÜ ayrı ayrı, birbirinden bağımsız bir görev gibi ele al ve her birinden en az bir kart üret. Sayfanın sonundaki/son bölümdeki bilgiye ağırlık verip başındaki/önceki bölümü tamamen atlamak KABUL EDİLEMEZ — bu, tek bir tablo içindeki satır atlamayla AYNI DERECEDE ciddi bir hatadır. Kart üretmeden önce sayfadaki tüm ayrı başlık/bölümleri say ve her birinin en az bir kartla temsil edildiğinden emin ol.

$zorlukKurali

$sinavTipiKurali

$icerikKalitesiOrnegi

$oncelikKurali

$terminolojiStandardiKurali

$guncellikDiliYasagiKurali

$kaynakReferansiGizlemeKurali

$ikiKatmanliCevapKurali
${hasImage ? '\n$elYazisiKurali\n\n$belirsizElYazisiKurali\n\n$slaytNumarasiKurali\n' : ''}
HER KART İÇİN:
- Soru ve cevabı (2-4 cümle, gerekçesini de ver) Türkçe yaz. $cevapSadeligiKurali
${hasImage ? '$etiketlemeSonHatirlatmasi\n\n' : ''}$kartEtiketleriKurali

Bu sayfadan sayfanın içerdiği bilgi miktarına göre kart üret (sınav tipi kartlar dahil, her klinik ilişki için ayrı sayılır); basit bir sayfa 2-3 kart yeterli olabilir, yoğun tablo/liste veya çok sayıda klinik ilişki içeren bir sayfa 25 karta kadar çıkabilir — bir üst sınır olarak düşünme, sayfadaki her ayrı ilişkiyi kapsamak öncelik. Sadece kapsamı doldurmak için tekrar/şişirme kart üretme.

SAYFA $pageNumber METNİ:
"""
$pageText
"""
''';
}

/// Sağlayıcıdan bağımsız olarak, çözülmüş tek bir kart öğesini [Flashcard]'a
/// çevirir. Öğe KOMPAKT DİZİ ise [flashcardFromCompactItem]'a devreder (güncel
/// biçim), alan adlı bir Map ise eski biçimden çevirir. soru/cevap boşsa (ya
/// da öğe ne List ne Map ise) `null` döner — çağıran bu durumda kartı atlar.
/// Gemini ve DeepSeek'in üç ayrı yerde tekrarlanan aynı dönüşüm mantığını tek
/// yerde tutar; biçim tutarlılığı buradan garanti edilir.
///
/// [sourcePage] çağıranın verdiği FİZİKSEL sayfa sırasıdır (bkz.
/// [PdfPage.page]). Modelin döndürdüğü "slaytNumarasi" (bkz.
/// [slaytNumarasiKurali]) geçerli bir pozitif sayıysa ona TERCİHEN kullanılır
/// — kapak/boş sayfa yüzünden oluşan kaymayı düzeltir. Model bu alanı
/// doldurmadıysa (Yol B'de hiç istenmez, Yol A'da okunamadıysa null) sessizce
/// [sourcePage]'e düşülür; davranış hiç değişmez.
Flashcard? flashcardFromItem(
  Object? item, {
  required String id,
  int? sourcePage,
}) {
  // KOMPAKT BİÇİM (güncel): model kartı sırası sabit bir dizi olarak döndürür.
  if (item is List) {
    return flashcardFromCompactItem(item, id: id, sourcePage: sourcePage);
  }
  // ESKİ BİÇİM (alan adlı nesne): şema kompakt diziye geçtiği için Gemini
  // artık böyle dönmüyor, ama şemasız/hoşgörülü bir sağlayıcı ya da eski bir
  // yanıt böyle gelirse kart yine de kurtarılsın diye bilerek korunuyor.
  if (item is! Map) return null;

  final question = (item['soru'] as Object?)?.toString().trim() ?? '';
  final answer = (item['cevap'] as Object?)?.toString().trim() ?? '';
  if (question.isEmpty || answer.isEmpty) return null;

  // TOLERANSLI: `as num?` cast'i, model bu alanı string ("12") yazdığında
  // TypeError fırlatıyordu. Çağıran döngülerin ([GeminiService._parsePageCards],
  // [DeepSeekService._parseCards]) hiçbirinde kart bazlı try/catch yok — tek
  // bozuk kart TÜM sayfayı düşürürdü. [_kompaktInt] native num/sayı-string/
  // null hepsini kabul eder, çözemezse null döner ve kart yalnızca fiziksel
  // sayfaya düşer. Kompakt yoldaki davranışla birebir aynı.
  final slaytNumarasi = _kompaktInt(item['slaytNumarasi']);
  final effectiveSourcePage = (slaytNumarasi != null && slaytNumarasi > 0)
      ? slaytNumarasi
      : sourcePage;

  return Flashcard(
    id: id,
    question: question,
    answer: answer,
    shortAnswer: (item['kisaCevap'] as Object?)?.toString().trim() ?? '',
    difficulty: CardDifficulty.parse(item['zorluk']),
    cardType: CardType.parse(item['kartTipi']),
    priority: CardPriority.parse(item['oncelik']),
    topic: (item['konu'] as Object?)?.toString().trim().toLowerCase() ?? '',
    sourcePage: effectiveSourcePage,
    isHandwritten: item['elYazisindanMi'] == true,
  );
}

/// Modelin döndürdüğü KOMPAKT kart dizisini [Flashcard]'a çevirir (bkz.
/// [kartEtiketleriKurali] — çıktı token maliyetini düşürmek için alan adları
/// kaldırılıp sıra sabitlendi).
///
/// Beklenen sıra (bkz. `kompakt*Index` sabitleri):
/// `[soru, kisaCevap, cevap, zorlukKodu, kartTipiKodu, oncelikKodu, konu,
/// slaytNumarasi, elYazisindanMi]`
///
/// SAVUNMACI — asla fırlatmaz: [item] dizi değilse, kısa/uzun geldiyse, bir
/// pozisyonda beklenmedik tip varsa ya da soru/cevap boşsa `null` döner ve
/// çağıran kartı sessizce atlar (mevcut `_parsePageCards` davranışıyla
/// birebir aynı). Kısaltma kodları tanınmazsa ilgili enum'un kendi
/// varsayılanına düşülür (zorluk→orta, kartTipi→temel, oncelik→oncelikli) —
/// yani biçim hatası kartı yok etmez, yalnızca etiketini varsayılana çeker.
///
/// Tip esnekliği bilinçli: şema şu an her elemanı STRING olarak istiyor ama
/// fonksiyon native `bool`/`num` de kabul eder, böylece şema gevşetilirse
/// (ya da başka bir sağlayıcı native tip dönerse) burada değişiklik gerekmez.
Flashcard? flashcardFromCompactItem(
  Object? item, {
  required String id,
  int? sourcePage,
}) {
  if (item is! List) return null;

  Object? at(int index) => index < item.length ? item[index] : null;
  String text(int index) => at(index)?.toString().trim() ?? '';

  final question = text(kompaktSoruIndex);
  final answer = text(kompaktCevapIndex);
  if (question.isEmpty || answer.isEmpty) return null;

  final slaytNumarasi = _kompaktInt(at(kompaktSlaytNumarasiIndex));
  final effectiveSourcePage = (slaytNumarasi != null && slaytNumarasi > 0)
      ? slaytNumarasi
      : sourcePage;

  return Flashcard(
    id: id,
    question: question,
    answer: answer,
    shortAnswer: text(kompaktKisaCevapIndex),
    difficulty: CardDifficulty.parse(
      _kompaktKod(kompaktZorlukKodlari, at(kompaktZorlukIndex)),
    ),
    cardType: CardType.parse(
      _kompaktKod(kompaktKartTipiKodlari, at(kompaktKartTipiIndex)),
    ),
    priority: CardPriority.parse(
      _kompaktKod(kompaktOncelikKodlari, at(kompaktOncelikIndex)),
    ),
    topic: text(kompaktKonuIndex).toLowerCase(),
    sourcePage: effectiveSourcePage,
    isHandwritten: _kompaktBool(at(kompaktElYazisiIndex)),
  );
}

/// Kısaltma kodunu tam değere açar. Kod tanınmazsa ham değeri olduğu gibi
/// döndürür — model kısaltmak yerine tam kelimeyi ("kolay") yazdıysa da
/// doğru ayrıştırılsın diye.
String? _kompaktKod(Map<String, String> kodlar, Object? raw) {
  if (raw == null) return null;
  final value = raw.toString().trim().toLowerCase();
  if (value.isEmpty) return null;
  return kodlar[value] ?? value;
}

/// Sayı pozisyonunu çözer: native sayı, sayı yazan string ya da null/"null"
/// gelebilir. Çözemezse null döner (çağıran fiziksel sayfaya düşer).
int? _kompaktInt(Object? raw) {
  if (raw is num) return raw.toInt();
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return int.tryParse(value);
}

/// Bool pozisyonunu çözer: native `true`, "true" ya da "1" kabul edilir;
/// diğer her şey (null, "false", boş, beklenmedik metin) false'tur —
/// el yazısı rozeti yanlışlıkla takılmasın diye varsayılan hep false.
bool _kompaktBool(Object? raw) {
  if (raw is bool) return raw;
  final value = raw?.toString().trim().toLowerCase();
  return value == 'true' || value == '1';
}
