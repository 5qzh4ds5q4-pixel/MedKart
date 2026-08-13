# MedKart — Proje Özeti

> Bu dosya Claude Code'un her oturumda otomatik okuduğu proje hafızasıdır.
> Amaç: sıfırdan keşif yapmadan mimariyi ve geçmiş kararları bilmesi.
> NOT: 2026-07-19'da gerçek kod tabanı taranarak doğrulandı; 2026-07-21'de
> (MCQ, Ayarlar/İstatistik ekranları, PDF önbellek, el yazısı anahtarı,
> "Faz 2/3" durumu) tekrar taranıp düzeltildi; 2026-07-30'da auth kapısı
> (`requireAuth`) bölümü gerçek kodla karşılaştırılıp baştan yazıldı ve o
> güne dek hiç belgelenmemiş olan "Sınav Tempo Uyarısı + Öncelikli Mod"
> özelliği kodu okunarak eklendi; 2026-08-03'te `npx supabase migration
> list --linked` + doğrudan PostgREST sorgusuyla `kullanici_kutuphane`
> migration'ının aslında ÇOKTAN deploy edilmiş olduğu doğrulandı (bu
> dosyadaki "henüz deploy edilmedi" notu o tarihe kadar eskimişti) ve aynı
> oturumda `MONTHLY_PAGE_CAP` secret'ı set edilip `ai-proxy` deploy edilerek
> aylık sert kota tavanı ilk kez aktif hale getirildi; 2026-08-04'te
31 Temmuz'da yazılıp belgelenmemiş kalan iki iş (deneme sınavı geçmişi +
kıyas, `pdf_cache` `hit_count` sayacı) kodu okunarak eklendi ve aynı
taramada `pdf_cache`'in yarım kalmış `model_version`/`prompt_version`
sütunları da belgelendi; 2026-08-06'da GLM (OpenRouter) sağlayıcısı sıfırdan
eklendi, prompt v18→v22 arası dört kez sıkılaştırıldı ve o oturumun tamamı
(geçici bayraklar dahil) bu dosyaya işlendi — yedeği
`CLAUDE.md.2026-08-06.bak`; 2026-08-10'da (bu dosyaya hiç işlenmeden) deste
listesi/kart listesi/kart düzenleme modalı "Obsidian Pulse" dashboard
mockup'larına göre yeniden tasarlandı (commit `f7199d4`) — 2026-08-11'de
`git log` + commit diff okunarak fark edildi ve bu dosyaya işlendi; aynı
oturumda iki geçici bayrağın (`kDebugBypassCache`, `activeAiProvider`) yine
7 Ağustos'tan beri açık unutulmuş olduğu `flutter test` ile bulundu, ikisi
de kullanıcı onayıyla geri alındı (662→667 test, hepsi yeşil); aynı günün
devamında sırasıyla Deneme Sınavı kurulum ekranı, kart listesi ekranı,
Kendini Test Et kurulumu, ortak `AppShell` (sidebar tek yerde), İstatistik
ekranı ve son olarak Ayarlar ekranı "Obsidian Pulse" dashboard mockup'larına
göre (amber→mor/pembe) yeniden tasarlandı — ayrıntılar "Devam Eden İş"
bölümündeki 0.1-0.6 numaralı alt başlıklarda; 2026-08-12'de GLM ve flash-lite
(`gemini-3.5-flash-lite`) ayrıntılı test edildi, ikisi de KESİN OLARAK
reddedildi ve production `gemini-3.5-flash`'ta sabitlendi — bkz. "Devam Eden
İş" 0.7 ve "GLM sağlayıcısı" bölümlerindeki kapanış notu; aynı oturumda
`flashcard_prompt.dart` v22→v25 arası üç kez daha güncellendi (ayrıntı "Kart
Üretim Kuralları"nda), iki geçici bayrak (`activeAiProvider`,
`kDebugBypassCache`, model sabiti) kalıcı değerlerine geri alındı (667/667
yeşil); 2026-08-13'te bu iki bayrak tekrar `grep` ile kontrol edildi, bu kez
İKİSİ DE zaten doğruydu (düzeltme gerekmedi) ve `flutter test` 667/667 yeşil
doğrulandı. Yine de kod
> değiştikçe eskiyebilir — şüphelendiğin bir iddiayı grep ile hızlıca
> doğrula ve bu dosyayı güncelle.

## Ne yapıyor bu uygulama
Tıp öğrencileri için AI destekli flashcard (çalışma kartı) uygulaması.
Öğrenci ders slaytı (PDF) yükler → sistem otomatik, sayfa sayfa işleyip
spaced-repetition çalışma kartı üretir. Hedef kitle: komite sınavına
hazırlanan tıp fakültesi öğrencileri.

## Devam Eden İş — KALDIĞIMIZ YER (2026-08-12)
> Yeni oturumda ÖNCE burayı oku. Bitince bu bölümü güncelle/temizle.

### 0.7. GLM ve flash-lite — İKİSİ DE REDDEDİLDİ, KONU KAPANDI (2026-08-12)
**KAPANIŞ NOTU:** Bugün GLM ve flash-lite (`gemini-3.5-flash-lite`) ayrıntılı
test edildi. Flash-lite tarafında üç farklı prompt tekniği denendi
(`flashcard_prompt.dart`, v23→v25: sinavTipiKurali/zorlukKurali için
uzlaştırma cümlesi, `etiketlemeSonHatirlatmasi`'na "derinlik" dengesi cümlesi,
`icerikKalitesiOrnegi` somut önce/sonra örneği) ama hiçbiri flash-lite'ın
derinlik sorununu ÇÖZEMEDİ. **İkisi de KESİN OLARAK reddedildi — production
artık `gemini-3.5-flash`'ta SABİT.** Bu konuyu tekrar açmadan önce YENİ bir
model ya da YENİ bir prompt tekniği gerekir; mevcut yöntemler (GLM
sağlayıcısı, flash-lite model geçişi, üç prompt tekniği) TÜKENMİŞTİR — aynı
şeyi tekrar denemeden önce neyin FARKLI olacağını netleştir.
- Kod tarafı kalıcı değerlerine geri alındı: `gemini_service.dart` →
  `model = 'gemini-3.5-flash'`, `pdf_cache_service.dart` →
  `kDebugBypassCache = false`, `ai_provider_config.dart` →
  `activeAiProvider = AiProvider.gemini` (bu zaten değişmemişti, yalnızca
  doğrulandı). Paket **667/667 yeşil**.
- Ayrıntı için bkz. "GLM sağlayıcısı" bölümü (aşağıda) — artık bu kapanış
  notuna atıf yapıyor.

### 0.6. Ayarlar ekranı — "ayarlar ekranı.png" mockup'ına göre kart-ızgara + VERİ DÜZELTMESİ
`~/Downloads/ayarlar ekranı.png` referans alınarak `SettingsScreen` düz
`ListView`+`Card`'dan (0.4/0.5'teki `StatsScreen` deseniyle AYNI) kart-ızgara
düzenine çevrildi: sol sütun Görünüm/Hesap/Yasal, sağ sütun Çalışma/Veri —
`AppShell`'e ZATEN bağlıydı (bkz. 0.4), sidebar/logo ayrıca dokunulmadı.
- **BİLİNÇLİ VERİ DÜZELTMESİ (kullanıcının açık talimatı):** referans
  tasarımdaki profil kartı "Pro Plan'a 3 gün kaldı" yazıyordu — uygulamada
  gerçek bir abonelik sistemi YOK (bkz. "Bilinmeyen / Henüz
  Kararlaştırılmamış"), bu metin KOPYALANMADI. Yerine (`_ProfileHeaderRow`)
  yalnızca GİRİŞ YAPMIŞ kullanıcıda, gerçek `StudyLog.currentStreak`'e
  dayanan bir durum satırı ("N günlük serin var") gösteriliyor; seri 0 ise
  satır tamamen atlanıyor (sahte "0 günlük seri" cümlesi kurulmuyor), giriş
  yapılmamışsa kart TAMAMEN gizleniyor (kimliksiz bir profil kartı yanlış
  veri olurdu). Ad da uydurulmadı: OTP e-posta akışında ayrı bir "ad" alanı
  yok (bkz. `AuthService` doc yorumu) — `userMetadata['full_name'/'name']`
  varsa (Google OAuth) o kullanılıyor, yoksa e-postanın `@` öncesi sadeleştirilip
  ad gibi gösteriliyor (`_nameFromEmail`). Canlıda bu makinenin hesabında
  `userMetadata` dolu çıktı ve "Kerem Külhacı" doğru göründü (ekran
  görüntüsüyle doğrulandı).
- **Tema seçimi artık toggle buton DEĞİL, iki tıklanabilir önizleme kartı**
  (`_ThemePreviewCard`, Koyu/Açık) — seçili olan violet kenarlık + gradyan
  checkmark rozeti alıyor. Her kart KENDİ temsil ettiği modun renklerini
  gösterir (uygulamanın o anki temasından BAĞIMSIZ — bir önizleme, "Koyu"
  kartı uygulama açık modda bile koyu görünür); yalnızca SEÇİLİ-DEĞİL
  çerçevenin rengi uygulamanın mevcut parlaklığına göre ayarlanıyor. Kartlar
  `ThemeController.setMode` ile DOĞRUDAN moda geçiyor (eski `toggle`
  metodundaki "mevcut moda göre tersini seç" mantığına ihtiyaç kalmadı —
  `toggle` metodunun kendisi ve `ThemeController` testleri hâlâ duruyor,
  yalnızca UI'da kullanılmıyor). **`lib/widgets/theme_toggle_button.dart`
  SİLİNDİ** — tek kullanan bu ekrandı, yeni tasarımda karşılığı yok; grep ile
  başka hiçbir yerden çağrılmadığı doğrulandı.
- **Tüm kartlar border YOK, elevation only** (kullanıcının açık talimatı) —
  `Card` widget'ı bu uygulamanın global `cardTheme`'i yüzünden HER ZAMAN bir
  kenarlık çiziyor (bkz. `flashcard_tile.dart`/`exam_sim_screen.dart
  _DashCard`'daki aynı, önceden bulunmuş bulgu) — o yüzden 5 bölüm de artık
  `Card` değil düz `Container`+`boxShadow` (`_SettingsCard`).
- İkon rozetleri artık dolu mor/pembe daire + beyaz ikon (`_IconBadge`,
  `_Accent.violet/pink/danger`) — nötr `Icon` değil, mockup'taki gibi renkli.
  "Çalışma" ve "Veri" kartlarındaki satırlar artık ne düz metin trailing ne
  chevron: değer PİLİ (`_ValuePill`, "20 kart"/"Belirlenmedi") ya da gerçek
  aksiyon BUTONU (`_GradientPillButton`/`_OutlinedPillButton`, "Dışa aktar"/
  "İçe aktar"/"Çıkış Yap"/"Giriş yap / Kayıt ol").
- **Veri kartındaki satırların KENDİSİ artık tıklanamıyor** (`_SettingsRow.
  onTap: null`) — asıl aksiyon trailing'deki BUTON'da; bu, yıkıcı "İçe aktar"
  işleminin yanlışlıkla satıra dokunarak tetiklenmesini de zorlaştırıyor
  (bilinçli, talimatta yoktu ama mockup'taki buton vurgusuyla tutarlı).
  "İçe aktar" ikon rozeti + buton rengi `colorScheme.error` (mor/pembe
  paletin dışında, KASITLI — üzerine yazan/yıkıcı bir işlem olduğu için ayrı
  bir semantik renk; "amber/gold temizliği" kapsamına GİRMİYOR çünkü zaten
  amber değil, error rengiydi/kaldı).
- Cloud illüstrasyonu (`_CloudIllustration`) saf dekoratif, hiçbir veriye
  bağlı değil; Veri kartı gövdesi `LayoutBuilder` ile <420px genişlikte
  illüstrasyonu satırların ÜSTÜNE alıyor (yan yana taşmasın diye) — sidebar
  sabit 80px olduğu için dar ekranlarda kart genişliği daralıyor (bkz. 0.4'ün
  "dar ekranda gerçek bir sınır" notu), bu ayrıca test EDİLMEDİ (bu ekran
  için ayrı bir `settings_screen_test.dart` yok), yalnızca savunmacı bir
  önlem.
- İçerik artık `ContentShell(maxWidth: AppTheme.dashboardMaxWidth)` (1240) —
  eskisi gibi `contentMaxWidth` (760, okunacak metin sütunu) DEĞİL; iki yan
  yana kartı sıkıştırırdı, `StatsScreen`'in aynı gerekçesiyle değiştirildi.
- **Tek sütuna düşünce (mobil/tablet) sıra SATIR SATIR** (Görünüm, Çalışma,
  Hesap, Veri, Yasal) — "önce tüm sol sütun, sonra sağ" DEĞİL
  (`_SettingsGrid._rowMajor`). Bunun tek sebebi estetik değildi: ilk yazımda
  "tüm sol sütun önce" sıralaması Çalışma kartını (limit/hedef düzenleme)
  800×600 test yüzeyinde EKRAN DIŞINA itti ve `deck_list_screen_test.dart`
  içindeki 3 test `tune_outlined` ikonuna tıklayamadığı için kırıldı — satır
  satır sıralama hem bunu ÇÖZDÜ hem ızgaranın masaüstündeki eşleşmesini
  (satır 1: Görünüm|Çalışma) mobilde de koruyor, iki kuş bir taş.
- **Test:** `theme_controller_test.dart`'taki tek widget testi ("toggle
  butonu temayı koyuya çevirir") YENİ etkileşim modeline göre YENİDEN
  YAZILDI ("tema önizleme kartına dokununca temayı değiştirir" — artık
  `find.text('Koyu')`/`find.text('Açık')`e tıklıyor, ikon aramıyor). Ayrı bir
  `settings_screen_test.dart` YOK (önceden de yoktu, bu oturumda da
  eklenmedi — kapsam dışı bırakıldı). Paket **667/667 yeşil**
  (`_SettingsGrid` sıralama düzeltmesinden SONRA), `flutter analyze` **0 yeni
  uyarı** (bir `unused_element_parameter` uyarısı `_IconBadge`'in kullanılmayan
  `size` parametresi kaldırılarak giderildi).
- **Tarayıcıda TAM doğrulandı** (2026-08-11): hem koyu hem açık modda
  ekran görüntüsüyle kontrol edildi — profil kartı gerçek ad+e-posta+"Çıkış
  Yap" gösterdi (test hesabı zaten girişliydi, "Pro Plan" hiçbir yerde
  YOK), tema kartları arasında geçiş (Koyu↔Açık, checkmark rozeti doğru
  kart üzerinde) çalıştı, Veri/Çalışma/Yasal kartları taşmadan render oldu.
  **Ortam notu:** bu oturumda sidebar'ın EN ALTINDAKİ (gear/Ayarlar) ikonu
  tıklamak alışılmadık derecede zor oldu — pencere yüksekliği ardışık
  screenshot çağrıları arasında dalgalanıyordu (734→683 gibi) ve `Spacer`
  ile en alta sabitlenen ikonun Y koordinatı buna göre kayıyordu; ÜSTTEKİ
  sabit-Y ikonlar (Ana Sayfa, Kendini Test Et) hep ilk denemede tıklandı.
  Çözüm: koordinatı EN SON screenshot'tan hesaplayıp araya başka tool call
  (zoom/navigate) SOKMADAN hemen tıklamak. Kod tarafında bir sorun DEĞİL.

### 0.5. İstatistik ekranı — "istatistik ekranı.png" mockup'ına göre amber/gold temizliği
`~/Downloads/istatistik ekranı.png` (Aug 11 16:05 — Aug 4'teki "istatistik
ekranı 2.png"'den AYRI, daha yeni bir mockup, "2" son eki YOK) referans
alınarak `StatsScreen`'deki amber vurgular mor→pembe dashboard paletine
çevrildi. Sidebar/logo tutarlılığı zaten 0.4'teki `AppShell` işinden
otomatik geldi (bu ekranda ayrıca bir logo/sidebar tanımı yoktu, kontrol
edildi).
- **`StudyHeatmap` (Çalışma takvimi):** `colorForLevel` artık `(ColorScheme
  scheme, HeatLevel level)` DEĞİL, `(HeatLevel level, {required bool
  isDark})` alıyor — imza değişti, bkz. aşağıda test notu. Renk artık tek
  bir rengin (`scheme.primary`, amber) alfa kademeleri DEĞİL, açık violet'ten
  (`AppTheme.dashboardViolet`) koyu pembeye (`AppTheme.dashboardPinkHot`)
  gerçek `Color.lerp` interpolasyonu (low=%33, medium=%66, high=uç). Bugün
  halkasının kenarlığı da amber'den `AppTheme.dashboardVioletDeep`'e döndü.
  Açıklama cümlesindeki "amber" kelimesi kaldırıldı ("ne kadar amber, o
  kadar çok" → "ne kadar koyu, o kadar çok").
- **`_DeckReadinessBar` (Deste hazırlığı):** kırmızı/tertiary/primary
  dallanması TAMAMEN kaldırıldı (bkz. yukarıdaki "Deste Hazırlığı"
  bölümünün düzeltmesi) — artık `LinearProgressIndicator` değil, elle
  `Stack`+`FractionallySizedBox`+`ClipRRect` ile çizilen, TEK bir mor→pembe
  gradyanlı (`AppTheme.dashboardProgressGradient` — DİKKAT, `dashboardCtaGradient`
  DEĞİL: `dashboardProgressGradient` zaten "İlerleme çubukları için" diye
  belgeli, daha soluk bir token; CTA gradyanı yalnızca BUTONLAR için) çubuk.
- **"Bugün" kartının amber kenarlığı kaldırıldı** — `_StatCard._emphasisShape`
  silindi, `emphasized` kart artık diğer üçü gibi border'sız. İkon rengi
  BİLİNÇLİ olarak dokunulmadı (hâlâ amber) — kullanıcı yalnızca kenarlığı
  hedef aldı, "iki izin verilen amber yeri" (bu ikon + seri alevi) kuralı
  kısmen duruyor, tam kaldırma istenmedi.
- **`ReviewForecastChart` ("Önümüzdeki 7 gün"):** çubuklar artık `scheme.
  primary` (amber, en yoğun gün tam/diğerleri %55 alfa) değil, hepsi AYNI
  `AppTheme.dashboardProgressGradient`; "en yoğun gün" ayrımı hâlâ
  `normalBarAlpha` ile ama artık rengi DEĞİL gradyanı saran bir `Opacity`
  üzerinden.
- **KORUNDU (dokunulmadı):** `TopicSuccessBar` (Konu başarısı listesi) —
  kullanıcı açıkça "semantic/durum renkleri, marka rengi değil" dedi.
  Genel layout/veri yapısı da değişmedi, yalnızca renkler.
- **Test:** `study_heatmap_test.dart`'ta imza değişikliği yüzünden 6 test
  güncellendi (`colorForLevel` çağrıları + iki test adı/beklenen değer,
  halka rengi testi, açıklama metni testi) — davranışsal kapsam AYNI kaldı,
  yalnızca hangi renk beklendiği değişti. `deck_readiness_test.dart` ve
  `review_forecast_test.dart` HİÇ dokunulmadan geçti (renk assertion'ı hiç
  yoktu). Paket **667/667 yeşil**, `flutter analyze` **0 yeni uyarı**.
- **Tarayıcıda KISMEN doğrulandı:** heatmap'in violet→pink kademeleri,
  "Deste hazırlığı" yüzde metninin moru ve "Bugün" kartının border'sız hâli
  ekran görüntüsüyle DOĞRU görüldü. "Önümüzdeki 7 gün" bölümü sayfanın
  altında kaldı ve bu oturumda ne fare tekerleği ne sürükleme ne klavye
  (`End`) ile aşağı kaydırılabildi (CanvasKit'te tekerlek zaten bilinen bir
  sorun, bkz. "ortam notları" — bu sefer sürükleme de çalışmadı) — kod
  incelemesiyle ve `ReviewForecastChart`'ın `_DeckReadinessBar` ile AYNI
  token'ı kullandığının doğrulanmasıyla yetinildi, gözle TEYİT edilemedi.

### 0.4. `AppShell` — sidebar TEK yerde, paylaşılan bir kabuğa çıkarıldı
Sebep: Deneme Sınavı kurulum ekranının sidebar'ı YOKTU (`ExamSimSetupScreen`
hâlâ eski `Scaffold(appBar: ...)` kalıbındaydı) — `deck_list_screen.dart` ve
`mcq_setup_screen.dart` sidebar'ı KENDİ kodlarına ayrı ayrı gömdüğü için bu
unutulmuştu ve fark edilmesi bir kullanıcı raporu gerektirdi. Kullanıcı
açıkça "bunu bir daha unutmayalım" dedi — çözüm nokta düzeltme DEĞİL, mimari:
- **`lib/widgets/app_shell.dart`** (YENİ) — `AppShell` widget'ı: sol
  `SideNavBar` + opsiyonel `topBar` + `body` slotu, TÜM navigasyon mantığını
  (hangi ikon nereye gider, "zaten oradaysan no-op", "Ana Sayfa"/"Destelerim"
  → `Navigator.popUntil((r) => r.isFirst)`) TEK yerde topluyor. Ayrıca
  `AppShellTopBar` (geri oku + başlık — Mcq/Exam/Stats/Settings ortak).
- **Beş ana ekranın HEPSİ artık bunu kullanıyor**: `DeckListScreen` (dolu
  dashboard dalı — boş/karşılama dalı KASITLI olarak DIŞARIDA, o ekranın
  sidebar'ı hiç olmaması ayrı bir tasarım kararı), `McqSetupScreen`,
  `ExamSimSetupScreen` (bu oturumda sidebar'a KAVUŞTU), `StatsScreen`,
  `SettingsScreen` (bu oturumda sidebar'a KAVUŞTU). Yeni bir ana ekran
  eklerken `AppShell`'i kullanmadan sidebar'ı elle kurma — tam da bunu
  önlemek için yazıldı.
- **Döngüsel import BİLİNÇLİ**: `app_shell.dart` dört hedef ekranı
  (Mcq/Exam/Stats/Settings) `push` edebilmek için import ediyor, o dört ekran
  da `AppShell`/`AppShellTopBar` için `app_shell.dart`'ı import ediyor —
  Dart bunu sorunsuz derliyor (iki dosya arası döngüsel `import` desteklenir,
  `part`/`part of` değil). `SideNavItem` enum'u `side_nav_bar.dart`'ta
  tanımlı ama `app_shell.dart` `export` ediyor — ekranlar tek import'la
  ikisine de erişiyor.
- **`WidgetTester.pageBack()` tuzağı:** `AppShellTopBar`'ın geri oku
  `Scaffold.appBar` DEĞİL (bilinçli — `AppBar` tüm genişliği kaplar,
  sidebar'ın ÜSTÜNE biner), bu yüzden Flutter'ın kendi `BackButton`
  widget'ını KULLANMIYOR. `WidgetTester.pageBack()` tam olarak
  `Tooltip(message: 'Back')` arıyor — bu eklenmezse "One back button
  expected on screen" ile testler patlıyor (`deck_list_screen_test.dart`'ta
  iki kez oldu). Yeni bir geri oku/ghost buton yazarsan ve testten
  `pageBack()` ile tetiklenmesi gerekiyorsa bu tooltip'i unutma.
- **Dar ekranda gerçek bir sınır ortaya çıktı:** `SideNavBar` genişliği
  (80px) HİÇBİR ekranda responsive olarak gizlenmiyor — bu deck_list_screen'de
  zaten 10 Ağustos'tan beri böyleydi (dokunulmadı), ama StatsScreen'e sidebar
  eklenince `daily_goal_test.dart`'ın "mobil genişlik" testi (380px viewport)
  gerçek TAŞMA (RenderFlex overflow) yakaladı — 380-80=300px içerik genişliği
  4 metrik kartı için gerçekten dar. Test genişliği 460'a çıkarıldı (380
  "gerçek mobil içerik" + 80 sidebar telafisi) — bu bir test ayarı düzeltmesi,
  UI kodunda bir şey DEĞİŞMEDİ. Eğer ileride app GERÇEKTEN dar (< ~400px)
  ekranlarda kullanılacaksa `SideNavBar`'ın kendisinin responsive
  gizlenmesi/daralması ayrı bir iş — bu oturumda kapsam dışı tutuldu, kimse
  istemedi.
- Test: paket **667/667 yeşil** (3 test bu refactor yüzünden güncellendi:
  `daily_goal_test.dart`'ın mobil genişlik sabiti + `deck_list_screen_test.
  dart`'taki iki `pageBack()` testi tooltip eklenince kendiliğinden düzeldi).
  `flutter analyze` **0 yeni uyarı** (90 baseline aynı kaldı).
- **Tarayıcıda KISMEN doğrulandı:** `McqSetupScreen`'de sidebar+topBar+
  branding paneli ekran görüntüsüyle DOĞRU çalıştığı görüldü (aynı `AppShell`
  bileşenini `ExamSimSetupScreen`/`StatsScreen`/`SettingsScreen` de birebir
  kullanıyor, kod düzeyinde farklı bir dal yok). Ama bu üçünü ayrı ayrı
  gerçek tarayıcıda gezip GÖRMEK bu oturumdaki tanıdık dwds/CanvasKit
  tıklama bozulması yüzünden tamamlanamadı (bkz. "ortam notları" — aynı tab'da
  arka arkaya birden fazla `Starting application` boot'u loglandı, bu her
  seferinde tıklamaların sessizce yutulmasıyla eşleşiyor). Sonraki oturumda
  önce bunu bitir.

### 0.3. Kendini Test Et kurulum ekranı — "kendini test et ekranı.png" mockup'ına göre yeniden çizildi
`mcq_setup_screen.dart` artık AppBar'lı tek sütun DEĞİL — deste listesindeki
AYNI sol `SideNavBar`'ı gösteriyor (bkz. hemen aşağıdaki paylaşılan widget
notu) ve içerik `[Sidebar] [Branding paneli] [Form]` üç kolon (masaüstü) /
`[Sidebar] + altta branding→form` (dar ekran) düzeninde. Renkler amber'dan
mor→pembe dashboard paletine döndü. İş mantığı hiç değişmedi.
- **`SideNavBar` artık PAYLAŞILAN bir widget** (`lib/widgets/side_nav_bar.
  dart`) — eskiden `deck_list_screen.dart`'a private (`_SideNavBar`) idi,
  bu ekran da göstermeye başladığı için ÇIKARILDI. Görsel olarak hiçbir şey
  değişmedi, yalnızca `active: bool` yerine `SideNavItem` enum'u (`home/
  library/quiz/exam/stats/settings`) ve `onOpenHome`/`onOpenLibrary`
  callback'leri eklendi. `DeckListScreen` ikisine de `() {}` verir (eskisi
  gibi no-op); `McqSetupScreen` ikisine de `Navigator.popUntil((r) =>
  r.isFirst)` verir ("Ana Sayfa" DeckListScreen'in KENDİSİ, `main.dart`'ın
  `home:` route'u — bkz. "Stack"). Yeni bir ekran sidebar göstermek isterse
  bu widget'ı import et, yeniden yazma.
- **Soru sayısı artık `SegmentedButton` DEĞİL, ayrık `ChoiceChip` pilleri**
  (`_QuestionCountPicker`) — sebep: görev tanımı seçili pilin GERÇEK
  mor→pembe gradyan olmasını istiyordu, `SegmentedButton`'ın `ButtonStyle`'ı
  gradyan zemin desteklemiyor (`backgroundColor` yalnızca düz `Color`).
  Aynı "gerçek widget'ı gradyan `Container`'a sar" deseni (`exam_sim_screen.
  dart`/`card_list_screen.dart` ile AYNI) — testler hâlâ `.selected`
  okuyabiliyor. `test/mcq_setup_screen_test.dart`'taki ilgili test
  `SegmentedButton` yerine `ChoiceChip` finder'ına güncellendi.
- **"Deste" alanı hâlâ gerçek `DropdownButtonFormField<String>`** (testler
  bunu açıp öğe seçiyor) — yalnızca `InputDecoration` zenginleştirildi
  (ikon, "Seçili deste" etiketi, odaklanınca mor kenarlık = "focus ring").
  **"Kapsam" hâlâ gerçek `RadioListTile<String?>`** — eskiden tek sütun +
  sabit yükseklikte kaydırılan bir kutuydu (`_scopeListMaxHeight`), o kutu
  KALDIRILDI: artık 2 sütunlu, her seçenek kendi kenarlıklı kutusunda (seçili
  = mor kenarlık), sayfa zaten `SingleChildScrollView` içinde olduğu için
  uzun konu listesi ekranı uzatıyor, kabul edilebilir bir davranış değişimi.
- Başlık artık iki renkli `Text.rich` ("Çoktan seçmeli" beyaz / "pratik" mor,
  ayrı satırlarda) — `find.text('Çoktan seçmeli pratik')` testi
  `'Çoktan seçmeli\npratik'`e güncellendi.
- 3 özellik satırı (Odaklanmış çalışma/Anında geri bildirim/Gelişimini takip
  et) ilk kez eklendi — eskiden hiç yoktu, mockup'ın bir parçası.
- Test: `mcq_setup_screen_test.dart` **10/10 yeşil** (2 test güncellendi,
  8'i hiç dokunulmadan geçti — dropdown/radio davranışı aynı widget
  tipleriyle korunduğu için). Paket **667/667**, `flutter analyze` bu
  dosyalarda **0 uyarı**.
- **Tarayıcıda doğrulama YAPILAMADI** — bu oturumdaki dwds/CanvasKit
  bozulması (bkz. "ortam notları") bu son adımda ısrarcıydı: birden fazla
  temiz sekme/sunucu yeniden başlatma denemesinde bile sidebar tıklamaları
  ya hiç kayda değmedi ya da screenshot CDP timeout'una düştü. Kod hatası
  olduğuna dair HİÇBİR belirti yok (statik analiz temiz, 10 dedike test
  yeşil) ama bu ekranın gerçek tarayıcıda göründüğü gibi çalıştığı CANLI
  doğrulanamadı — sonraki oturumda önce bunu dene.

### 0.2. Kart listesi ekranı — "kart liste ekranı.png" mockup'ına göre ince ayar (2026-08-11)
`~/Downloads/kart liste ekranı.png` (Obsidian Pulse ailesinden, PDF'ten
üretilen kart listesi/deste detay ekranının mockup'ı) referans alınarak
`card_list_screen.dart` + `flashcard_tile.dart` üzerinde hedefli değişiklikler
yapıldı — ekranın ÇOĞU (banner gradyanı, "Kartların hazır" kartı, sabit alt
çubuk konumu) zaten 10 Ağustos'taki dashboard işinden doğru geliyordu, bu
oturum yalnızca EKSİK kalan üç şeyi tamamladı:
- **`_FilterBar` zorluk/konu renk ayrımı:** Kolay/Orta/Zor çipleri seçiliyken
  artık konu çipleriyle AYNI mor DEĞİL, kendi semantik rengini taşıyor (yeşil/
  amber/kırmızı — `AppTheme.accentGreen(OnLight)`/`accentAmber(OnLight)`/
  `colorScheme.error`, yeni token YOK). `_chip()`'e opsiyonel `accent` parametresi
  eklendi; `accent: null` (konu çipleri) eski mor davranışı aynen korur.
  Ayrıca çubuğa inline "Zorluk"/"Konular" grup etiketleri + aralarında ince
  bir ayraç eklendi (mockup'ta ayrı bir başlık satırındaydı; burada AYNI
  kaydırılabilir satırın içine, grubun hemen başına gömülü — ayrı bir satırın
  çip grubu genişliğini tahmin etmesi gerekirdi, bu her zaman doğru hizalanır).
- **DÜZELTME — "Çalışmaya Başla" artık mor→pembe gradyan:** `_StudyBar`'ın
  butonu eskiden tema varsayılanı (amber) renkteydi, sistemdeki TEK
  tutarsızlıktı. `_GradientCtaButton` eklendi — `exam_sim_screen.dart`'taki
  `_GradientStartButton` ile AYNI desen (gerçek `FilledButton` saydam zeminle
  gradyan `Container`'a sarılı, testler `.onPressed`'i hâlâ okuyabiliyor).
  Bilinçli olarak PAYLAŞILAN bir widget'a çıkarılmadı (iki dosyada da private
  kaldı) — bu oturumda yalnızca `card_list_screen.dart` isteniyordu, zaten
  667/667 yeşil olan `exam_sim_screen.dart`'ı gereksiz yere değiştirmemek için.
- **`FlashcardTile` sıra numarası artık kenarlıklı daire** (`_NumberBadge`,
  düz metin DEĞİL) — nötr dashboard token'ları (`heroNeutralFill`/
  `dashboardSurfaceElevated` + kenarlık), mor DEĞİL (numara bir seçim durumu
  değil). Bu genişlik değişikliği yüzünden açıklama sütununun sol boşluğu da
  22→36'ya güncellendi (başlığın altına hizalı kalsın diye).
- Edit/sil ikonları ve "Hocanın Favorisi" rozeti zaten mockup'la uyumluydu,
  DOKUNULMADI.
- Test: `card_filter_test.dart`'taki "Temizle" tıklaması artık önce
  `tester.ensureVisible` çağırıyor — yeni grup etiketleri çubuğu genişletip
  sabit 800px test yüzeyinde "Temizle"yi hit-test alanının dışına itti.
  Paket **667/667 yeşil**, `flutter analyze` bu üç dosyada **0 uyarı**.
- **Tarayıcıda doğrulama KISMEN yapıldı:** temiz bir tek-boot oturumunda tüm
  değişiklikler (grup etiketleri, semantik zorluk renkleri, numaralı rozet,
  gradyan buton, gradyan banner) ekran görüntüsüyle doğrulandı. Ardından aynı
  tanıdık dwds/CanvasKit bozulması (tekrarlanan tıklama/screenshot sonrası
  filtre çubuğunun ekranı yatay+dikey döşeyerek tekrarladığı bir render
  bozulması) tekrar çıktı — kod hatası değil, bu oturumda defalarca görülen
  ortam kırılganlığı (bkz. "Tarayıcıda elle doğrulama — ortam notları").

### ✅ GEÇİCİ BAYRAKLAR ÜÇÜNCÜ KEZ AÇIK BULUNDU VE KAPATILDI (2026-08-11)
5-6 Ağustos'ta iki kez, sonra 7 Ağustos'ta TEKRAR (GLM v23 ölçümü + flash-lite
testi için) açılmış, bir dahaki oturuma (10 Ağustos'taki koca bir tasarım
işine) kadar geri alınmamıştı. 2026-08-11'de `flutter test` çalıştırılınca
`pdf_cache_service_test.dart`'ın 5 testi kırmızı çıktı, sebep tam da bu
tekrarlayan hata kalıbıydı. Kullanıcı onayıyla ikisi de geri alındı. Şu anki
(doğru) değerler:

| Dosya | Sabit | Değer |
|---|---|---|
| `lib/services/ai_provider_config.dart` | `activeAiProvider` | `AiProvider.gemini` |
| `lib/services/pdf_cache_service.dart` | `kDebugBypassCache` | `false` |

- `kDebugBypassCache` artık DÖRT kez (5, 6, 7 Ağustos, fark edilmesi
  11 Ağustos) açık unutuldu — sabitin üstündeki uyarı yorumu bunu önlemeye
  yetmiyor, yeni bir oturuma başlarken bu iki sabiti `grep` ile kontrol etmek
  otomatik hafızadan daha güvenilir.
- Test paketi bu iki değerle **667/667 yeşil** (2026-08-11'de doğrulandı;
  sayı 662'den 667'ye çıktı — aradaki commit'lerde yeni testler eklenmiş).
- **2026-08-13 yeniden kontrol:** her iki dosya da `grep`'le tekrar okundu —
  bu kez İKİSİ DE zaten doğru değerdeydi (`activeAiProvider = AiProvider.
  gemini`, `kDebugBypassCache = false`), düzeltme GEREKMEDİ — bir önceki
  oturumun (12 Ağustos, flash-lite testi sonrası) kapanışında zaten geri
  alınmışlardı ve bu kez açık unutulmamış. `flutter test` yeniden
  çalıştırıldı, **667/667 yeşil** doğrulandı (00:26, "All tests passed!").

### 0. 2026-08-10 dashboard tasarım işi — bu dosyaya İLK KEZ 11 Ağustos'ta işlendi
Commit `f7199d4` (10 Ağustos 17:41), önceki oturumda hiç `CLAUDE.md`'ye
yazılmadan yapılmıştı. `~/Downloads` altındaki "Obsidian Pulse" mockup'ları
(`medkart koyu mod dashboard/`, `medcard light mode dashboard/`, `medcard
açık mod dashboard.zip`, `soruların gelme ekranı/` — her biri `DESIGN.md` +
`code.html` + `screen.png` üçlüsü) referans alınarak:
- **Deste listesi** (`deck_list_screen.dart`, 3292 satır fark): koyu+açık
  dashboard, sol sidebar navigasyon (stilize tooltip'li ikonlar).
- **Kart listesi / deste detay** (`card_list_screen.dart`): `_SummaryCard`,
  `_ReadyBadge`, filtre pilleri (`_FilterBar._chip`), "Hocanın Favorilerini
  Çalış" banner'ı artık mor→pembe `AppTheme.dashboardCtaGradient` kullanıyor
  (eskiden amber `primaryContainer`'dı). `_StudyBar` `bottomNavigationBar`
  slotuna taşındı (eskiden `Column`'un son çocuğuyduydu — uzun içerikte
  gizlenme riski vardı).
- **Kart düzenleme modalı** (`edit_card_dialog.dart`, 189 satır fark).
- Tüm bu değişiklikler `app_theme.dart`'a eklenen 52 satırlık YENİ
  "dashboard" token ailesini (`AppTheme.dashboardViolet*`,
  `AppTheme.dashboardCtaGradient`, `AppTheme.heroSurface`,
  `AppTheme.dashboardSurface*` vb.) kullanıyor — bu, "Tasarım Sistemi"
  bölümünde anlatılan ESKİ amber/lacivert token setinden AYRI, ikinci bir
  palet. İki palet birlikte yaşıyor; hangi ekranın hangisini kullandığı
  netleştirilmedi/belgelenmedi, sonraki oturumda karışıklık olursa önce
  `app_theme.dart`'ı oku.
- **HENÜZ dokunulmamış ekranlar** (mockup klasörlerinde bunlara ait bir
  tasarım YOK, yani bu bir sonraki faz değil — sadece not): çalışma ekranı,
  istatistik, ayarlar hâlâ eski (7/20 tarihli) amber/lacivert temada.
  **Deneme Sınavı kurulum ekranı 11 Ağustos'ta, Kendini Test Et (MCQ) kurulum
  ekranı da aynı gün DAHA SONRA bu listeden ÇIKTI** — bkz. aşağıdaki "Deneme
  Sınavı kurulum ekranı — dashboard yeniden tasarımı" ve "Kendini Test Et
  kurulum ekranı" bölümleri. Kullanıcı yeni bir mockup indirmedikçe kalan
  ekranlara "dashboard" paletini yaymaya kalkma — sor.

### 0.1. Deneme Sınavı kurulum ekranı — dashboard yeniden tasarımı + sidebar item (2026-08-11)
Sol sidebar'da "Deneme Sınavı" artık "Kendini Test Et"ten AYRI bir ikonla
duruyor (`Icons.timer_outlined`, `_SideNavBar` içinde quiz ile istatistik
arasında) — eskiden yalnızca dashboard gövdesindeki kısayol kartından ve
AppBar'dan erişilebiliyordu, sidebar'da hiç yoktu, "Kendini Test Et" ile
karışıyordu. `deck_list_screen.dart`'a `onOpenExam` callback'i eklendi.
- `exam_sim_screen.dart` (`ExamSimSetupScreen`) TAMAMEN yeniden çizildi —
  kullanıcının verdiği ayrıntılı görsel şartnameye göre (mockup dosyası
  YOK, şartname metin olarak verildi): "Soru Sayısı ve Süre" kartı
  (`SegmentedButton<int>` 10/20/40 + `-`/`+` stepper, adım 5, alt sınır 5,
  üst sınır 180 dk — eski serbest metin `TextField` KALDIRILDI), "Hangi
  destelerden sınav olmak istersin?" kartı ("Tüm desteler" gradyan pil +
  diğer destelerin kart-sayısı rozetli ghost pilleri), "Sınav Kapsamını
  Özelleştir" kartı (arama kutusu + seçili konular üstte kaldırılabilir
  gradyan pil + altta ghost etiket bulutu + sayfa aralığı çipi), sağda sabit
  "Sınav Özeti" paneli (soru sayısı/süre/seçili konu + zorluk dağılım barı +
  gradyan "Sınavı Başlat" butonu). Masaüstünde (`ScreenSize.desktop`, ≥900px)
  iki sütun, dar ekranda tek sütun (özet panel en altta) — `ResponsiveBuilder`.
- **İş mantığı HİÇ değişmedi**: `_pool`, `_onDeckChanged`, `_pageBounds`,
  `_start` (→ `McqGenerator.generate` + `requireAuth`) birebir aynı; yalnızca
  süre artık `TextEditingController` yerine `int _minutes` + stepper.
- **Gradyan chip'ler gerçek `ChoiceChip`/`FilterChip` SARILARAK yapıldı**
  (`_deckGradientChip`, `_topicChip`): iç chip'in `backgroundColor`/
  `selectedColor`'ı saydam, asıl mor→pembe rengi dıştaki `Container`'ın
  `AppTheme.dashboardCtaGradient`'ı veriyor. Bilinçli seçim — Flutter'da
  `ChoiceChip`/`FilterChip` gradyan zemin desteklemiyor, ama widget TİPİNİ
  değiştirmeden (testler `.selected` property'sini hâlâ okuyabiliyor)
  gradyan istenen görünümü vermenin tek yolu buydu. Aynı desen "Sınavı
  Başlat" butonunda da (`_GradientStartButton`, gerçek bir `FilledButton`).
  Yeni bir gradyan chip/buton gerekirse bu deseni tekrarla, widget tipini
  değiştirme.
- Testler yeniden yazıldı: `test/exam_sim_screen_test.dart` (soru sayısı/süre
  artık `SegmentedButton`/stepper key'leriyle okunuyor —
  `ExamSimSetupScreen.minutesValueKey`/`minutesDecrementKey`/
  `minutesIncrementKey`, TextField YOK artık), `test/exam_sim_deck_filter_
  test.dart` (yalnızca son test güncellendi, deste/konu chip testlerinin
  TAMAMI değişmeden geçti — gradyan-sarma deseni sayesinde). Paket
  **667/667 yeşil**, `flutter analyze` bu iki dosyada ve `deck_list_screen.
  dart`'ta **0 uyarı**.
- **DÜZELTME — `flutter analyze` bu makinede ÇALIŞIYOR** (2026-08-11'de
  doğrulandı, hem dosya bazlı hem tüm proje). Bu dosyanın "Türkçe karakter
  yüzünden çalışmıyor" notu ESKİMİŞ — ne zaman eskidiği bilinmiyor, bir daha
  güvenip atlamadan önce dene.
- **Tarayıcıda elle doğrulama YARIM KALDI:** ekran görüntüleriyle düzen/
  gradyan/gerçek veri (zorluk dağılımı, deste rozetleri) doğrulandı, ama
  chip/stepper/buton TIKLAMALARI bu oturumda hiç kayda değer şekilde
  çalışmadı — `flutter run` sekmesi tekrar tekrar (3-4 kez, sunucu yeniden
  başlatılsa bile) `Starting application from main method` satırını İKİ+ KEZ
  logladı ve bir noktada tamamen BEYAZ EKRAN verdi (bkz. "Tarayıcıda elle
  doğrulama — ortam notları"). Bilinen dwds çoklu-istemci sorununun bu
  oturumdaki en ısrarlı hâliydi — "tüm sekmeleri kapat + sunucuyu yeniden
  başlat" bile tek seferde çözmedi. **Bu bir kod hatası DEĞİL** (667/667 test
  aynı etkileşimleri ayrıntılı kapsıyor ve yeşil) — ama tıklamaların gerçek
  tarayıcıda çalıştığı canlı doğrulanamadı. Sonraki oturumda önce bunu
  doğrula, güvenip atlama.

### 1. GLM sağlayıcısı VE flash-lite — DEĞERLENDİRİLDİ, İKİSİ DE KESİN OLARAK REDDEDİLDİ
Altyapı uçtan uca çalışıyor ve canlı doğrulandı (bkz. "GLM sağlayıcısı").
Gerçek PDF'lerle kalite karşılaştırması yapıldı (iki çalıştırma, 145 + 157
kart) ve **karar verildi: production Gemini'de kalıyor.**
- ARTI: klinik vaka / senaryo kartlarının kalitesi güçlü.
- EKSİ (belirleyici oldu): el yazısı ve vurgu güvenilirliğinde TEKRARLAYAN
  sorunlar — el yazısını yanlış okuma ve kaynakta olmayan bilgi uydurma,
  ayrıca aşırı `elYazisindanMi: true` etiketleme (kartların %20+'si).
- GLM kodu (`glm_service.dart`, `glm_transport.dart`, `ai-proxy`'nin `glm`
  dalı, 32 test) **SİLİNMEDİ, olduğu gibi duruyor** — ileride yeniden
  değerlendirilebilir. Yalnızca `activeAiProvider` artık `gemini`.

**KAPANIŞ (2026-08-12) — bkz. "Devam Eden İş" 0.7:** GLM'in ardından
`gemini-3.5-flash-lite` (Gemini'nin kendi ucuz modeli) de ayrıntılı test
edildi. Üç farklı prompt tekniği denendi (`flashcard_prompt.dart` v23→v25 —
sinavTipiKurali/zorlukKurali uzlaştırma cümlesi, "derinlik" son
hatırlatması, `icerikKalitesiOrnegi` somut örneği) ama flash-lite'ın
derinlik sorunu (yüzeysel/tanım-düzeyi kart üretme eğilimi) HİÇBİRİYLE
çözülmedi. **İkisi de (GLM + flash-lite) artık KESİN OLARAK reddedilmiş
durumda — production `gemini-3.5-flash`'ta SABİT.** Bu konuyu tekrar açmadan
önce YENİ bir model ya da YENİ bir prompt tekniği gerekir; v19-v25 arası
denenen prompt teknikleri (el yazısı ayrımı, boş dizi genişletmesi,
uzlaştırma/denge cümleleri, somut örnek) TÜKENMİŞTİR — aynı kalıptan bir
dördüncü/beşinci varyant denemeden önce neyin FARKLI olacağını netleştir.

### 2. Prompt sıkılaştırmaları — CANLI ÖLÇÜM BEKLİYOR
`kPromptVersion` bugün v18 → **v22** oldu (dördü de saf prompt metni, kodda
davranış değişmedi). Ayrıntılar "Kart Üretim Kuralları" bölümünde:
- v19: `elYazisiKurali` — el yazısı rozetinin "sonradan eklenmiş vurgu" ile
  "slaydın kendi tasarım dili" ayrımı.
- v20: `metinVeGorselBirlikteKurali` — önceliklendirme aynı ayrımla hizalandı.
- v21: Yol A "boş dizi döndür" kuralı ders-dışı içeriği kapsayacak şekilde
  genişletildi.
- v22: Aynı kural Yol B'ye de eklendi + "5-20 kart" alt sınır gibi
  okunamayacak şekilde netleştirildi.
**HİÇBİRİ CANLI ÖLÇÜLMEDİ.** v19/v20'nin hedefi, GLM'de gözlenen "kartların
%20+'si yanlışlıkla `elYazisindanMi: true`" oranını düşürmekti — yeni oran
ölçülmedi. v21/v22'nin hedefi, alakasız bir el yazısı fotoğrafından uydurma
kart üretilmesi vakasıydı — tekrar denenmedi.

### 3. İstatistik ekranı yeniden tasarımı — FAZ 1 BİTTİ, FAZ 2 SÜRÜYOR
Kullanıcı referans bir tasarım görselinden ilerliyor ve FAZLI çalışmayı
açıkça istiyor ("bu FAZ 1, diğer bölümlere dokunma"). Referans görsel:
`C:\Users\Admin\Downloads\istatistik ekranı 2.png` (yeni fazlarda yeni
numaralı dosya gelebilir — `~\Downloads\istatistik ekranı *.png`).
- YAPILDI (FAZ 1): kart-ızgara düzeni + üst 4 metrik kartı + opsiyonel
  günlük hedef. Ayrıntı: "İstatistik ekranı ızgara düzeni + Günlük Hedef".
- YAPILDI (FAZ 2 / 1. kalem, 2026-08-05): Konu Durumu'nda "Az veri" /
  "Henüz başlanmadı" durumları. Ayrıntı: "Konu başarısı — veri yeterliliği
  durumları".
- YAPILMADI (sonraki fazlar, kullanıcı bilinçli olarak erteledi):
  1. **"Bugün İçin Özet" kartı** — tasarımda sağ üstte, üç satır: bugünkü
     tekrar yükü, bugün odaklanılacak konu, henüz başlanmamış konu.
     Henüz HİÇ kodu yok.
  2. **"Önümüzdeki 7 gün" bölümünün tasarımdaki yeni hâli** — sağda ayrı
     bir "En yoğun gün" bilgi kutusu var; mevcut `ReviewForecastChart`
     bunu alt yazı olarak veriyor.
- FAZ 1'de bilinçli üç sapma var (aktif gün etiketi, tablet sütun sayısı,
  takvim alt metni) — hepsi kendi bölümünde gerekçesiyle yazılı.

### 4. Kompakt kart biçimi — ÇÖZÜCÜ CANLI DOĞRULANDI, GEMİNİ ŞEMASI HÂLÂ DEĞİL
2026-08-06 GÜNCELLEMESİ, dikkatli oku — iki ayrı şey var:
- **9 elemanlı kompakt dizi biçimi ve `flashcardFromCompactItem` çözücüsü artık
  CANLI ÇALIŞTI.** GLM ile yapılan iki gerçek çalıştırmada (145 + 157 kart)
  model kompakt dizileri üretti ve ortak çözücü bunları sorunsuz `Flashcard`'a
  çevirdi. Yani biçimin kendisi ve ayrıştırma yolu artık teorik değil.
- **Ama Gemini'nin `responseSchema`'sı (ARRAY of ARRAY) hâlâ hiç denenmedi.**
  GLM şema kullanmıyor; biçimi prompt + `response_format: json_object` ile
  dayatıyor (bkz. "GLM sağlayıcısı"). Yani "şema 400 döner mi" riski AYNEN
  duruyor ve yalnızca gerçek bir Gemini çağrısıyla kapanır.
- Gemini hesabının kredisi 2026-08-04'te tükenmişti (429 `"Your prepayment
  credits are depleted"`, curl ile doğrulandı). 2026-08-06'da TEKRAR
  KONTROL EDİLMEDİ — hâlâ tükenmiş olduğunu varsayma, önce dene.

