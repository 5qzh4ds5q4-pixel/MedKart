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
doğrulandı; 2026-08-14'te kullanıcı talimatıyla `flashcard_prompt.dart`'a
> yeni bir `kaynakReferansiGizlemeKurali` bloğu eklendi (v25→v26) — bu, o
> ana kadar `guncellikDiliYasagiKurali`'nın (v18, 2026-08-05) "güncellik
> dilinden kaçınmak için kaynağa atıf yap ('slayta göre' vb.)" tavsiyesiyle
> DOĞRUDAN ÇELİŞİYORDU; çelişki kodu okurken fark edildi ve o tavsiye
> KALDIRILARAK "çözüldü" — ama bu YANLIŞ bir düzeltmeydi: kullanıcı AYNI
> oturumda geri bildirdi, tedavi/kılavuz bilgisinde "slayta göre" bir stil
> tercihi değil, eski kaynaktan gelen tedavi bilgisinin kesin gerçekmiş gibi
> sunulmasını önleyen bir GÜVENLİK ÖNLEMİ. v27'de doğru çözümle düzeltildi:
> tavsiye GERİ GETİRİLDİ, `kaynakReferansiGizlemeKurali`'ne bir İSTİSNA
> maddesi eklendi (ayrım ölçütü: tedavi/doz/kılavuz gibi zamanla değişebilen
> bilgi mi, yoksa tanım/anatomi/patofizyoloji gibi stabil bilgi mi) — artık
> iki kural ÇAKIŞMIYOR, KAPSAMLARI AYRIK (bkz. "Kart Üretim Kuralları").
> CANLI ÖLÇÜLMEDİ. Yine de kod
> değiştikçe eskiyebilir — şüphelendiğin bir iddiayı grep ile hızlıca
> doğrula ve bu dosyayı güncelle; 2026-08-17'de İstatistik ekranı
> (`stats_screen.dart`) kullanıcı taslağına göre baştan tasarlandı — 2026-08-04
> tarihli kart-ızgara düzeni TAMAMEN kaldırıldı, yerine en üstte TEK dominant
> "bugünkü odak" kartı (`FlashcardStore.weakestTopicInfo`, yeni bir hesap
> İCAT EDİLMEDİ) + altında varsayılan KAPALI katlanabilir satırlar
> (`ExpansionTile`) geldi; bu değişiklik `daily_goal_test.dart`,
> `study_stats_test.dart`, `review_forecast_test.dart`,
> `exam_trend_chart_test.dart`, `deck_readiness_test.dart` içindeki
> testleri kırdı (bölüm içerikleri artık satır önce AÇILMADAN görünmüyor) —
> hepsi satırı açan bir `tester.tap` eklenerek düzeltildi, artı yeni
> `stats_screen_test.dart` (9 test) eklendi; paket 667/667'den **675/675
> yeşil**'e çıktı (bkz. "Devam Eden İş" 0.8); aynı günün ilerleyen
> saatlerinde (ayrı bir görev) kod tabanındaki gerçek parametreler
> (model/fiyat/`maxOutputTokens`/`thinkingBudget`/prompt uzunlukları —
> prompt uzunlukları geçici bir `dart run` script'iyle GERÇEKTEN ÖLÇÜLDÜ,
> tahmin edilmedi) üzerinden kapsamlı bir Gemini maliyet mühendisliği
> raporu çıkarıldı; hiçbir gerçek API çağrısı yapılmadı, ayrıntı ve tüm
> ara hesaplar "Maliyet" bölümündeki yeni alt başlıkta. Aynı oturumun
> devamında (1) sol sidebar'daki "Destelerim" ilk kez KENDİ ekranını aldı
> (`DeckLibraryScreen` — sade liste; öncesinde "Ana Sayfa" ile birebir aynı
> şeyi yapıyordu) ve deste eylemleri/menüsü `DeckActions`+`DeckActionMenu`'ye
> çıkarılarak `deck_list_screen.dart`'taki İKİ kopya menü teke indi
> (675→684 test); (2) maliyet raporunun devamı olarak bir düşürme planı
> çıkarıldı ve **tek risksiz maddesi UYGULANDI** — `buildPagePrompt`'un
> açılış cümlesindeki `(sayfa $pageNumber)` kaldırılarak prompt ön eki
> 134 karakterden 22.575 karaktere çıkarıldı (Gemini örtük context cache
> eşiği: 4.096 token), `kPromptVersion` v27→**v28**; aynı anda
> `usage_metadata.dart` eklenerek token/cache ölçümü İLK KEZ mümkün oldu
> (kullanıcının talimatı: "loglamayı 1. adımdan ayırma, yoksa kör
> optimizasyon olur"). Ardından kod okumasıyla DOĞRULANDI ki **v28 tek
> başına üretimdeki varsayılan (görselli) akışta cache'i AÇMIYOR** — görsel
> parçası 0. pozisyonda ve her sayfada değişiyor; görsel sırası BİLİNÇLİ
> OLARAK değiştirilmedi (canlı A/B ister). Bkz. "Context caching" bölümü;
> test 675→**695**, `flutter analyze` baseline 90→**92** (DÜZELTME 2026-08-18:
> bu sayı eskidi, proje geneli baseline ölçüldü ve **120** (2026-08-19'da yeniden ölçüldü: **130** — artış yine `tool/` script'lerinden) — artış 10 Ağustos
> sonrası eklenen `tool/` script'lerinden geliyor, bu oturumun değişiklikleri
> 0 yeni uyarı ekledi) (yalnızca yeni dosyadaki `avoid_print`). Aynı günün
> ilerleyen saatlerinde Gemini'ın
> "Flex" service tier'ı (`serviceTier: FLEX`) maliyet kaldıracı olarak
> değerlendirildi ve REDDEDİLDİ — mevcut mimari kod okunarak incelendi:
> kart üretimi tamamen senkron/kullanıcı-bekletmeli (`PdfImportScreen`,
> "pencereyi açık tut" UX, `PopScope(canPop: !_running)`), tek istek
> timeout'u sabit 120sn (`GeminiTransport.defaultRequestTimeout`) ve
> timeout'lar BİLİNÇLİ olarak retry edilmiyor (çift faturalama riski,
> bkz. "Hata Yönetimi"). Flex'in 1-15 dakikalık belirsiz gecikmesi bu
> mimariyle uyumsuz. Ayrıntı ve yeniden değerlendirme koşulu "Bilinmeyen /
> Henüz Kararlaştırılmamış" bölümünde; 2026-08-19'da `pdf_cache`'teki 733
> gerçek kart üzerinden `zorlukKurali` ile `sinavTipiKurali`'nin çakışması
> İLK KEZ SAYISAL OLARAK ölçüldü — `zor` etiketi `sinav`'ın TAM ALT KÜMESİ
> çıktı (P(sinav|zor)=%100, beş prompt sürümünde ayrı ayrı) ve
> `zorlukKurali`'nin tek bağımsız dalı olan "formül/sayısal hesap" 733 kartta
> HİÇ tetiklenmemişti; prompt'a DOKUNULMADI, bulgu kaydı olarak yeni bir
> bölüme yazıldı (bkz. "`zorlukKurali` × `sinavTipiKurali` ÇAKIŞMASI"); aynı
> gün `CardFilter.examOnly`'nin ARAYÜZ tarafı incelenirken o bölümdeki bir
> sayı YANLIŞ çıktı (predicate `||` iken `&&` sanılmıştı: Sınav Modu 129 değil
> **607/733** kart tutuyordu) — düzeltme kalıcı kayıt olarak bölümün içine
> işlendi, ve aynı incelemede switch'in "Zor" zorluk çipi seçiliyken kart
> kümesine ETKİSİNİN SIFIR olduğu ölçülünce kullanıcı talimatıyla
> **"Sınav Modu" switch'i `StudyScreen`'den TAMAMEN KALDIRILDI**
> (`CardFilter.examOnly` alanı modelde bilinçli olarak BIRAKILDI, üretim/
> etiketleme katmanına dokunulmadı, 737→734/734 test yeşil — bkz. "Sınav Modu
> switch'i KALDIRILDI").

## Ne yapıyor bu uygulama
Tıp öğrencileri için AI destekli flashcard (çalışma kartı) uygulaması.
Öğrenci ders slaytı (PDF) yükler → sistem otomatik, sayfa sayfa işleyip
spaced-repetition çalışma kartı üretir. Hedef kitle: komite sınavına
hazırlanan tıp fakültesi öğrencileri.

## Devam Eden İş — KALDIĞIMIZ YER (2026-08-17)
> Yeni oturumda ÖNCE burayı oku. Bitince bu bölümü güncelle/temizle.

### 0.9. MALİYET ARAŞTIRMASI — KAPANDI, LAUNCH'I BLOKLAMIYOR (2026-08-17)
> Bu konuyu tekrar açmadan önce buradaki dört maddeyi oku. Ayrıntılı denetim
> raporu: [Maliyet Optimizasyonu Denetimi](https://claude.ai/code/artifact/b2242e76-52c9-4277-977e-58f1af8e0d2d)
> (ölçüm dökümü, çürütülen hipotezler, reddedilen kaldıraçlar).

- **v28 KALDI, v29 (systemInstruction) GERİ ALINDI.** Gemini'ın örtük
  (implicit) context cache'i **inline görsel taşıyan isteklerde HİÇ devreye
  girmiyor**. Sorunun kaynağı görselin **KONUMU DEĞİL, VARLIĞI** — bu iki
  bağımsız canlı ölçümle kanıtlandı (statik bloğu `systemInstruction`'a
  taşımak da, görseli `contents`'in sonuna almak da cache'i açmadı; dört
  çağrının hepsinde `cache=YOK`). Dolayısıyla "parça sırasını değiştir" ve
  "systemInstruction'a taşı" seçeneklerinin İKİSİ DE ÖLÜ. v28 (prompt ön
  ekinin sabitlenmesi) kodda kaldı ve görselSİZ yolda çalışıyor (%12,6
  tasarruf), ama o yol üretimin varsayılanı değil.
- **`pdf_cache` isabet oranı sorgulandı: geçmiş veri %40 gösteriyor AMA
  ÖRNEKLEM ANLAMSIZ** (yalnızca ~10 lookup, 6 gerçek PDF). Üstelik bayatlık
  kapısı devreye girdiği için **şu an itibarıyla efektif isabet oranı %0** —
  6 kaydın 6'sı da v27 eşiğine göre bayat (null×2, v16×2, v23, v24). Kayıtlar
  PDF'ler yeniden yüklendikçe v28 ile ezilerek tazelenecek. Bu beklenen ve
  kasıtlı; %40'lık geçmiş oran ŞU AN GEÇERLİ DEĞİL, plan yaparken kullanma.
- **Açık (explicit) cache denemesi ASKIDA.** Launch sonrasına, gerçek trafik
  birikince tekrar değerlendirilecek. Şimdi yapmanın anlamı yok: örtük cache
  multimodal'de hiç çalışmadığına göre açığın çalışacağı garanti değil,
  ayrıca `ai-proxy` yalnızca `:generateContent`'e proxy'lediği için
  **denemenin kendisi bile fonksiyon değişikliği + deploy gerektiriyor**.
- **MALİYET KONUSU LAUNCH'I BLOKLAMIYOR.** Öncelik sırası artık: (1) config
  doğrulaması, (2) domain + Resend'e kayıt. Maliyet çalışması bu ikisinden
  SONRA gelir.

### 0.8. İstatistik ekranı — dominant "bugünkü odak" kartı + katlanabilir satırlar (2026-08-17)
Kullanıcının verdiği bir taslağa göre (`stats_screen.dart` içindeki
2026-08-04 tarihli kart-ızgara düzeni TAMAMEN retire edildi) ekran baştan
kuruldu:
- **En üstte TEK dominant kart** (`_FocusCard`): `FlashcardStore.
  weakestTopicInfo` (deck_list_screen'deki "En Zayıf Konu Antrenmanı" ile
  AYNI kaynak — yeni bir hesap İCAT EDİLMEDİ) + aynı konunun `topicStats`
  içindeki `successPercent`'i (bu da yeni bir hesap değil, var olan listeden
  okunuyor). "BUGÜN İÇİN" rozeti + "$konu konusuna odaklan" başlık + "%X
  başarı · Y kart" + "Antrenmana başla" butonu (`requireAuth` ile sarılı,
  basılınca `StudyScreen(filter: CardFilter(topics: {konu}), ignoreDueDate:
  true)` açar — deck_list_screen'deki `_LightWeakestTopicCard`'ın AYNI
  navigasyon deseni). `weakestTopicInfo` null ise (güvenilir veri yok, bkz.
  `SrsEngine.weakestReliableTopic` eşikleri) `_FocusEmptyCard` düşer: "Çalışmaya
  başladığında burada görünecek." Ekrandaki TEK amber vurgusu bilerek bu
  kartta (`colorScheme.primary`); alttaki satırlar nötr.
