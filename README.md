# MedKart

Tıp öğrencileri için AI destekli flashcard uygulaması. Ders notunu yapıştır,
Gemini soru-cevap kartları üretsin.

## Kurulum

1. Bağımlılıkları indir:

   ```
   flutter pub get
   ```

2. Proje kökündeki `.env` dosyasına Supabase proje URL'ini ve anon anahtarını
   yaz (bkz. `.env.example`):

   ```
   SUPABASE_URL=https://xxxx.supabase.co
   SUPABASE_ANON_KEY=sb_publishable_xxxx
   ```

   Bu ikisi GİZLİ DEĞİL (Supabase'in anon/publishable anahtarı tarayıcıda
   durmak üzere tasarlanmıştır, gerçek yetkilendirme sunucu tarafında
   Edge Function + RLS ile yapılır). `.env` yine de git'e gönderilmez
   (`.gitignore`'da).

   Gemini/DeepSeek API anahtarları istemcide YOK — `supabase/functions/
   ai-proxy` Edge Function'ı içinde Supabase Secret olarak duruyor (bkz.
   "Backend mimarisi" bölümü).

4. Çalıştır:

   ```
   flutter run -d chrome
   ```

## Proje yapısı

```
lib/
  main.dart                       uygulama girişi, servis kurulumu
  models/
    deck.dart                     deste modeli
    flashcard.dart                kart modeli
  services/
    flashcard_generator.dart      kart üretiminin soyut arayüzü + hata tipi
    gemini_service.dart           Gemini API uygulaması (HTTP)
    card_storage.dart             kalıcılık (soyut arayüz + shared_preferences)
  srs/
    srs_engine.dart               aralıklı tekrar algoritması (saf fonksiyonlar)
    study_session.dart            oturum kuyruğu (geri alma dahil)
  state/flashcard_store.dart      deste + kartların tek doğruluk kaynağı
  theme/app_theme.dart            renk, tipografi, buton ölçüleri
  screens/
    deck_list_screen.dart         ana ekran: desteler
    add_cards_screen.dart         desteye not yapıştırıp kart üretme
    card_list_screen.dart         bir destenin kartları, düzenle/sil
    study_screen.dart             çalışma ekranı
  widgets/                        yeniden kullanılan arayüz parçaları
```

## Büyük PDF'ten otomatik kart üretimi (pipeline)

Öğrenci büyük bir ders PDF'ini (ör. 100+ sayfa) seçer, gerisini uygulama arka
planda yapar — hiçbir teknik adım yok. Kart Ekle ekranındaki **"Ders PDF'i yükle
(otomatik)"** butonu:

1. **Sayfalama (görünmez):** PDF, pdf.js ile (tarayıcıda) sayfalarına ayrılır ve
   her sayfanın metni `kaynak_sayfa` numarasıyla çıkarılır. Hiçbir sayfa
   atlanmaz; metni çıkmayan (görsel ağırlıklı) sayfalar işaretlenir.
2. **Ön uyarı:** "Bu PDF X sayfa, ~N dk sürebilir. Başlat?" onayı.
3. **Sayfa başına üretim (paralel):** her sayfa AYRI olarak Gemini'a gönderilir
   (tüm PDF tek prompt'a doldurulmaz → kapsam korunur, "lost in the middle"
   olmaz). Aynı anda en fazla birkaç sayfa işlenir; sayfa hata verirse yeniden
   denenir, yine olmazsa o sayfa işaretlenir ama işlem çökmez.
4. **Streaming + ilerleme:** "Sayfa 47/130 işleniyor" + çubuk; kartlar
   üretildikçe destene akar, öğrenci ilk kartları hemen görür.