**Test durumu:** paket toplam **662 test** (630 mevcut + 6 Ağustos'ta eklenen
32 GLM testi), **662/662 yeşil** — geçici bayraklar kapatıldıktan sonra
2026-08-06'da doğrulandı. GLM testleri sağlayıcı `gemini` iken de çalışır
(hepsi `MockClient`, `activeAiProvider`'a bakmaz).
(DÜZELTME 2026-08-11: "`flutter analyze` bu makinede çalışmıyor" iddiası
ARTIK YANLIŞ — hem tek dosya hem tüm proje taraması sorunsuz çalıştığı
doğrulandı, bkz. "Deneme Sınavı kurulum ekranı — dashboard yeniden tasarımı".
Ne zaman düzeldiği/doğru olmadığı bilinmiyor; yine de `flutter test` asıl
davranış doğrulaması için birincil araç olmaya devam ediyor.)

## Stack
- Dart / Flutter, tek hedef **web** (`flutter run -d web-server --web-port 8080`).
  Android klasörü repo'da duruyor ama aktif geliştirme web üzerinden.
  (DÜZELTME: "dartlang-app"/"dwds" kod tabanında hiçbir yerde geçmiyor —
  bunlar taslakta yanlış/doğrulanamamış bir iddiaydı, kaldırıldı.)
- Paket adı `medcard` (pubspec.yaml) — uygulama görünen adı "MedKart".
- Gemini API, model `gemini-3.5-flash` (`gemini_service.dart` içinde tek
  yer). NOT: `gemini-2.5-flash` yeni API anahtarlarına kapalı (404 döner),
  yanlışlıkla o modele dönme.
- **ÜÇ sağlayıcı var** (2026-08-06): `gemini` (production varsayılanı),
  `deepseek` (yalnızca mekanik/hacim testi, metin-only) ve `glm`
  (`z-ai/glm-4.5v`, OpenRouter üzerinden, GÖRSEL DESTEKLİ). Seçim tek yerden:
  `lib/services/ai_provider_config.dart` → `activeAiProvider`. Bkz.
  "GLM sağlayıcısı".
- Doğrulanmış gerçek dosyalar: `lib/services/gemini_service.dart`,
  `lib/services/gemini_transport.dart` (artık Gemini'yi DİREKT çağırmıyor —
  Supabase Edge Function `ai-proxy`'ye proxy'liyor, bkz. "Backend mimarisi"),
  `lib/services/deepseek_transport.dart` (aynı proxy, `provider: deepseek`),
  `lib/services/glm_service.dart` + `lib/services/glm_transport.dart`
  (aynı proxy, `provider: glm`),
  `lib/services/device_id_service.dart` (anonim cihaz kimliği, kota için),
  `lib/services/pdf_cache_service.dart` (paylaşılan PDF→kart önbelleği, bkz.
  "Maliyet Optimizasyonu"), `lib/services/mcq_generator.dart` (MCQ çeldirici
  üretimi, bkz. "MCQ — Kendini Test Et"),
  `supabase/functions/ai-proxy/index.ts`, `supabase/functions/pdf-cache/
  index.ts`, `supabase/migrations/` (kota tablosu + pdf_cache tablosu),
  `lib/services/pdf_card_pipeline.dart`,
  `lib/services/pdf_text_web.dart` (+ `pdf_text.dart`/`pdf_text_stub.dart`
  conditional import), `lib/services/pdf_export_service.dart`,
  `lib/screens/card_list_screen.dart`, `lib/screens/study_screen.dart`,
  `lib/screens/settings_screen.dart`, `lib/screens/stats_screen.dart`,
  `lib/screens/mcq_setup_screen.dart`, `lib/screens/mcq_quiz_screen.dart`,
  `lib/models/flashcard.dart`, `lib/models/card_filter.dart`,
  `lib/models/deck.dart` (examDate/cramming), `lib/srs/srs_engine.dart`,
  `lib/theme/app_theme.dart` (TEK görsel kimlik kaynağı, bkz. "Tasarım
  Sistemi").

## Mimari — İki Ayrı Üretim Yolu (KRİTİK, DÜZELTİLDİ)
Taslakta "Yol B kaldırıldı" deniyordu — bu YANLIŞ. Kod tabanında (bkz.
`add_cards_screen.dart` satır 45-49 yorumu) İKİ yol da hâlâ aktif, PDF'e
özel olan sadece HANGİ yolun kullanılacağı:
- **Yol A — sayfa-bazlı otomatik pipeline** (`GeminiService.generateForPage`
  + `PdfCardPipeline`): PDF girişi için **tek** yol. Her PDF sayfası ayrı
  çağrıyla (chunk = 1 sayfa) işlenir, sınırlı paralellikle (`concurrency: 4`).
  Kullanıcı PDF'i nereden eklerse eklesin hep buraya yönlendirilir, hiçbir
  teknik adım görmez.
- **Yol B — tek istek, genel prompt** (`GeminiService.generate`): Yapıştırılan
  metin VE görsel ekler (PNG/JPG/WebP/HEIC — **PDF DEĞİL**) için kullanılan,
  hâlâ tamamen aktif yol. PDF asla buraya gitmez: `sourcePage`
  damgalayamaz ve çok sayfalı PDF'te "5-15 kart" tavanına çarpıp kapsamı
  daraltır (bkz. `add_cards_screen.dart` yorumu). Bir PDF Yol B'nin medya
  listesine hiç eklenmez.
- **Vision (görsel) kullanımı:** Yol A'da normalde her sayfa hem METİN
  (pdf.js extract) hem GÖRÜNTÜ (JPEG, 1024px genişlik) olarak birlikte
  Gemini'ye gönderilir (bkz. `pdf_card_pipeline.dart` yorumu) — el yazısı
  notlar, highlight, renkli tablolar SADECE görüntüden yakalanabiliyor. Yol
  B'de de görsel ekler multimodal gönderilir; PDF-özel değil, genel bir
  Gemini yeteneği.
- Thinking modu KAPALI tutuluyor (`thinkingBudget: 0`, her iki yolda da) —
  maliyet optimizasyonu için bilinçli karar, kart üretiminde derin muhakeme
  gerekmiyor.

## Kart Veri Modeli (`lib/models/flashcard.dart` ile doğrulandı)
```
id, question, answer, shortAnswer (YENİ, 2026-07-19 — kısa doğrudan cevap),
deckId, difficulty (kolay/orta/zor — artık statik değil: her tekrar sonrası
`SrsEngine.deriveDifficulty` lapses/repetitions'a göre otomatik kalibre eder;
kontrol sırası: ÖNCE lapses>=3 → zor (repetitions guard'ından BAĞIMSIZ —
"Zor" cevap repetitions'ı sıfırladığı için guard önce gelse en zorlanılan
kart "zor" olamazdı), sonra repetitions<2 ise dokunmaz, sonra lapses==0 &&
repetitions>=3 → kolay, aksi orta; eşikler SrsEngine'de named constant),
difficultyManual (YENİ, 2026-07-22 — kullanıcı EditCardDialog'da zorluğu
elle değiştirdiyse true olur ve otomatik kalibrasyon o kartı atlar),
cardType (temel/sinav),
priority (oncelikli/arkaPlan), topic, note,
originalQuestion, originalAnswer (kullanıcı düzenlemesi öncesi orijinal),
flagged (kullanıcı "hatalı" işaretlemesi),
sourcePage (kaynak PDF sayfası, int?),
isHandwritten (bool — el yazısından geldi mi),
intervalDays, easeFactor, repetitions, lapses, nextReview (SM-2 SRS alanları)
```
DÜZELTME: `sourcePage`'in "HER ZAMAN dolu olmalı, null gelirse bug" iddiası
YANLIŞ. Yalnızca **Yol A** (PDF sayfa pipeline) ürettiği kartlarda dolu.
**Yol B**'den (metin yapıştırma / görsel ekleme, `generate()`) gelen
kartlarda `sourcePage` her zaman `null` — bu normal ve beklenen, bug değil.
`CardFilter.hasPageRange` aktifken `sourcePage == null` olan kartlar filtre
dışı bırakılır, bu da Yol B kartlarının sayfa-aralığı filtresinde hiç
görünmeyeceği anlamına gelir (bilinçli davranış).

**Sayfa numarası kayması düzeltmesi (2026-07-22):** Yol A'da `sourcePage`
DEFAULT olarak `PdfPage.page` — pdf.js'in `doc.numPages` üzerinde saydığı
FİZİKSEL yaprak sırası (`web/pdf_extract.js` `for (var i = 1; ...)`), slaytın
kendi üzerinde yazan numara DEĞİL. PDF'in başında kapak/boş sayfa varsa bu
ikisi kayar (slaytın 24. sayfası dosyanın 27. fiziksel yaprağı olabilir).
Bunu düzeltmek için: `buildPagePrompt`'ta görsel eklendiğinde (`hasImage`)
modelden `slaytNumarasi` alanına slaytın üzerinde YAZILI OLAN kendi numarasını
okuması istenir (bkz. `flashcard_prompt.dart` `slaytNumarasiKurali`, şemada
`required` DEĞİL — okunamazsa null bırakması beklenir, tahmin etmesi değil).
`flashcardFromItem` bu değer geçerli (pozitif) bir sayıysa fiziksel sayfaya
TERCİHEN kullanır; `PdfCardPipeline` da (`c.sourcePage != null ? c : ...`)
zaten dolu gelen bu değeri EZMEZ. Yol B (`buildGeneralPrompt`) bu alanı hiç
istemez — sourcePage orada zaten her zaman null, değişmedi. Model okuyamazsa
(görsel yok, sayı basılı değil, emin değil) sessizce eski davranışa (fiziksel
index) düşülür — hiçbir geriye dönük uyumluluk sorunu yok.

## Kart Üretim Kuralları (`gemini_service.dart`'taki ortak kural bloklarıyla doğrulandı)
- "Sayfadaki HER tabloyu satır satır işle" kuralı yalnızca **Yol A**'nın
  sayfa prompt'unda (`_buildPagePrompt`, "TABLO VE SAYISAL VERİ" bloğu) var;
  Yol B'nin genel prompt'unda (`_buildPrompt`) bu özel blok YOK (DÜZELTME —
  taslak ikisi için de geçerliymiş gibi genellemişti).
- Sayısal değerler/formüller/normal aralıklar asla atlanmaz (Yol A).
- **Çoklu öğe satırlarında endikasyon karışması yasak (2026-08-05, Yol A'nın
  tablo bloğunda):** bir satırda/hücrede birden fazla ilaç/öğe aynı hedefi
  paylaşıyor ama her birinin AYRI endikasyonu varsa, tek birleşik cevapta
  harmanlanamaz. İki seçenek: (a) her öğeye ayrı kart, (b) tek kartta her
  öğeyi KENDİ endikasyonuyla eşleştir. "Hepsi şu dört durumda kullanılır"
  gibi genelleyici tek liste, kaynakta olmayan bilgi üretmek sayılır.
  Prompt'ta kötü/iyi örnek çifti var (Cetuximab/Panitumumab/Nimotuzumab).
  Gerçek çıktıda görülen bir hatadan sonra eklendi.
- **Kapanış/teşekkür slaydı filtresi (2026-08-05, Yol A):** "test edilecek
  bilgi yoksa BOŞ dizi döndür" kuralı artık örnekleri sayıyor — başlık/ajanda/
  geçiş/telif YANINDA kapanış slaydı ("Teşekkür ederim", "Sorularınız?",
  kaynakça, salt yazar/kurum bilgisi). Model bir "Teşekkür ederim" slaydından
  gerçek kart ürettiği için net olumsuz örnek eklendi.
- **"Boş dizi döndür" kuralı ders-DIŞI içeriği de kapsıyor (2026-08-06,
  v21 = Yol A, v22 = Yol B):** Kural artık slayt TÜRLERİYLE sınırlı değil.
  Kaynak hiçbir şekilde ders/eğitim materyali değilse — kişisel not, alakasız
  fotoğraf, okunamayan/bozuk görüntü, tıbbi/akademik olmayan herhangi bir
  içerik — KESİN boş dizi. "İnandırıcı görünen, konuyla ilgili olabilecek"
  bilgi uydurmak açıkça yasaklandı; "emin değilsen hiç üretme, bu her zaman
  daha güvenlidir" ve "boş dizi başarısızlık değildir, uydurma kart ciddi
  hatadır" satırları eklendi. Kötü/iyi örnek çifti var.
  - GERÇEK VAKA: bir kullanıcı tıbbi hiçbir içerik taşımayan, alakasız bir el
    yazısı notunun fotoğrafını yükledi; model kaynakta HİÇ olmayan bir
    "bulaşıcı hastalık kontrolü" bilgisi UYDURUP kart üretti. Kaynak sadakati
    kuralının ciddi ihlali.
  - Vaka bir FOTOĞRAF olduğu için **Yol B**'den geçmişti ve Yol B'de bu kural
    HİÇ YOKTU (yalnızca Yol A'da vardı). Dahası Yol B'nin "5-20 kart üret"
    cümlesi alt sınır gibi okunabiliyordu. v22'de kural Yol B'ye eklendi ve o
    cümle netleştirildi: *"Kaynakta GERÇEKTEN yeterli içerik varsa 5-20 kart
    üret… Bu sayı bir ALT SINIR DEĞİLDİR: kaynak eğitim içeriği değilse ya da
    hiçbir test edilebilir bilgi taşımıyorsa BU SAYI GEÇERLİ DEĞİLDİR."*
  - Yol B'de boş dizi SESSİZ geçmez: `generate()` boş listede
    "Bu metinden kart üretilemedi…" hatası fırlatır ve kullanıcı net bir mesaj
    görür. Bu DOĞRU davranış, değiştirme. **Düzeltme canlı denenmedi.**
- **El yazısı / vurgu ayrımı (2026-08-06, v19+v20 — ÖNEMLİ, eski hâli
  yanıltıcıydı):** Kural artık "el yazısı VEYA highlight VEYA altı çizili"
  diye üç kategoriyi ayrımsız toplamıyor. Tek karar kriteri şu:
  *"Bu öğe slaydın GERİ KALANINDAN farklı, SONRADAN eklenmiş gibi mi duruyor;
  yoksa slaydın TUTARLI, baştan tasarlanmış bir parçası mı?"*
  - `elYazisindanMi: true` YALNIZCA üç durumda: gerçek el yazısı (düzensiz,
    basılı fontla uyuşmayan); sonradan eklenmiş görünen işaret (üzerine
    çizilmiş daire/ok, fosforlu kalem izi); tasarım diliyle tutarsız
    kutu/çerçeve.
  - `false` OLMASI GEREKENLER: slaydın kendi başlık/terim renk şeması (tüm
    başlıklar mor, tüm terimler mavi gibi), slayt boyunca TUTARLI kalın/renkli
    stil, tablo başlıkları ve bold terim tanımları gibi standart biçimlendirme.
  - "Emin değilsen `false`" satırı da var — rozet anlamını yitirmesin diye.
  - SEBEP: GLM çalıştırmalarında kartların %20+'si yanlışlıkla `true`
    işaretleniyordu; slayt TASARIMCISININ kalıcı renk stili, sonradan eklenmiş
    gerçek vurguyla karışıyordu. **Yeni oran henüz ölçülmedi.**
  - `metinVeGorselBirlikteKurali` (yalnızca Yol A, görsel varken) AYNI ayrımla
    hizalandı (v20): "EN ÖNCELİKLİ bilgi" muamelesi artık yalnızca SONRADAN
    EKLENMİŞ vurgular için geçerli; slaydın kendi tasarım diline ait
    renkli/kalın metin bu öncelik kuralına GİRMEZ, normal `ÖNCELİKLENDİR`
    ölçütleriyle (ayırt edicilik, sayısal değer, sınıflandırma) değerlendirilir.
    İki blok birbirine açıkça atıf yapar — birinde vurgu sayılan diğerinde de
    vurgudur. Yeni bir yere vurgu tanımı YAZMA, bu ikisi taşıyor.
- El yazısından gelen bilgi soru/cevap METNİNE yazılmaz — sadece
  `isHandwritten: true` olarak işaretlenir, UI'da ayrı gösterilir (rozet/ikon).
  Kaynağa atıf da yasak ("el yazısı", "görselde" gibi ifadeler soru/cevaba
  hiç yazılmaz).
- Her kart iki alan üretir: `kisaCevap`→`shortAnswer` (3-8 kelime, sorunun
  doğrudan yanıtı) ve `cevap`→`answer` (2-4 cümle: doğrudan cevap + NEDEN/
  mekanizma + varsa ayrım/örnek; kullanılan terim açıklanmadan bırakılmaz).
  Bu ikisi birbirinin türevi DEĞİL, ayrı ayrı üretilir — `_ikiKatmanliCevapKurali`
  modele bunu açıkça söylüyor. (DÜZELTME: taslaktaki "20-40 kelime" hedefi
  prompt metninde YOK, gerçek kural cümle sayısına dayalı; canlı ölçümde
  39-63 kelime aralığı gözlendi ama bu bir gözlem, kesin sınır değil.)
  **"2-4 cümle" TEK STANDART (2026-08-05):** öncesinde prompt kendi içinde
  çelişiyordu — `cevapSadeligiKurali`, `ikiKatmanliCevapKurali` ve kompakt
  biçim listesi "2-4" derken her iki yolun "HER KART İÇİN" satırı (Yol B
  `buildGeneralPrompt`, Yol A `buildPagePrompt`) "1-3 cümle" diyordu. Beş yer
  de artık "2-4". Yeni bir yere uzunluk kuralı yazma, bu üç blok zaten
  taşıyor.
- Sınav tipi (`cardType: sinav`) kartlar klinik senaryo/vinyet formatında,
  ayırıcı tanı veya mekanizma sorgular. Klinik bağlamı olan HER konu için
  üretilmeli, tutarsız atlanmamalı.
- (DÜZELTME) `priority: arkaPlan` etiketli kartların **üretimi engellenmez**
  — bağlam/tanım niteliğindeki bilgi yine kart olarak üretilir, sadece bu
  etiketi alır ve Sınav Modu bunları gizler. Yalnızca Yol B'nin genel
  prompt'unda ayrı bir sınır var: "en fazla 1-2 kart temel tanım düzeyinde
  olabilir" (saf tanım/hatırlama kartı SAYISINI kısıtlar, arkaPlan
  etiketiyle karıştırılmamalı).
- Zorluk kalibrasyonu (`_zorlukKurali`): "kolay" = tek bir terimin doğrudan
  tanımı; "orta" = birden fazla kavramı ilişkilendiren mekanizma/neden-sonuç;
  "zor" = hasta/durum senaryosu + ayırıcı tanı, YA DA formül/sayısal hesap
  gerektiren (TUS düzeyi). (Tıp uzmanı geri bildirimiyle kalibre edildi,
  değiştirmeden önce sebep sor.)
- **Öncelik kalibrasyonu sıkılaştırıldı (2026-08-05, `oncelikKurali`):** canlı
  bir çalıştırmada 147 karttan 140'ı (%95) "oncelikli" gelmişti — ayrım
  işlevsizdi (Sınav Modu'nun gizleyecek neredeyse hiçbir şeyi yoktu). Kuralın
  başına karar sorusu kondu: *"Bu bilgi sınavda bir şıkkı BAŞKA bir şıktan
  ayırt ettirir mi?"* — net "evet" değilse `arka_plan`; "doğru olmak ve derste
  anlatılmış olmak" tek başına yetmiyor. `arka_plan` örnekleri genişletildi
  (salt isimlendirme, bir şeyin yalnızca VAR OLDUĞUNU söyleyen cümle,
  karşılaştırılmayan liste maddesi, giriş/geçiş cümleleri).
  **Hedef yüzde BİLEREK DAYATILMADI** (kullanıcı kararı) — oran zorlamak
  uydurma/gerilmiş sınıflandırma üretir; prompt yalnızca "neredeyse her karta
  oncelikli veriyorsan ayrımı uygulamıyorsun" diyor. Etki henüz canlı
  ölçülmedi.
- **`terminolojiStandardiKurali` (2026-08-05, HER İKİ YOL):** kartlarda altı
  terim standart yazımla geçer — "MHC Sınıf I/II" (İngilizce "Class" değil),
  "CTLA-4", "PD-1", "PD-L1", "IFN-γ", "proteazom". **Kaynak sadakati kuralıyla
  çelişmez, dar bir istisnadır:** yalnızca YAZIM biçimini (tire/boşluk/
  büyük-küçük harf, İngilizce→Türkçe çeviri tutarlılığı) düzeltir, içeriği
  değil. Prompt'ta liste açıkça **KAPALI** ilan edilir ("burada olmayan hiçbir
  terimi düzeltme") — yoksa model bundan genel bir "terimleri düzelt" yetkisi
  çıkarıp kaynak sadakatini aşındırırdı. Listeye terim eklerken bu sınırı
  koru.
- **`guncellikDiliYasagiKurali` (2026-08-05, HER İKİ YOL):** kart metni
  güncellik/otorite iddiası taşıyamaz — "güncel kılavuzlara göre",
  "günümüzde kabul edilen", "birinci basamak/standart tedavi" gibi ifadeler
  YASAK; yerine kaynağa atıf ("slayta göre", "bu kaynakta belirtildiği
  üzere"). Sebep: kaynak slayt eski olabilir, kart onun adına güncellik
  iddiası üstlenmemeli. NOT: el yazısı kuralındaki "kaynağa atıf YASAK" ile
  karıştırma — o, bilginin NEREDEN geldiğini (el yazısı/görsel) söylemeyi
  yasaklar; bu kural ise tam tersine kaynağa atfı ZORUNLU kılar.

## Hata Yönetimi (`gemini_transport.dart` + `pdf_card_pipeline.dart` ile doğrulandı)
- **Savunmasız cast bug'ı (çözüldü):** API cevabını `as List` ile cast etmeden
  önce MUTLAKA `is List` kontrolü yapılmalı. Hata nesnesi (Map) geldiğinde
  kart sanıp cast etmeye çalışmak TypeError'a yol açıyordu.
- **429/5xx retry (çözüldü, HTTP katmanında — `GeminiTransport`):**
  `maxAttempts = 4` (ilk deneme + 3 tekrar). Bekleme çarpanları **1x→2x→4x**
  (DÜZELTME: taslaktaki "8x" adımı gerçekte YOK — 4. deneme sonucu ne
  olursa olsun döner, ondan sonra bekleme yapılmaz).
- **maxOutputTokens: 4096** (`GeminiService.maxOutputTokens`). Tarihçe: 2048
  dar kalıp MAX_TOKENS ile boş çıktı veriyordu → 8192'ye çıkarıldı; 2026-07-31
  maliyet sertleştirmesinde 8192 → **4096**'ya düşürüldü (çıktı girdinin 6 katı
  fiyattan faturalanıyor; sayfa başı tavan ~$0.085 → ~$0.048). 4096, boş
  çıktıya yol açan 2048'in iki katı güvenlik marjı. NOT: DeepSeek'in kendi
  `max_tokens`'ı (`deepseek_service.dart`) hâlâ 8192 — production akışı o
  sağlayıcıya hiç dokunmadığı için bilinçli olarak düşürülmedi.
- **Kota (429) davranışı iki katmanlı (DÜZELTME — taslak bunu birleştirmişti):**
  (1) HTTP katmanı önce 429'u da yukarıdaki 1x→2x→4x backoff ile 4 kez
  dener; (2) tüm denemeler yine 429 dönerse `FlashcardGenerationException.isQuota`
  fırlatılır ve **Yol A pipeline'ı bunu görünce TÜM işlemi erken durdurur**
  — kalan sayfalar hiç denenmez, kullanıcıya net "kota doldu" mesajı
  gösterilir (100 sayfayı boşuna denememek için bilinçli tasarım).
  Kota DIŞI bir sayfa hatası (parse/format sorunu, ağ hatası, sayfa bazlı
  yeniden deneme de tükendi) ise yalnızca o sayfa "işlenemedi" işaretlenir,
  diğer sayfalar işlenmeye devam eder. Sessizce "0 kart" hiç gösterilmez.

## Tamamlanan Özellikler
- Yol A: sayfa-bazlı otomatik PDF→kart pipeline (vision destekli)
- Yol B: yapıştırılan metin ve/veya görsel (PNG/JPG/WebP/HEIC) ekinden tek
  istekte genel prompt ile kart üretme (`generate()`, `AddCardsScreen`)
- **SM-2 tabanlı SRS motoru** (`srs_engine.dart`, `study_session.dart`):
  zorluk-kalibreli başlangıç kolaylık katsayısı, zayıf-konu-önce sıralama,
  oturum-içi geri alma.
- **Günlük çalışma kuyruğu** (`FlashcardStore.dailyQueue`, `StudySettings.
  dailyNewCardLimit`, varsayılan 20, `Ayarlar` ekranından değiştirilebilir):
  due kartlar + zayıf-konu-öncelikli yeni kartlar, günlük limitle sınırlı,
  tüm destelerden birleşik ("Bugün Çalış").
- **Sınav tarihine duyarlı zamanlama** (`Deck.examDate`, `SrsEngine.
  crammingThresholdDays`/`_compressForExam`): deste bazlı sınav tarihi
  girilebilir, SM-2 aralıkları o tarihi aşmayacak şekilde sıkıştırılır;
  sınava `crammingThresholdDays` (3) günden az kalınca "yoğun tekrar modu"
  devreye girer (o destenin yeni kartları günlük limitten muaf, hepsi
  kuyruğa girer). Deste listesinde "sınav tarihi belirle" menü aksiyonu +
  kalan gün rozeti.
- **Sınav tempo uyarısı + Öncelikli Mod** ("bu tempoda yetişemiyorsun" uyarısı
  ve arka plan kartlarını kuyrukta geriye iten elle triage) — bkz. ayrı bölüm
  "Sınav Tempo Uyarısı + Öncelikli Mod".
- Kart düzenleme/hata bildirme (`edit_card_dialog.dart`): soru/cevap/zorluk/
  konu/not düzenleme, "hatalı" işaretleme, "AI orijinaline dön"
  (`originalQuestion`/`originalAnswer` snapshot'ı korunarak).
- İki katmanlı cevap (`shortAnswer`/`answer`): çalışma ekranında önce kısa
  cevap, "Açıklamasını gör" ile açıklamalı hali; PDF export'ta ikisi de
  statik görünür. Yalnızca yeni üretilen kartlarda dolu, eski kartlar
  migrate edilmedi (`hasShortAnswer` boşsa eski tek-katmanlı davranışa düşer).
- Sınav Modu: yalnızca `cardType: sinav` VE `priority: oncelikli` kartları
  bırakan, `priority: arkaPlan` temel kartları gizleyen çalışma filtresi
  (`CardFilter.examOnly`, yalnızca `StudyScreen`'de — `card_list_screen`'in
  kendi filtre çubuğuna karıştırılmadı, bilinçli tasarım kararı)
- **"Kendini Test Et" MCQ pratik modu** — bkz. "MCQ — Kendini Test Et".
- **"Hocanın Favorileri" (el yazısı/highlight kart) filtresi ve hızlı pratik
  modu** (2026-07-28) — bkz. ayrı bölüm "Hocanın Favorileri / En Zayıf Konu
  Antrenmanı".
- PDF export: tüm kartlar (arkaPlan dahil), soru numaralandırma,
  el yazısı kartlarda küçük rozet/ikon (soru metnine karışmaz)
- Klavye kısayolları (Space=çevir, 1/2/3=zorluk), Dark Mode, tam tema
  sistemi (bkz. "Tasarım Sistemi")
- İstatistik ekranı (`stats_screen.dart`) bölüm sırası: streak → çalışma
  takvimi (heatmap) → deneme sınavı trendi → deste hazırlığı → konu başarısı
  → önümüzdeki 7 gün. Ortadaki üçü 2026-08-04'te eklendi, her birinin aşağıda
  kendi bölümü var
- JSON dışa/içe aktarma (yedekleme — 2026-07-30'dan beri girişe tabi, bkz.
  "Zorunlu Login"), Ayarlar ekranı (`settings_screen.dart` — tema/günlük
  limit/yedek dışa-içe aktarma tek yerde)
- Paylaşılan PDF→kart önbelleği + el yazısı anahtarı — bkz. "Maliyet
  Optimizasyonu"

## MCQ — Kendini Test Et
Var olan kartlardan, HİÇ yeni AI çağrısı yapmadan çoktan seçmeli pratik
üretir. Mantık: `lib/services/mcq_generator.dart` (`McqGenerator.generate`),
UI: `lib/screens/mcq_setup_screen.dart` (kapsam: tüm deste/konu + soru
sayısı 5/10/20) → `lib/screens/mcq_quiz_screen.dart` (soru+4 şık, cevaplayınca
doğru=yeşil/yanlış=kırmızı + her şıkkın kendi `answer`'ından kısa açıklama,
son soruda özet + "Bu kartı çalışmaya git"). Giriş noktası: deste listesi
AppBar'ında `Icons.quiz_outlined` (yalnızca deste varsa görünür).
- Şıklar `Flashcard.shortAnswer`'dan, çeldiriciler AYNI `topic`'teki diğer
  kartlardan; bir konuda <4 kart varsa o konu havuzdan tamamen çıkar; çeldirici
  ile doğru cevap arasında Jaccard kelime-benzerliği ≥0.7 ise o çeldirici elenir.
- "Bu kartı çalışmaya git" `StudyScreen`'i `CardFilter.forCard(id)` ile açar
  (`CardFilter`'a eklenmiş minimal `cardIds` alanı) — ana çalışma ekranına
  DOKUNULMADI, yalnızca zaten var olan `filter` parametresi kullanıldı.

### Kurulum ekranı yeniden tasarımı (2026-08-04)
`mcq_setup_screen.dart` referans bir tasarım görselinden yeniden düzenlendi.
İŞ MANTIĞI HİÇ DEĞİŞMEDİ (havuz kurulumu, `McqGenerator.generate` çağrısı,
`requireAuth`, yetersiz havuz hata mesajı bit-bit aynı).
- Yapı: marka bloğu (kenarlıklı kare + amber `Icons.assignment_outlined`) →
  ortalanmış "Çoktan seçmeli pratik" başlığı → TEK panel (`_SetupCard`:
  Deste dropdown, kapsam radyo listesi, ayraç, soru sayısı) → panelin ALTINDA
  ayrı duran amber play ikonlu "Başla". Kart genişliği `ContentShell`'in
  `AppTheme.contentMaxWidth` (760) sınırından geliyor — `ExamSimSetupScreen`
  ile aynı.
- Kapsam TEKLİ seçim (radyo): "Tüm deste" ya da tam olarak bir konu. Deneme
  Sınavı'nın çoklu konu + sayfa aralığı kapsamıyla KARIŞTIRMA, ikisi farklı.
- **Davranış değişikliği:** `_onDeckChanged` artık koşullu — seçili konu YENİ
  destede de varsa KORUNUR, yoksa "Tüm deste"ye döner. Eskiden deste
  değişince konu seçimi HER ZAMAN sıfırlanıyordu.
- **Soru sayısı `SegmentedButton` (ChoiceChip DEĞİL) — bilinçli sapma.**
  Talimat "exam_sim ile aynı bileşen" diyordu ama referans görselde bitişik
  segmentli kontrol vardı ve "görsel öncelikli" denmişti. Yani bu iki kurulum
  ekranı soru sayısı kontrolünde KASITLI olarak farklı; "tutarlılık" adına
  birini diğerine çevirmeden önce sor. Renkler tema token'ı
  (`selectedBackgroundColor: primary`).
- `McqSetupScreen.initialDeckId` (opsiyonel): bağlam destesiyle açmak için.
  ŞU AN HİÇBİR ÇAĞIRAN VERMİYOR — tek giriş noktası deste listesi AppBar'ı ve
  orada deste bağlamı yok; verilmezse/deste silinmişse ilk desteye düşer.
- **Tuzak:** kapsam listesi renkli zeminli bir `Container` içinde olduğu için
  `RadioListTile`'lar saydam bir `Material` ile sarılmak ZORUNDA — yoksa
  Flutter "ink splashes may be invisible" assert'i atıyor ve widget testleri
  patlıyor. Görsel etkisi yok.
- Test: `mcq_setup_screen_test.dart` (10 test — deste filtreleme, geçersiz
  seçimin düşmesi, geçerli seçimin korunması, tekli seçim, soru sayısı).

## Deneme Sınavı (TAMAM, 2026-07-22)
MCQ "Kendini Test Et"ten AYRI, onu SİLMEYEN mod: süreli/puanlı komite sınavı
provası. Soru üretimi McqGenerator'ı AYNEN yeniden kullanıyor (yeni üretici
yazılmadı, HİÇ API çağrısı yok). Giriş: deste listesi AppBar'ında
`Icons.assignment_outlined` (MCQ ikonunun yanında).
- Kurulum: `lib/screens/exam_sim_screen.dart` (`ExamSimSetupScreen`) — soru
  sayısı 10/20/40 (varsayılan 20), kapsam = TÜM kütüphane havuzu, `CardFilter`
  ile çoklu konu + sayfa aralığı daraltması ("Kendini Test Et"ten farkı: tek
  deste/tek konu değil, karışık konu). Süre ELLE girilebilir (dakika, TextField
  `_minutesController`): varsayılan soru sayısına göre önerilir (1 dk/soru) ve
  soru sayısı değişince otomatik güncellenir; kullanıcı alana dokununca
  (`_minutesEdited`) artık ezilmez. Boş/0 girilirse üretilen gerçek soru
  sayısına göre 60 sn/soru fallback (`_targetSeconds`).
- **Deste seçimi (2026-08-04):** Kurulumda "Kapsam"ın ÜSTÜNDE bir "Deste"
  çip grubu (`_deckId`, `null` = **"Tüm desteler"**, varsayılan). `null` iken
  ekran eskisiyle BİT-BİT aynı davranır (havuz, konu listesi, açıklama metni
  dahil) — yukarıdaki "kapsam = TÜM kütüphane havuzu" ifadesi hâlâ
  varsayılan davranış.
  - Deste seçilince kapsamın TAMAMI o desteye iner: konu çipleri
    (`store.topicsIn`), havuz (`store.cardsIn`) ve **sayfa aralığı sınırları**
    (`_pageBounds` artık `_deckCards` üzerinden). Sonuncusu talimatta yoktu
    ama şart: PDF kartı olmayan bir deste seçildiğinde asla 0 kart üretecek
    bir "Sayfa aralığı" çipi görünürdü.
  - Deste değişiminde seçili konulardan YENİ destede olmayanlar düşer, olanlar
    KORUNUR (`_onDeckChanged`). Zorluk/sayfa aralığına dokunulmaz.
  - Deste seçili + hiç konu seçili değilse "hepsi" kuralı deste ölçeğinde
    uygulanır (o destenin tüm kartları).
  - CANLI DOĞRULANDI (2026-08-04, tarayıcı): "fizyo" seçilince konu listesi
    kütüphane genelindeki ~40 etiketten yalnızca endokrin konularına indi;
    "Tüm desteler"de seçilmiş "diyabet" konusu "kerem" destesine geçince
    düştü ve sayaç 0 değil "Kapsamda 50 kart var." gösterdi (temizleme
    çalışmasaydı 0 olurdu).
  - Test: `exam_sim_deck_filter_test.dart` (7 test). **Tuzak:** yeni bölüm
    Kapsam kartını varsayılan 800×600 test yüzeyinin altına itti; `ListView`
    tembel oluşturduğu için çipler build EDİLMİYOR. `exam_sim_screen_test.
    dart`'a bunun için `_scrollToScope` yardımcısı eklendi — kapsamla ilgilenen
    yeni testler onu çağırmalı, yoksa "findsNothing" yanlış sebeple geçer.
- Sınav akışı: `lib/screens/exam_sim_quiz_screen.dart` (`ExamSimQuizScreen`).
  KRİTİK farklar (McqQuizScreen'in TERSİ): (1) şık seçimi yalnızca işaretlenir,
  doğru/yanlış + açıklama sınav bitene kadar GÖSTERİLMEZ; (2) süreli — soru
  başına 60 sn hedef (`targetSeconds = soru×60`), geri sayan timer; süre
  dolunca sınav KESİLMEZ, tek uyarı + timer kırmızı/negatif sayar; (3)
  ileri/geri gezinme + cevap değiştirme; "Sınavı Bitir" boş soru varsa onay
  ister. Süre biçimi `ExamSimQuizScreen.formatSeconds` (statik, sonuç ekranı
  da kullanır).
- Sonuç: `lib/screens/exam_sim_result_screen.dart` (`ExamSimResultScreen`) —
  büyük yüzde puan + doğru/toplam, kullanılan süre (hedef altı/üstü), konu
  bazlı kırılım (sınav cevaplarından `TopicStat` kurup en zayıf üstte),
  yanlış sorular listesi (soru + öğrencinin yanlış şıkkı + doğru şık + kaynak
  kartın açıklamalı `answer`'ı). "Yanlışları tekrar çalışmaya ekle" →
  `FlashcardStore.pullCardsForwardToToday` yanlış kartların `nextReview`'ünü
  bugüne çeker (SM-2 durumu BOZULMAZ, sadece öne alınır; yeni/zaten-due
  kartlara dokunulmaz).
- Ortak çıkarımlar: sayfa aralığı çipi `lib/widgets/page_range_filter_chip.dart`
  (`PageRangeFilterChip`, card_list_screen'den taşındı); konu başarı barı
  `lib/widgets/topic_success_bar.dart` (`TopicSuccessBar`, stats_screen'in
  `_TopicBar`'ından çıkarıldı — istatistik ve sınav sonucu ortak kullanıyor,
  `unitLabel` ile "kart"/"soru").

### Sınav geçmişi + önceki denemeyle kıyas (2026-07-31)
Tamamlanan her deneme sınavı kalıcı olarak saklanır ve sonuç ekranında bir
öncekiyle kıyaslanır. Ayrı bir depolama İCAT EDİLMEDİ: kayıtlar
`LibraryData.examResults` içinde durur, yani mevcut JSON yedekleme ve bulut
senkronu akışlarına (`LibraryCodec`) otomatik dahil olur.
- `lib/models/exam_result.dart`: `ExamResult` (id, deckId?, takenAt,
  correctCount, totalQuestions, topicScores) + `ExamTopicScore` +
  `ExamComparison`/`ExamTopicDelta`/`ExamTrend`. Kıyas mantığı SAF ve
  UI'dan bağımsız (`ExamComparison.between`).
- Yalnızca son sonuç değil GEÇMİŞ tutuluyor (trend grafiği ileride bu
  listeden çizilebilsin diye), `ExamResult.maxHistory` = **20** ile sınırlı
  (localStorage şişmesin). Sınırı hem `FlashcardStore.recordExamResult` hem
  `SyncService` uyguluyor. NOT: `exam_result.dart` başındaki doc yorumu
  sabiti `FlashcardStore.maxExamResultHistory` diye anıyor — o isimde bir
  şey YOK, yorum eskimiş; gerçek sabit `ExamResult.maxHistory`.
- `FlashcardStore.recordExamResult` sonucu listenin BAŞINA ekler + persist;
  `lastExamResultFor(deckId)` aynı kapsamdaki en son sonucu döner.
  `ExamSimResultScreen` `initState`'te (post-frame, build sırasında store
  değiştirmemek için) ÖNCE `lastExamResultFor`'u okur, SONRA kaydeder —
  sıra ters olsa kıyas sınavın kendisiyle yapılırdı. `_recorded` bayrağı
  hot reload/yeniden build'de çift kayıt olmasını engeller.
- `ExamResult.deckId` pratikte HEP null (deneme sınavı tüm kütüphane havuzundan
  karışık konu sorar). Alan yine de var: kıyas eşleştirmesi deste bazlı
  yazıldığı için ileride deste kapsamlı bir sınav eklenirse kayıtlar karışmaz.
- Eşikler (`ExamComparison`): `neutralThresholdPoints` **3** (40 soruluk
  sınavda tek soru 2.5 puan — tek soruluk dalgalanmaya "daha iyisin"/
  "gerilemişsin" dememek için), `topicDeltaThresholdPoints` **10**,
  `maxTopicHighlights` **2** (yön başına en fazla 2 konu). Konu kıyası
  yalnızca İKİ sınavda da sorusu çıkmış konular için yapılır. Gerileme
  mesajının dili bilinçli olarak yumuşak ("Tek bir deneme her şeyi söylemez").
- Senkron: `SyncService._mergeExamResults` sonuçları BİRLEŞTİRMEZ, **TOPLAR**
  — her sonuç geçmişte olmuş bağımsız bir olay, iki tarafta çakışan bir
  "durum" değil. Aynı `id` iki kez gelirse tek kopya tutulur; deste
  birleşmesinde id değiştiyse sonuç `deckRemap` ile hayatta kalan desteye
  taşınır; `takenAt`'e göre yeniden sıralanıp `maxHistory`'ye kırpılır.
- UI: `ExamSimResultScreen` içindeki `_ExamComparisonCard`. İlk denemede
  (önceki sonuç yok) kıyas bloğu HİÇ gösterilmez. Kayıt için konu kırılımı
  (`_topicScores`) ekrandaki mevcut çubukları besleyen `_topicBreakdown`'dan
  AYRI tutuldu — o ekranın davranışı değişmesin diye.
- Testler: `test/exam_result_test.dart`, `test/exam_sim_result_screen_test.dart`.
- **Trend grafiği (2026-08-04):** İstatistik ekranında, Çalışma takvimi ile
  Konu başarısı arasında `Deneme sınavı trendi` bölümü
  (`lib/widgets/exam_trend_chart.dart`). Aynı `examResults` geçmişini okur,
  yeni veri/hesap YOK (yüzde doğrudan `ExamResult.percent`).
  `ExamTrendChart.maxPoints` = son **10** deneme (20 nokta birbirine
  yapışıyordu), `minPointsToShow` = **2** — 2'den az sonuçta bölüm BAŞLIĞIYLA
  BİRLİKTE gizlenir (`shouldShow`, tek nokta trend değildir). Çizim elle
  `CustomPainter` ile; **charting paketi (fl_chart vb.) bilinçli olarak
  eklenmedi** — birkaç nokta + düz çizgi için yeni bir bağımlılık taşımaya
  değmez, "iyileştirme" diye paket ekleme. Tuvale çizilen etiketler ekran
  okuyucuya görünmediği için grafik `Semantics(container: true)` özetiyle
  sarılı. Test: `test/exam_trend_chart_test.dart` (10 test).

## Hocanın Favorileri / En Zayıf Konu Antrenmanı (TAMAM, 2026-07-28)
El yazısı/highlight kaynaklı ("hocanın favorisi") kartlara odaklanan filtre +
iki hızlı pratik girişi. Hiç yeni AI çağrısı yapmaz, yalnızca zaten var olan
`Flashcard.isHandwritten` bayrağını kullanır.
- `CardFilter.handwrittenOnly` (`lib/models/card_filter.dart`): true iken
  yalnızca `isHandwritten` kartlar kalır. `StudyScreen`'de "Sadece Hocanın
  Favorileri" switch'i (`_HandwrittenOnlyBar`, `_ExamModeBar` ile aynı görsel
  desen) bunu açar/kapar.
- `HandwrittenFavoriteChip` (`lib/widgets/card_chips.dart`): kart üstünde
  görünür "Hocanın Favorisi" rozeti (amber, `primaryContainer` token'ı) —
  var olan sessiz `HandwrittenIcon`'dan ayrı, ondan daha belirgin.
- `ignoreDueDate` mekanizması (`StudyScreen` parametresi + `FlashcardStore.
  buildSession`, `lib/state/flashcard_store.dart`): true ise SM-2 due tarihi
  hiç kontrol edilmez, filtreye uyan TÜM kartlar oturuma girer. Normal
  çalışma akışını (varsayılan `false`) etkilemez.
- İki giriş noktası bu mekanizmayı kullanır: `CardListScreen`'de "Hocanın
  Favorilerini Çalış" butonu (deste bazlı, yalnızca destede 3+ el yazısı
  kart varsa görünür) ve `DeckListScreen`'de "En Zayıf Konu Antrenmanı"
  (tüm kütüphaneden, `FlashcardStore.weakestTopicInfo`'ya göre en zayıf
  konuyu seçip `deckId: null` ile birleşik kuyrukta çalıştırır).

## Sınav Tempo Uyarısı + Öncelikli Mod
"Bu tempoda sınava yetişemiyorsun" uyarısı ve ona bağlı, kullanıcının elle
açtığı triage modu. Birbirine bağlı ama AYRI iki şey: uyarı salt bilgi verir,
Öncelikli Mod ise kuyruk sırasını değiştirir. İkisi de HİÇBİR kartı gizlemez/
silmez — Sınav Modu'ndan (`CardFilter.examOnly`, kart havuzunu daraltır) bu
yönüyle temelden farklıdır.

**Tempo uyarısı** (`SrsEngine.examPaceWarning` → `ExamPaceWarning` modeli,
`srs_engine.dart`; kütüphane geneli sarmalayıcı `FlashcardStore.
examPaceWarning`):
- Girdi `dailyPace` = `StudyLog.recentAverageDailyPace(maxDays: 7,
  minActiveDays: 3)` — son 7 AKTİF günün ortalaması. `_counts` zaten yalnızca
  >0 günleri tuttuğu için "aktif gün" filtresi bedava geliyor. Aktif gün < 3
  ise `null` → uyarı HİÇ hesaplanmaz (yeni kullanıcıyı boş yere korkutmamak
  için bilinçli).
- `null` dönen diğer durumlar: destenin `examDate`'i yok, veya sınav
  geçmiş/bugün (`daysLeft <= 0`).
- "Kalan kart" = `SrsEngine.isWellLearned` OLMAYANLAR (paylaşılan tanım, bkz.
  aşağıdaki "İyi öğrenilmiş kart" bölümü). DÜZELTME: bu satır önceden
  "`repetitions < difficultyKolayRepetitions`" diyordu — 2026-08-04'te
  `lapses == 0` şartı eklendiğinden ARTIK EKSİK.
- Uyarı ancak `remaining > expectedCapacity * examPaceToleranceFactor` ise
  çıkar (`expectedCapacity = dailyPace * daysLeft`, tolerans **1.1** = %10 —
  küçük sapmalarda gereksiz uyarı çıkmasın diye).
- Birden fazla deste yetişmiyorsa **sınav tarihi en yakın** olan döner (en
  büyük açık olan değil — `daysLeft` karşılaştırılıyor), tek uyarı gösterilir.

**Öncelikli Mod** (`StudySettings.priorityModeDeckIds` / `isPriorityMode` /
`setPriorityMode`, `lib/state/study_settings.dart`):
- DESTE BAZLI bir küme, `shared_preferences`'ta **kendi ayrı anahtarında**
  (`medkart.priorityModeDeckIds.v1`, günlük limitin `medkart.
  dailyNewCardLimit.v1` anahtarından ayrı). Açılışta `main.dart`
  `loadPriorityModeDeckIds()` ile okuyup `StudySettings`'e enjekte eder.
- **CİHAZ BAZLI — bulut senkronuna DAHİL DEĞİL** (`LibraryCodec`/
  `kullanici_kutuphane` içine girmiyor). Geçici bir triage tercihi olduğu için
  bilinçli; senkrona eklemeye kalkmadan önce sebep sor.
- Etkisi tek yerde: `SrsEngine.sortForStudy`'nin `priorityModeDeckIds`
  parametresi. Kümedeki desteye ait `CardPriority.arkaPlan` kartlara
  `priorityRank = 1` verilir ve bu, zayıflık/gecikme sıralamasından ÖNCE gelen
  en üst düzey ayrım olur — yani o kartlar kuyruğun sonuna itilir, silinmez.
  Kümede olmayan destelerin kartları hep `rank 0` alır, sıraları hiç değişmez.
  `priorityModeDeckIds` boşsa karşılaştırma bloğu tamamen atlanır (mevcut
  davranış bit-bit korunur).

**Kritik kapsam sınırı:** `priorityModeDeckIds` yalnızca
`FlashcardStore.dailyQueue`'ya geçiriliyor — yani SADECE birleşik "Bugün
Çalış" kuyruğunda etkili. `StudyScreen`'in deste-bazlı dalı
(`store.studyQueueFor(deckId, ...)`, `study_screen.dart:88`) bu parametreyi
HİÇ almıyor, `ignoreDueDate` hızlı pratik dalı da (`study_screen.dart:102`)
`sortForStudy`'yi parametresiz çağırıyor. Yani bir destede Öncelikli Mod açıkken
o desteye tek tek girip çalışırsan sıralama değişmez. Bunun bilinçli mi yoksa
eksik mi olduğu KAYITLI DEĞİL — davranışı değiştirmeden önce kullanıcıya sor.

**UI** (`deck_list_screen.dart`, `_DailyStudyBanner`): uyarı varsa "Bugün
Çalış" kartının ALTINA `errorContainer` renkli bir blok eklenir ("<Deste> için
sınava N gün kaldı. Bu tempoda yaklaşık X kart çalışabilirsin, elinde Y kart
var."). Blok içindeki `TextButton` Öncelikli Mod'u toggle eder ve etiketi
duruma göre "Öncelikli Kartlara Odaklan" / "Normal Moda Dön" olur. Uyarı
yoksa (`paceWarning == null`) ne blok ne buton oluşturulur — banner'ın kendisi
normal görünür. Buton, ana banner'ın `onTap`'ından (çalışmaya başla, girişe
tabi) ayrı; toggle'ın kendisi `requireAuth`'a TABİ DEĞİL (veri üretmiyor,
yalnızca yerel görünüm tercihi).

**Testler:** `srs_engine_test.dart` (`examPaceWarning` grubu 6 test +
`sortForStudy` öncelik sıralaması 4 test), `flashcard_store_test.dart`
(`examPaceWarning` grubu + `dailyQueue` öncelik testleri),
`study_settings_test.dart` (kalıcılık/toggle/notify), `deck_list_screen_test.
dart` (banner + toggle'ın kuyruğa yansıması).

## "İyi öğrenilmiş kart" — paylaşılan tanım (2026-08-04)
`SrsEngine.isWellLearned(card)` = `lapses == 0 && repetitions >=
difficultyKolayRepetitions`. Bir kartın "öğrenilmiş/hazır" sayılmasının TEK
kaynağı burası; yeni bir "hazır" tanımı İCAT ETME, bu fonksiyonu çağır.
- Kullananlar: sınav tempo uyarısındaki "kalan kart" sayımı
  (`examPaceWarning` → `ExamPaceWarning.remainingCards`) ve deste hazırlık
  yüzdesi (`deckReadiness`). Ölçüt tam da bu iki yer aynı kartı farklı
  sınıflandırmasın diye ortak bir fonksiyona çıkarıldı.
- Tanım `deriveDifficulty`'nin "kolay" kriteriyle KASITLI olarak aynı: bir
  kart aynı anda "zor" etiketli ama "öğrenilmiş" olamaz.
- TARİHÇE: `lapses == 0` şartı 2026-08-04'te eklendi (kullanıcının bilinçli
  kararı). Öncesinde yalnızca repetitions'a bakılıyordu; şart eklenince tempo
  uyarısı SERTLEŞTİ — daha çok kart "kalan" sayılıyor, uyarı daha sık çıkıyor.
  **Tek fonksiyon olduğu için tempo uyarısı ile hazırlık yüzdesi ayrı ayrı
  ayarlanamaz** — birini değiştiren diğerini de değiştirir.
- NOT: `srs_engine_test.dart`'taki mevcut `examPaceWarning` testleri kartları
  `lapses` vermeden (0) kuruyor, yani bu ayrıma DUYARSIZ — yeşil kalmaları
  değişikliğin güvenli olduğunun kanıtı değil. Ayrımı test eden tek yer
  `deck_readiness_test.dart`.

## İstatistik ekranı ızgara düzeni + Günlük Hedef (FAZ 1, 2026-08-04)
İstatistik ekranı referans bir tasarım görselinden dikey listeden **kart-ızgara
(dashboard)** düzenine çevrildi. Bölümlerin İÇERİĞİ/hesabı HİÇ DEĞİŞMEDİ —
yalnızca bir kart kabuğuna (`_SectionCard`: ikon + başlık + açıklama) alınıp
ızgaraya yerleştirildiler.
- **Yerleşim:** üstte 4 metrik kartı, altında iki sütun (sol: Çalışma takvimi,
  Deste hazırlığı, Deneme sınavı trendi / sağ: Konu başarısı), en altta tam
  genişlik Önümüzdeki 7 gün.
- **Kırılma noktaları** (`StatsScreen._columnsFor` / `_metricColumnsFor`):
  metrik kartları masaüstünde 4, daha darda **2x2** (4'ünü alt alta dizmek
  ekranı yiyordu); bölüm ızgarası yalnızca MASAÜSTÜNDE 2 sütun — tablette
  (600-900) iki sütun ısı haritasını okunmaz hâle getiriyordu.
- Gövde `ListView` DEĞİL **`SingleChildScrollView`**: ızgarada yan yana duran
  sütunlarda tembel oluşturma bir şey kazandırmıyor ama görünmeyen sütunun
  hiç build edilmemesine yol açıyordu (widget testleri de bunu görürdü).
- `ContentShell`'e opsiyonel **`maxWidth`** parametresi eklendi; bu ekran
  `AppTheme.dashboardMaxWidth` (**1240**) veriyor. Varsayılan hâlâ
  `contentMaxWidth` (760) — o okunacak METİN sütunu içindir, 4 kartı 760'a
  sıkıştırmak okunaksızdı. Diğer ekranlar etkilenmedi.
- **Metrik kartlarının test anahtarları** `StatsScreen.metric*Key` (public
  `ValueKey`) — gerekli, çünkü kart etiketleri ekranda başka yerlerde de
  geçiyor (ör. "Bugün" hem metrik kartında hem Önümüzdeki 7 gün grafiğinin
  ilk sütununda). Testler metni bu anahtarla kapsamlandırmalı.
- **"Aktif gün" alt metni bilerek "son 30 gün" DEMİYOR:** `StudyLog.activeDays`
  = `_counts.length`, yani TÜM ZAMANLARDAKİ kayıtlı gün sayısı. Referans
  tasarımdaki "Son 30 günde aktif olduğun gün" ifadesi yanlış iddia olurdu.
  Pencereli bir sayım istenirse önce `StudyLog`'a o hesabı eklemek gerekir.
- Çalışma takvimi kartına `subtitle` VERİLMEDİ: `StudyHeatmap` kendi açıklama
  cümlesini zaten içeride yazıyor, ikinci bir tane metni ikizliyordu.

**Opsiyonel günlük hedef** (`StudySettings.dailyGoal`, `int?`):
- `null` = hedef yok, **VARSAYILAN**. Kendi anahtarında saklanır
  (`medkart.dailyGoal.v1`) — günlük YENİ KART LİMİTİNDEN
  (`medkart.dailyNewCardLimit.v1`) tamamen ayrı bir kavram: limit kuyruğa kaç
  yeni kart gireceğini belirler, hedef **hiçbir kuyruk/SRS davranışını
  etkilemez**, yalnızca "Bugün" kartını besler. Cihaz bazlı, buluta gitmiyor.
- `setDailyGoal(null)` (ya da 0/negatif) hedefi TEMİZLER ve anahtarı siler.
- Ayarlar > Çalışma > "Günlük hedef (opsiyonel)" → `DailyGoalDialog`. Alan boş
  bırakılabildiği için pencere `int?` değil **`DailyGoalResult?`** döner:
  `null` = iptal, `result.goal == null` = kullanıcı hedefi kaldırdı. İkisini
  tek `int?` ile ayırt etmek imkânsızdı.
- "Bugün" kartı: hedef VARSA yeşil halka (`DailyGoalRing`) + `%N`; hedef YOKSA
  halka hiç kurulmaz, yalnızca "N kart" + nazik ipucu ("Ayarlar'dan günlük
  hedef belirleyebilirsin.").
- **`DailyGoalRing.percentFor` %100'de KİLİTLENİR** — hedefini üçe katlayan
  kullanıcıda yay taşmaz, metin %300 demez. `isComplete` aynı fonksiyonu
  kullanır (ikisi ayrışmasın); tamamlanınca yüzde metni yerine "Günlük
  hedefini tamamladın 🎉" gösterilir.
- `AppTheme.accentGreen` / `accentGreenOnLight` / `successColor(context)`
  eklendi — başarı/tamamlanma için tek token. `colorScheme.tertiary` amber
  tohumundan türediği için güvenilir bir yeşil vermiyordu; yeni bir yerde
  yeşil gerekirse elle renk yazma, bu token'ı çağır.
- Test: `test/daily_goal_test.dart` (25 test — %100 tavanı, hedefli/hedefsiz
  render, ayar kalıcılığı, dar ekranda 2x2 + taşma yok).
- **SONRAKİ FAZLARA BIRAKILDI** (bu fazda kasıtlı olarak yapılmadı): Konu
  Durumu'ndaki "Az veri" durumları, "Bugün İçin Özet" kartı, Önümüzdeki 7
  gün'ün tasarımdaki yeni hâli.

## İstatistik ekranı görsel sadeleştirme (2026-08-05, SAF GÖRSEL)
Hiçbir veri kaynağı/hesap/sıralama değişmedi — yalnızca `stats_screen.dart`
içindeki görsel ağırlık, renk ve boşluk.
- **Metrik kartlarının açıklama cümleleri kaldırıldı** ("Serini koru, devam
  et!", "Bugüne kadar çalıştığın kart sayısı.", "Çalıştığın toplam gün
  sayısı."). `_StatCard.caption` artık `String?` ve yalnızca metin VERİ
  taşıdığında doldurulur — tek kullanan "Bugün" kartı ("Günlük hedef: N/M
  kart"). Rakamı tekrar eden açıklama EKLEME.
- **Amber (`colorScheme.primary`) bu ekranda yalnızca İKİ yerde:** seri alevi
  ve "Bugün" kartı (ikon + kenarlık). Diğer metrik ikonları ve TÜM
  `_SectionCard` başlık ikonları `onSurfaceVariant`. Yeni bölüm/metrik
  eklerken ikonu amber yapma.
  - Kapsam dışı bırakılanlar (bilinçli): ısı haritası kareleri, konu başarı
    çubukları, "Önümüzdeki 7 gün" çubukları, deste hazırlık çubuğu. Oradaki
    amber DEKORASYON değil VERİ kodlaması (yoğunluk/oran) — süsleme diye
    nötrleştirme.
- **Hiyerarşi:** `_StatCard.emphasized` (yalnızca "Bugün" `true`) → değer
  `headlineSmall` (24) + ikon 30px + amber kenarlık; diğer üçü `titleLarge`
  (20) + ikon 22px + soluk (`onSurfaceVariant`) etiket. Vurgulanan kart TEK
  olmalı. Kenarlık yarıçapı elle yazılmadı, `theme.cardTheme.shape`'ten
  türetiliyor (`_StatCard._emphasisShape`).
- Hedef halkası (`DailyGoalRing`) YEŞİL kaldı — `AppTheme.successColor`
  başarı token'ı; "Bugün" kartının amber vurgusu ikon + kenarlıktan geliyor.
- YAPILMASI İSTENDİ AMA GEREKMEDİ: "ikon-daire kalıbını azalt" ve "konu
  satırlarındaki başlangıç ikonunu kaldır" — kodda ne renkli daire içinde
  ikon var (hepsi düz `Icon`) ne de `TopicSuccessBar`'da satır başı ikonu.
  İkisi de zaten istenen hâldeydi.
- Test: `daily_goal_test.dart` (kaldırılan alt metinler + "son 30 gün iddiası
  yok" güvencesi güncellendi).

## Konu başarısı — veri yeterliliği durumları (FAZ 2 / 1. kalem, 2026-08-05)
"Konu başarısı" bölümü artık her konuda yüzde göstermiyor; yüzdenin arkasında
yeterli veri yoksa sayı yerine etiket çıkıyor (1 kartta 1 hata = "%0" yanıltıcı
bir "en zayıf konu" üretiyordu).
- Üç durum: `TopicDataState { normal, lowData, notStarted }` (`srs_engine.dart`,
  `TopicStat.dataState`). **enum sırası = GÖSTERİM sırası**, sıralama `index`
  üzerinden karşılaştırıyor — araya eleman ekleme, sona ekle.
- Eşik: `TopicStat.minAttemptsForPercent` = **5** (tek yerde, kolay ayarlanır).
- **Ölçü `attempts` (= lapses + repetitions), ÇIPLAK `repetitions` DEĞİL.**
  Talimat "toplam repetitions" diyordu ama SM-2'de "Zor" cevap repetitions'ı
  SIFIRLIYOR (`SrsEngine.review`) — hep zorlanılan bir konunun tüm kartları
  `repetitions == 0` olabilir ve çıplak repetitions'a bakılsaydı öğrencinin EN
  ÇOK çalıştığı konu "Henüz başlanmadı" diye listenin dibine düşerdi. `attempts`
  zaten `TopicStat`'ta vardı ve `successRate`'in paydası da o, yani "bu yüzdeyi
  kaç gözlem destekliyor" sorusunun doğrudan cevabı. Regresyon testi:
  `topic_data_state_test.dart` içindeki "hep Zor cevaplanmış konu" testi.
- **Sıralama** (`SrsEngine.topicStats`): önce grup (normal → az veri → henüz
  başlanmadı), grup içinde yalnızca NORMAL konular başarı oranına göre artan
  (en zayıf üstte). Diğer iki grupta sıralanacak yüzde yok; sıra deterministik
  olsun diye kart sayısı fazla olan önce, sonra ada göre.
- **UI bayrağı `TopicSuccessBar.showLowDataStates`, varsayılan `false`.**
  Yalnızca istatistik ekranı `true` veriyor. Deneme Sınavı sonuç ekranı aynı
  widget'ı kullanıyor ve orada `attempts` = o konudan çıkan SORU sayısı — 3
  soruluk bir konuyu "Az veri" göstermek sınav sonucunun anlamını değiştirirdi.
  Bayrağı oraya açma.
- **Renk kademesinden KIRMIZI KALDIRILDI** (kullanıcı kararı, 2026-08-05):
  artık `<%75` amber (`primary`), `>=%75` yeşil (`AppTheme.successColor`);
  veri yetersizse gri (`outlineVariant`) + çubuk 0. Eski eşikler `<50 error /
  <75 tertiary / üstü primary` idi. **Bu değişiklik Deneme Sınavı sonuç
  ekranını da etkiliyor** (widget ortak) — bilinçli: tek widget'ta iki ayrı
  renk dili taşımamak için.
- (DÜZELTME 2026-08-11) `_DeckReadinessBar` (Deste hazırlığı) ARTIK
  KIRMIZIYI KORUMUYOR — bu satır önceden öyle diyordu, o tarihte doğruydu.
  Amber/gold temizliği kapsamında kırmızı/tertiary/primary dallanması TAMAMEN
  kaldırıldı, artık TEK bir mor→pembe gradyan (`AppTheme.
  dashboardProgressGradient`) — bkz. aşağıdaki "Deste Hazırlığı" bölümünün
  güncellenmiş notu. `TopicSuccessBar`'ın kendi semantik (durum) renklerine
  DOKUNULMADI, hâlâ ayrı.
- Test: `test/topic_data_state_test.dart` (13 test — eşik sınırı, "Zor" tuzağı,
  gruplu sıralama, etiketler, bayrak kapalı davranışı, renkler).

## Deste Hazırlığı (2026-08-04)
İstatistik ekranında, Deneme sınavı trendi ile Konu başarısı arasında
"Deste hazırlığı" bölümü: her deste için `%X hazır` + ilerleme çubuğu +
"{hazır}/{toplam} kart".
- Hesap: `SrsEngine.deckReadiness(decks, cards)` → `DeckReadiness` listesi
  (`readyCards`/`totalCards`/`readyPercent`). "Hazır" = `isWellLearned`
  (yukarı bkz.). Store sarmalayıcısı `FlashcardStore.deckReadiness`.
- Sıralama EN DÜŞÜK hazırlık ÖNCE (ekrandaki "en zayıf üstte" kuralıyla
  tutarlı), eşitlikte deste adına göre — sıra deterministik olsun diye.
- **Kartı olmayan deste listeye HİÇ girmez** (yüzde tanımsız olurdu + boş
  desteyi "%0 hazır" göstermek yanıltıcı). Liste boşsa bölüm BAŞLIĞIYLA
  BİRLİKTE gizlenir.
- UI: `stats_screen.dart` içindeki özel `_DeckReadinessBar`. `TopicSuccessBar`
  ile aynı görsel dil (aynı çubuk yüksekliği/yarıçapı) ama ayrı bir widget — alt metni
  "3/10 kart" biçiminde İKİ sayı taşıyor, `TopicSuccessBar` tek sayı
  gösteriyor. (DÜZELTME 2026-08-11) Renk eşikleri (<50 error, <75 tertiary,
  üstü primary) ARTIK YOK — amber/gold temizliği kapsamında TEK bir
  mor→pembe gradyana (`AppTheme.dashboardProgressGradient`, `LinearProgressIndicator`
  yerine elle çizilmiş `Stack`+`FractionallySizedBox`) çevrildi; yüzde
  metninin rengi de tek bir mor tona sabitlendi (`dashboardVioletDeep`/
  `dashboardViolet`). `TopicSuccessBar` HÂLÂ kendi semantik renklerini
  koruyor (2026-08-05'te kırmızıyı bırakmıştı, amber/yeşil kaldı) — bu
  ikisi birbirinden BAĞIMSIZ, karıştırma. Bkz. "Konu başarısı — veri
  yeterliliği durumları".
- Test: `deck_readiness_test.dart` (10 test — tanım tutarlılığı, sıralama,
  boş deste, ekran).

## Önümüzdeki 7 Gün — tekrar yükü tahmini (2026-08-04)
İstatistik ekranının EN ALTINDA (Konu başarısı'ndan sonra) 7 çubuklu bar
chart: hangi gün kaç kartın tekrara düşeceği.
- Hesap: `SrsEngine.reviewForecast(cards, now, {days = 7})` →
  `List<ReviewForecastDay>` (gün + sayı), ilk eleman BUGÜN. Saf fonksiyon,
  store'da sarmalayıcı yok — ekran doğrudan `store.cards` ile çağırıyor.
- **Gecikmiş kartlar (nextReview < bugün) İLK GÜNE toplanır** — bugünün
  gerçek yükünü göstersin, gecikmiş yük grafikten kaybolmasın.
- **`nextReview == null` kartlar (hiç çalışılmamış YENİ kartlar) SAYILMAZ:**
  zamanlanmış tekrarları yok, günlük yeni-kart limiti üzerinden kuyruğa
  giriyorlar (bkz. `dailyQueue`). Bugüne saymak grafiği şişirirdi.
- Pencere dışı (>= 7 gün sonrası) kartlar sayılmaz.
- Hiç kart yoksa bölüm BAŞLIĞIYLA BİRLİKTE gizlenir. Kart var ama hiç
  zamanlanmış tekrar yoksa bölüm görünür ve "tekrara düşecek kart yok" der.
- UI: `lib/widgets/review_forecast_chart.dart`. Çubuklar düz `Container`
  (CustomPainter DEĞİL) — sayı ve gün etiketleri gerçek `Text` widget'ı
  kalsın diye: ekran okuyucu görüyor, testler tuvale bakmadan doğruluyor.
  Yeni charting paketi yok. En yoğun gün tam `primary`, diğerleri aynı rengin
  %55 opak tonu, 0 kartlı günler `outlineVariant` ince taban. `shortLabel`
  (Bugün/Yarın/Cmt…), `busiestIndex` (eşitlikte en YAKIN gün kazanır) ve
  `captionFor` statik + saf, testler doğrudan çağırıyor.
- **Giriş kapısı BİLEREK YOK.** Kullanıcı "sadece giriş yapmış kullanıcılar
  için" demişti ama istatistik ekranı pasif görüntüleme; Faz 3 kuralı kapıyı
  yalnızca veri üreten/dışarı çıkaran eylemlere uyguluyor (bkz. "Zorunlu
  Login"). Ölçüt "kart yoksa gizle" olarak uygulandı. Buraya `requireAuth`
  eklemeye kalkma — ekranın geri kalanıyla tutarsız olur.
- Test: `review_forecast_test.dart` (13 test — dağılım, gecikmiş kartlar,
  pencere sınırı, etiketler, alt not varyantları, ekran).

## Tarayıcıda elle doğrulama — ortam notları (2026-08-04, 2026-08-06 eklerle)
Uygulamayı gerçek tarayıcıda sürerken tekrar tekrar çarpılan şeyler:
- **2026-08-06: Node.js bu makinede KURULU DEĞİLDİ** — `npx`/`npm`/`node`/
  `supabase` komutlarının hiçbiri PATH'te yoktu (CLAUDE.md'nin "npx supabase"
  yazan eski notlarına rağmen). Çözüm: resmî Windows zip'i (v24.19.0 LTS,
  SHA-256 doğrulandı) `C:\Users\Admin\.local\nodejs` altına açıldı ve o dizin
  KULLANICI kapsamındaki PATH'e eklendi. Admin/UAC gerekmedi, sistem geneline
  hiçbir şey yazılmadı; geri almak için klasörü silip PATH satırını çıkarmak
  yeterli.
- **`!` ile açılan bash kabuğu, Windows kullanıcı PATH'ini GÖRMÜYOR** —
  kullanıcı `! npx supabase login …` yazdığında `npx: command not found`
  aldı. Node gerektiren komutları PowerShell aracıyla ve PATH'i başa
  ekleyerek çalıştır: `$env:PATH = "C:\Users\Admin\.local\nodejs;$env:PATH"`.
- **Supabase CLI girişi token ile yapıldı** (`supabase login --token sbp_…`) —
  interaktif giriş bu ortamda çalışmıyor (TTY yok). Giriş 2026-08-06'da
  yapıldı; `supabase projects list` MedKart'ı (`zmwjlchbpiyjzwvkaatu`,
  `linked: true`) döndürüyor. Bir dahaki deploy'da önce bu komutla oturumun
  hâlâ geçerli olduğunu kontrol et.
- **2026-08-06'da port 8080 yerine 8081 kullanıldı** (kullanıcı öyle istedi).
  Aşağıdaki 8080 talimatları port numarası dışında aynen geçerli.
- **Beyaz ekran vakası 2026-08-06'da TEKRARLADI** ve aşağıdaki teşhis birebir
  doğrulandı: sunucu log'unda `Failed to create WebSocket debug connection …
  was not upgraded to websocket` satırı çıktı. Sebep yine birden fazla sekme.
  Çözüm sırası ÖNEMLİ: önce TÜM sekmeleri kapat, SONRA sunucuyu yeniden
  başlat, en son tek sekme aç. Sekmeler açıkken yeniden başlatmak işe
  yaramıyor — açık sekme yeni sunucuya anında bağlanıp bağlantıyı tekrar
  bozuyor. Yeniden başlattıktan sonra log'da o satırın OLMAMASI, temiz
  başladığının kanıtı.
- **`print()` çıktısı sunucu log'una GİTMEZ** — Flutter web'de tarayıcı
  konsoluna yazılır. `[GEMINI s.N]`/`[GLM s.N]` tanılama satırlarını
  `flutter run` çıktısında arama, bulamazsın.
- Sunucu: `flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1`.
  Arka planda başlatılırsa stdin yok → **hot reload (`r`) İMKÂNSIZ**. Yeni kodu
  görmek için süreci öldürüp yeniden başlat: 8080'i dinleyen `dartvm.exe`
  PID'ini (`Get-NetTCPConnection -LocalPort 8080 -State Listen`) ve `dart`
  sürecini durdur, sonra komutu tekrar çalıştır (~25 sn'de ayağa kalkar).
- **Fare tekerleğiyle kaydırma CanvasKit'te çoğu ekranda ÇALIŞMIYOR.**
  Telafi etmek için `left_click_drag` kullanma — dikey sürükleme geri
  navigasyonu tetikliyor ve yanlış ekrana düşüyorsun. Ekranın altındaki bir
  şeyi görmen gerekiyorsa ya pencereyi büyüt ya da içeriği kısaltan bir seçim
  yap (ör. konu listesi kısa olan bir deste seç).
- **BEYAZ EKRAN = çoğu zaman senin kodun değil.** Konsolda tek hata
  `dwds/src/injected/client.js` içindeyse (`TypeError: Instance of
  '_JsonMap' ... is not a subtype of List<Object?>`) ve sunucu log'unda
  `Failed to create WebSocket debug connection ... was not upgraded to
  websocket` varsa: aynı `flutter run` oturumuna **birden fazla tarayıcı
  sekmesi** bağlanmıştır. dwds tek debug istemcisi bekler; ikincisi
  bağlanınca injected client çöker ve Flutter bootstrap tamamlanamaz —
  uygulamanın kendi script'leri sorunsuz yüklenmiş olsa bile ekran beyaz
  kalır. Çözüm sırayla: (1) fazla sekmeleri kapat, tek sekme bırak;
  (2) yetmezse sunucuyu öldürüp yeniden başlat. Kodda hata arama.
- Debug/DDC ilk yükleme yavaş: sayfayı açtıktan sonra ~10 sn beklemeden
  ekran görüntüsü alma, boş kare gelir. (Ağ/anahtar doğrulaması gibi ciddi
  uçtan uca testler için `flutter build web --release` + statik sunucu —
  bkz. "Backend mimarisi".)

## MCQ overflow düzeltmesi (2026-07-28)
`McqQuizScreen`'de "Sonraki"/"Özeti Gör" butonu artık sabit
`bottomNavigationBar` (`_McqNextBar`) — önceden `Column` içinde `Spacer` ile
itiliyordu ve uzun şık açıklamalarında ekran altından taşıp erişilemez
oluyordu.

## Tasarım Sistemi
TEK kaynak `lib/theme/app_theme.dart` — koyu lacivert zemin + amber vurgu
(landing mockup'ından), tipografi skalası, `AppTheme.space*` spacing.
Tamamlanan ekranlar (hepsi bu token'ları kullanıyor, masaüstü+mobil+açık/koyu
görsel doğrulandı): deste listesi/landing, çalışma ekranı, istatistik,
ayarlar, MCQ (kurulum+soru+özet). Yeni bir ekran eklerken renk/font/padding'i
asla sabit kodlama — `Theme.of(context).colorScheme.*`/`textTheme.*` kullan.

## Maliyet (ölçülmüş gerçek veri)
- Vision + uzun cevap ile: ~$0.019/sayfa (Gemini 3.5 Flash, thinking kapalı)
- 100 sayfa/ay kullanıcı ≈ $1.92 API maliyeti
- Görsel token sabit (~1092/sayfa, JPEG 1024px, içerikten bağımsız)
- NOT: Bu ölçüm `shortAnswer` alanı eklenmeden ÖNCE yapıldı (2026-07-18);
  her kartta ekstra bir alan üretildiği için gerçek maliyet şu an muhtemelen
  bu rakamdan biraz yüksek — henüz shortAnswer sonrası yeniden ölçülmedi.

**GLM (`z-ai/glm-4.5v`, OpenRouter) — 2026-08-06 ölçümü:**
- Fiyat: girdi **$0.592/M**, çıktı **$1.80/M** (yanıtın `cost_details`
  bloğundan hesaplanarak doğrulandı, tahmin değil).
- İki gerçek çalıştırma (145 + 157 = 302 kart): toplam **≈ $0.4551**,
  kart başına **≈ $0.0015**.
- Reasoning kapatılması aynı isteği **%52 ucuzlattı** (bkz. "GLM sağlayıcısı").
- **Sayfa başına maliyet HESAPLANAMADI**: token dökümü hiçbir yerde
  tutulmuyor ve o çalıştırmaların sayfa sayısı kayıt altına alınmadı.
  $0.4551'in token karşılığı yalnızca aralık olarak biliniyor (tamamı girdi
  olsaydı ~758K, tamamı çıktı olsaydı ~253K token). Gemini'nin ~$0.019/sayfa
  rakamıyla doğrudan karşılaştırma yapmak için önce sayfa sayısı ya da
  `usage` logu gerekir.

## Maliyet Optimizasyonu (2026-07-21)
- **Paylaşılan PDF→kart önbelleği:** Aynı PDF'in SHA-256 hash'i (dosya
  adından bağımsız, içerik bazlı — `PdfCacheService.hashBytes`) TÜM
  kullanıcılar için paylaşılan `pdf_cache` tablosunda aranır
  (`supabase/functions/pdf-cache/index.ts`, `lookup`/`save` action'ları,
  `ai-proxy`'den AYRI bir fonksiyon). İsabet varsa Gemini'a hiç gidilmeden
  (pdf.js çıkarımı/konu seçimi bile atlanarak) kartlar anında eklenir +
  şeffaflık dialogu ("bu ders notu daha önce işlenmiş"). **Yalnızca TÜM PDF**
  (sayfa aralığı/konu ile daraltılmamış) işlendiğinde geçerli — kullanıcı
  alt küme seçerse o çalışma ne önbellekten okur ne yazar (bilinçli kapsam
  sınırı). Cache-hit yolu `ai-proxy`'ye hiç uğramadığı için `kullanim_kota`
  hiç artmaz (kullanıcı avantajlı çıkar — viral teşvik: "arkadaşın zaten
  yüklediyse kotan gitmez").
- **El yazısı/işaretleme anahtarı** (`AddCardsScreen`'de `SwitchListTile`,
  varsayılan Evet): "Hayır" seçilirse `web/pdf_extract.js`'te sayfa görüntüsü
  HİÇ render edilmez (yalnızca metin gönderilir, daha hızlı + sıfır görsel
  token maliyeti). `gemini_service.dart`'ın `generateForPage`'i zaten
  `imageBase64 == null` durumunu native destekliyor — bu yüzden
  Gemini/pipeline kodunda değişiklik gerekmedi, yalnızca JS render adımı
  atlandı. Kapalıyken ayrıca `hasImage:false` olduğu için görsel-bağımlı
  prompt blokları (`elYazisiKurali`, `slaytNumarasiKurali`,
  `metinVeGorselBirlikteKurali`) da prompt'a hiç girmez — üretilen tüm
  kartlarda `isHandwritten` zorunlu false, slayt numarası düzeltmesi devre
  dışı (sourcePage hep fiziksel yaprak sırası). Metin katmanı çıkarımı ve
  "TABLO — ASLA ATLAMA" bloğu vision'dan bağımsız, kapalıyken de çalışır;
  ama SALT görsel içerik (taranmış sayfa, resim olarak gömülü tablo, el
  yazısı) tamamen atlanır — metin katmanı da yoksa sayfa pipeline'a hiç
  girmez (`hasExtractableText || hasImage` filtresi).
- **Cache anahtarı el yazısı anahtarını İÇERİR (2026-08-05 bug düzeltmesi):**
  önceden `pdf_cache` anahtarı yalnızca dosya içeriğiydi (`hashBytes`) ve iki
  mod aynı rafı paylaşıyordu — görsel KAPALI işlenmiş (zayıf, el yazısız)
  sonuç, aynı PDF'i görsel AÇIK yükleyen kullanıcıya sessizce servis
  edilebiliyordu. Artık `PdfCacheService.hashBytes(bytes, includeImages:)`:
  `true` (varsayılan) DÜZ SHA-256 döndürür — tüm eski (soneksiz) kayıtlar
  geçerli, geriye dönük uyumlu; `false` özete `PdfCacheService.noVisionSuffix`
  (`':novision'`, tek yerde tanımlı sabit) ekler. İki mod ayrı raflarda,
  birbirini asla ezmez/servis etmez. Tek çağrı noktası
  `add_cards_screen.dart` (`includeImages: _hasHandwriting`); save tarafı
  aynı hash'i `PdfImportScreen.pdfHash` üzerinden alır, ayrı değişiklik
  gerekmedi. Sunucu/Edge Function DEĞİŞMEDİ (hash onun için opak bir
  string). `hit_count` sayacı da raf bazına ayrıştı (beklenen yan etki).
  Test: `pdf_cache_service_test.dart` "includeImages" grubu (5 test).
- **Cache HIT sayacı (`hit_count`, 2026-07-27):** `pdf_cache` tablosuna
  `hit_count integer not null default 0` sütunu + atomik
  `pdf_cache_hit_artir(p_hash)` RPC'si eklendi (migration
  `20260727010000_add_pdf_cache_hit_count.sql`, `kullanim_kota_artir` ile aynı
  desen — tek `UPDATE ... RETURNING`, eşzamanlı HIT'lerde sayaç kaçmaz).
  Yalnızca **lookup HIT** olduğunda artar; MISS'te veya `save`'de hiç
  dokunulmaz.
  - `pdf-cache` Edge Function lookup'ta HIT sonrası RPC'yi çağırır ve
    `hit_count`'u cevaba koyar. RPC hata verirse HIT YİNE karşılanır, sayaç
    olarak eski değere düşülür — kartların gelmesi sayaç gösteriminden önemli.
  - `PdfCacheService.lookup` artık düz kart listesi değil
    `PdfCacheHit(cards, hitCount)` döner; `hitCount` **nullable** (RPC
    başarısızsa null gelir → çağıran taraf sayı GÖSTERMEMELİ).
  - UI: `AddCardsScreen._showCacheHitFeedback` — `hitCount >= 10` ise
    "⚡ Bu set daha önce işlenmiş — anında hazır! (N kez çalışıldı)", aksi
    halde sayısız kısa hâli (küçük sayı sosyal kanıt olarak motive etmez).
- **Model/prompt sürüm sütunları (2026-07-26, YARIM İŞ):** `pdf_cache`'e
  `model_version` / `prompt_version` sütunları eklendi (migration
  `20260726000000_add_pdf_cache_version_columns.sql`) — amaç prompt/model
  güncellenince eski cache kayıtlarını ayırt edebilmek. ŞİMDİLİK yalnızca
  yazılıyor, **lookup tarafında sürüme göre filtreleme YOK**, cache-hit
  davranışı değişmedi. Eski kayıtlarda NULL kalır (beklenen, zararsız).

## Kompakt kart çıktı biçimi (2026-08-04)
Model artık her kartı alan adlı bir NESNE değil, **sırası sabit 9 elemanlı bir
DİZİ** olarak döndürüyor. Amaç tek: çıktı token maliyeti (çıktı, girdinin 6
katı fiyattan faturalanıyor ve her kartta 9 alan adı + uzun enum değerleri
tekrar tekrar yazılıyordu). **Öğrenciye giden veri/davranış HİÇ değişmedi** —
`Flashcard` modeli, UI, export, cache, senkron aynen duruyor.
- Sıra (tek kaynak: `flashcard_prompt.dart` `kompakt*Index` sabitleri):
  `[soru, kisaCevap, cevap, zorlukKodu, kartTipiKodu, oncelikKodu, konu,
  slaytNumarasi, elYazisindanMi]`. **Bir pozisyon bilinmiyorsa null yazılır,
  ATLANMAZ** — atlanırsa sıra kayar.
- Kısaltmalar: zorluk `k`/`o`/`z`, kartTipi `t`/`s`, oncelik `o`/`a`.
  DİKKAT: `"o"` [3]. pozisyonda **orta**, [5]. pozisyonda **oncelikli**.
- `sourcePage` diziye DAHİL DEĞİL (model bilemez, backend damgalıyor).
  Modelin okuduğu slayt numarası ayrı bir pozisyonda ([7]) ve eskisi gibi
  fiziksel sayfayı ezer.
- Şema (`responseSchema`) artık `ARRAY of ARRAY`, iç elemanlar
  `STRING + nullable`. **Neden hepsi STRING:** Gemini'ın şema alt
  kümesi heterojen ("tuple") dizi desteklemiyor — bir ARRAY'in tek `items`
  şeması olabilir, pozisyon başına farklı tip verilemez. Bu yüzden bool/int de
  string olarak isteniyor ("true"/"12"). Ayrıştırıcı native tipleri de kabul
  ediyor, yani şema ileride gevşetilirse kod değişmez.
- **`minItems`/`maxItems` BİLEREK YOK** (kullanıcı kararı, 2026-08-04):
  uzunluğu şemada kilitlemek sıra kaymasına karşı yapısal garanti olurdu ama
  Gemini'ın bu alanları nested ARRAY'de kabul ettiği canlı doğrulanamadı
  (kredi yok) ve reddedilseydi TÜM istekler 400 ile ölürdü. Şema en sade
  hâlinde: yalnızca `type` + `items` + `nullable`. Eleman sayısı yalnızca
  prompt'ta dayatılıyor. Geri eklemek istersen önce canlıda doğrula.
- Çözücü: `flashcardFromCompactItem` (`flashcard_prompt.dart`). ASLA fırlatmaz:
  dizi değilse/boşsa/soru-cevap boşsa null döner (kart atlanır), kısa dizide
  kalan etiketler enum varsayılanına düşer, tanınmayan kod kartı YOK ETMEZ.
  `flashcardFromItem` gelen öğe List ise buna devreder, Map ise eski alan adlı
  biçimi çözer — eski biçim desteği bilerek KORUNDU (şemasız sağlayıcı ya da
  eski yanıt kartı kurtarabilsin diye).
- Her iki yola da (Yol A `generateForPage` + Yol B `generate`) uygulandı —
  ikisi zaten aynı `responseSchema` sabitini paylaşıyor. DeepSeek'in
  `_jsonFormatTalimati` zarfı da (`{"cards": [...]}`) kompakt diziye hizalandı.
- `kPromptVersion` şu an **v22**. Tarihçe: v14 → v15 (kompakt biçim), 2026-08-05'te
  üç kez daha arttı — v16 (cevap uzunluğu "1-3"→"2-4" eşitlemesi +
  slaytNumarasi satırındaki yön düzeltmesi), v17 (kapanış/teşekkür slaydı
  filtresi + öncelik kalibrasyonunun sıkılaştırılması), v18
  (`terminolojiStandardiKurali` + `guncellikDiliYasagiKurali` + tablo
  çoklu-öğe eşleştirme kuralı); 2026-08-06'da dört kez daha arttı — v19
  (`elYazisiKurali` vurgu/tasarım ayrımı), v20 (`metinVeGorselBirlikteKurali`
  aynı ayrımla hizalandı), v21 (Yol A "boş dizi" kuralı ders-dışı içeriği
  kapsadı), v22 (aynı kural Yol B'ye eklendi + "5-20 kart" alt sınır
  olmadığı netleşti). Hepsinin ayrıntısı "Kart Üretim Kuralları"
  bölümünde. Eski `pdf_cache` kayıtları etkilenmez:
  orada saklanan şey ham model çıktısı değil, çözülmüş `Flashcard` JSON'u —
  ayrıca lookup sürüme göre filtrelemiyor (bkz. `pdf_cache_service.dart`
  `save` doc yorumu), yani sürüm artışının bugün fonksiyonel etkisi YOK,
  yalnızca yeni kayıtların etiketi doğru olsun diye artırılıyor.
- **Eski (Map) çözücü yolu CANLI, ölü kod DEĞİL** — `flashcardFromItem` gelen
  öğe Map ise hâlâ alan adlı biçimi çözüyor ve bu dal üç production çağrı
  noktasından da (`gemini_service.dart:282`/`:449`, `deepseek_service.dart:216`)
  erişilebilir. 2026-08-05'te oradaki `item['slaytNumarasi'] as num?` cast'i
  `_kompaktInt`'e çevrildi: model bu alanı string ("12") yazsaydı TypeError
  fırlıyordu ve çağıran döngülerin HİÇBİRİNDE kart bazlı try/catch olmadığı
  için tek bozuk kart TÜM sayfayı düşürüyordu. Artık kompakt yolla aynı
  toleransta (native num / sayı-string / null kabul, çözülemezse fiziksel
  sayfaya düşer). Map dalındaki diğer alanlar zaten `Object?` üzerinden
  okunduğu için çökmüyordu.
- İÇERİK kurallarının hiçbiri değişmedi (kaynak sadakati, el yazısı
  önceliklendirme, tablo eksiksizliği, kaynağa atıf yasağı, zorluk
  kalibrasyonu) — yalnızca çıktı biçimi ve o biçimi anlatan blok
  (`kartEtiketleriKurali`) değişti.
- **CANLI DOĞRULANMADI:** Gemini hesabının kredisi tükenmiş durumda (her
  istek 429 "prepayment credits are depleted"), bu yüzden şemanın API
  tarafından kabul edildiği gerçek çağrıyla teyit edilemedi. Risk, şema en
  sade hâline indirilerek (yukarı bkz.) asgariye çekildi.
- Test: `test/compact_card_format_test.dart` (33 test — pozisyon eşlemesi,
  kod eşlemesi, bozuk/eksik dizi, uçtan uca iki yol).

## GLM sağlayıcısı (2026-08-06) — OpenRouter, görsel destekli
> **DURUM: kod hazır ve çalışır, ama AKTİF SEÇİM DEĞİL.** Kalite testi
> yapıldı; klinik vaka kartları güçlüydü fakat el yazısı/vurgu
> güvenilirliğinde tekrarlayan sorunlar (yanlış okuma + uydurma, aşırı
> etiketleme) çıktığı için `activeAiProvider` `gemini`'ye geri alındı.
> Aşağıdaki her şey geçerli ve dokunulmadı — ileride yeniden test edilebilir.

Üçüncü sağlayıcı. DeepSeek'in deseni referans alındı ama DeepSeek'ten temel
farkı **görsel desteklemesi**: yani Yol A'nın vision'a bağlı tüm yetenekleri
(el yazısı yakalama, slayt numarası okuma, görsel gömülü tablolar) bu
sağlayıcıda da çalışır — DeepSeek'te hiç çalışmıyordu.

**Dosyalar:** `lib/services/glm_service.dart` (prompt kurma + yanıt
ayrıştırma), `lib/services/glm_transport.dart` (ağ + retry + güvenlik
sabitleri), `ai-proxy`'nin `glm` dalı, `main.dart` `_buildGenerator()`
switch'inde `case AiProvider.glm`. Testler: `test/glm_service_test.dart`
(19 test) + `test/glm_transport_test.dart` (13 test) — **hiçbiri gerçek ağa
çıkmaz**, hepsi `MockClient`.

**Model:** `GlmService.model = 'z-ai/glm-4.5v'`. Model adı URL'de değil
PAYLOAD'ın içinde taşınır (Gemini'de URL path'inde). Bu yüzden `GlmTransport`
zarfa `model` alanı KOYMAZ — DeepSeek ile aynı, Gemini ile farklı.

**Protokol:** OpenAI-uyumlu Chat Completions. Gemini'nin `responseSchema`
karşılığı YOK; kompakt 9 elemanlı diziler DeepSeek'teki gibi
`{"cards": [...]}` zarfı içinde isteniyor (`_jsonFormatTalimati`, DeepSeek'in
metniyle birebir aynı) + `response_format: {'type':'json_object'}`. İçerik
kuralları paylaşılan `buildGeneralPrompt`/`buildPagePrompt`'tan geliyor,
kopyalanmıyor.

**Görsel gönderimi:** Gemini'nin `inlineData`'sının OpenAI-stilindeki
karşılığı. `hasImage` true iken `content` düz string yerine blok dizisine
dönüşür: önce `{'type':'image_url','image_url':{'url':'data:<mime>;base64,…'}}`,
sonra `{'type':'text','text':<prompt>}` — Gemini'deki "görsel önce, yönerge
sonra" sıralamasıyla aynı. Görsel yokken `content` düz string kalır.

**DeepSeek'ten üç bilinçli GÜVENLİK farkı** (hepsi `GlmTransport`'ta):
1. `maxOutputTokens = 4096` (DeepSeek'te 8192) — Gemini ile aynı maliyet
   tavanı. Sabit transport'ta duruyor ama gövdeyi kuran `GlmService` onu
   `GlmTransport.maxOutputTokens` diye okuyor (üç güvenlik kararı tek dosyada
   toplansın diye).
2. **Zaman aşımı yeniden denemeden AYRI:** `TimeoutException` ayrı yakalanıp
   `isTimeout: true` ile fırlatılır, böylece `PdfCardPipeline` o sayfayı
   TEKRAR DENEMEZ (üretim faturalanmış olabilir). DeepSeek'te bu YOK — orada
   zaman aşımı jenerik "bağlanılamadı" dalına düşüyor.
3. Hata mesajları API anahtarı için `.env`'e YÖNLENDİRMEZ (anahtar sunucuda).
   `SUPABASE_URL`/`SUPABASE_ANON_KEY` mesajları ise `.env` demeye DEVAM eder —
   onlar gerçekten istemcinin `.env`'inde, bu ayrım bilinçli.

**Reasoning KAPALI — `'reasoning': {'effort': 'none'}`** (`_reasoningKapali`).
Gemini'deki `thinkingBudget: 0`'ın karşılığı. Reasoning tokenları görünmez ama
ÇIKTI fiyatından faturalanır. Canlı ölçüm (2026-08-06, önemsiz bir test
prompt'uyla): kapalıyken 124 çıktı tokenının 82'si (%66) reasoning'di,
maliyet $0.00029542; açtıktan sonra 41 token ve $0.00014122 — **%52 ucuz**.
- `exclude: true` KULLANMA: model düşünmeye DEVAM eder, yalnızca göstermez;
  tokenlar yine faturalanır. Kapatan iki biçim `{'effort':'none'}` ve
  `{'enabled':false}`; ikisi de `z-ai/glm-4.5v`'de canlı denendi, birebir aynı
  sonucu verdi. Doküman kanonik biçim olarak `effort: 'none'` diyor.
- `test/glm_service_test.dart` bu alanın gönderildiğini doğruluyor; o satır
  silinirse maliyet sessizce ~2 katına çıkar.

**CANLI DOĞRULANDI (2026-08-06)** — proxy üzerinden gerçek çağrılarla:
- `response_format: json_object` OpenRouter tarafından bu model için KABUL
  EDİLDİ (400 gelmedi).
- Model markdown fence KULLANMADI, `content` ham JSON geldi → ayrıştırıcı
  sorunsuz çözdü.
- Fiyatlar doğrulandı: girdi **$0.592/M**, çıktı **$1.80/M** (yanıtın
  `cost_details` bloğundan hesaplandı).
- İki gerçek PDF çalıştırması yapıldı: 145 ve 157 kart, toplam **≈ $0.4551**,
  kart başına **≈ $0.0015**.

**BİLİNEN SINIR — fence temizleme YOK:** `_parseCards` DeepSeek'in desenini
birebir izliyor ve `content`'i doğrudan `jsonDecode` ediyor. Model bir gün
` ```json ` ile sararsa kart üretilmez, sayfa sessizce düşer ve konsola
`[GLM s.N] iç JSON çözülemedi` yazılır. Bugün bu olmadı ama `json_object`
modu bir sağlayıcıda desteklenmezse ilk şüpheli budur.

**TOKEN SAYIMI HİÇBİR YERDE TUTULMUYOR** (2026-08-06'da arandı, bulunamadı):
`GlmService._parseCards` yanıttan yalnızca `choices[0].message.content`
okuyup `usage` bloğunu atıyor; `ai-proxy` de `usage`'ı loglamıyor;
`kullanim_kota.islenen_sayfa` token değil SAYFA sayıyor. Ayrıca `print()`
çıktısı Flutter web'de `flutter run` stdout'una değil TARAYICI KONSOLUNA
gider — sunucu log dosyalarında `[GLM …]` satırı hiç görünmez, oraya bakma.
OpenRouter'ın `/api/v1/activity` uç noktası per-generation token dökümü
verebilir ama "management key" ister, normal API anahtarı 403 alır. Dolar
bazında `/api/v1/key` ve `/api/v1/credits` çalışıyor. Token sayısı gerekiyorsa
tek yol `_parseCards`'a `usage`'ı loglayan bir `print()` eklemek.

## Backend mimarisi (Supabase Edge Function proxy) ✅ (2026-07-20)
> 2026-08-06 EKİ — **`glm` dalı**: `ai-proxy` artık ÜÇ sağlayıcıya dallanıyor.
> `provider === "glm"` → `OPENROUTER_API_KEY` secret'ı `Authorization: Bearer`
> başlığına konur ve sabit `https://openrouter.ai/api/v1/chat/completions`
> adresine POST atılır (model adı payload'ın içinde, URL'de değil). Dallanma
> sırası `gemini` → `deepseek` → `else (glm)`; `provider` doğrulaması da üçünü
> tanıyor. **Aylık tavan (`MONTHLY_PAGE_CAP`) dallanmadan ÖNCE çalıştığı için
> yeni dala KENDİLİĞİNDEN uygulanır** — ayrıca bir şey yapmak gerekmedi.
> Secret set edildi, fonksiyon deploy edildi ve canlı doğrulandı: geçersiz bir
> `provider` gönderilip dönen hatanın `glm`'i tanıdığı görüldü (OpenRouter'a
> hiç dokunmadan, ücretsiz bir doğrulama).

API anahtarları artık istemcide YOK. Gemini/DeepSeek çağrıları
`GeminiTransport`/`DeepSeekTransport` üzerinden Supabase Edge Function'a
(`supabase/functions/ai-proxy/index.ts`, tek fonksiyon, `provider` alanına
göre dallanır) gidiyor; o da ilgili sağlayıcıya gidip ham cevabı aynen geri
dönüyor. Anahtarlar (`GEMINI_API_KEY`, `DEEPSEEK_API_KEY`) yalnızca Supabase
Secret olarak sunucuda duruyor. İstemcide kalan tek şey `.env`'deki
`SUPABASE_URL`/`SUPABASE_ANON_KEY` — bunlar GİZLİ DEĞİL (Supabase'in
anon/publishable anahtarı tarayıcıda durmak üzere tasarlanmış, gerçek
yetkilendirme Edge Function + RLS'te). Prompt kurma/response parse mantığı
(`GeminiService`/`DeepSeekService`) HİÇ değişmedi, yalnızca transport
katmanı (zaten bu geçiş için ayrılmıştı) değişti.

Kota altyapısı: `kullanim_kota` tablosu (kullanici_id, ay, saglayici,
islenen_sayfa; `supabase/migrations/20260720120000_create_kullanim_kota.sql`)
her başarılı Edge Function isteğinde `kullanim_kota_artir()` RPC'siyle atomik
artıyor. Henüz auth yok, `kullanici_id` = `DeviceIdService`'in ürettiği,
`shared_preferences`'ta saklanan anonim UUID (kullanıcının kendi kararı,
gerçek hesap sistemi gelince taşınacak).

**Aylık sert tavan (2026-07-31'de kodlandı, 2026-08-03'te canlıya alındı):**
DÜZELTME — yukarıdaki "hiçbir istek reddedilmiyor (sınırsız)" artık YANLIŞ.
`ai-proxy/index.ts` artık sağlayıcıya (Gemini/DeepSeek) gitmeden ÖNCE
kullanıcının o ayki (`YYYY-MM`, UTC) toplam `islenen_sayfa` sayacını okuyor;
`MONTHLY_PAGE_CAP` secret'ını aşarsa sağlayıcı HİÇ çağrılmadan 429 dönüyor.
İstemci tarafında değişiklik gerekmedi — 429 zaten
`FlashcardGenerationException.isQuota` üretiyor, pipeline (bkz. "Hata
Yönetimi") bunu görünce işlemi erken durdurup net "kota doldu" mesajı
gösteriyor; bu yeni tavan o mevcut yolu tetikliyor, yeni bir hata yolu değil.
Secret tanımsız/geçersizse tavan devre dışı kalır (fail-open). Değer şu an
**500 sayfa/ay** (`supabase/functions/.env.example` içindeki önerilen
değer — ~$9.50 tipik maliyet, ~$24 tavan maliyet). Secret değişikliği
fonksiyon deploy'u GEREKTİRMİYOR (panelden veya `supabase secrets set` ile
anında etkili), ama fonksiyonun KENDİSİ ilk kez bu kontrolü içerecek şekilde
2026-08-03'te deploy edildi (`npx supabase functions deploy ai-proxy`).

`pdf_cache` tablosu da aynı RLS-kilitli desende (`supabase/migrations/
20260721000000_create_pdf_cache.sql`, `hash`/`generated_cards`/`created_at`)
— yalnızca `pdf-cache` Edge Function'ı (service_role) erişir, istemci
doğrudan hiç dokunmaz. Bkz. "Maliyet Optimizasyonu".

Supabase projesi: "MedKart" (ref `zmwjlchbpiyjzwvkaatu`, eu-central-1).
CANLI DOĞRULANDI (2026-07-20): gerçek bir PDF, Playwright ile UI üzerinden
uçtan uca yüklendi (Flutter web CanvasKit'te `flt-semantics-placeholder`
tıklanarak erişilebilirlik ağacı etkinleştirilip gerçek DOM/text locator'lar
kullanıldı — debug/DDC modu bu ortamda aşırı yavaş kaldığı için `flutter
build web --release` + statik sunucuyla test edildi). Sonuç: istekler
yalnızca `.../functions/v1/ai-proxy`'ye gitti, `generativelanguage.
googleapis.com`/`api.deepseek.com`'a hiç direkt istek atılmadı, 17 yakalanan
istekte hiçbir yerde eski anahtar string'i/`GEMINI_API_KEY`/`DEEPSEEK_API_KEY`
geçmedi. Derlenmiş `build/web` paketinde de statik grep ile aynı doğrulandı.
Bir istek 429 (Gemini günlük kota) aldı, mevcut retry/hata mesajı mantığı
(değişmedi) bunu düzgün karşıladı.

`gemini_service.dart`'taki `_describeHttpError` 401/403/400/404 mesajları
artık ".env dosyandaki GEMINI_API_KEY'i kontrol et" DEMİYOR (kullanıcı artık
o anahtara sahip değil) — sunucu tarafı hata olarak ifade ediliyor.

`pdf-cache` fonksiyonu da DEPLOY EDİLDİ VE CANLI DOĞRULANDI (2026-07-21):
gerçek bir PDF'in hash'ine sahte kartlar seed edilip taze bir cihaz
kimliğiyle aynı PDF yüklendiğinde ağ günlüğünde YALNIZCA `pdf-cache`
isteği görüldü, `ai-proxy` hiç çağrılmadı. Supabase CLI'a interactive
login bu ortamda çalışmıyor (TTY yok) — personal access token
(`supabase login --token ...`, https://supabase.com/dashboard/account/tokens)
gerekiyor, bir dahaki deploy'da önce `supabase projects list` ile mevcut
login durumu kontrol edilmeli.

## Zorunlu Login (Faz 1+2+3 kod tarafı tamam — 2026-08-03 güncellendi)
Plan: Faz 1 = auth iskeleti (TAMAM), Faz 2 = kullanıcı-bazlı tablolar/veri
taşıma (KOD + MIGRATION TAMAM, migration CANLIYA ALINMIŞ — bkz. aşağıdaki
DÜZELTME), Faz 3 = eylem kapısı (TAMAM — bkz. aşağıdaki "Faz 3" bölümü).
(DÜZELTME 2026-07-30: bu bölüm önceden "Faz 3 = zorunlu kapı YOK, login
hiçbir yerde zorunlu değil" diyordu — ARTIK YANLIŞ, kapı kodda ve aktif.)
(DÜZELTME 2026-08-03: bu bölüm önceden Faz 2 migration'ının "HENÜZ DEPLOY
EDİLMEDİ" olduğunu söylüyordu — bu artık YANLIŞ. `npx supabase migration
list --linked` local `20260724000000_create_kullanici_kutuphane.sql`'in
remote'ta eşleştiğini gösterdi VE doğrudan PostgREST'e
`GET /rest/v1/kullanici_kutuphane` isteği 200 + `[]` döndürdü (tablo
olmasaydı 404/PGRST205 dönerdi) — yani tablo canlıda gerçekten var. Bu
oturumda `supabase db push` ÇALIŞTIRILMADI, yalnızca doğrulandı; deploy'u
muhtemelen kullanıcı kendisi, önceki bir oturumda yapmış. İki-cihaz/
gerçek-hesap uçtan uca senkron testi hâlâ yapılmadı, bu hâlâ açık.)

**Faz 3 — "bakmak serbest, yapmak üye" eylem kapısı:** Tam ekran zorunlu
login duvarı DEĞİL. Uygulama girişsiz açılır, gezinme/inceleme (deste listesi,
kart listesi, istatistik, ayarlar, yasal metinler) tamamen serbest; yalnızca
VERİ ÜRETEN / VERİ DIŞARI ÇIKARAN eylemler kapıya tabi.
- Ortak yardımcı: `lib/utils/require_auth.dart` → `requireAuth(context,
  action, {reason})`. Girişliyse `action` hiç UI göstermeden çalışır;
  değilse tam sayfa `AuthScreen(reason: ...)` push edilir ve `action` O AN
  ÇALIŞTIRILMAZ. `AuthScreen` `pop(true)` ile dönerse (giriş başarılı)
  `action` OTOMATİK çalışır — kullanıcı eylemi baştan tetiklemek zorunda
  kalmaz. Vazgeçilirse sessizce dönülür.
- **KURAL: buton/menü öğesi ASLA gizlenmez veya disable edilmez** — görünür
  kalır, yalnızca basılınca kapıdan geçer. Yeni bir giriş-gerektiren eylem
  eklerken bu deseni bozma.
- Testler için `debugRequireAuthSignedInOverride` (bool?) — `null` iken
  (üretimde HER ZAMAN) gerçek `AuthService.currentUser` okunur; widget
  testleri `setUp`'ta `true`/`false` atayıp `tearDown`'da MUTLAKA `null`'a
  döndürür. Kullanan testler: `widget_test`, `deck_list_screen_test`,
  `study_screen_test`, `exam_sim_screen_test`, `card_edit_test`.
- Kapıya tabi eylemlerin TAM listesi (çağrı noktası → reason):
  - Deste oluşturma (`deck_list_screen.dart:29`)
  - "Bugün Çalış" banner'ı ve "En Zayıf Konu Antrenmanı" banner'ı
    (`deck_list_screen.dart:193`, `:233`)
  - Çalışmaya başlama + "Hocanın Favorilerini Çalış"
    (`card_list_screen.dart:73`, `:92`)
  - Kart düzenleme (`card_list_screen.dart:35`, `study_screen.dart:217`)
  - PDF yükleme / kart üretme — hem sürükle-bırak hem dosya seçme
    (`add_cards_screen.dart:96`, `:131`, ortak `_pdfUploadReason` sabiti)
  - "Kendini Test Et" MCQ (`mcq_setup_screen.dart:55`)
  - Deneme sınavı (`exam_sim_screen.dart:97`)
  - Deste PDF dışa aktarma (`card_list_screen.dart:116`)
  - **JSON yedek dışa/içe aktarma** (`settings_screen.dart:56`, `:88`) —
    2026-07-30'da eklendi, bkz. aşağıdaki not.
- **JSON yedekleme kapısı (2026-07-30):** Ayarlar > Veri altındaki "Yedeği
  dışa aktar" / "Yedekten içe aktar" girişsiz kullanılabiliyordu (veri
  açığı) — artık `requireAuth`'a alındı. Desen: `_exportBackup`/
  `_importBackup` yalnızca `requireAuth` çağıran ince sarmalayıcı, asıl iş
  `_runExportBackup`/`_runImportBackup`'ta (mantık değişmedi). Ortak reason
  sabiti `_backupAuthReason` = "Yedek almak/geri yüklemek için giriş yapman
  gerekiyor." Her iki `ListTile` da görünür/tıklanabilir kaldı.
  NOT: JSON import/export ÖZELLİĞİNİN KENDİSİ kaldırılmadı — yalnızca kapıya
  alındı. Kaldırma ayrı bir iş olarak ileriye bırakıldı (kullanıcı kararı).
- `ProfileBubble` (`lib/widgets/profile_bubble.dart`): deste listesinin sağ
  üstünde HER ZAMAN görünen dairesel profil butonu — girişsizken `AuthScreen`'i
  `reason` VERMEDEN açar (o yüzden `AuthScreen.reason` nullable), girişliyken
  hesap bilgisi + "Çıkış Yap" popup menüsü gösterir.

**Faz 2 — bulut senkronu (kod tamam, migration CANLIDA; uçtan uca test
EKSİK):** Giriş yapan
kullanıcının tüm kütüphanesi (desteler+kartlar+SM-2+studyLog, mevcut
`LibraryCodec.toMap/fromMap` formatı AYNEN — yeni format icat edilmedi)
`kullanici_kutuphane` tablosunda (`user_id` PK, `library_data` jsonb,
`updated_at`) saklanır.
- `supabase/migrations/20260724000000_create_kullanici_kutuphane.sql`:
  pdf_cache/kullanim_kota'nın aksine bu tabloya İSTEMCİ DOĞRUDAN erişiyor
  (Edge Function YOK) — RLS `auth.uid() = user_id` policy'leriyle (select/
  insert/update) kilitli, "deny all" değil (çünkü Supabase client oturum
  JWT'sini zaten taşıyor).
- `lib/services/sync_service.dart` (`SyncService`): `downloadLibrary`/
  `uploadLibrary` (hataya dayanıklı, ağ/yetki sorununda sessizce null/no-op)
  + saf `mergeLibraries(local, remote)` — kartlar önce `id` ile, eşleşmeyen
  için (question+sourcePage) ikilisiyle (aynı PDF iki cihazda bağımsız
  işlenirse farklı id üretebilir) eşleştirilir, iki tarafta da varsa SM-2
  bakımından daha ileri olan (repetitions, eşitse nextReview) kazanır;
  desteler aynı isimle birleşir (examDate boş olan taraf diğerinden alır);
  studyLog gün bazlı büyük sayım. Test: `test/sync_service_test.dart` (10 test).
- `lib/state/library_sync_controller.dart` (`LibrarySyncController`):
  `AuthService.authStateChanges`'i dinler, `signedIn` olunca indir→(boşsa
  yükle / doluysa birleştir+lokale yaz+buluta yaz) akışını çalıştırır;
  sonrasında `FlashcardStore`'u dinleyip 8 saniyelik debounce ile buluta
  yazar (`uploadDebounce`). `main.dart`'a `ChangeNotifierProxyProvider` ile
  eklendi; `isSyncing` iken `MaterialApp.builder`'daki `_SyncStatusBanner`
  üstte ince bir "Verilerin senkronize ediliyor..." şeridi gösterir.
  Giriş YAPMAMIŞ kullanıcı hiç etkilenmez (authStateChanges hiç `signedIn`
  atmaz, controller boşta bekler).
- **Migration canlıda (2026-08-03 doğrulandı, yukarıdaki DÜZELTME'ye bkz.).**
  **HENÜZ YAPILMADI:** iki-cihaz/gerçek-hesap uçtan uca senkron doğrulaması
  (aynı hesapla iki farklı cihazdan/tarayıcı profilinden giriş yapıp
  birleşmenin gerçekten çalıştığını görmek) hâlâ yapılmadı.
- Paket: `supabase_flutter` ^2.16.0. `main.dart`'ta `.env`'deki
  SUPABASE_URL/ANON_KEY ile `Supabase.initialize` — env eksik/başlatma
  hatalıysa uygulama YİNE anonim açılır (try/catch, kapı yok).
- E-POSTA AKIŞI = OTP KODU (2026-07-22, magic link/şifreden çevrildi):
  Supabase panelindeki e-posta şablonları {{ .Token }} kullanıyor (kullanıcıya
  6 haneli kod gidiyor). ŞİFRE YOK, kayıt/giriş ayrımı YOK — `signInWithOtp`
  hesap yoksa oluşturur (shouldCreateUser varsayılanı), varsa giriş yapar.
- `lib/services/auth_service.dart` (`AuthService`): `sendOtpToEmail(email)` →
  kod gönderir, `verifyOtp(email, token)` → doğrular/oturum kurar
  (`OtpType.email`); `signInWithGoogle` (OAuth kod tarafı hazır — Google
  client ID Supabase panelinden AYARLANMADI henüz, kullanıcı kendisi
  ayarlayacak), signOut, `currentUser`, `authStateChanges`. Tüm hatalar
  Türkçe mesaja çevrilir (`AuthException.code` switch'i — NOT: Supabase
  YANLIŞ kodu da `otp_expired` olarak raporlar, mesaj iki olasılığı da
  söyler); Supabase başlatılmadıysa her işlem "yapılandırma eksik" döner
  (`isConfigured`). Dönüş tipi `AuthResult` (success + message). Testler
  için `GoTrueClient` enjekte edilebilir.
- `lib/screens/auth_screen.dart` (`AuthScreen`): İKİ ADIMLI akış — (1)
  e-posta gir → "Kod Gönder", (2) 6 haneli kod alanı (büyük/aralıklı, 6.
  rakamda otomatik doğrulama) → "Doğrula"; "Kodu tekrar gönder" 60 sn
  cooldown'lu (`_resendCooldownSeconds`), "E-posta adresini değiştir" ile
  1. adıma dönüş; "Google ile devam et" 1. adımda. Giriş yapılmışsa hesap
  bilgisi + Çıkış Yap. Tema token'larından (sabit renk yok).
- Doğrudan giriş noktaları (eylem kapısından bağımsız, kullanıcı kendi
  isteğiyle giriş yapmak isterse): `ProfileBubble` (deste listesi sağ üst) ve
  Ayarlar > Hesap > "Hesap (deneme)" ListTile'ı. İkincisi Faz 1'den kalma
  geçici bir giriş — hâlâ duruyor, başlığı/alt metni ("test aşamasında,
  zorunlu değil") artık gerçeği yansıtmıyor, temizlenmesi bekleyen küçük bir
  iş. Kodundaki "FAZ 1 ... zorunlu kapı yok" yorumu da bu yüzden eskimiş.
- (DÜZELTME) "Supabase'de kullanıcı-bazlı tablo YOK" iddiası ARTIK GEÇERSİZ —
  `kullanici_kutuphane` tablosu Faz 2'de eklendi (yukarı bkz.) ve migration'ı
  2026-08-03'te canlıda doğrulandı. Açık kalan tek şey iki-cihaz/gerçek-hesap
  uçtan uca senkron testi.

## Bilinmeyen / Henüz Kararlaştırılmamış
- Ödeme/abonelik sistemi — henüz yok. Kota tablosu altyapısı hazır
  (bkz. "Backend mimarisi") ama hiçbir plana bağlı değil.
- Paylaşım/sızıntı sorunu — KISMEN ADRESLENDİ (2026-07-21): bir öğrenci
  aynı PDF'i paylaşırsa artık bu "sızıntı" değil, paylaşılan PDF önbelleği
  sayesinde her iki taraf da avantajlı çıkıyor (ikinci öğrenci API
  kullanmadan anında kart alıyor, kota da harcanmıyor) — bkz. "Maliyet
  Optimizasyonu". Ama üretilmiş KARTLARIN kendisinin (JSON export ile)
  dışarıdan paylaşılıp uygulama dışında dağıtılması hâlâ çözülmedi; bu
  hâlâ açık bir soru, olası çözüm aynı kalıyor: değeri interaktif çalışma
  deneyimine (SRS, istatistik, MCQ) kaydırmak.
- Ses kaydından kart üretme fikri — RAFA KALDIRILDI, şimdilik yapılmıyor.

## Kurallar / Yapma
- Yeni bir ekran eklerken renk/tipografi/spacing'i elle kodlama — her zaman
  `lib/theme/app_theme.dart`'taki token'ları kullan (`Theme.of(context).
  colorScheme.*`/`textTheme.*`, `AppTheme.space*` spacing skalası). 2026-07-20
  tema geçişinde tüm ekranlar bu sayede yeni palete otomatik uydu, tek tek
  dokunmak gerekmedi (bkz. "Tasarım sistemi" notu).
- (DÜZELTME) PDF'i Yol B'ye (tek istek, genel prompt) yönlendirme/PDF için
  Yol B'yi yeniden icat etme — PDF her zaman Yol A'ya (sayfa-bazlı pipeline)
  gitmeli. Yol B'nin kendisi kaldırılmadı, hâlâ metin/görsel girişi için
  aktif ve öyle kalmalı.
- El yazısı bilgisini soru/cevap metnine yazma, sadece isHandwritten flag.
- Kompakt kart dizisinin eleman SIRASINI değiştirme/araya alan ekleme —
  pozisyonlar `kompakt*Index` sabitlerinde tek yerde tanımlı, prompt metni de
  çözücü de oradan besleniyor (bkz. "Kompakt kart çıktı biçimi"). Yeni bir
  alan gerekiyorsa SONA ekle, araya sıkıştırma.
- Modelden kart isterken alan adlı nesne biçimine geri dönme — biçim bilinçli
  olarak kompakt diziye çevrildi (çıktı token maliyeti).
- Günlük hedefi (`StudySettings.dailyGoal`) çalışma kuyruğuna/SRS'e bağlama —
  yalnızca istatistikteki ilerleme halkasını besleyen, opsiyonel bir motivasyon
  aracı (bkz. "İstatistik ekranı ızgara düzeni + Günlük Hedef"). Günlük yeni
  kart limitiyle de karıştırma, ikisi ayrı kavram ve ayrı anahtar.
- Hedef halkasının %100 tavanını kaldırma — `DailyGoalRing.percentFor` bilinçli
  olarak sıkıştırıyor.
- Konu veri yeterliliğini çıplak `repetitions` ile ölçme — hep `TopicStat.
  attempts`/`dataState` (bkz. "Konu başarısı — veri yeterliliği durumları").
  `TopicSuccessBar.showLowDataStates`'i Deneme Sınavı sonuç ekranında da açma.
- İstatistik ekranının gövdesini `ListView`'a geri çevirme — ızgarada
  görünmeyen sütun hiç build edilmiyordu, `SingleChildScrollView` bilinçli.
- Thinking modunu açma (maliyet).
- PDF önbelleğini (`pdf_cache`) sayfa aralığı/konu ile daraltılmış
  çalıştırmalar için kullanma/yazma — yalnızca TÜM PDF işlendiğinde geçerli
  (bilinçli kapsam sınırı, bkz. "Maliyet Optimizasyonu").
- "Hazır/iyi öğrenilmiş kart" için yeni bir ölçüt yazma — hep
  `SrsEngine.isWellLearned` çağır (bkz. o bölüm). Tanımı değiştirmek tempo
  uyarısını ve deste hazırlığını AYNI ANDA etkiler, önce sebep sor.
- Deneme trend grafiğine charting paketi (fl_chart vb.) ekleme — elle
  `CustomPainter` bilinçli tercih (bkz. "Deneme Sınavı / Trend grafiği").
- Öncelikli Mod tercihini (`priorityModeDeckIds`) bulut senkronuna veya
  `LibraryCodec`'e ekleme — bilinçli olarak cihaz bazlı bırakıldı (bkz.
  "Sınav Tempo Uyarısı + Öncelikli Mod"). Değiştirmeden önce sebep sor.
- Giriş gerektiren bir eylem eklerken butonu gizleme/disable etme — görünür
  bırak ve `requireAuth` ile sar (bkz. "Zorunlu Login / Faz 3"). Kapıyı elle
  `AuthService().currentUser` kontrolüyle yeniden yazma, hep `requireAuth`
  kullan (giriş sonrası eylemi otomatik sürdürme mantığı orada).
- Büyük/çok fazlı görevlerde tek seferde her şeyi yapmaya çalışma — aşamalı
  ilerle, her fazda durup rapor ver, onay bekle.
- **Geçici bayrakları (`activeAiProvider`, `kDebugBypassCache`) kullanıcı
  açıkça söylemeden geri alma** — ama oturum başında durumlarını HATIRLAT.
  `kDebugBypassCache` 5 Ağustos'ta açık unutulup önbelleği sessizce devre dışı
  bırakmıştı; bir daha olmasın diye ikisinin de üstünde kutulu GEÇİCİ yorumu
  ve bu dosyanın en başında bir tablo var.
- GLM'de `reasoning` parametresini kaldırma ya da `exclude: true`'ya çevirme —
  `exclude` düşünmeyi kapatmaz, yalnızca gizler; tokenlar yine faturalanır ve
  maliyet ~2 katına çıkar (bkz. "GLM sağlayıcısı"). Testi de silme.
- El yazısı/vurgu için YENİ bir tanım yazma — tanım tek: "slaydın geri
  kalanından farklı, SONRADAN eklenmiş mi?" `elYazisiKurali` ve
  `metinVeGorselBirlikteKurali` bu ayrımı birlikte taşıyor ve birbirine atıf
  yapıyor; birini değiştirirsen diğerini de hizala.
- Yol B'nin "5-20 kart" cümlesini alt sınır gibi yeniden yazma — kaynak
  eğitim içeriği değilse boş dizi dönmesi bu sayının ÖNÜNDE gelir (v22).
- `flutter run` çıktısında `[GLM …]`/`[GEMINI …]` satırı arama — `print()`
  Flutter web'de tarayıcı konsoluna gider (bkz. "ortam notları").
- Node gerektiren komutları `!` ile açılan bash kabuğunda çalıştırma — o kabuk
  Windows kullanıcı PATH'ini görmüyor; PowerShell aracıyla PATH'i başa ekle.