- **Altında varsayılan KAPALI katlanabilir satırlar** (`_CollapsibleRow`,
  ham `ExpansionTile` — `shape`/`collapsedShape` saydam yapılıp KART
  görünümü BİLEREK engellendi, ayraç `_CollapsibleSectionList` tarafından
  satırlar ARASINA 0.5px `Divider` olarak ekleniyor): "Genel özet" (eski 4
  metrik kartı, `_MetricRow`/`_StatCard`/`_TodayCard`/`_CardGrid` İÇERİK
  olarak DEĞİŞMEDİ), "Çalışma takvimi" (`StudyHeatmap`), "Deste hazırlığı"
  (`_DeckReadinessBar` listesi, boşsa satır hiç yok), "Deneme sınavı trendi"
  (`ExamTrendChart`, `ExamTrendChart.shouldShow` false ise satır hiç yok),
  "Konu başarısı" (`TopicSuccessBar` listesi / `_EmptyTopics`),
  "Önümüzdeki 7 gün" (`ReviewForecastChart`, kart yoksa satır hiç yok).
  Kapalıyken görünen özet metni her satırın header'ında (`ExpansionTile.
  subtitle`) — ör. "2 günlük seri · 164 tekrar", "Son puan %70", "Tüm
  konular · 9 konu" — hepsi ZATEN hesaplanmış verilerden okunuyor, YENİ bir
  hesap yok (deneme trendinde "son puan" = `examResults.first.percent`,
  liste en yeniden en eskiye sıralı olduğu için `.first` = son sınav; deste
  hazırlığında "en düşük %X" = `deckReadiness.first.readyPercent`, liste
  zaten en düşük hazırlıktan başlıyor).
- **BİLİNÇLİ OLARAK EKLENMEDİ — "Bugün İçin Özet" kartı:** kullanıcının
  isteğinde katlanabilir satırlar arasında sayılmıştı ama bu kart HİÇ
  kodlanmamıştı (bkz. eski "İstatistik ekranı yeniden tasarımı — FAZ 1
  BİTTİ, FAZ 2 SÜRÜYOR" notu, "YAPILMADI" listesinin 1. maddesi — bugünkü
  tekrar yükü/odaklanılacak konu/başlanmamış konu için üç ayrı hesap
  gerekiyor). "Yeni bir hesap İCAT ETME" talimatıyla DOĞRUDAN çelişeceği
  için bu satır eklenmedi; ileride istenirse önce o üç hesabın nereden
  geleceği netleştirilmeli.
- **Kırılan testler düzeltildi (5 dosya):** `daily_goal_test.dart`
  (7 test + "dar ekranda bölümler tek sütuna düşer" testi SİLİNDİ — ızgara
  kavramı retire olunca test edilecek bir "kırılma noktası" kalmadı),
  `study_stats_test.dart`, `review_forecast_test.dart` (2 test),
  `exam_trend_chart_test.dart` (1 test), `deck_readiness_test.dart`
  (1 test) — hepsinde aynı desen: içerik artık `ExpansionTile` altında
  gizli olduğu için `_pumpStats`'tan sonra ilgili satır başlığına
  `tester.tap` + `pumpAndSettle` eklendi. **Yeni `test/stats_screen_test.dart`
  (9 test)**: dominant kart var/yok davranışı, "Antrenmana başla" girişli/
  girişsiz akışı (`requireAuth`), satırların varsayılan kapalı başlaması,
  bir satıra dokununca YALNIZCA o satırın açılması, tekrar dokununca
  kapanması. Paket **667 → 675/675 yeşil**, `flutter analyze` bu dosyalarda
  **0 yeni uyarı** (proje geneli baseline 90 aynı kaldı).
- **Tarayıcıda DOĞRULANMADI** — bu oturumda yalnızca `flutter analyze` +
  `flutter test` ile doğrulandı, gerçek tarayıcıda ekran görüntüsü
  ALINMADI (Chrome uzantısı bu oturumda bağlı değildi). Sonraki oturumda
  önce bunu dene — özellikle `_FocusCard`'ın amber kenarlık/gölge/rozet
  görünümü ve katlanabilir satırların açılış animasyonu göz kararı.

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
- **KAPSAM KAYDI (2026-08-18): bu ret KART ÜRETİMİ içindir, "flash-lite'ı
  hiçbir yerde kullanma" demek DEĞİLDİR.** Aynı gün `TopicScanService` (PDF
  konu ön-taraması) bilinçli olarak flash-lite'a alındı — orada istenen şey
  kart derinliği değil, kısa metin örneklerinden konu başlığı çıkarmak; yani
  bu retin dayandığı "yüzeysel/tanım-düzeyi kart üretme" sorunu o işi
  etkilemiyor. Bkz. "Konu ön-taraması (`TopicScanService`)". İkisini
  "tutarlılık" adına tek modele çekme.

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
  etiketi alır (2026-08-19'a kadar Sınav Modu switch'i bunları gizliyordu;
  switch kaldırıldı ama etiket ÜRETİLMEYE DEVAM EDİYOR — `dailyQueue`
  sıralaması ve Öncelikli Mod hâlâ kullanıyor). Yalnızca Yol B'nin genel
  prompt'unda ayrı bir sınır var: "en fazla 1-2 kart temel tanım düzeyinde
  olabilir" (saf tanım/hatırlama kartı SAYISINI kısıtlar, arkaPlan
  etiketiyle karıştırılmamalı).
- ~~Zorluk kalibrasyonu (`zorlukKurali`)~~ — **2026-08-20'de (v31) TAMAMEN
  KALDIRILDI**, bkz. "`zorlukKurali` KALDIRILDI" bölümü. Model artık kompakt
  dizinin [3]. pozisyonuna HER ZAMAN `"o"` yazıyor; zorluk yalnızca
  `SrsEngine.deriveDifficulty` ile çalışma performansından türetiliyor.
  Pozisyon KORUNDU (silinmedi/kaydırılmadı).
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
- **`guncellikDiliYasagiKurali` (2026-08-05, HER İKİ YOL — 2026-08-14'te v27'de
  DÜZELTİLDİ):** kart metni güncellik/otorite iddiası taşıyamaz — "güncel
  kılavuzlara göre", "günümüzde kabul edilen", "birinci basamak/standart
  tedavi" gibi ifadeler YASAK; yerine kaynağa atıf yapan bir dil kullanılır:
  "slayta göre", "bu kaynakta belirtildiği üzere", "kaynakta vurgulanan".
  Sebep: kaynak slayt eski olabilir, kart onun adına güncellik iddiası
  üstlenmemeli — **tedavi/kılavuz bilgisinde "slayta göre" bir stil tercihi
  DEĞİL, eski/güncel-olmayan bir kaynaktaki tedavi bilgisini kesin bir
  gerçekmiş gibi sunmayı önleyen bir GÜVENLİK ÖNLEMİDİR.**
  **TARİHÇE (v26→v27 dalgalanması):** v26'da bu "kaynağa atıf yap" tavsiyesi
  aşağıdaki `kaynakReferansiGizlemeKurali` ile çeliştiği gerekçesiyle
  KALDIRILMIŞTI — bu YANLIŞ bir düzeltmeydi (kullanıcı aynı gün geri bildirdi).
  v27'de tavsiye GERİ GETİRİLDİ, çakışma `kaynakReferansiGizlemeKurali`'ne
  eklenen bir İSTİSNA maddesiyle çözüldü (aşağı bkz.) — artık iki kural
  ÇAKIŞMIYOR, KAPSAMLARI AYRIK. NOT: el yazısı kuralındaki "kaynağa atıf
  YASAK" ile karıştırma — o, bilginin NEREDEN geldiğini (el yazısı/görsel)
  söylemeyi yasaklar; bu kural TAM TERSİNE tedavi/kılavuz bağlamında kaynağa
  atfı ZORUNLU kılar.
- **`kaynakReferansiGizlemeKurali` (YENİ, 2026-08-14, kullanıcı talimatıyla,
  HER İKİ YOL, v26'da eklendi + v27'de İSTİSNA maddesiyle düzeltildi):** kart
  metninin HİÇBİR ALANINDA (soru kökü, şıklar, açıklama/cevap) kaynağa atıf
  yapan ifade KULLANILAMAZ — "slayta göre", "slaytta belirtildiği gibi",
  "kaynağa göre", "verilen bilgiye göre", "yukarıdaki tabloya göre", "tabloda
  belirtilen", "sunuma göre", "derse göre" ve benzerleri KESİN YASAK. Bilgi
  her zaman slayttaki içeriğe dayanır (bu değişmedi), yalnızca metinde
  bağımsız bir tıbbi olgu gibi sunulur.
  **İSTİSNA (v27, `guncellikDiliYasagiKurali` ile çakışmayı gidermek için
  eklendi):** bu kural TEDAVİ/KILAVUZ/GÜNCEL PRATİK içeren kartlara
  UYGULANMAZ — o alan tamamen `guncellikDiliYasagiKurali`'nin kapsamında ve
  orada "slayta göre" ZORUNLU. Ayrım ölçütü: bilgi zamanla değişebilir mi
  (tedavi, doz, birinci basamak seçimi, kılavuz önerisi) yoksa stabil/
  mekanizma bilgisi mi (tanım, anatomi, patofizyoloji, bulaş yolu gibi
  zamanla değişmeyen bilgi)? İlki `guncellikDiliYasagiKurali`'ye (atıf
  ZORUNLU), ikincisi bu kurala (atıf YASAK) girer.
  El yazısı kuralındaki dar "el yazısı/görselde" atıf yasağından FARKI: bu
  kural GENEL, kaynak türünden bağımsız HER ifadeyi kapsar (tedavi/kılavuz
  istisnası hariç). **CANLI ÖLÇÜLMEDİ.** `kPromptVersion` v25→v26→**v27**.
- **`ornekTabanliKartKurali` (YENİ, 2026-08-18, kullanıcı talimatıyla, HER İKİ
  YOL, v30):** kaynakta bir kavramın TANIMININ YANINDA somut örnek(ler)
  veriliyorsa (ör. "neoantijen: X mutasyonu, Y mutasyonu"), o kavram için
  tanım kartına **EK OLARAK** (onun YERİNE değil) bir örnek/uygulama kartı da
  üretilir. Örnek kart düz tanımı TEKRAR SORMAZ — verilen örneği ya da ona
  benzer YENİ bir senaryoyu kullanıp öğrencinin kavramı TANIYABİLDİĞİNİ /
  UYGULAYABİLDİĞİNİ test eder. Prompt'ta yanlış/doğru örnek çifti var
  ("Neoantijen örnekleri nelerdir?" YANLIŞ ↔ KRAS mutasyonu senaryosu DOĞRU).
  - **EN KRİTİK MADDE:** kaynakta kavramın yanında HİÇ somut örnek yoksa bu
    kart tipi ÜRETİLMEZ. Uydurulmuş bir "örnek" kaynak sadakatinin ihlalidir
    ve prompt bunu açıkça "örnek kart üretmemekten çok daha ciddi bir hata"
    diye niteler.
  - **`sinavTipiKurali` ile ÖRTÜŞEBİLİR ama aynı değil:** o kural KLİNİK/
    patolojik ilişkiler için hasta senaryosu ister; bu kural kaynakta ZATEN
    VERİLMİŞ somut örnekler için (klinik olsun olmasın — mutasyon/ilaç/tür
    adı) tanıma-uygulama kartı ister. Klinik bir örnekte ikisi aynı kartta
    buluşabilir. **Bu çakışma BİLEREK ARBİTRE EDİLMEDİ** — prompt'a "ikisinden
    birini seç" gibi bir hakem cümlesi EKLENMEDİ, çünkü v26'da iki kuralı
    "tutarlı hale getirme" girişimi yanlış çıkmıştı (bkz.
    `kaynakReferansiGizlemeKurali` TARİHÇE notu). Çıktıda ikiz kart görürsen
    ÖNCE ÖLÇ, sonra hakem cümlesi ekle.
  - Prompt maliyeti: +988 karakter ≈ **+323 token/istek** (her iki yolda da).
  - **✅ A/B İLE CANLI ÖLÇÜLDÜ (2026-08-18) — KURAL FAZLALIK ÜRETMİYOR.**
    Şüphe şuydu: kural, `sinavTipiKurali` ile örtüşüp "aynı bilgiyi iki kez
    soran" kart üretiyor olabilir mi? Kontrollü deney kuruldu
    (`tool/ab_ornek_kurali_test.dart`, pakete dahil DEĞİL): aynı PDF, aynı
    sayfalar, aynı model/config; TEK fark bu bloğun prompt'ta var/yok olması.
    80 gerçek çağrı, ölçülen maliyet **$1,32**.
    - Üretimde fazlalık üreten sayfalarda: kural YOKken **%34,7**, VARken
      **%32,7** — yani kural kaldırılınca fazlalık DÜŞMÜYOR. Kart sayısına
      etkisi de ihmal edilebilir (147 → 150).
    - Kuralın gerçek etkisi küçük ama DOĞRU yönde: senaryo/uygulama metni
      içeren kart payı %25,9 → **%28,7**.
    - **FAZLALIĞIN ASIL KAYNAĞI BAŞKA, ve v30'dan ESKİ:** (1) sıfır metinli,
      görsel-ağırlıklı sayfalar (üretimdeki en büyük iki katkı: s.10 → 8 kart,
      s.20 → 6 kart; metin-only test bunları yapısal olarak kapsayamıyor,
      HÂLÂ ÖLÇÜLMEDİ), (2) **`sinavTipiKurali`'nin koşulsuz "EK olarak
      MUTLAKA" ifadesi** — kuralın hiç olmadığı arm'da bile 9 tanım+senaryo
      çifti oluştu.
    - **KARAR: bu kurala DOKUNMA.** Kırpmak fazlalığı düşürmez, yalnızca
      uygulama kartlarını kaybettirir. Ayrıntılı döküm:
      `SYSTEM_STATE_2026-08-18.md` §7.1b.
    - **METODOLOJİ UYARISI:** ilk turda "metni en uzun sayfalar" seçilmişti ve
      iki arm da ~%6 çıkıp "fark yok" gibi göründü — ama o sayfalar üretimde de
      yalnızca %3,5 fazlalık gösteriyordu, yani olgu ORADA HİÇ YOKTU. Bu tür
      A/B'lerde örneklemi, olgunun GERÇEKTEN görüldüğü sayfalardan al.
  - Test: `test/ornek_tabanli_kart_kurali_test.dart`
    (8 test — kural metni, iki yola da girdiği, Yol A'da statik cache bloğunda
    durduğu). `kPromptVersion` v28→**v30** (v29 ATLANDI, aşağı bkz.).

## ✅ `zorlukKurali` KALDIRILDI (2026-08-20, prompt v31) — A/B ile karar verildi
> Aşağıdaki 2026-08-19 çakışma ölçümünün SONUCU. O bölüm "karar verilmedi"
> diyordu; **karar verildi ve uygulandı.** Kuralı geri eklemeden önce ikisini
> de oku.

**NE YAPILDI (`lib/services/flashcard_prompt.dart`):**
- `zorlukKurali` bloğu ve HER İKİ YOLDAKİ (`buildGeneralPrompt` +
  `buildPageSystemInstruction`) enjeksiyonu kaldırıldı. Yerinde uzun bir
  gerekçe yorumu duruyor — silme.
- **Kompakt dizinin [3]. pozisyonu KORUNDU** (silinmedi/kaydırılmadı,
  "pozisyon sabit" kuralı gereği). Talimat basitleşti: *"HER ZAMAN 'o' yaz.
  Bu alan artık kullanılmıyor…"*. `BİÇİM ÖRNEĞİ`'ndeki `"z"` de `"o"` yapıldı
  (yoksa örnek talimatla çelişirdi).
- `zorlukKurali`'ye atıf yapan İKİ cümle temizlendi: `etiketlemeSonHatirlatmasi`
  ("derinlik" hatırlatması) ve Yol A'daki "ÖNEMLİ AYRIM" maddesi.
  **`sinavTipiKurali` atıfları KASITLI OLARAK BIRAKILDI** — o kural bu adımda
  kaldırılmadı (TUS eklentisi mimarisinin ayrı işi).
- `kPromptVersion` v30→**v31**, `kMinCacheablePromptVersion` 30→**31**
  (etiket değişikliği içerik değişikliğidir: v30 kayıtları hâlâ `kolay`/`zor`
  etiketli kart taşır, v31 hepsini `orta` doğurur).

**GEREKÇE — A/B ile ölçüldü** (`tool/ab_sinavtipi_kurali_test.dart`, pakete
dahil DEĞİL; 60 gerçek çağrı, **$0,67**, görselsiz, 3 arm × 10 sayfa × 2 tekrar):

| Arm | Kart | zor | sinav tipi |
|---|---:|---:|---:|
| `B_v30` (o günkü üretim) | 123 | **11 (%8,9)** | %23,6 |
| `A_sinavsiz` (yalnız `sinavTipiKurali` çıktı) | 95 | **1 (%1,1)** | %8,4 |
| `C` (+ `icerikKalitesiOrnegi` de çıktı) | 96 | **0 (%0,0)** | %1,0 |

- B vs A: p=0,011; B vs C: p=0,003 (iki oran z-testi). Tekrarlar tutarlı.
- **EN SERT TEST — s.14 formül sayfası:** kaynağın literal formül slaydı
  (enfektivite/patojenite/fatalite hızı), yani `zorlukKurali`'nin tek BAĞIMSIZ
  dalı ("formül/sayısal hesap") için elimizdeki en uygun zemin.
  **B: 2/10 zor · A: 0/8 · C: 0/13.** En uygun zeminde bile, `sinavTipiKurali`
  olmadan kural tek bir `zor` üretemedi.
- **Örneklem üretim kanıtıyla seçildi** (rastgele/en-uzun DEĞİL): `pdf_cache`
  kaydı sayfa sayfa çözülüp yalnızca üretimde ZATEN `zor`/vinyet üretmiş VE
  metni yeterli sayfalar alındı — seçilenlerde üretim zor oranı %19,7, PDF
  geneli %8,0. Metni görselde olan yüksek-vinyet sayfalar (s.37/31/35/39)
  bilinçli ELENDİ (görselsiz ölçümde iki arma da boş sayfa giderdi).
- **P(sinav|zor)=%100 bu A/B'de de çıktı** (her armda istisnasız) — kapsanma
  artık iki bağımsız veri setinde, farklı model ve prompt sürümünde doğrulanmış.
- **YAN ÖLÇÜM — kart hacmi:** kural yokken çağrı başına kart 6,2 → 4,8
  (**−%22**), üç armda da 0 boş çağrı. Bu, komite/TUS ayrımının ürün tarafını
  ilgilendiriyor (ücretsiz katman ~%22 daha az kart alacak) — ama v31 TEK
  BAŞINA bu düşüşü YAPMAZ: ölçülen düşüş `sinavTipiKurali` kaldırılan armlara
  ait ve **o kural hâlâ prompt'ta.**

**BİLİNÇLİ KABUL EDİLEN SONUÇ — `initialEase` artık hep 2.5:**
`CardDifficulty.parse` tanınmayan/sabit kodu `orta`ya düşürdüğü için YENİ
üretilen her kart `orta` doğuyor ve `SrsEngine.initialEase` hep 2.5'ten
başlıyor (eskiden zor→2.3 / kolay→2.6). **AI'ın zorluk sezgisi artık SRS
zamanlamasına HİÇ girmiyor.** Bu bir bug değil, kabul edilmiş bir kayıp: o
sezgi ölçümde `sinavTipiKurali`'nin gölgesi çıktı ve zaten kartın 2.
tekrarında `deriveDifficulty` tarafından üzerine yazılıyordu.
**`initialEase`'in üç dalı da KORUNDU** — v31 ÖNCESİ kartlar ve kullanıcının
elle ayarladığı (`difficultyManual`) kartlar hâlâ o yoldan geçiyor; switch'i
"nasılsa hep orta" diye sadeleştirmek onların davranışını sessizce değiştirir.

**NE DEĞİŞMEDİ:** `CardDifficulty` enum'u, kart listesindeki zorluk çipleri,
`deriveDifficulty`, `difficultyManual`, `EditCardDialog`'daki elle zorluk
ayarı, PDF export'taki zorluk dağılımı — hepsi duruyor. Değişen tek şey,
zorluğun ÜRETİM ZAMANINDA tahmin edilmemesi.

**TESTLER:** paket **734/734 yeşil**. İki test güncellendi, ikisi de sürüm
sabitleyen testler: `ornek_tabanli_kart_kurali_test.dart` (v30→v31) ve
`prompt_version_gate_test.dart` (eşik 30→31, `v30` artık isabet SAYILMIYOR).
`gemini_service_test.dart`'taki ortak biçim satırı da yeni [3] talimatına
güncellendi. **Davranışsal hiçbir test kırılmadı** — zorluk üretimini test
eden ayrı bir test zaten yokmuş.

**`flutter analyze`:** değişen 5 üretim/test dosyasında **0 uyarı**. Proje
geneli baseline 130 → **141**; artışın TAMAMI yeni `tool/ab_sinavtipi_kurali_
test.dart`'tan (10 `avoid_print` + 1 `invalid_use_of_visible_for_testing_member`)
— mevcut `tool/ab_ornek_kurali_test.dart` da aynı deseni taşıyor (10 uyarı),
yani yeni bir regresyon DEĞİL, `tool/` script'lerinin bilinen maliyeti.

**✅ CANLI ÜRETİMDE DOĞRULANDI (2026-08-20, aynı gün).**
`tool/verify_v31_test.dart` — elle prompt kurmaz, DOĞRUDAN
`GeminiService.generateForPage`'i çağırır (yani üretimin kendi yolu:
`buildPagePrompt` + `responseSchema` + `flashcardFromItem` çözücüsü).
6 gerçek sayfa, **40 kart**, ölçülen maliyet **$0,0955**. Girdi: aynı bulaşıcı
hastalıklar PDF'i (s.4 düz tanım, s.14 formül sayfası, s.17/24/27/28 klinik).

| Ölçülen | Sonuç |
|---|---|
| Zorluk dağılımı | **kolay=0 · orta=40 · zor=0** — istisnasız |
| Kart tipi | **sinav=9 (%22,5)** · temel=31 — `sinavTipiKurali` ÇALIŞMAYA DEVAM EDİYOR |
| Vinyet kalitesi | Gerçek hasta senaryoları üretiliyor (paslı çivi→tetanoz, TBC damlacık bulaşı, kültür→çapraz bulaş) |

Script bir ön koşul da doğruluyor: prompt'ta `ZORLUK KALİBRASYONU` YOK ama
`SINAV TİPİ KART` VAR — yani yanlış sürüm ölçülmediği garanti.

**Arayüz tarafı da doğrulandı** (`tool/verify_v31_chips_test.dart`, ağa
çıkmaz — yukarıdaki 40 gerçek kartı `CardListScreen`'e verir):
- Üç zorluk çipi de **ekranda duruyor** (koşulsuz çiziliyorlar, `card_list_
  screen.dart:595`) ama "Kolay" ve "Zor" **"Bu filtreyle kart yok" boş
  durumuna** düşüyor; yalnızca "Orta" kart gösteriyor.
- Deste özeti metni: **"Kolay 0 · Orta 40 · Zor 0"**.
- Bu tespit üzerine iki çip **ÖLÜ KONTROL** ilan edildi (2026-08-19'da
  kaldırılan "Sınav Modu" switch'iyle aynı kalıp) ve **aynı gün düzeltildi** —
  bkz. aşağıdaki "Zorluk çipleri: 0 kartlı seviye gizleniyor".

## Zorluk çipleri: 0 kartlı seviye GİZLENİYOR (2026-08-20)
`card_list_screen.dart` `_FilterBar` zorluk çiplerini artık
`CardDifficulty.values` üzerinden KOŞULSUZ çizmiyor; yalnızca destede **en az
1 kartı olan** seviyeler çiziliyor. **SAF GÖRÜNÜRLÜK değişikliği** —
`CardFilter` mantığına, `difficulty` alanına ve SRS hesaplarına DOKUNULMADI.

- **Kaynak liste:** `_CardListScreenState.build` içinde `availableDifficulties`
  (`allCards` üzerinden, `CardDifficulty.values` SIRASINI koruyarak) hesaplanıp
  `_FilterBar`'a yeni bir `difficulties` parametresiyle geçiriliyor.
- **Gizlenen çipin SEÇİMİ de temizleniyor:** `effectiveFilter`, `_filter`'daki
  artık mevcut olmayan zorlukları (var olan `withDifficulty(d, false)` API'siyle)
  düşürüyor; bu build'de o kullanılıyor ve `addPostFrameCallback` ile state'e
  geri yazılıyor. Yazma ŞART: `_startStudying` `_filter`'ı okuyor, yoksa
  görünmeyen bir filtreyle BOŞ bir çalışma oturumu açılırdı.
- **Grup etiketi ve ayraç da koşullu:** "Zorluk" etiketi hiç çip yoksa,
  "Konular"dan önceki dikey ayraç da SOLUNDA grup yoksa çizilmiyor (yoksa
  çubuğun başında sahipsiz bir ayraç kalırdı).
- **`distributionLabel` DEĞİŞMEDİ** (bilinçli): deste özeti hâlâ
  "Kolay 0 · Orta 40 · Zor 0" gösteriyor. O bir DAĞILIM bilgisi, tıklanabilir
  bir kontrol değil; sıfırları göstermesi doğru.
- **Kalıcı değil, veriye bağlı:** çipler eski (v31 öncesi) kartlar, elle
  ayarlanmış zorluk (`difficultyManual`) ve çalışma türevi kalibrasyon
  (`lapses>=3 → zor`, `lapses==0 && reps>=3 → kolay`) ile kendiliğinden geri
  gelir. Yani "Zor çipi yok" = "bu destede henüz zor kart yok", "bu özellik
  kaldırıldı" değil.
- **Test:** `card_filter_test.dart`'a 3 test eklendi (0 kartlı seviyenin çipi
  çizilmez / hepsi orta ise yalnızca Orta görünür ve çalışır / seçili çipin
  kartları silinince çip gizlenir VE seçim temizlenir). Mevcut testler
  değişmedi — fixture'da zaten `orta` kart yoktu ve "Kolay ∩ beyin = boş"
  testi hâlâ geçiyor (kombinasyon kaynaklı boş durum korunuyor, yalnızca
  TEK BAŞINA boş olan çip gizleniyor). Paket **734 → 737/737 yeşil**,
  değişen iki dosyada **0 analyze uyarısı**.
- **Canlı v31 kartlarıyla doğrulandı** (`tool/verify_v31_chips_test.dart`,
  40 gerçek kart): önce `Kolay: true / Orta: true / Zor: true`, düzeltmeden
  sonra **`Kolay: false / Orta: true / Zor: false`**.

## ⚠️ `zorlukKurali` × `sinavTipiKurali` ÇAKIŞMASI — ÖLÇÜLDÜ (2026-08-19)
> **DURUM (2026-08-20):** bu bölümün başlığı "KARAR VERİLMEDİ" diyordu —
> artık verildi: `zorlukKurali` KALDIRILDI (yukarı bkz.). Aşağısı, kararın
> dayandığı ölçümün tam kaydı olarak DEĞİŞTİRİLMEDEN duruyor.
> Masaüstündeki tam rapor:
> `~/Desktop/MedKart_zorluk_sinavtipi_cakisma_olcumu_2026-08-19.md`.

İki kural kod tabanında ayrı ve bağımsız iki eksen gibi duruyor
(`flashcard_prompt.dart:90` = `sinavTipiKurali`, `:162` = `zorlukKurali`) ama
**üretilen kartlarda tek bir eksenin iki adı gibi davranıyorlar.** Bu, daha
önce `ornekTabanliKartKurali` notunda "ÖRTÜŞEBİLİR ama aynı değil" diye
geçiştirilen çakışmanın ilk kez SAYISAL ölçümüdür.

**Veri:** `pdf_cache.generated_cards`, smoke-test artefaktı ve boş satır
elenince **6 gerçek PDF / 733 kart**, 5 prompt sürümü (sürümsüz, v16, v23,
v24, v30). `kullanici_kutuphane` RLS ile kilitli olduğu için başka
kullanıcıların kütüphanesi ölçüme GİRMEDİ — bu "tüm kullanıcılar" değil,
önbelleğe düşmüş üretim çıktısıdır.

### Çapraz dağılım (n=733) — 6 hücrenin 2'si YAPISAL OLARAK BOŞ
| | temel | sinav | satır toplamı |
|---|---:|---:|---:|
| **kolay** | 281 (%38,3) | **0 (%0,0)** | 281 (%38,3) |
| **orta** | 323 (%44,1) | 32 (%4,4) | 355 (%48,4) |
| **zor** | **0 (%0,0)** | 97 (%13,2) | 97 (%13,2) |
| sütun toplamı | 604 (%82,4) | 129 (%17,6) | 733 |

`kolay+sinav` ve `zor+temel` 733 kartta TEK KEZ BİLE oluşmadı.

### Üç bulgu
1. **`zor ⊂ sinav`, kapsanma TAM.** `P(sinav | zor) = %100,0`,
   Jaccard(zor, sinav) = **0,752**, Cramér's V = **0,852**, belirsizlik
   azalması **%68,5** (zorluğu bilmek kart tipinin belirsizliğinin üçte
   ikisini yok ediyor). **Kapsanma BEŞ prompt sürümünün HEPSİNDE ayrı ayrı
   %100** — tek bir çalıştırmanın tesadüfü değil.
2. **`zorlukKurali`'nin tek BAĞIMSIZ dalı hiç tetiklenmemiş.** Kuralın "zor"
   tanımı iki dallı: *"hasta/durum senaryosu + ayırıcı tanı"* **ya da**
   *"formül/sayısal hesap"*. Birinci dal `sinavTipiKurali`'nin tanımının
   KENDİSİ. İkinci dal — yani kuralın kendine ait olan tek bölge — 733 kartta
   **0 kez** kullanıldı (`zor` + vinyet yok + formül/hesap var = **0**). Yani
   "zor" etiketi fiilen `sinavTipiKurali`'nin çıktısının ETİKET KOPYASI.
   İçerik ölçümü de bunu doğruluyor: `P(vinyet | zor) = %73,2` ve
   `P(vinyet | sinav) = %72,9` — iki kural AYNI kartları seçiyor.
   Ek olarak `zorlukKurali`'nin "ayırıcı tanı gerektiren" şartı da fiilen
   uygulanmıyor: `zor` kartların yalnızca **%9'unda** ayırıcı tanı ifadesi var.
3. **Tek ayrışma noktası da ayrışmıyor.** `orta|sinav` (32) ile `zor|sinav`
   (97), iki kuralın farklı cevap verdiği TEK hücre çifti. Ölçülebilir hiçbir
   özellik ikisini ayırmıyor: vinyet oranı %71,9 vs %73,2 (**p = 0,88**), soru
   uzunluğu 175 vs 192 karakter (Welch **p = 0,09**), ayırıcı tanı %6 vs %9.
   Model bu ayrımı metne YANSITMIYOR.

### Sürüm bazında — çakışma ZAYIFLAMIYOR, GÜÇLENİYOR
| prompt | n | zor | sinav | P(sinav\|zor) | P(vinyet\|sinav) |
|---|---:|---:|---:|---:|---:|
| (sürümsüz) | 49 | 12 | 12 | %100 | %83 |
| v16 | 179 | 27 | 30 | %100 | %47 |
| v23 | 238 | 19 | 27 | %100 | %52 |
| v30 (güncel) | 266 | 39 | 60 | %100 | **%93** |

v23'teki genel sapma (%68 kolay, %8 zor) o sürümün flash-lite denemeleri
sırasında üretildiğiyle tutarlı — belgelenmiş "yüzeysel/tanım-düzeyi kart"
sorununun sayısal izi (bkz. "Devam Eden İş" 0.7).

### Pratik sonuçları (bunları kod tarafında bilerek kullan)
- **6 hücrelik tablo gerçekte 4 hücre.** Zorluk ve kart tipi filtrelerini
  "bağımsız iki boyut" varsayan yeni bir UI/özellik tasarlama — değiller.
- **Zorluk filtresindeki "Zor" çipi, fiilen "sınav tipi" filtresiyle AYNI kart
  kümesini veriyor** (`card_list_screen.dart` `_FilterBar`). İkisini yan yana
  sunmak kullanıcıya iki ayrı seçenek gibi görünüyor ama değil.
- **🔴 DÜZELTME (2026-08-19, aynı gün) — Sınav Modu ölçümü İLK YAZILDIĞINDA
  YANLIŞTI, sonra özellik KALDIRILDI.** Kalıcı kayıt olarak bırakılıyor:
  - **Hata:** `card_filter.dart:71`'deki predicate
    `!(card.isExamType || card.priority == CardPriority.oncelikli)` bir
    **VEYA**; ilk yazımda "`sinav` ∧ `oncelikli`" diye VE olarak okundu ve
    "Sınav Modu = **129 kart / %17,6**" denildi. **YANLIŞTI.**
  - **Doğrusu:** `sinav` **VEYA** `oncelikli` kalır → fiilen "arka plan
    kartlarını gizle". Ölçülen: **kalan 607 kart / %82,8**, gizlenen
    **126 kart / %17,2** (104 `kolay|temel|arkaPlan` + 22
    `orta|temel|arkaPlan` — yani `arkaPlan` etiketli 126 kartın TAMAMI, ki
    hepsi zaten `temel` tarafında). Filtre havuzu DARALTMIYORDU, yalnızca
    %17,2'sini kırpıyordu.
  - **Hatanın kaynağı:** `card_filter.dart:38`'deki doc yorumu ("yalnızca
    `CardType.sinav` kartlar **ve** `CardPriority.oncelikli` işaretli temel
    kartlar kalır") — buradaki "ve" BİRLEŞİM anlamında (iki grup da kalır),
    kesişim değil. Türkçe doc yorumu okurken bu tuzağa dikkat.
  - **Yan bulgu — `isExamType` terimi ÖLÜYDÜ:** `sinav` olup `arkaPlan` olan
    kart 733'te **0** (yani `sinav ⊂ oncelikli`). Predicate'ten
    `card.isExamType ||` silinse filtre BİREBİR aynı kümeyi verirdi. Yani
    "Sınav Modu" bir sınav tipi filtresi değil, bir ÖNCELİK filtresiydi.
  - **✅ SONUÇ: Sınav Modu switch'i 2026-08-19'da UI'dan KALDIRILDI**, bkz.
    aşağıdaki "Sınav Modu switch'i kaldırıldı" bölümü.

### ⚠️ "DÜZELTMEDEN" ÖNCE OKU
Bu ölçüm bir SORUN TESPİTİDİR, çözüm reçetesi DEĞİL. İki kuralı
"tutarlı hale getirmek" için birini kırpma girişimi bu depoda DAHA ÖNCE
YAPILDI ve YANLIŞ ÇIKTI (v26'da `guncellikDiliYasagiKurali`'nin kaynağa atıf
tavsiyesi, `kaynakReferansiGizlemeKurali` ile "çelişiyor" diye silinmişti;
kullanıcı aynı gün geri bildirdi, v27'de kapsam ayrımıyla düzeltildi — bkz.
"Kart Üretim Kuralları"). Aynı hata kalıbı burada da geçerli: `zorlukKurali`
ile `sinavTipiKurali` BİLİNÇLİ olarak arbitre edilmemiş durumda
(bkz. `ornekTabanliKartKurali` notundaki aynı gerekçe). **Kullanıcı karar
vermeden prompt'a dokunma; dokunulacaksa da önce hangi davranışın İSTENDİĞİ
netleşmeli** — "zor" bağımsız bir zorluk ekseni mi olsun (o zaman formül/hesap
dalı ve vinyet-dışı zorluk ölçütleri güçlendirilmeli), yoksa "sinav"ın
şiddet kademesi mi (o zaman çakışma bir hata değil, tasarım)?

### Metodoloji ve tekrarlanabilirlik
- Sınıflandırma **belirteç (regex) tabanlı**, LLM ile yapılmadı (API maliyeti,
  yetki istenmedi) — bu yüzden KABA. Güvence için İKİ BAĞIMSIZ vinyet ölçütü
  kullanıldı (anahtar kelime vs. soru kökünden önce anlatı cümlesi olması);
  aralarındaki uyum **%94,8**, Jaccard 0,648. Yanlış-pozitifler elle
  doğrulandı: vinyet taşıyıp `temel` kalan 4 kartın 2'si aslında belirteç
  hatası ("75 **yaşından önce** kanser riski" — hasta değil, epidemiyolojik
  istatistik), yani `sinavTipiKurali` pratikte vinyet KAÇIRMIYOR.
- **Türkçe tuzağı:** `'İ'.toLowerCase()` JS'te `i` + birleşen nokta üretir ve
  eşleşmeyi bozar. Script'ler kendi normalizasyon fonksiyonunu kullanıyor;
  Türkçe metinde regex taraması yazarken bunu atlama.
- Anlamlılık: iki oran z-testi + Welch t-testi (normal yaklaşım, erf ile).
- **Hiçbir API çağrısı yapılmadı, hiçbir proje dosyası değiştirilmedi.**
- Script'ler pakete dahil DEĞİL, oturum scratchpad'inde
  (`agg2.js` çapraz dağılım, `overlap.js` çakışma/entropi/içerik,
  `sep.js` anlamlılık testleri). Veriyi tazelemek için `pdf_cache`'i
  `select=hash,prompt_version,created_at,hit_count,generated_cards` ile
  anon key üzerinden çek (bkz. "Maliyet Optimizasyonu" — tablo anon okumaya
  BİLİNÇLİ olarak açık).

## Sınav Modu switch'i KALDIRILDI (2026-08-19)
Çalışma ekranındaki (`StudyScreen`) "Sınav Modu" switch'i (`_ExamModeBar`)
tamamen kaldırıldı. **Bu bir UI kaldırma işidir; kart üretimi/etiketleme
katmanına HİÇ dokunulmadı.**

**GEREKÇE (ölçüldü, bkz. yukarıdaki çakışma bölümü):**
- Kullanıcı aynı ihtiyacı zaten iki yerden karşılıyor: kart listesindeki
  **"Zor" zorluk çipi** (`card_list_screen.dart` `_FilterBar`) ve ayrı
  **"Deneme Sınavı"** akışı (`ExamSimSetupScreen`, sidebar'da kendi ikonu).
- **"Zor" çipi seçiliyken switch'in kart kümesine etkisi SIFIRDI.** `zor ⊂
  sinav ⊂ oncelikli` olduğu için (733 kartta 0 istisna) "Zor" seçiliyken
  switch açık da kapalı da aynı 97 kart geliyordu — kullanıcı bir kontrolü
  çeviriyor, ekranda hiçbir şey değişmiyordu.
- Ad, mevcut **"Deneme Sınavı"** özelliğiyle çakışıyordu (biri süreli/puanlı
  gerçek sınav simülasyonu, diğeri bir kart filtresi) ve kart üzerindeki
  `ExamTypeChip` rozetiyle (label: `'sınav tipi'`) karışıyordu — switch
  açıkken kalan 607 kartın 478'i o rozeti taşımıyordu.
- Predicate'in `isExamType` yarısı zaten ölüydü (bkz. düzeltme notu), yani
  switch fiilen "arka plan kartlarını gizle"den ibaretti.

**NE KALDIRILDI (`lib/screens/study_screen.dart`):** `_ExamModeBar` widget'ı,
`bool _examMode` state'i, `_toggleExamMode` metodu ve `mainColumn`'daki
kullanımı (+ altındaki `SizedBox`). `_effectiveFilter` artık
`examOnly: _examMode || base.examOnly` DEĞİL, sadece `examOnly: base.examOnly`
— yani dışarıdan gelen filtre hâlâ aktarılıyor, ekranın kendisi bu alanı
AÇMIYOR.

**NE KALDIRILMADI (bilinçli):**
- **`CardFilter.examOnly` alanı ve `withExamOnly` metodu MODELDE DURUYOR.**
  Kullanıcının açık talimatı: "şimdilik kaldırma, sadece UI'dan
  eriş(il)emez hale getir." Bugün hiçbir çağıran `examOnly: true`
  göndermiyor, yani alan fiilen ölü ama API'si sağlam. Testleri de duruyor
  (`card_filter_test.dart` 2 test, `flashcard_store_test.dart` 1 test) —
  model davranışını koruyorlar, BOZULMADI.
- **`isExamType` / `CardType.sinav` / `CardPriority` üretim tarafına HİÇ
  DOKUNULMADI** — prompt (`sinavTipiKurali`, `oncelikKurali`), model
  (`flashcard.dart`), şema ve kompakt biçim aynen duruyor. Kartlar hâlâ
  `sinav`/`oncelikli` etiketleniyor; `ExamTypeChip` rozeti hâlâ görünüyor;
  `dailyQueue` sıralaması ve Öncelikli Mod bu etiketleri hâlâ kullanıyor.
- `_ToggleRow` (paylaşılan gövde) duruyor — tek kullananı artık
  `_HandwrittenOnlyBar`. **`trailingLabel` parametresi ARTIK HEP null**
  (o dal yalnızca `_ExamModeBar`'ın "N kart" pilini çiziyordu); ölü bir dal
  ama analyze uyarı vermiyor, temizliği ayrı bir iş olarak bırakıldı.

**TESTLER:** `test/study_screen_test.dart`'tan kaldırılan UI'ı test eden ÜÇ
test silindi — "Sınav Modu sınav tipi + öncelikli temel kartları bırakır",
"Sınav Modu ile birlikte çalışır (ikisi de uygulanır)", "Sınav Modu birleşik
kuyrukta da uygulanır". Silinmelerinin sebebi hepsinin `find.text('N kart')`
ile `_ExamModeBar`'ın trailing pilini okuması ve `Switch`'i konumuna göre
(`.first`) tıklaması; artık var olmayan bir UI'yı test ediyorlardı. Konu
filtresi kapsamı kaybolmadı (ayrı testleri zaten var). "Sadece Hocanın
Favorileri" testindeki `find.byType(Switch).last` çağrısı ekranda tek switch
kaldığı için değişmeden çalışıyor; yalnızca yanıltıcı hale gelen yorumu
güncellendi. **Paket 737 → 734/734 yeşil**, `flutter analyze` değişen iki
dosyada **0 YENİ uyarı** (kalan 2 uyarı baseline: `study_screen.dart:217`
`use_build_context_synchronously` ve testteki `_deckB` adlandırması — ikisi de
dokunulan satırlarda değil).

**TARAYICIDA DOĞRULANMADI** — yalnızca `flutter test` + `flutter analyze` ile
doğrulandı, gerçek tarayıcıda ekran görüntüsü ALINMADI.

**BİR DAHA EKLEMEDEN ÖNCE:** çalışma ekranına yeni bir "havuzu daraltan"
switch eklemek istersen önce yukarıdaki çakışma ölçümünü oku — zorluk çipi,
kart tipi ve öncelik etiketi BAĞIMSIZ boyutlar DEĞİL, biri diğerini kapsıyor.

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
- ~~Sınav Modu (`CardFilter.examOnly` switch'i, `StudyScreen`)~~ —
  **2026-08-19'da KALDIRILDI**, bkz. "Sınav Modu switch'i kaldırıldı".
  Model alanı (`CardFilter.examOnly`) duruyor ama UI'dan erişilemiyor.
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
silmez — 2026-08-19'da kaldırılan Sınav Modu switch'inden
(`CardFilter.examOnly`, kart havuzunu daraltıyordu) bu yönüyle temelden
farklıydı; o switch artık yok, Öncelikli Mod duruyor.

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
  bu rakamdan biraz yüksek — henüz shortAnswer sonrası CANLI yeniden
  ölçülmedi (aşağıdaki 2026-08-17 raporu kod-türetilmiş bir TAHMİN,
  canlı ölçüm değil).

## Context caching — prompt ön eki SABİT KALMALI (2026-08-17, v28)
> **YENİ BİR ŞEY EKLEMEDEN ÖNCE OKU.** `buildPagePrompt`'un başına sayfaya
> göre DEĞİŞEN bir şey koymak sayfa başı maliyeti ~%39 artırır.

Gemini 3.5 Flash tekrar eden prompt ÖN EKİNE **%90 indirim** uygular (örtük/
implicit context caching, 2.5+ modellerde VARSAYILAN AÇIK, depolama ücreti
yok). Koşul: iki isteğin **baştan itibaren birebir aynı** olması ve ortak ön
ekin **4.096 token**'ı (3.5 Flash için asgari) aşması.

**BULUNAN SORUN (2026-08-17, ölçüldü):** `buildPagePrompt`'un açılış cümlesi
`... TEK BİR SAYFASININ metni var (sayfa $pageNumber). ...` diyordu — yani
prompt daha **134. karakterde** değişkenleşiyordu. Aynı PDF'in iki sayfası
arasındaki ortak ön ek **~36 token**'dı, eşiğin çok altında: **cache HİÇ
devreye girmiyordu** ve ~6.100 token'lık statik kural bloğu her sayfada tam
fiyattan yeniden faturalanıyordu (tipik sayfa girdi token'ının **%79'u**).

**YAPILAN (v27→v28):** `(sayfa $pageNumber)` açılış cümlesinden KALDIRILDI.
Bilgi kaybı YOK — numara zaten prompt'un SONUNDAKİ `SAYFA N METNİ:` bloğunda
duruyor ve `flashcardFromItem`/pipeline onu oradan değil, çağıranın verdiği
`sourcePage` argümanından alıyor; baştaki tekrar modele ek bilgi VERMİYORDU.
Ölçüm (gerçek fonksiyon iki farklı sayfa için çalıştırılıp karakter karakter
karşılaştırıldı):

| Yol | ÖNCE (v27) | SONRA (v28) | Eşik (4.096 tkn) |
|---|---|---|---|
| Yol A görselli | 134 krkt (~36 tkn) | **22.575 krkt (~6.101 tkn)** | ✓ aşıyor |
| Yol A görselsiz | 134 krkt (~36 tkn) | **16.569 krkt (~4.478 tkn)** | ✓ aşıyor |

**KURAL:** `buildPagePrompt`'un GÖVDESİNE (yani `SAYFA N METNİ:` bloğundan
ÖNCEKİ her yere) sayfaya/isteğe göre değişen HİÇBİR ŞEY yazma — sayfa
numarası, dosya adı, tarih, kullanıcı/cihaz kimliği, rastgele id, deste adı...
Değişken her şey prompt'un SONUNA gitmeli. Fonksiyonun doc yorumunda da bu
uyarı var; oradan silme.

### ⚠️ v28 TEK BAŞINA ÜRETİMDE HİÇBİR ŞEY KAZANDIRMIYOR (kod okunarak DOĞRULANDI)
Aynı oturumda uçtan uca kod okumasıyla doğrulandı — **v28 düzeltmesi
üretimdeki VARSAYILAN akışta cache'i AÇMIYOR.** Zincir:
1. `add_cards_screen.dart:43` → `bool _hasHandwriting = true` — el yazısı
   anahtarının VARSAYILANI AÇIK, yani üretimde baskın yol görselli yol.
2. `gemini_service.dart` `generateForPage` parçaları
   `[inlineData(görsel), text(prompt)]` sırasıyla kuruyor — **görsel 0.
   POZİSYONDA** ve her sayfada FARKLI.
3. `gemini_transport.dart` gövdeyi olduğu gibi `payload`'a koyuyor;
   `ai-proxy/index.ts:101` de `JSON.stringify(payload)` ile **birebir**
   Gemini'ye iletiyor (hiçbir yeniden yapılandırma yok).
4. `systemInstruction` alanı kod tabanında **HİÇ KULLANILMIYOR** (grep'lendi).

Sonuç: token dizisinin en başında her sayfada değişen bir görsel duruyor,
dolayısıyla ortak ön ek ~0. Arkasındaki 22.575 karakterlik statik blok ne
kadar sabit olursa olsun cache'e giremiyor. **v28'in fiili kazancı şu an
YALNIZCA el yazısı anahtarı KAPALI çalıştırmalarda** (orada hiç görsel parçası
yok, prompt tek `text` parçası → ön ek ~4.478 token, eşiği aşıyor).

v28 yine de DOĞRU ve gerekli: görsel sırası düzeltildiği anda kazanç
kendiliğinden gelsin diye ÖN KOŞUL olarak duruyor, ayrıca görselsiz yolu
bugünden ucuzlatıyor.

**Sıradaki adım olarak İKİ seçenek düşünülmüştü — İKİSİ DE DENENDİ VE
BAŞARISIZ OLDU, aşağıdaki "GÖRSELLİ YOLDA CACHE HİÇ ÇALIŞMIYOR" bölümüne bak.
(A) parça sırasını değiştirmek ve (B) statik bloğu `systemInstruction`'a
taşımak; ikisi de görselli yolda cache'i açmadı. Tekrar denemeden önce neyin
FARKLI olacağını netleştir.**

### Ölçüm altyapısı — `usage_metadata.dart` (2026-08-17, EKLENDİ)
Bu tarihe kadar kod tabanında **hiçbir yerde token sayımı tutulmuyordu**
(`GeminiService` yanıttan yalnızca `candidates` okuyup `usageMetadata`'yı
atıyordu, `ai-proxy` loglamıyordu, `kullanim_kota` token değil SAYFA sayıyor).
Bu yüzden tüm maliyet analizleri karakter→token TAHMİNİNE dayanmak zorundaydı
ve v28'in etkisi ölçülemezdi — yani "kör optimizasyon" riski vardı. Kullanıcının
açık talimatıyla v28 ile **AYNI ANDA** eklendi:
- `lib/services/usage_metadata.dart`: `UsageMetadata.tryParse` (savunmacı —
  blok yoksa/bozuksa null döner, ASLA fırlatmaz) + `cacheHitPercent` +
  `logUsageMetadata`. Fiyat/dolar hesabı BİLİNÇLİ OLARAK YOK — birim fiyatı
  koda gömmek bu depodaki diğer sabit rakamların başına gelen "sessizce eskime"
  sorununu davet ederdi; yalnızca ölçülen token sayıları ve cache ORANI loglanır.
- Çağrı noktaları: `_parsePageCards` (Yol A, etiket `s.N`) ve `_parseResponse`
  (Yol B, etiket `yol-B`). İkisinde de **candidates kontrollerinden ÖNCE**
  çağrılıyor — kart ayrıştırma başarısız olsa bile istek faturalandığı için
  ölçüm kaybolmamalı.
- Log satırı: `[USAGE s.12] girdi=7688 cache=6101 (%79) çıktı=1080 toplam=8768`.
  Cache isabet etmediyse `cache=YOK` yazar (sessiz kalmıyor — "ölçüm var"
  yanılgısı olmasın diye). `thinkingBudget: 0` olmasına rağmen thinking tokenı
  gelirse `thinking=N(!)` diye dikkat çeker.
- **NEREDE GÖRÜNÜR:** Flutter web'de `print()` sunucu log'una DEĞİL TARAYICI
  KONSOLUNA gider (bkz. "ortam notları") — `flutter run` çıktısında arama,
  DevTools konsolunda ara. Daha kalıcı bir çözüm istenirse `ai-proxy`'de
  sunucu tarafında loglamak gerekir (yapılmadı).
- Test: `test/usage_metadata_test.dart` (11 test — eksik/bozuk blok, sıfıra
  bölme, oran hesabı, log biçimi).
- **`flutter analyze` baseline 90 → 92:** iki yeni uyarı bu dosyadaki
  `avoid_print`'ten geliyor. `ignore` yorumu EKLENMEDİ — `gemini_service.dart`
  zaten 30'dan fazla aynı tarz tanılama `print`'i taşıyor ve hiçbirinde ignore
  yok; yalnızca burada susturmak tutarsız olurdu. Yeni bir regresyon DEĞİL.

### ✅ CANLI ÖLÇÜLDÜ (2026-08-17) — cache ÇALIŞIYOR ama beklenenin ÜÇTE BİRİ
`tool/measure_cache_test.dart` ile gerçek API'ye 4 ardışık GÖRSELSİZ çağrı
yapıldı (`flutter test tool/measure_cache_test.dart`). Ham çıktı:

```
[USAGE s.1] girdi=5743 cache=YOK        çıktı=1280
[USAGE s.2] girdi=5696 cache=1983 (%35) çıktı=1412
[USAGE s.3] girdi=5679 cache=1983 (%35) çıktı=965
[USAGE s.4] girdi=5682 cache=1983 (%35) çıktı=1303
```

**1. Cache GERÇEKTEN isabet ediyor — v28 çalışıyor.** İlk çağrı cache'i
dolduruyor (beklenen), 2-4. çağrılar isabet ediyor. Yani "prompt ön ekini
sabitlemek işe yarar mı" sorusu artık teorik değil: **EVET.**

**2. AMA ortak ön ekin yalnızca ~%37'si önbelleklendi.** Ortak ön ek ~5.414
token (16.569 krkt ÷ 3,06), önbelleklenen ise **1.983 token** — üç çağrıda da
DEĞİŞMEDEN 1983, yani rastgele değil deterministik. Mekanizma BİLİNMİYOR
(blok/kuantum sınırı olabilir; 1983 ≈ 2048'in hemen altı). Beklenti ön ekin
TAMAMININ önbelleklenmesiydi; gerçekleşmedi. **Bu, örtük (implicit) cache'in
bilinen bir sınırı olabilir** — bkz. googleapis/python-genai #1880 ("tutarsız
cache isabeti").

**3. KARAKTER→TOKEN ORANI DÜZELTİLDİ: 3,7 DEĞİL ~3,06.** Ölçülen `girdi`
değerleri yerel karakter sayılarına bölününce dört çağrıda da 3,06 çıktı
(Türkçe tıbbi metin İngilizceden daha kötü tokenize oluyor). **Bu dosyadaki ve
maliyet raporlarındaki 3,7'ye dayanan TÜM token rakamları ~%21 DÜŞÜK
TAHMİNDİ.** Düzeltilmiş statik blok boyutları:
| Yol | Karakter | ESKİ tahmin (3,7) | GERÇEK (3,06) |
|---|---|---|---|
| Yol A görselsiz iskelet | 16.597 | 4.486 tkn | **5.424 tkn** |
| Yol A görselli iskelet | 22.603 | 6.109 tkn | **7.386 tkn** |

**4. GERÇEK TASARRUF, VAAT EDİLENİN ÇOK ALTINDA.** Ölçülen s.2 çağrısı:
- cache'siz olsa: 5.696 × $1,50/M + 1.412 × $9/M = **$0,021252**
- cache'li (ölçülen): (5.696−1.983) × $1,50/M + 1.983 × $0,15/M + çıktı
  = **$0,018575**
- tasarruf **$0,00268/sayfa = %12,6** (rapordaki vaat: %38,7)

### 🔴 GÖRSELLİ YOLDA CACHE HİÇ ÇALIŞMIYOR — İKİ ÇÖZÜM DENENDİ, İKİSİ DE BAŞARISIZ
Aynı gün, görselli (üretim varsayılanı) yolu açmak için iki yapısal değişiklik
denendi ve **ikisi de canlı ölçümle çürütüldü.** Ölçüm: sayfa başına FARKLI
sentetik PNG üretilerek üretim koşulu birebir taklit edildi.

**Deneme 1 — statik bloğu `systemInstruction`'a taşı (v29):** Gerekçe, Google
dokümanındaki "cached content is a prefix to the prompt" ifadesiydi; system
instruction ön ekin parçası olduğu için görselden etkilenmemesi bekleniyordu.
```
[USAGE s.1] girdi=8775 cache=YOK   [USAGE s.3] girdi=8711 cache=YOK
[USAGE s.2] girdi=8728 cache=YOK   [USAGE s.4] girdi=8714 cache=YOK
```
Dördü de `cache=YOK`. **ÇALIŞMADI.**

**Deneme 2 (teşhis) — görseli `contents`'in SONUNA al:** sorunun görselin
KONUMU mu VARLIĞI mı olduğunu ayırt etmek için. Dördü de yine `cache=YOK`.

**KESİN SONUÇ: sorun görselin KONUMU DEĞİL, VARLIĞI.** Inline görsel taşıyan
istekler Gemini'ın örtük cache'ine hiç girmiyor. Bu, "parça sırasını değiştir"
(A) ve "systemInstruction'a taşı" (B) seçeneklerinin İKİSİNİ DE öldürüyor —
bir daha denemeden önce neyin FARKLI olacağını netleştir.

**v29 GERİ ALINDI.** Ölçülebilir faydası olmayan ama kart kalitesini
etkileyebilecek (kurallar user turn yerine system instruction'a taşınıyordu)
bir değişikliği tutmanın anlamı yoktu. `kPromptVersion` v28'de kaldı —
gönderilen prompt metni v28 ile BİREBİR AYNI. **Bölme
(`buildPageSystemInstruction`/`buildPageUserContent`) KORUNDU**: prompt metnini
değiştirmiyor, yalnızca cache sınırını kodda görünür kılıyor ve
`test/page_prompt_split_test.dart` (10 test) bu sınırı değişmez olarak
koruyor.

**GERİYE KALAN DURUM:**
- Görselsiz yol: cache çalışıyor (~%35 girdi, ~%12,6 tasarruf). Ama bu
  üretimin varsayılanı DEĞİL ve el yazısı yakalamayı kaybettiği için
  varsayılan yapılamaz.
- Görselli yol (varsayılan): örtük cache ile hiçbir kazanç MÜMKÜN DEĞİL.
- **Açık (explicit) cache** hâlâ denenmedi ve artık daha BELİRSİZ: örtük cache
  multimodal isteklerde hiç devreye girmediğine göre açık cache'in gireceği de
  garanti değil. Ayrıca `ai-proxy` yalnızca `:generateContent` uç noktasına
  proxy'liyor; `cachedContents` kaydı oluşturmak için **fonksiyonu değiştirip
  DEPLOY etmek** gerekiyor — yani denemenin kendisi bile üretime dokunmayı
  gerektiriyor. Karar kullanıcıya bırakıldı.
- **`pdf_cache` kaldıracı SORGULANDI (2026-08-17) ve "kalite nötr" olmadığı
  ortaya çıktı** — ayrıntı "Maliyet Optimizasyonu"ndaki "İSABET ORANI İLK KEZ
  SORGULANDI" maddesinde. Özet: isabet oranı ~%40 ama örneklem 10 lookup
  (anlamsız derecede küçük), VE önbellekteki her kayıt eski prompt
  sürümünden (v16-v24; v28 ile üretilmiş tek kayıt yok), yani isabet
  bedava ama ESKİMİŞ kalite servis ediyor. Kapsamı genişletmeden önce
  lookup'a sürüm eşiği eklenmeli.

**ÖLÇÜM TEKRARLANABİLİR:** `tool/measure_cache_test.dart` (pakete dahil
DEĞİL, `tool/` altında). Prompt/model değiştirdikten sonra tekrar çalıştır.
Not: `TestWidgetsFlutterBinding` tüm HTTP'ye 400 döndürdüğü için script
`HttpOverrides.global = null` yapıyor — normal test paketinde bunu ASLA yapma.

**HÂLÂ ÖLÇÜLMEDİ:** görselli (üretim varsayılanı) yolda cache'in GERÇEKTEN
sıfır olduğu canlı doğrulanmadı — kod okumasıyla kesin (görsel 0. pozisyonda,
her sayfada farklı), ama ölçülmedi. Ölçmek için sayfa başına FARKLI bir
görsel üretmek gerekiyordu, bu script'e eklenmedi.

⚠️ **AŞAĞIDAKİ BEKLENTİ CANLI ÖLÇÜMLE ÇÜRÜTÜLDÜ — bkz. "CANLI ÖLÇÜLDÜ"
bölümü.** Gerçekleşen tasarruf %38,7 değil **%12,6** (örtük cache ön ekin
yalnızca ~%37'sini tutuyor). Tarihsel kayıt olarak bırakılıyor:
~~Beklenen kazanç (cache isabet ederse): tipik sayfa $0,0213 → **$0,0131**
(−%38,7), 500 sayfa/ay $14,60 → **$10,47** (−%28).~~ Ayrıntı ve reddedilen
alternatifler (`maxOutputTokens` düşürmek TASARRUF ETMEZ — tavan, bütçe değil;
sayfa birleştirme kapsam kaybı riski taşır; prompt kısaltmak yanlış yerden
tasarruf):
[Maliyet Düşürme Planı](https://claude.ai/code/artifact/bcf3494c-03ec-4b2c-99bc-f6dd536a49a8).

**YAN FAYDA:** cache isabet ettiğinde statik blok 10 kat ucuzluyor, yani
prompt'a yeni kalite kuralı eklemenin maliyeti ~$0,0018'den ~$0,0002'ye
düşüyor — v22→v27 büyümesinin kompakt JSON tasarrufunu yeme sorunu
(aşağıdaki rapora bkz.) pratikte ortadan kalkıyor.

**Gemini maliyet mühendislik raporu (2026-08-17, koddan TÜRETİLMİŞ hesap —
CANLI ÖLÇÜM DEĞİL):** `shortAnswer` ve v27 prompt büyümesi sonrası sayfa
başı maliyeti güncellemek için kod tabanındaki gerçek parametreler
(model/fiyat/`maxOutputTokens`/prompt uzunlukları) üzerinden kapsamlı bir
hesap çıkarıldı. Prompt uzunlukları geçici bir `dart run` script'iyle
GERÇEKTEN ÖLÇÜLDÜ (v27 güncel + git geçmişindeki v22/v25 durumları da
worktree'de checkout edilip aynı şekilde ölçüldü); fiyat ($1,50/$9,00 per
M token, girdi/çıktı) ve USD/TRY (~47,90) web'den doğrulandı. Sayfa
içeriği (kart sayısı, sayfa metni uzunluğu) ve karakter→token oranı
(3,7 kr/token) TAHMİN — ayrıntı için tam rapora bkz.:
[MedKart Maliyet Raporu](https://claude.ai/code/artifact/77bb27f7-b781-481f-a6c4-6d398acd4bdd).
Özet:
- Sayfa başı (Yol A, görsel açık — varsayılan): tipik sayfa (6 kart)
  **$0,0213**, yoğun/tablo sayfa (22 kart) **$0,0476**, teorik tavan
  (4096 çıktı token dolu) **$0,0488** — bu sonuncusu kodun kendi
  yorumundaki (`gemini_service.dart:88`) "~$0,048/sayfa" tahminiyle
  neredeyse birebir örtüştü, modelin tutarlılığı için iyi bir çapraz
  doğrulama.
- Yukarıdaki eski $0.019/sayfa rakamı `shortAnswer` öncesi VE daha kısa
  (v22 öncesi) prompt ile ölçülmüştü; bugünkü tipik-sayfa rakamı
  ($0,0213) ona yakın ama biraz yüksek — iki ölçüm tutarlı yönde.
- Vision (görsel eki) payı sayfa yoğunluğuna göre değişiyor: tipik
  sayfada **%19,2**, yoğun sayfada **%8,6** — ve tipik sayfadaki bu payın
  yarıdan fazlası (11,5 puan / 19,2 puan) aslında 1.092 sabit görsel
  tokeninden değil, görsel açıkken devreye giren EKSTRA PROMPT
  KURALLARINDAN (el yazısı ayrımı, slayt numarası vb.) geliyor.
- Prompt büyümesi (v22→v27, +4.412 karakter/%24,3) vs kompakt JSON
  formatının çıktı tasarrufu: tipik sayfada neredeyse BAŞA BAŞ (net
  ~$0,0001 kayıp), yoğun sayfada kompakt format NET KAZANDIRIYOR
  (+$0,0043/sayfa) — prompt'u büyütmenin maliyeti sabit (~$0,0018/sayfa,
  girdi tarafı), kompakt formatın kazancı kart sayısıyla orantılı (çıktı
  tarafı); tıp müfredatı ağırlıklı olarak yoğun/tablolu olduğu için net
  etki muhtemelen kazanç yönünde.
- Aylık (karışık %70 tipik/%30 yoğun varsayımıyla — TAHMİN): 100 sayfa
  ≈ $2,92 (140 TL), 500 sayfa (= mevcut `MONTHLY_PAGE_CAP`) ≈ $14,58
  (698 TL), 1000 sayfa ≈ $29,15 (1.396 TL).
- 100/200/300 TL abonelik fiyatı + %30/%50 cache isabet oranı
  senaryolarının HİÇBİRİNDE azami kârlı sayfa hacmi 500 sayfalık aylık
  tavana çarpmıyor (en kötü durumda ~215 ücretli sayfa) — bu fiyat
  aralığında darboğaz `MONTHLY_PAGE_CAP` değil, ham API maliyeti.
- **CANLI DOĞRULAMA YOK:** Gemini tokenizer'ı hiç canlı ölçülmedi (3,7
  kr/token bir tahmin), kart-başı çıktı token'ı yalnızca kodun kendi
  yorumundaki tek bir gözlemden (25 kart ≈ 4.000-5.000 tkn) türetildi.
  Gerçek bir çalıştırmadan sonra `usage` bloğu loglanıp bu rakamlar
  kalibre edilebilir (bkz. GLM bölümündeki "TOKEN SAYIMI HİÇBİR YERDE
  TUTULMUYOR" notu — Gemini tarafında da aynı boşluk var).

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

## Boş sayfa ölçümü — `emptyResultPages` + `pdf_isleme_olcum` (2026-08-18)
"Sayfaların yüzde kaçı modele gidip boş dizi (`[]`) dönüyor, yani kart
üretmeye değmez bulunuyor?" sorusunu artık TAHMİN etmeye gerek yok.

**ÜÇ SAYFA SONUCU AYRI ŞEYDİR, KARIŞTIRMA** (`PipelineResult`):
| Liste | Anlamı | Maliyet | Kart |
|---|---|---|---|
| `emptyTextPages` | modele HİÇ gitmedi (metin+görüntü yok, ön-filtre) | yok | yok |
| `emptyResultPages` | modele GİTTİ, `[]` döndü — **hata değil, kuralın beklediği davranış** | VAR | yok |
| `failedPages` | modele gitti, istisna fırlattı (ağ/parse/timeout) | var | yok |

`emptyResultPages` 2026-08-18'de eklendi. Öncesinde `[]` dönen sayfa HİÇBİR
YERDE kaydedilmiyordu — `processedPages`'e sessizce başarılı sayılıyordu — bu
yüzden oran ancak `pdf_cache`'teki `sourcePage` BOŞLUKLARINDAN tahmin
edilebiliyordu (2026-08-17 ölçümü: 12 boşluk / 91 sayfa ≈ **%13**, ama 4
PDF'lik örneklem + numaralandırma kayması gürültüsü + PDF'in SONUNDAKİ boş
sayfaların görünmezliği yüzünden yalnızca kaba bir alt sınırdı). Oranın DOĞRU
paydası `PipelineResult.billedPages` (toplam − ön-filtre − hata); toplam
sayfaya bölmek yanıltıcı olur, modele hiç gitmemiş sayfa "değmez bulundu"
sayılamaz.

**KALICI KAYIT: `pdf_isleme_olcum` tablosu** (migration
`20260818000000_create_pdf_isleme_olcum.sql`, 2026-08-18'de `supabase db push`
ile CANLIYA ALINDI; varlığı anon SELECT ile doğrulandı → 200 + `[]`, olmayan
tablo 404 döner). Satır başına BİR ÇALIŞTIRMA (PDF başına değil).
- **Neden `pdf_cache`'e sütun DEĞİL, ayrı tablo:** (1) `pdf_cache` satır başına
  bir PDF tutar, zaman serisi olmaz; (2) `pdf_cache`'e yazma yalnızca TAM PDF +
  cache MISS + en az 1 kart üretilmiş çalıştırmalarda oluyor — yani DARALTILMIŞ
  (konu/sayfa aralığı) çalıştırmalar, cache HIT'ler ve HİÇ kart üretmeyen
  çalıştırmalar sistematik olarak dışarıda kalırdı, ki ölçmek istediğimiz tam
  da bu uçlar; (3) sütun eklemek `pdf-cache` Edge Function'ını değiştirip
  DEPLOY etmeyi gerektirirdi. Yeni tabloya istemci DOĞRUDAN yazıyor
  (`kullanici_kutuphane` deseni, RLS `auth.uid() = user_id`) — **hiçbir Edge
  Function değişmedi/deploy edilmedi.**
- Yazan: `lib/services/pipeline_metrics_service.dart` → `PdfImportScreen._run`
  sonunda `unawaited(...)`. **Best-effort:** giriş yoksa/Supabase yoksa/ağ
  patlarsa sessizce no-op, kart üretimi ASLA etkilenmez. Önbellek yazımının
  AKSİNE koşulsuz çalışır (hash null olsa da, kart 0 olsa da, kota kesse de).
- RLS: insert+select yalnızca kendi satırına; **UPDATE/DELETE'e bilerek policy
  YOK** (ölçüm geçmişte olmuş bir olay, sonradan değiştirilemez). Toplu analiz
  Supabase panelinden service_role ile yapılır.
- **INSERT PROBU BİLİNÇLİ OLARAK YAPILMADI:** anon insert RLS'e takılmalı, ama
  takılmasaydı DELETE de kapalı olduğu için silinemeyen bir çöp satır kalırdı —
  2026-07-21'de tam bu yaşandı (bkz. `20260721000003_cleanup_rls_probe_row.sql`).
  İlk gerçek satır bir sonraki PDF yüklemesinde kendiliğinden düşecek.
- Veri birikince oranı sormak için (panel, service_role):
  ```sql
  select sum(bos_donen_sayfa) as bos,
         sum(bos_donen_sayfa + kart_ureten_sayfa) as faturalanan,
         round(100.0 * sum(bos_donen_sayfa)
               / nullif(sum(bos_donen_sayfa + kart_ureten_sayfa), 0), 1) as yuzde
  from pdf_isleme_olcum;
  ```
- Test: `test/pipeline_metrics_test.dart` (9 test — alan eşlemesi, **paydalar
  toplamı = `toplam_sayfa` eşitliği**, sıfır-kart ve daraltılmış çalıştırma,
  Supabase yoksa no-op) + `test/pdf_card_pipeline_test.dart` içindeki
  `emptyResultPages` grubu (5 test). Paket 719 → **730/730 yeşil**,
  `flutter analyze` **0 yeni uyarı**.
- **UI'a EKLENMEDİ (bilinçli):** `PdfImportScreen`'in bitiş özeti hâlâ yalnızca
  `emptyTextPages`/`failedPages` gösteriyor. `[]` dönen sayfa bir hata değil,
  kullanıcıya "3 sayfa atlandı" demek yanlış sinyal olurdu. İstenirse ayrı iş.

## Konu ön-taraması (`TopicScanService`) — flash-lite BURADA KULLANILIYOR
`lib/services/topic_scan_service.dart` (2026-08-10'da eklendi, bu dosyaya ilk
kez 2026-08-18'de işlendi): pahalı Yol A pipeline'ından ÖNCE çalışan ucuz bir
ön-tarama. Her sayfanın metninden yalnızca ilk ~200 karakteri
(`sampleCharsPerPage`) alıp tek istekte (parça başına, `maxPagesPerBatch` =
150) Gemini'ye gönderir ve PDF'i ana konu başlıklarına + sayfa aralıklarına
böler. **Görsel/vision HİÇ gönderilmez, sayfa başına ayrı çağrı YOKTUR.**
Amaç: kullanıcı istemediği konuları eleyince o sayfalar pahalı pipeline'a hiç
girmez (bkz. `PdfTopicSelectionScreen`). Hata toleranslı — ağ/parse sorununda
istisna fırlatmaz, `null` döner ve çağıran "tüm sayfalar" davranışına düşer;
bu adım bir maliyet optimizasyonu, kullanıcıyı asla engellememeli.

**MODEL: `TopicScanService.model = 'gemini-3.5-flash-lite'`** (2026-08-18'de
`GeminiService.model`'den ayrıldı). Bu, "Devam Eden İş" 0.7'deki flash-lite
retiyle ÇELİŞMEZ, kapsamları ayrıktır:
- 0.7'deki ret **kart üretimi** içindir; gerekçe flash-lite'ın yüzeysel/
  tanım-düzeyi kart üretmesi, yani DERİNLİK sorunuydu. Üç ayrı prompt tekniği
  (v23-v25) denenip çözülemedi ve production `gemini-3.5-flash`'ta sabitlendi.
- Konu ön-taramasında üretilen şey kart değil, 1-4 kelimelik başlık + sayfa
  aralığı. Derinlik gerekmiyor, dolayısıyla retin dayandığı sorun burada
  ortaya çıkmıyor. Kart üretimi HÂLÂ `GeminiService.model`
  (`gemini-3.5-flash`) ile yapılıyor — o karar DEĞİŞMEDİ.

**TUZAK — `thinkingConfig` guard'ı GERÇEKTEN gönderilen modele bakmalı:**
`gemini-3.5-flash-lite` `generationConfig.thinkingConfig`'i hiç kabul etmiyor
(400 `INVALID_ARGUMENT`, tek başına gönderilse bile — 2026-08-07'de canlı
doğrulandı, bkz. `GeminiService.supportsThinkingConfig` doc yorumu).
`_scanBatch` bu kontrolü yapıyor ama 2026-08-18'e kadar
`GeminiService.supportsThinkingConfig(GeminiService.model)` diye SORUYORDU —
yani `flash`'a bakıp `true` alıyordu. Model değişikliğinde yalnızca
`_transport.send(model: ...)` güncellenseydi guard yine `true` döner ve her
istek 400 ile ölerdi. Guard artık servisin KENDİ `model` sabitine bakıyor.
Modeli bir daha değiştirirsen bu iki yerin (guard + send) AYNI sabitten
beslendiğini koru.
- **Yan etki:** flash-lite bu alanı hiç kabul etmediği için bu çağrıda
  `thinkingBudget: 0` artık GÖNDERİLEMİYOR — thinking davranışı modelin kendi
  varsayılanına kalıyor, kodla bastırılamıyor. Modelin doğasından gelen bir
  sınır, yapılabilecek bir şey yok. (Kart üretim yolunda `thinkingBudget: 0`
  aynen duruyor, orası flash.)
- Test: `test/topic_scan_service_test.dart` — istek zarfındaki `model`'in
  `TopicScanService.model` olduğunu, guard'ın o modele göre karar verdiğini
  ve bugünkü kasıtlı seçimi (`flash-lite` + `supportsThinkingConfig == false`)
  doğruluyor. Ayrıca `test/pdf_topic_selection_screen_test.dart` ekranı
  kapsıyor. 2026-08-18'de paket **719/719 yeşil**.

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
- **İSABET ORANI İLK KEZ SORGULANDI (2026-08-17) — 3 BULGU:**
  Canlı `pdf_cache` tablosu okundu (7 satır, 1'i 2026-07-21 smoke-test
  artefaktı `smoketest-nonexistent-hash`, yani **6 gerçek PDF**).
  | Ölçüt | Değer |
  |---|---|
  | Toplam isabet (`sum(hit_count)`) | **4** |
  | En az bir kez tekrar kullanılan PDF | 3/6 (%50) |
  | Tahmini toplam lookup | ~10 (6 kaçırma + 4 isabet) |
  | **Tahmini isabet oranı** | **~%40** |
  | Tarih aralığı | 2026-07-26 → 2026-08-08 (~2 hafta) |

  **(1) Mekanizma ÇALIŞIYOR ama örneklem ANLAMSIZ derecede küçük.** 10 lookup
  üzerinden çıkan %40'a dayanıp kapsam genişletme kararı VERME — bu sayı
  tek bir kullanıcının test dönemine ait. Karar için gerçek kullanıcı
  trafiği beklenmeli.

  **(2) ⚠️ ÖNBELLEKTEKİ HER KAYIT ESKİ PROMPT SÜRÜMÜNDEN — "kalite etkisi
  yok" iddiası BU YÜZDEN YANLIŞ.** Sürüm dağılımı: 3×null (sütunlar
  2026-07-26'da eklendi), 2×v16, 1×v23, 1×v24. **Güncel sürümle (v28)
  üretilmiş TEK BİR KAYIT YOK.** Lookup sürüme göre filtrelemediği için
  (bkz. aşağıdaki "Model/prompt sürüm sütunları") bugün bir isabet, v16
  döneminde üretilmiş kartları servis ediyor — yani `terminolojiStandardiKurali`,
  `guncellikDiliYasagiKurali` (v18), el yazısı/vurgu ayrımı (v19-v20), ders-dışı
  içerik boş-dizi kuralı (v21-v22) ve `kaynakReferansiGizlemeKurali` (v26-v27)
  kurallarının HİÇBİRİ o kartlara uygulanmamış. **`pdf_cache` "bedava ve kalite
  nötr" DEĞİL: bedava ama eskimiş kalite servis ediyor.** Bu, kapsamı
  genişletmeden önce çözülmesi gereken asıl sorun — muhtemel çözüm lookup'ta
  `prompt_version` eşiği (ör. "v18'den eski kayıtları isabet sayma").

  **(3) `pdf_cache` ANON KEY İLE OKUNABİLİYOR — GÜVENLİK AÇIĞI DEĞİL, KASITLI
  TASARIM.** `.env`'deki anon key ile `GET /rest/v1/pdf_cache?select=*` 200
  dönüyor ve `generated_cards` dahil tüm sütunlar okunuyor. **Bu dosyanın
  "yalnızca `pdf-cache` Edge Function (service_role) erişir, istemci doğrudan
  hiç dokunmaz" ifadesi ESKİMİŞTİ** (aşağıda düzeltildi) — gerçekte
  `20260721000002_pdf_cache_public_read.sql` migration'ı okumayı KULLANICI
  İSTEĞİYLE anon+authenticated'e açmış: *"paylaşılan, herkese açık bir
  önbellek — içerik hassas değil, yalnızca üretilmiş kartlar"*. Yani ilk
  tespitteki "güvenlik bulgusu" YANLIŞ ALARMDI; sorun DB'de değil, bu
  dosyanın tarifindeydi.
  - **Yazma kapalı:** aynı migration INSERT/UPDATE/DELETE'e bilerek policy
    EKLEMİYOR (policy yoksa varsayılan deny; service_role zaten RLS'i bypass
    eder). 2026-08-17'de `supabase migration list --linked` ile **11/11
    migration'ın local == remote** olduğu doğrulandı, yani canlı DB bu
    tanımlarla birebir aynı.
  - **CANLI YAZMA PROBU BİLİNÇLİ OLARAK YAPILMADI:** RLS'i INSERT ile
    denemek, izin varsa üretim tablosuna çöp satır yazar ve DELETE de kapalı
    olduğu için temizlenemez. Tam olarak bu 2026-07-21'de yaşandı — bkz.
    `20260721000003_cleanup_rls_probe_row.sql` (bir probe satırını silmek için
    yazılmış migration). Migration durumu zaten kanıt olduğu için probu
    tekrarlama.
  - Diğer iki tablo da doğrulandı (anon SELECT): `kullanim_kota` → `[]`
    (deny all, policy yok), `kullanici_kutuphane` → `[]`
    (`auth.uid() = user_id`). İkisi de beklendiği gibi.

- **BAYATLIK KAPISI (2026-08-17) — kod HAZIR, `pdf-cache` HENÜZ DEPLOY
  EDİLMEDİ.** Yukarıdaki (2) numaralı bulgunun ("önbellekteki her kayıt eski
  prompt sürümünden") çözümü. **İKİ değişiklik BİRLİKTE yapıldı, biri diğeri
  olmadan İŞE YARAMAZ — ayırma:**
  1. **lookup filtresi:** istemci artık `min_prompt_version` gönderiyor;
     sunucu bundan eski (ya da sürümsüz) kaydı İSABET SAYMIYOR
     (`found: false`, ayrıca tanı için `stale: true` +
     `stored_prompt_version`). Bayat kayıtta `hit_count` de ARTIRILMIYOR —
     gerçekten kullanılmadı, sayaç gerçeği yansıtmalı.
  2. **save artık EZİYOR:** eskiden `ignoreDuplicates: true` ("ilk kaydeden
     kazanır") idi. **Yalnızca (1) yapılsaydı durum DAHA KÖTÜ olurdu:** bayat
     kayıt yerinde kalır, her kullanıcı yeniden üretir (tam maliyet) ve
     önbellek ASLA tazelenmezdi. Artık sürüm karşılaştırılıyor: gelen sürüm
     eldekinden DAHA YENİYSE kayıt ezilir. Eşit sürümde dokunulmaz (aynı PDF
     + aynı prompt = aynı içerik, gereksiz yazma yok). Gelen sürüm
     çözülemiyorsa ASLA ezilmez (sürümsüz kayıt, sürümlünün yerini almamalı).
     `hit_count` payload'da olmadığı için `ON CONFLICT DO UPDATE` onu
     değiştirmez — sayaç korunur.
  - **Eşik: `flashcard_prompt.dart` → `kMinCacheablePromptVersion` (2026-08-18'de
    27 → **30** yükseltildi — `ornekTabanliKartKurali` üretilen kart KÜMESİNİ
    değiştiriyor, v27/v28 kayıtları örnek/uygulama kartlarını HİÇ taşımaz, yani
    eksik set servis eder. **Bugünkü pratik maliyeti SIFIR:** canlı önbellekteki
    6 kaydın en yenisi v24, zaten 27 eşiğini de geçmiyorlardı).** `kPromptVersion` İLE AYNI ŞEY DEĞİL, bilinçli olarak ayrı: her
    sürüm artışı kart İÇERİĞİNİ değiştirmez (ör. v28 saf maliyet/cache
    düzeltmesiydi, v27 kartları içerik olarak ayırt edilemez). İkisini
    eşitlemek sağlam kayıtları boşuna çöpe atardı. **Yalnızca kart
    içeriğini/etiketlerini gerçekten değiştiren bir kural eklendiğinde artır.**
    27 seçildi çünkü kart metnini etkileyen en yeni kural
    (`kaynakReferansiGizlemeKurali`) DOĞRU hâliyle v27'de geldi (v26 hatalıydı).
  - **Eşik SUNUCUDA SABİT DEĞİL, istemciden geliyor** — politika prompt
    kurallarının yanında duruyor (kuralı ekleyen kişi eşiği de orada görür) ve
    değiştirmek Edge Function deploy'u GEREKTİRMİYOR. `min_prompt_version`
    gönderilmezse filtre uygulanmaz (geriye dönük uyumlu).
  - **BEKLENEN İLK ETKİ: önbellek fiilen boşalır.** Canlıdaki 6 kaydın HEPSİ
    (v16/v23/v24 + 3 sürümsüz) eşiğin altında, yani hiçbiri artık isabet
    saymayacak. Bu KASITLI: 10 lookup'lık bir örneklemde kaybedilecek bir şey
    yok, eskimiş kalite servis etmektense yeniden üretmek doğru. Kayıtlar
    PDF'ler yeniden yüklendikçe güncel sürümle EZİLEREK tazelenecek.
  - **✅ DEPLOY EDİLDİ VE CANLI DOĞRULANDI (2026-08-17).**
    `npx supabase functions deploy pdf-cache` (Docker gerekmedi, uzaktan
    bundle). Dört senaryo gerçek uç noktaya atılan isteklerle doğrulandı:

    | Senaryo | Sonuç |
    |---|---|
    | Olmayan hash | `{found:false}` ✓ |
    | Gerçek v16 kayıt + eşik v27 | `{found:false, stale:true, stored_prompt_version:"v16"}`, **`hit_count` ARTMADI** ✓ |
    | Gerçek v16 kayıt + eşik v16 | `{found:true}`, 133 kart, `hit_count` 2→3 ✓ |
    | Eşik hiç gönderilmedi | `{found:true}`, `hit_count` 3→4 ✓ (geriye dönük uyumlu) |

    Yani hem yeni kapı hem ESKİ HIT yolu sağlam; bayat sorgu sayacı
    artırmıyor (filtre doğru yerde, RPC'den ÖNCE). NOT: 3. ve 4. testler
    gerçek HIT olduğu için o kaydın `hit_count`'u 2→4 çıktı — ölçüm
    kaynaklı, gerçek kullanım değil.
  - **`save` TARAFI CANLI DENENMEDİ — BİLİNÇLİ.** Güvenli bir prob yolu yok:
    var olan bir hash'e sahte kartla `save` atmak, mantıkta bir hata olsaydı
    133 gerçek kartı silerdi; olmayan bir hash'e atmak ise silinemeyen bir çöp
    satır bırakırdı (anon DELETE kapalı — 2026-07-21'de tam olarak bu
    yaşanmış, bkz. `20260721000003_cleanup_rls_probe_row.sql`). Ezme dalı
    bir sonraki GERÇEK PDF yüklemesinde kendiliğinden çalışacak: lookup bayat
    diyecek → kartlar yeniden üretilecek → `save` v28 ile kaydı EZECEK.
    **İlk yüklemeden sonra `prompt_version`'ın gerçekten güncellendiğini
    doğrula.**
  - Test: `test/prompt_version_gate_test.dart` (13 test — sürüm ayrıştırma,
    eşik sınırları, sürümsüz kayıt, eşiğin `kPromptVersion`'ı aşmadığı
    güvencesi, istemci gövdesi). Sunucu tarafı (Deno) bu depoda test
    EDİLEMİYOR.

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
- `kPromptVersion` şu an **v30** (2026-08-18: v28→v30,
  `ornekTabanliKartKurali` eklendi — İÇERİK kuralı, bu yüzden
  `kMinCacheablePromptVersion` de 30'a çekildi. **v29 BİLİNÇLİ OLARAK
  ATLANDI, yeniden kullanma:** o numara 2026-08-17'de statik bloğun
  `systemInstruction`'a taşınması denemesinde kullanılmış, canlı ölçümde
  kazanç çıkmayınca değişiklik geri alınmış ve sürüm v28'de kalmıştı; aynı
  numarayı farklı bir anlamla tekrar kullanmak `pdf_cache.prompt_version`
  sütununu ikircikli yapardı.) Öncesi: **v28** (2026-08-17: v27→v28, sayfa numarası
  `buildPagePrompt`'un açılış cümlesinden kaldırıldı — İÇERİK kuralı değişikliği
  DEĞİL, saf maliyet/cache düzeltmesi; bkz. "Context caching" bölümü).
  (DÜZELTME 2026-08-14: bu satır uzun süre
  "v22" diye eski kalmıştı, gerçek dosya o zamandan beri v25'e kadar
  ilerlemişti — sürüm sayısını değiştirirken bu paragrafı da güncellemeyi
  unutma). Tarihçe: v14 → v15 (kompakt biçim), 2026-08-05'te
  üç kez daha arttı — v16 (cevap uzunluğu "1-3"→"2-4" eşitlemesi +
  slaytNumarasi satırındaki yön düzeltmesi), v17 (kapanış/teşekkür slaydı
  filtresi + öncelik kalibrasyonunun sıkılaştırılması), v18
  (`terminolojiStandardiKurali` + `guncellikDiliYasagiKurali` + tablo
  çoklu-öğe eşleştirme kuralı); 2026-08-06'da dört kez daha arttı — v19
  (`elYazisiKurali` vurgu/tasarım ayrımı), v20 (`metinVeGorselBirlikteKurali`
  aynı ayrımla hizalandı), v21 (Yol A "boş dizi" kuralı ders-dışı içeriği
  kapsadı), v22 (aynı kural Yol B'ye eklendi + "5-20 kart" alt sınır
  olmadığı netleşti); 2026-08-12'de flash-lite denemeleri için üç kez daha
  arttı — v23-v25 (sinavTipiKurali/zorlukKurali uzlaştırma cümlesi,
  etiketlemeSonHatirlatmasi "derinlik" dengesi, icerikKalitesiOrnegi somut
  önce/sonra örneği — bkz. "Devam Eden İş" 0.7 kapanış notu, flash-lite
  yine de reddedildi); 2026-08-14'te iki kez daha arttı — v26
  (`kaynakReferansiGizlemeKurali` YENİ eklendi, `guncellikDiliYasagiKurali`
  onunla "çelişmeyecek" diye kaynağa atıf tavsiyesi KALDIRILARAK
  güncellendi — bu YANLIŞ bir düzeltmeydi), v27 (aynı gün, kullanıcı
  düzeltmesiyle: `guncellikDiliYasagiKurali`'ndeki kaynağa atıf tavsiyesi
  GERİ GETİRİLDİ, `kaynakReferansiGizlemeKurali`'ne tedavi/kılavuz için bir
  İSTİSNA maddesi eklendi — iki kural artık KAPSAM AYRIMIYLA bir arada
  yaşıyor, bkz. "Kart Üretim Kuralları"). Hepsinin ayrıntısı "Kart Üretim
  Kuralları" bölümünde. Eski `pdf_cache` kayıtları etkilenmez:
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
- **CANLI DOĞRULANDI (2026-08-17 EKİ):** yukarıdaki "kredi tükendi, teyit
  edilemedi" notu artık ESKİMİŞ. 2026-08-17'deki `usage_metadata`/context
  caching ölçümleri (`tool/measure_cache_test.dart`, bkz. "Context caching")
  gerçek Gemini API çağrılarıyla yapıldı ve `responseSchema` her seferinde
  kabul edildi — aksi halde 400 dönerdi ve o ölçümler hiç çıkmazdı. Şema
  (ARRAY of ARRAY, nullable STRING) fiilen doğrulanmış durumda; şemayı en
  sade hâlinde tutma kararı (`minItems`/`maxItems` yok) hâlâ geçerli ama artık
  "kredi yok, denenemedi" gerekçesiyle değil, kendi başına bilinçli bir tercih
  olarak duruyor.
  - **NOT — pozisyon açıklaması PROMPT METNİNDEN ÇIKARILAMAZ:** Gemini'ın
    şema alt kümesi heterojen ("tuple") dizi desteklemiyor — bir ARRAY'in tek
    `items` şeması olabilir, pozisyona göre farklı tip/anlam veremez. Yani
    şema kartın 9 pozisyonunun HANGİSİNİN ne olduğunu (soru/kisaCevap/zorluk
    kodu/...) hiçbir şekilde taşıyamıyor — bu bilgi yalnızca
    [kartEtiketleriKurali]'ndeki SIRA açıklamasında var. O blok kısaltılıp
    şemaya "devredilemez"; kaldırılırsa model pozisyonların anlamını
    bilmediği için kart üretimi bozulur.
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

**TOKEN SAYIMI HİÇBİR YERDE TUTULMUYOR** (2026-08-06'da arandı, bulunamadı;
**KISMİ DÜZELTME 2026-08-17:** Gemini tarafında artık tutuluyor — bkz.
"Ölçüm altyapısı — `usage_metadata.dart`". GLM tarafı DEĞİŞMEDİ, aşağıdaki
her şey GLM için hâlâ geçerli):
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

`pdf_cache` tablosu (`supabase/migrations/20260721000000_create_pdf_cache.sql`,
`hash`/`generated_cards`/`created_at`) **YAZMA tarafında** aynı RLS-kilitli
desende: INSERT/UPDATE/DELETE'e hiç policy yok, yalnızca `pdf-cache` Edge
Function'ı (service_role, RLS'i bypass eder) yazabiliyor.
**OKUMA tarafında DEĞİL — DÜZELTME (2026-08-17):** bu satır uzun süre
"istemci doğrudan hiç dokunmaz" diyordu, YANLIŞTI. Bir gün sonraki
`20260721000002_pdf_cache_public_read.sql` migration'ı okumayı KULLANICI
İSTEĞİYLE anon+authenticated'e AÇMIŞ (gerekçe: "paylaşılan, herkese açık bir
önbellek — içerik hassas değil"). Yani anon key'i olan herkes
`generated_cards` dahil tüm satırları okuyabilir; bu bilinçli bir tasarım
kararı, açık değil. Canlı doğrulandı (2026-08-17). Bkz. "Maliyet
Optimizasyonu".

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
- **Gemini Flex service tier — DEĞERLENDİRİLDİ VE REDDEDİLDİ (2026-08-17).**
  `serviceTier: "FLEX"` (istek gövdesinin en üst seviyesinde, `generationConfig`
  içinde DEĞİL) maliyet düşürme kaldıracı olarak incelendi. Kod okunarak üç
  şey doğrulandı:
  - Kart üretimi tamamen SENKRON/kullanıcı-bekletmeli: `PdfImportScreen`
    öğrenciyi ilerleme ekranında tutuyor (`PopScope(canPop: !_running)`,
    "Bu pencereyi açık tut." metni), arka planda devam eden bir iş kuyruğu/
    bildirim mekanizması YOK — sekme kapanırsa iş durur.
  - Tek istek timeout'u sabit **120 saniye**
    (`GeminiTransport.defaultRequestTimeout`, `gemini_transport.dart`) ve
    timeout'lar BİLİNÇLİ olarak yeniden denenmiyor (`isTimeout` hem
    transport hem `PdfCardPipeline._generateWithRetry` seviyesinde rethrow
    ediliyor — "sağlayıcı üretimi tamamlayıp faturalamış olabilir, tekrar
    denemek çift ödeme demek").
  - Paralellik (`concurrency: 4`, bağımsız worker havuzu) Flex'in
    dakikalarca sürebilen gecikmesine yapısal olarak UYGUN (bir sayfa yavaş
    kalınca diğer worker'ları BEKLETMİYOR) — ama yukarıdaki 120sn'lik sabit
    timeout bu avantajı test etmeye bile fırsat bırakmadan isteği zaten
    kesiyor.
  - **KARAR:** Flex'in 1-15 dakikalık belirsiz yanıt süresi, mevcut
    senkron/kullanıcı-bekletmeli mimariyle UYUMSUZ. Gerçek bir arka plan/
    asenkron iş kuyruğu mimarisi (öğrenci ekrandan ayrılabilir, kartlar
    hazır olunca bildirim/güncelleme gelir) kurulmadan Flex UYGULANMAYACAK.
  - **YENİDEN DEĞERLENDİRME KOŞULU:** yalnızca launch SONRASI, eğer zaten
    arka planda çalışan bir üretim akışı ortaya çıkarsa (ör. lazy açıklama
    üretimi, toplu deste yenileme gibi kullanıcının o anda ekranda
    beklemediği bir akış) — o zaman Flex o akış için tekrar masaya
    yatırılabilir. Mevcut senkron PDF→kart akışı için gündemde DEĞİL.

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
- Kart metninde (soru/şık/açıklama) "slayta göre", "kaynağa göre", "tabloya
  göre", "sunuma göre" gibi kaynak atfı kullanma — **TEDAVİ/KILAVUZ/GÜNCEL
  PRATİK bilgisi HARİÇ** (`guncellikDiliYasagiKurali`'nin kapsamı — orada
  "slayta göre" ZORUNLU, bu bir güvenlik önlemi, stil tercihi değil).
  `kaynakReferansiGizlemeKurali` (2026-08-14, v27) bu ikisini bir İSTİSNA
  maddesiyle ayırıyor; ikisinden birini diğerinin tavsiyesine göre "tutarlı
  hâle getirmeye" çalışıp KALDIRMA — v26'da tam bu hata yapılmıştı
  (`guncellikDiliYasagiKurali`'ndeki atıf tavsiyesi silinmişti) ve kullanıcı
  aynı gün v27'de düzeltti. İkisi KASITLI olarak kapsam ayrımıyla bir arada
  duruyor, bkz. "Kart Üretim Kuralları".
- **`buildPagePrompt`'un gövdesine sayfaya/isteğe göre DEĞİŞEN bir şey yazma**
  (sayfa numarası, dosya adı, tarih, cihaz kimliği, rastgele id...) — prompt
  ön ekinin sabit kalması Gemini'ın %90 indirimli context cache'inin TEK
  koşulu. Değişken her şey prompt'un SONUNDAKİ `SAYFA N METNİ:` bloğuna
  gitmeli. Bu tam olarak v27'de var olan ve v28'de düzeltilen hataydı; geri
  getirmek sayfa başı maliyeti ~%39 artırır (bkz. "Context caching").
- `maxOutputTokens`'ı maliyet düşürmek için indirme — TASARRUF ETMEZ. Yalnızca
  üretilen token faturalanır; 4096 bir TAVAN, bütçe değil (tipik sayfa zaten
  ~1.080 token üretiyor). İndirmek sadece yoğun tablo sayfalarını yarıda keser
  = doğrudan kapsam kaybı.
- Maliyet için PDF sayfalarını birleştirip tek istekte gönderme — belgelenmiş
  "kart tavanına çarpıp tabloları atlama" sorununu geri getirir ve `sourcePage`
  damgasını bozar. Context caching aynı kazancı bu risk olmadan sağlıyor.
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
- Kaynakta somut örnek YOKKEN örnek/uygulama kartı üretme (ya da modelden
  istemesini sağlayacak şekilde `ornekTabanliKartKurali`'ni gevşetme) —
  uydurulmuş örnek, kaynak sadakatinin ihlali. Bu kuralı `sinavTipiKurali` ile
  "tutarlı hale getirmek" için birini kırpma; çakışma bilerek arbitre
  edilmedi (bkz. "Kart Üretim Kuralları"). **2026-08-18 A/B'si
  kuralı AKLADI** — kart fazlalığı ondan gelmiyor (%34,7 kuralsız vs %32,7
  kurallı), o yüzden "fazlalık var" gerekçesiyle kırpma.
- **`zorlukKurali`'ni prompt'a GERİ EKLEME** — 2026-08-20'de (v31) bilinçli
  olarak kaldırıldı, A/B ile karar verildi (kural `sinavTipiKurali` olmadan
  tek bir "zor" üretemiyordu; formül sayfasında bile 0/8 ve 0/13). Zorluk
  artık yalnızca `SrsEngine.deriveDifficulty` ile çalışma performansından
  geliyor. Kompakt dizinin [3]. pozisyonuna sabit `"o"` yazılıyor —
  **pozisyonu silme/kaydırma.** Bkz. "`zorlukKurali` KALDIRILDI" bölümü.
- **`SrsEngine.initialEase`'in üç dalını sadeleştirme** ("nasılsa hep orta
  geliyor" diye) — v31 ÖNCESİ kartlar ve elle ayarlanmış (`difficultyManual`)
  kartlar hâlâ `kolay`(2.6)/`zor`(2.3) dallarından geçiyor; sadeleştirmek
  onların zamanlamasını sessizce değiştirir.
- **`sinavTipiKurali`'ni "artık zorlukKurali de yok" diye kaldırma** — o
  kural TUS eklentisi mimarisinin ayrı bir işi ve v31'de KASITLI olarak
  bırakıldı. Kaldırılırsa çağrı başına kart sayısı ~%22 düşer (ölçüldü).
- Zorluk ve kart tipini BAĞIMSIZ iki boyut varsayan yeni bir filtre/UI/istatistik
  tasarlama — ölçümde değiller (6 hücrenin 2'si yapısal olarak boş, zorluk
  filtresindeki "Zor" fiilen "sınav tipi" ile aynı kümeyi veriyor).
- **Çalışma ekranına "Sınav Modu" switch'ini geri ekleme** — 2026-08-19'da
  ölçümle fazlalık olduğu görülüp KALDIRILDI ("Zor" çipi seçiliyken etkisi
  SIFIRDI, ayrıca "Deneme Sınavı" ile adı çakışıyordu). Bkz. "Sınav Modu
  switch'i kaldırıldı". Havuzu daraltan YENİ bir switch eklemeden önce de
  aynı ölçümü oku.
- `CardFilter.examOnly` alanını/`withExamOnly`'yi modelden silme — switch
  kaldırıldı ama alan ve testleri BİLİNÇLİ olarak duruyor (kullanıcı kararı).
  Bugün hiçbir çağıran `true` göndermiyor; "ölü kod" diye temizlemeye
  kalkmadan önce sor.
- `kPromptVersion`'da v29'u kullanma — denenip geri alınmış bir numara, atlandı.
- `emptyResultPages`'i `failedPages`'e karıştırma / hata gibi raporlama —
  modele gidip `[]` dönmek kuralın BEKLEDİĞİ davranış (kapak/ajanda/kapanış
  slaytı). Oranı hesaplarken payda `billedPages`, `totalPages` DEĞİL (bkz.
  "Boş sayfa ölçümü").
- `pdf_isleme_olcum`'a yazımı kullanıcı akışına bağlama (await etme, hatasını
  yüzeye çıkarma) — telemetri, kart üretiminin başarısı buna bağlı olmamalı.
- `TopicScanService.model`'i "tutarlılık olsun" diye `GeminiService.model`'e
  geri bağlama — konu ön-taraması bilinçli olarak daha ucuz flash-lite'ı
  kullanıyor ve bu, kart üretimi için verilmiş flash-lite retiyle çelişmiyor
  (kapsamlar ayrık, bkz. "Konu ön-taraması (`TopicScanService`)"). Modeli
  değiştirirsen `thinkingConfig` guard'ının da AYNI sabite baktığından emin ol,
  yoksa flash-lite'a thinkingConfig gidip her istek 400 döner.
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