5. **Özet:** "130 sayfadan 214 kart üretildi, 3 sayfadan metin çıkarılamadı."
6. **kaynak_sayfa:** her kartta "s. 47" rozeti (yanlış kartta hangi slayta
   bakılacağı belli) + kart listesinde **sayfa aralığı filtresi** ("40-60.
   sayfalardan çalış").

Mimari: sayfa metni `pdf_text.dart` (web-only pdf.js interop), orkestrasyon
`services/pdf_card_pipeline.dart` (saf, test edilebilir; LLM enjekte edilir),
sayfa promptu `GeminiService.generateForPage`. Yalnızca **web** sürümünde çalışır.
Doğrulama, deduplikasyon ve model kademelendirme sonraki faza bırakıldı (kota).

**PDF için TEK giriş noktası bu pipeline'dır.** Kullanıcı PDF'i "Ders PDF'i yükle
(otomatik)" butonundan seçse de, "Görsel / PDF ekle" ile eklese de (bkz. aşağı),
sonuç aynıdır: PDF hiçbir zaman tek istekte işlenmez, her zaman sayfa sayfa bu
pipeline'a girer. Eskiden PDF'i tek bir Gemini isteğine tıkıştıran ikinci bir yol
vardı (`GeminiService.generate` + medya eki); kaldırıldı çünkü sourcePage
damgalayamıyordu ve çok sayfalı PDF'lerde "5-15 kart" tavanına çarpıp
tabloları/sayısal verileri atlıyordu.

## Görselden kart üretme

Kart eklerken ders notunu yapıştırmanın yanında **ders slaytı görselini** de
ekleyebilirsin ("Görsel / PDF ekle" — bu buton PDF de kabul eder ama seçilen PDF
otomatik olarak yukarıdaki sayfa-bazlı pipeline'a yönlendirilir, medyaya
eklenmez). Gemini multimodal olduğundan görsel doğrudan modele gönderilir ve
içindeki metin, başlık, tablo ve diyagram etiketlerinden kart üretilir. Metin ve
görseli birlikte de verebilirsin.

- Desteklenen türler: PNG, JPG, WebP, HEIC/HEIF. Toplam ~14 MB, en fazla 10 dosya.
- Model yalnızca **net okuduğu** içerikten kart üretir; bulanık/kesik kısımlardan
  ve dışarıdan bilgi eklemez (prompt bunu açıkça talep eder).
- Dosya seçme tarayıcı API'siyle yapılır (`file_transfer_web.dart`), bu yüzden
  **görsel ekleme yalnızca web sürümünde** çalışır; masaüstü/Android'de metin
  yapıştırma çalışmaya devam eder. İşin çekirdeği `GeminiService` içinde
  (`generate(text, media:)`), arayüz `AddCardsScreen`.

## Desteler

Kartlar destelere ayrılır (ör. "Komite 1 · Kalp"). Her deste ayrı çalışılır,
kendi tekrar kuyruğunu ve konu etiketlerini taşır; bir destede çalışmak
diğerlerini etkilemez. Deste silinince yalnızca kendi kartları gider.

Deste desteği gelmeden önce kaydedilmiş kartlar, ilk açılışta otomatik olarak
"Kartlarım" adlı tek bir desteye taşınır; SRS ilerlemesi korunur.

## Aralıklı tekrar (SRS)

SM-2'nin (SuperMemo/Anki) sadeleştirilmiş hali. Ayrıntılar `lib/srs/srs_engine.dart`
içinde; özet:

Çalışma ekranında üç kademeli değerlendirme (Anki tarzı):

| Cevap | Kısayol | Sonuç |
|---|---|---|
| Zor | 1 | Aralık sıfırlanır, kart ertesi güne atanır, kolaylık katsayısı 0.2 düşer (kart sıklaşır) ve aynı oturumda tekrar sorulur |
| Orta | 2 | 1. doğruda 1 gün, 2. doğruda 4 gün, sonrasında aralık × kolaylık katsayısı (4 → 10 → 25 …) |
| Kolay | 3 | Ortadan bir kademe ileri (yeni kartta bile en az 4 gün) + kolaylık bonusu; katsayı 0.15 artar |

Aralık en fazla 365 gün. Klavye: **Boşluk/Enter** = kartı çevir, **1/2/3** =
Zor/Orta/Kolay. Kısayol ipucu çalışma ekranının altında (yalnızca masaüstü/web'de).

Kolaylık katsayısı 1.3 ile 2.8 arasında tutulur. Başlangıç değeri AI'ın zorluk
etiketinden gelir (kolay 2.6 / orta 2.5 / zor 2.3), sonrasında kullanıcının kendi
cevaplarıyla kayar.

Konu etiketleri zayıflık ölçmekte kullanılır: bir konudaki unutma oranı yüksekse
o konunun kartları çalışma sırasında öne çekilir.

## İstatistik (streak, heatmap, konu başarısı)

Ana ekranın sağ üstündeki grafik simgesi **İstatistik** ekranını açar:

- **Streak (seri)** — kesintisiz ardışık çalışma günü sayısı (🔥). Gün içinde
  henüz çalışılmadıysa seri kopmuş sayılmaz (düne kadar sayılır).
- **Heatmap** — GitHub katkı grafiği tarzı takvim: her kare bir gün, rengi o gün
  çalışılan kart sayısıyla koyulaşır. Yatay kaydırılır, en yeni hafta sağda.
- **Konu başarısı** — her konu etiketi için başarı oranı (`= 1 − zayıflık =
  doğru/deneme`), en zayıf konu üstte. Bu, SRS'in çalışmada öne çektiği zayıflık
  ölçüsüyle birebir aynıdır. Hiç çalışılmamış konu "henüz çalışılmadı" görünür.

Günlük çalışma sayacı her "Zor/Orta/Kolay" cevabında artar ve kütüphaneyle
birlikte `shared_preferences`'a kaydedilir (`studyLog` alanı).

## Kart düzenleme, not ve hata bildirme

Yapay zekâ ürettiği kartlar hatalı olabilir. Her kartın menüsünden **Düzenle**
ile:

- **Soru/cevap düzenleme** — kullanıcının düzeltmesi kalıcı kaydedilir. İlk
  düzenlemede AI'ın orijinal metni kartta saklanır (`originalQuestion` /
  `originalAnswer`); üzerine yazılmaz. Panelde "AI orijinaline dön" ile
  düzeltme geri alınabilir. Düzenlenen kart listede "düzenlendi" rozetiyle
  işaretlenir.
- **Kendi notum / mnemonik** — kullanıcı cevabın altına kendi akrostiş/şifresini
  ekler. Not hem kart listesinde hem çalışma ekranında (cevap açılınca) ampul
  simgesiyle gösterilir. AI üretmez; yalnızca kullanıcıya aittir.
- **"Bu kartta hata var"** — şüpheli kart işaretlenir ("hata bildirildi"
  rozeti). İşaretli kartlar `FlashcardStore.flaggedCards` ile toplu
  listelenebilir; ileride prompt iyileştirme için kullanılır. Her işaretli kart
  kendi AI orijinalini de taşıdığından hata analizinde ham çıktı elde edilir.

## Görünüm (tema)

Açık ve koyu tema desteklenir. Sağ üstteki güneş/ay düğmesi ikisi arasında
geçirir; tercih `shared_preferences`'ta saklanır (`medkart.themeMode.v1`) ve
sonraki açılışta korunur. İlk açılışta tercih yoksa cihazın sistem ayarına
uyulur. Renkler `lib/theme/app_theme.dart` içinde tek tohumdan türetilir; koyu
palet gece çalışmaya uygun, metin kontrastı WCAG AA üstündedir.

## Filtreleme (geçici çalışma destesi)

Bir destenin kart listesinin üstünde çoklu seçimli filtre çubuğu vardır: kullanıcı
**zorluk** (Kolay/Orta/Zor) ve **konu etiketi** çiplerini birlikte seçerek kartları
daraltır (ör. yalnızca "Zor" + "kalp boşlukları"). Aynı boyutta çoklu seçim "veya",
boyutlar arası "ve" gibi çalışır; boş seçim "hepsi" demektir.

Filtre etkinken alttaki buton **"Filtreyle Çalış"** olur ve çalışma oturumu yalnızca
filtreye uyan kartlarla kurulur — kalıcı bir deste oluşturmadan geçici bir alt küme
çalışılır. SRS ilerlemesi ve zayıflık sıralaması destenin tamamına göre işler.
Filtre modeli `lib/models/card_filter.dart`, uygulama `studyQueueFor(deckId, filter:)`.

## Yedekleme (JSON dışa/içe aktarma)

Veriler yalnızca tarayıcıda/cihazda (`shared_preferences`) tutulduğundan, veri
kaybına karşı yedek alınabilir. Ana ekranın sağ üstündeki yedek menüsünden:

- **Yedeği dışa aktar** — bütün kütüphane (desteler + kartlar + SRS ilerlemesi +
  çalışma geçmişi) tarih damgalı tek bir JSON dosyası olarak indirilir
  (`medkart-yedek-YYYYAAGG.json`).
- **Yedekten içe aktar** — bir yedek dosyası seçilir; onaydan sonra mevcut
  kütüphanenin tamamı bununla değiştirilir (geri yükleme).

Yedek biçimi ve okuma/yazma mantığı `lib/services/backup_service.dart` +
`library_codec.dart` içinde; okuma hoşgörülüdür (bozuk tek kayıt atlanır, yabancı
dosya reddedilir). Dosya indir/seç işi web'de tarayıcı API'siyle yapılır
(`file_transfer_web.dart`); koşullu import sayesinde masaüstü/Android derlemesi
bozulmaz (o platformlarda özellik nazikçe devre dışıdır). Depolama katmanı da
aynı `LibraryCodec`'i paylaşır.

## Kalıcılık

Kartlar ve SRS ilerlemesi her değişiklikte otomatik kaydedilir (kart üretme,
düzenleme, silme, geri alma ve her "Biliyorum/Bilmiyorum" cevabı). Kayıt yeri
`shared_preferences`: web'de tarayıcının localStorage'ı, Android'de uygulama
tercihleri. Açılışta kartlar otomatik yüklenir.

Veri bozulursa uygulama çökmez: okunamayan tek kayıt atlanır, dosyanın tamamı
bozuksa boş desteyle açılır.

Kartlar tarayıcıya/cihaza özeldir — farklı tarayıcıda veya gizli sekmede
görünmezler. Cihazlar arası eşitleme için kalıcılığın sunucuya taşınması
gerekir; `CardStorage` arayüzü bunun için hazır.

## Durum

- [x] **Adım 1** — .env kurulumu, Gemini bağlantısı, kart üretme ve listeleme
- [x] **Adım 2** — SRS motoru + çalışma ekranı
- [x] **Adım 3** — kalıcılık (kaydet/yükle)

## Backend mimarisi

Gemini/DeepSeek API çağrıları istemciden değil, bir Supabase Edge Function'ı
(`supabase/functions/ai-proxy`) üzerinden yapılır: istemci kendi Edge
Function'ına istek atar, o da ilgili sağlayıcıya gidip ham cevabı aynen
döner. API anahtarları yalnızca orada, Supabase Secret olarak duruyor —
`.env`'de veya derlenmiş web paketinde HİÇBİR ŞEKİLDE bulunmuyor.
Değişecek tek yer `GeminiTransport`/`DeepSeekTransport`'tı (bkz. o
dosyaların doc yorumu); prompt kurma/response parse mantığı ve UI hiç
etkilenmedi.

Kota altyapısı: `kullanim_kota` tablosu (kullanici_id, ay, saglayici,
islenen_sayfa) her başarılı istekte artıyor. Henüz auth olmadığı için
`kullanici_id` cihazda üretilip `shared_preferences`'ta saklanan anonim bir
UUID (`DeviceIdService`) — gerçek kullanıcı hesabı eklenince buna taşınabilir.
Şimdilik hiçbir istek reddedilmiyor (sınırsız), yalnızca sayaç tutuluyor.

Supabase tarafını yeniden kurmak/deploy etmek için:
```
npx supabase login                       # veya SUPABASE_ACCESS_TOKEN
npx supabase link --project-ref <ref>
npx supabase db push                     # migrations/ içindeki tabloyu kurar
npx supabase functions deploy ai-proxy
npx supabase secrets set GEMINI_API_KEY=... DEEPSEEK_API_KEY=...
```

## Testler

```
flutter test
```

Gemini yanıt ayrıştırma ve hata durumları `test/gemini_service_test.dart`'ta
sahte HTTP istemcisiyle test edilir; arayüz akışı `test/widget_test.dart`'ta.
