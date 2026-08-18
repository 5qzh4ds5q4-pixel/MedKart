# MedKart — Kod Tabanı Durum Raporu

**Tarih:** 2026-08-18 · **Branch:** `main` · **Son commit:** `dd6209f` (2026-08-17)
**Test:** 737/737 yeşil · **`flutter analyze`:** 120 issue (baseline; bu oturumun değişiklikleri 0 yeni uyarı ekledi)

> Bu rapor CLAUDE.md'nin özeti DEĞİL — her madde bu oturumda kod okunarak,
> canlı DB sorgulanarak ya da test çalıştırılarak yeniden doğrulandı.
> Doğrulanamayan / kanıtla çelişen iddialar **açıkça işaretlendi** (bkz. §9).

**Kanıt seviyeleri:** `ÖLÇÜLDÜ` (gerçek çalıştırma / canlı veri) · `HESAPLANDI`
(gerçek parametrelerden türetilmiş aritmetik) · `KOD OKUMASIYLA DOĞRULANDI`
(kaynak dosya okundu) · `TAHMİN` (dayanağı zayıf — karar dayanağı yapma)

---

## 1. AI SAĞLAYICI VE MODEL

| Ne | Değer | NEREDE | KANIT |
|---|---|---|---|
| Aktif sağlayıcı | **`AiProvider.gemini`** | `lib/services/ai_provider_config.dart:23` | KOD OKUMASIYLA DOĞRULANDI |
| Ana kart üretimi modeli | **`gemini-3.5-flash`** | `lib/services/gemini_service.dart:56` | KOD OKUMASIYLA DOĞRULANDI |
| Konu ön-taraması modeli | **`gemini-3.5-flash-lite`** | `lib/services/topic_scan_service.dart:56` | KOD OKUMASIYLA DOĞRULANDI |
| Sağlayıcı → servis eşlemesi | üç dallı `switch` | `lib/main.dart:23-30` | KOD OKUMASIYLA DOĞRULANDI |

### 1.1 Hardcoded model referanslarının TAM listesi

Kod tabanında model string'i geçen **her** yer tarandı (`lib/`, `supabase/`):

| Model string | NEREDE | Durum |
|---|---|---|
| `gemini-3.5-flash` | `gemini_service.dart:56` | **AKTİF** — ana kart üretimi |
| `gemini-3.5-flash-lite` | `topic_scan_service.dart:56` | **AKTİF** — yalnızca konu ön-taraması |
| `gemini-3.5-flash-lite` | `gemini_service.dart:43` | Aktif ama model SEÇİMİ değil — `supportsThinkingConfig` guard'ının karşılaştırma sabiti |
| `deepseek-chat` | `deepseek_service.dart:38` | Ölü kod değil ama ULAŞILMAZ (`activeAiProvider` gemini olduğu sürece) |
| `z-ai/glm-4.5v` | `glm_service.dart:47` | Aynı şekilde ulaşılmaz — altyapı duruyor, aktif seçim değil |

**Üretimde EŞ ZAMANLI İKİ Gemini modeli çalışıyor.** Bu 2026-08-18'de yapılmış
bilinçli bir ayrım, kaza değil.

### 1.2 Flash-lite geçişi gerçekten uygulandı mı?

**EVET, uygulandı ve hâlâ yürürlükte.** `KOD OKUMASIYLA DOĞRULANDI`:

- `TopicScanService.model = 'gemini-3.5-flash-lite'` — `topic_scan_service.dart:56`
- İstek gerçekten bu modele gidiyor: `_transport.send(model: model, ...)` — `topic_scan_service.dart:124`
- **KRİTİK GUARD:** `thinkingConfig`, servisin KENDİ modeline göre koşullanıyor
  (`topic_scan_service.dart:117`). Flash-lite bu alanı hiç kabul etmiyor
  (400 `INVALID_ARGUMENT`; `gemini_service.dart:32-43` doc yorumunda 2026-08-07
  tarihli canlı doğrulama kayıtlı). Guard 2026-08-18'e kadar
  `GeminiService.model`'e bakıyordu — yalnızca `send`'in modeli değiştirilseydi
  **her ön-tarama isteği 400 ile ölürdü.**
- **YAN ETKİ:** flash-lite `thinkingConfig` kabul etmediği için bu çağrıda
  `thinkingBudget: 0` artık GÖNDERİLEMİYOR; thinking davranışı modelin kendi
  varsayılanına kalıyor, kodla bastırılamıyor. Ana kart üretiminde
  (`gemini-3.5-flash`) `thinkingBudget: 0` aynen duruyor (`gemini_service.dart:18`).
- Ön-tarama gerçekten UI akışında: `add_cards_screen.dart:203` →
  `PdfTopicSelectionScreen` → `TopicScanService`.
- Test: `test/topic_scan_service_test.dart` istek zarfındaki `model`'in
  `TopicScanService.model` olduğunu ve guard'ın o modele göre karar verdiğini
  sabitliyor. `ÖLÇÜLDÜ` (test yeşil)

Ön-taramanın flash-lite kullanması, flash-lite'ın kart üretimi için
REDDEDİLMİŞ olmasıyla **çelişmez** — bkz. §4.2, kapsamlar ayrık.

---

## 2. PROMPT SÜRÜMÜ VE İÇERİK KURALLARI

| Ne | Değer | NEREDE | KANIT |
|---|---|---|---|
| `kPromptVersion` | **`v30`** | `lib/services/flashcard_prompt.dart:85` | KOD OKUMASIYLA DOĞRULANDI |
| `kMinCacheablePromptVersion` | **`30`** | `flashcard_prompt.dart:55` | KOD OKUMASIYLA DOĞRULANDI |

**v29 BİLİNÇLİ OLARAK ATLANDI.** O numara 2026-08-17'de `systemInstruction`
denemesinde kullanıldı, canlı ölçümde kazanç çıkmadı, geri alındı ve sürüm
v28'de kaldı (bkz. §4.3). Aynı numarayı farklı anlamla tekrar kullanmak
`pdf_cache.prompt_version` sütununu ikircikli yapardı.

### 2.1 Kural envanteri — HEPSİ AKTİF

Her kural sabiti tek tek grep'lendi ve prompt'a gerçekten enterpole edildiği
doğrulandı. "A+B" = hem Yol A (`buildPageSystemInstruction`) hem Yol B
(`buildGeneralPrompt`). Tümü `KOD OKUMASIYLA DOĞRULANDI`:

| Kural | Satır | Yol | Ne yapar |
|---|---|---|---|
| `sinavTipiKurali` | :90 | A+B | Klinik/patolojik HER ilişki için senaryo kartı ZORUNLU |
| `icerikKalitesiOrnegi` | :103 | A+B | Zayıf/güçlü kart önce-sonra örneği (Bruselloz) |
| **`ornekTabanliKartKurali`** | **:132** | **A+B** | **YENİ (v30)** — aşağı bkz. |
| `cevapSadeligiKurali` | :142 | A+B | Cevap uzunluğu / sadeliği |
| `ikiKatmanliCevapKurali` | :155 | A+B | `kisaCevap` + `cevap` ayrı ayrı üretilir |
| `zorlukKurali` | :162 | A+B | kolay/orta/zor kalibrasyonu (tıp uzmanı geri bildirimiyle) |
| `kaynakSadakatiKurali` | :171 | A+B | Kaynakta olmayanı üretme |
| `terminolojiStandardiKurali` | :188 | A+B | 6 terimin yazım standardı; liste KAPALI |
| `guncellikDiliYasagiKurali` | :210 | A+B | "güncel kılavuza göre" YASAK; tedavide "slayta göre" ZORUNLU |
| `kaynakReferansiGizlemeKurali` | :234 | A+B | Kaynağa atıf YASAK — tedavi/kılavuz İSTİSNA |
| `oncelikKurali` | :246 | A+B | oncelikli/arkaPlan ayrımı ("şıkkı ayırt ettirir mi?") |
| `elYazisiKurali` | :263 | A+B (görselli) | El yazısı/vurgu ile slaydın tasarım dili ayrımı |
| `belirsizElYazisiKurali` | :300 | A+B (görselli) | Emin değilsen `false` |
| `etiketlemeSonHatirlatmasi` | :318 | A+B (görselli) | Etiketleme + derinlik dengesi |
| `slaytNumarasiKurali` | :337 | **YALNIZ A** (görselli) | Slaydın basılı numarasını oku (sayfa kayması düzeltmesi) |
| `kartEtiketleriKurali` | :355 | A+B | Kompakt 9 elemanlı dizi biçimi |
| `metinVeGorselBirlikteKurali` | :384 | **YALNIZ A** (görselli) | Metin + görsel önceliklendirme |

**Kaldırılmış kural YOK.** v22'den beri tek geri alma, `guncellikDiliYasagiKurali`
içindeki "kaynağa atıf yap" tavsiyesiydi — v26'da yanlışlıkla silindi, v27'de
GERİ GETİRİLDİ ve çakışma `kaynakReferansiGizlemeKurali`'ne eklenen İSTİSNA
maddesiyle çözüldü.

### 2.2 v22 → v30 sürüm tarihçesi

`KOD OKUMASIYLA DOĞRULANDI` (kod yorumları + `git log`):

| Sürüm | Tarih | Değişiklik | Commit |
|---|---|---|---|
| v19–v22 | 08-06/08 | El yazısı/vurgu ayrımı, terminoloji, boş-dizi kuralının ders-dışı içeriğe genişletilmesi (v21=Yol A, v22=Yol B) | `ad67035` |
| v23–v25 | 08-12/13 | Flash-lite için üç uzlaştırma/denge/örnek cümlesi — **flash-lite yine de reddedildi, cümleler KALDI** | `817c4e8` |
| v26 | 08-14 | `kaynakReferansiGizlemeKurali` eklendi + güncellik tavsiyesi YANLIŞLIKLA kaldırıldı | `6995f45` |
| v27 | 08-14 | Aynı gün düzeltme: tavsiye geri geldi, çakışma İSTİSNA maddesiyle çözüldü | `6995f45` |
| v28 | 08-17 | `(sayfa N)` açılış cümlesinden kaldırıldı — saf cache/maliyet, İÇERİK DEĞİŞMEDİ | `0a67c31` |
| ~~v29~~ | 08-17 | `systemInstruction` denemesi — GERİ ALINDI, hiç yayınlanmadı | `b361ac5` |
| **v30** | **08-18** | **`ornekTabanliKartKurali` eklendi — İÇERİK kuralı** | (henüz commit'lenmedi) |

### 2.3 v30 — `ornekTabanliKartKurali` (`flashcard_prompt.dart:132`)

Kaynakta bir kavramın TANIMININ YANINDA somut örnek varsa, tanım kartına **EK**
(yerine değil) bir tanıma/uygulama kartı üretilir. Prompt'ta yanlış/doğru örnek
çifti var. **En kritik maddesi:** kaynakta örnek YOKSA bu kart tipi üretilmez —
uydurulmuş örnek, kaynak sadakatinin ihlali.

- Boyut: **988 karakter ≈ +323 token/istek**, her iki yolda. `HESAPLANDI`
  (3,06 karakter/token — §3.2'de ölçülmüş oran)
- Test: `test/ornek_tabanli_kart_kurali_test.dart` (8 test). `ÖLÇÜLDÜ`
- **Eşik neden 30'a çekildi:** kural üretilen kart KÜMESİNİ değiştiriyor;
  v27/v28 kayıtları örnek kartlarını hiç taşımaz. Bugünkü pratik maliyeti
  sıfır — canlı önbellekteki kayıtların en yenisi zaten v24'tü.

---

## 3. CACHE MİMARİSİ — ÜÇ AYRI KATMAN

> Bu üç şey sürekli birbirine karışıyor. Farklı katmanlar, farklı sorunlar.

### 3.1 Katman 1 — PDF-seviyeli cache (`pdf_cache`) · ÇALIŞIYOR

İçerik bazlı SHA-256 (`PdfCacheService.hashBytes`, dosya adından bağımsız);
isabette Gemini'ye HİÇ gidilmez, kota da harcanmaz. Yalnızca **TÜM PDF**
işlendiğinde geçerli (daraltılmış çalıştırma ne okur ne yazar). Hash el yazısı
anahtarını içerir (`:novision` soneki) — iki mod ayrı raflarda.

- Sunucu: `supabase/functions/pdf-cache/index.ts` (`lookup` / `save`)
- **Bayatlık kapısı** (2026-08-17, `9a23c8c` + deploy `2005b33`): lookup
  `min_prompt_version`'dan eski kaydı isabet SAYMIYOR ve `hit_count`
  ARTIRMIYOR; `save` daha yeni sürüm gelirse kaydı EZİYOR. Dört senaryo canlı
  uç noktaya istek atılarak doğrulandı. `ÖLÇÜLDÜ`

**CANLI DURUM (2026-08-18'de sorgulandı) — `ÖLÇÜLDÜ`:**

| hash | tarih | prompt | hit_count |
|---|---|---|---|
| `fb81427e` | **2026-08-18** | **v30** | 0 |
| `89e31aab` | 08-08 | v24 | 0 |
| `68144c37` | 08-07 | v23 | 1 |
| `fe752b78` | 08-05 | v16 | 4 |
| `233814c3` | 08-05 | v16 | 0 |
| `a49c388b` | 07-27 | (yok) | 1 |
| `8a4cbd8e` | 07-26 | (yok) | 0 |
| `smoketest-…` | 07-21 | (yok) | 0 ← test artefaktı |

- **Efektif isabet oranı bugün %0.** 8 kaydın yalnızca 1'i (v30) eşiği geçiyor
  ve onun `hit_count`'u 0. Diğer 7'si bayat. Bu **beklenen ve kasıtlı.**
- **Geçmişteki "%40 isabet" rakamı GEÇERSİZ, plan yaparken kullanma.** `TAHMİN`
  seviyesindeydi: ~10 lookup'lık örneklem, tek kullanıcının test dönemi.
  Ayrı ölçüm tablosuna geçilmesinin sebeplerinden biri tam olarak buydu (§3.3).
- **`pdf_cache` anon key ile OKUNABİLİR — açık değil, KASITLI**
  (`20260721000002_pdf_cache_public_read.sql`). Yazma kapalı (INSERT/UPDATE/
  DELETE'e policy yok). `ÖLÇÜLDÜ` (anon SELECT 200; migration list 11/11 eşleşti)

### 3.2 Katman 2 — Gemini örtük (implicit) context cache · **GÖRSELLİ YOLDA ÖLÜ**

| Deneme | Sonuç | KANIT |
|---|---|---|
| v28: prompt ön ekini sabitle (görselSİZ yol) | **ÇALIŞIYOR** — 4 ardışık çağrıda isabet, ama ön ekin yalnızca **~%37'si** (1.983 token, üç çağrıda da sabit) önbelleklendi | `ÖLÇÜLDÜ` (`tool/measure_cache_test.dart`) |
| Gerçek tasarruf (görselsiz) | **%12,6** — vaat edilen %38,7 değil | `HESAPLANDI` (ölçülen token'lardan) |
| v29: statik bloğu `systemInstruction`'a taşı | 4 çağrının 4'ünde `cache=YOK` | `ÖLÇÜLDÜ` |
| Görseli `contents`'in sonuna al | 4 çağrının 4'ünde `cache=YOK` | `ÖLÇÜLDÜ` |

**KESİN SONUÇ: sorun görselin KONUMU değil, VARLIĞI.** Inline görsel taşıyan
istekler Gemini'ın örtük cache'ine hiç girmiyor. Bu, "parça sırasını değiştir"
ve "systemInstruction'a taşı" seçeneklerinin İKİSİNİ DE öldürüyor.

**Üretimin varsayılanı görselli yol** (`add_cards_screen.dart:43`,
`_hasHandwriting = true`) — yani **v28'in üretimdeki fiili kazancı ~0.**
v28 yine de kodda: görselsiz yolu bugünden ucuzlatıyor ve ön koşul olarak duruyor.

- Karakter→token oranı **3,06** olarak ölçüldü; eski 3,7 tahmini %21 düşüktü,
  ona dayanan tüm eski token rakamları düşük tahmindir.
- **Açık (explicit) cache HİÇ DENENMEDİ**, launch sonrasına askıda. Denemenin
  kendisi bile `ai-proxy` değişikliği + deploy gerektiriyor.

### 3.3 Katman 3 — `pdf_isleme_olcum` (YENİ, 2026-08-18) · HENÜZ VERİ YOK

Cache DEĞİL, **telemetri**. Çalıştırma başına bir satır: `toplam_sayfa`,
`metin_yok_sayfa`, `hatali_sayfa`, **`bos_donen_sayfa`**, `kart_ureten_sayfa`,
`uretilen_kart`, `bos_sayfa_no`, sürümler, `gorsel_acik`, `kota_kesildi`.

- Migration `20260818000000_create_pdf_isleme_olcum.sql`, **canlıya alındı**
  (`supabase db push`). Varlık doğrulandı: anon SELECT 200 + `[]`, olmayan
  tablo 404. `ÖLÇÜLDÜ`
- Yazan: `lib/services/pipeline_metrics_service.dart` ←
  `lib/screens/pdf_import_screen.dart:109` (`unawaited`, best-effort).
- Kaynak alan: `PipelineResult.emptyResultPages` (`pdf_card_pipeline.dart:54`,
  doldurma `:220`) + oranın doğru paydası `billedPages` (`:73`).
- **Neden `pdf_cache`'e sütun değil, ayrı tablo:** `pdf_cache` PDF başına bir
  satır tutar (zaman serisi olmaz) ve yazımı yalnızca *tam PDF + cache MISS +
  ≥1 kart* koşulunda olur — daraltılmış çalıştırmalar, cache HIT'ler ve sıfır
  kartlı çalıştırmalar sistematik olarak dışarıda kalırdı, ki ölçülmek istenen
  uçlar tam da bunlar. Ayrıca sütun eklemek `pdf-cache` Edge Function'ını
  değiştirip DEPLOY etmeyi gerektirirdi.
- **VERİ MİKTARI DOĞRULANAMADI:** RLS `auth.uid() = user_id` olduğu için anon
  key'le satır sayılamıyor (`Content-Range: */0`, anon'un GÖRDÜĞÜ sayı — gerçek
  toplam değil). Toplu analiz Supabase panelinden service_role ile yapılmalı.

---

## 4. REDDEDİLEN / GERİ ALINAN DENEMELER

### 4.1 GLM-4.5V (OpenRouter) — REDDEDİLDİ

**Ne denendi:** üçüncü sağlayıcı, görsel destekli, uçtan uca çalışır hale
getirildi (`glm_service.dart`, `glm_transport.dart`, `ai-proxy`'nin `glm` dalı,
32 test). İki gerçek PDF çalıştırması: 145 + 157 = 302 kart. Commit `ad67035`.

**Bulgu:** klinik vaka kartları güçlü; **ama el yazısı/vurgu güvenilirliğinde
tekrarlayan sorunlar** — yanlış okuma + kaynakta olmayan bilgi uydurma, ayrıca
kartların %20+'sinde hatalı `elYazisindanMi: true`. `ÖLÇÜLDÜ`

**Maliyet:** girdi $0,592/M, çıktı $1,80/M; toplam ≈ $0,4551, kart başına
≈ $0,0015. `ÖLÇÜLDÜ` (yanıtın `cost_details` bloğundan hesaplandı)

**Neden reddedildi:** el yazısı güvenilirliği bu ürünün ayırt edici özelliği
("Hocanın Favorileri"). Kod SİLİNMEDİ, ulaşılmaz halde duruyor.

### 4.2 `gemini-3.5-flash-lite` — ANA ÜRETİM İÇİN REDDEDİLDİ

**Ne denendi:** ana kart üretim modelini flash-lite'a çekmek + üç ayrı prompt
tekniği (v23→v25). 2026-08-12.

**Bulgu:** yüzeysel / tanım-düzeyi kart üretme eğilimi (derinlik sorunu);
**hiçbir prompt tekniği çözemedi.**

**Kanıt sınırı:** bu değerlendirmenin KENDİ COMMIT'İ YOK (`git log` 08-08 →
08-10 atlıyor) — bayrak çevirmeyle yapılmış ve geri alınmış. Bulgular yalnızca
CLAUDE.md ve kod yorumlarında yaşıyor, ölçüm ayrıntısı yeniden üretilemez.
`TAHMİN`

**KAPSAM:** ret **kart üretimi** içindir. 2026-08-18'de konu ön-taraması
flash-lite'a alındı (§1.2) — orada üretilen şey kart değil, 1-4 kelimelik
başlık; derinlik gerekmiyor. Çelişki yok.

### 4.3 `systemInstruction`'a taşıma (v29) — GERİ ALINDI

Commit `b361ac5`. Dört çağrının dördünde `cache=YOK`. `ÖLÇÜLDÜ`
Ölçülebilir faydası olmayan ama kart kalitesini etkileyebilecek (kurallar user
turn yerine system instruction'a taşınıyordu) bir değişikliği tutmanın anlamı
yoktu. **Bölme korundu** (`buildPageSystemInstruction` / `buildPageUserContent`):
prompt metnini değiştirmiyor, cache sınırını kodda görünür kılıyor;
`test/page_prompt_split_test.dart` bu sınırı değişmez olarak koruyor.

### 4.4 Görsel sırası değişikliği — REDDEDİLDİ

Aynı commit. Görseli `contents`'in sonuna almak da cache'i açmadı — bu, sorunun
görselin KONUMU değil VARLIĞI olduğunu kanıtladı. `ÖLÇÜLDÜ`

### 4.5 ⚠️ "Flex service tier" — BU DENEME KOD TABANINDA YOK

`service_tier` / `serviceTier` araması `lib/`, `supabase/`, `test/`, `tool/`
genelinde **HİÇBİR SONUÇ** vermedi. (`Flex` / `flex` eşleşmeleri Flutter'ın
layout widget'ları.) CLAUDE.md'de de geçmiyor, `git log`'da da yok.
**Böyle bir deneme yapıldıysa bu depoda iz bırakmamış.** `KOD OKUMASIYLA DOĞRULANDI`

### 4.6 ⚠️ "Hibrit OCR (görselsiz varsayılan)" — BU HÂLİYLE YOK

`OCR` / `tesseract` araması hiçbir sonuç vermedi. **Kısmen karşılığı olan şey:**
el yazısı/işaretleme anahtarı (`add_cards_screen.dart:43`) — kapatılırsa sayfa
görüntüsü hiç render edilmez, yalnızca pdf.js metni gönderilir (sıfır görsel
token). Ama bu bir OCR entegrasyonu DEĞİL ve **varsayılanı AÇIK**
(`_hasHandwriting = true`), yani "görselsiz varsayılan" hiç uygulanmadı.
Uygulanamaz da: görselsiz mod el yazısı yakalamayı tamamen kaybeder.
`KOD OKUMASIYLA DOĞRULANDI`

---

## 5. MALİYET DURUMU

### 5.1 Sayfa başına maliyet

| Senaryo | Değer | KANIT |
|---|---|---|
| Tipik sayfa (6 kart), görselli / varsayılan | **$0,0213** | `HESAPLANDI` (2026-08-17, koddan türetildi) |
| Yoğun / tablo sayfa (22 kart) | $0,0476 | `HESAPLANDI` |
| Teorik tavan (4096 çıktı token dolu) | $0,0488 | `HESAPLANDI` |
| Eski referans (2026-07-18) | $0,019 | `ÖLÇÜLDÜ` — ama **`shortAnswer` ÖNCESİ ve v22 öncesi prompt ile** |

**GÖRSELLİ (varsayılan) AKIŞTA SAYFA BAŞI MALİYET HİÇ CANLI ÖLÇÜLMEDİ.**
$0,0213 kod parametrelerinden türetilmiş bir hesaptır. Canlı ölçüm yalnızca
**görselsiz** yolda yapıldı (2026-08-17, `tool/measure_cache_test.dart`).
Ölçüm altyapısı hazır (`lib/services/usage_metadata.dart`) ama çıktısı tarayıcı
konsoluna gidiyor, kalıcı değil.

Parametreler (`KOD OKUMASIYLA DOĞRULANDI`): `maxOutputTokens = 4096`
(`gemini_service.dart:96`), `thinkingBudget: 0` (`:18`), `temperature: 0.4`
(`:133`, `:207`), aylık sert tavan `MONTHLY_PAGE_CAP` (`ai-proxy/index.ts:176`).
Secret'ın **VARLIĞI doğrulandı, DEĞERİ okunamaz** — CLAUDE.md 500 sayfa/ay
diyor, bu `TAHMİN`.

### 5.2 Hangi optimizasyon gerçekten tasarruf sağladı?

| Optimizasyon | Sonuç | KANIT |
|---|---|---|
| `thinkingBudget: 0` (Gemini) | Sağladı — thinking tokenı çıktı fiyatından faturalanır | KOD OKUMASIYLA DOĞRULANDI |
| GLM'de `reasoning: none` | **%52 ucuzlattı** (124 → 41 çıktı tokenı) | `ÖLÇÜLDÜ` — ama sağlayıcı aktif değil |
| Kompakt 9 elemanlı dizi biçimi | Yoğun sayfada **+$0,0043/sayfa net kazanç**, tipik sayfada başa baş | `HESAPLANDI` |
| `maxOutputTokens` 8192 → 4096 | Tavan düştü ama **gerçek tasarruf ~0** — yalnızca üretilen token faturalanır | KOD OKUMASIYLA DOĞRULANDI |
| v28 prompt ön eki (görselSİZ yol) | **%12,6 tasarruf** | `ÖLÇÜLDÜ` |
| v28 (görselli / varsayılan yol) | **SIFIR** — görsel cache'i tamamen kırıyor | `ÖLÇÜLDÜ` |
| `pdf_cache` (PDF-seviyeli) | Mekanizma çalışıyor ama **bugün efektif isabet %0** | `ÖLÇÜLDÜ` |
| El yazısı anahtarı KAPALI | Görsel tokenı sıfırlanır — ama varsayılan AÇIK, üretimde kazanç yok | KOD OKUMASIYLA DOĞRULANDI |

**NET: bugün üretimin varsayılan akışında aktif ve ölçülmüş HİÇBİR cache
tasarrufu yok.** Tek gerçek kaldıraçlar `thinkingBudget: 0` ve kompakt çıktı
biçimi. v30'un +323 token/istek eklemesi maliyeti bir miktar ARTIRIYOR.

---

## 6. KART ÜRETİM ŞEMASI

### 6.1 Modelin döndürdüğü biçim — 9 elemanlı KOMPAKT DİZİ

Alan adlı nesne DEĞİL. Pozisyonlar `flashcard_prompt.dart:406-414`
(`KOD OKUMASIYLA DOĞRULANDI`):

| # | Alan | Not |
|---|---|---|
| 0 | `soru` | |
| 1 | `kisaCevap` | 3-8 kelime |
| 2 | `cevap` | 2-4 cümle |
| 3 | `zorlukKodu` | `k` / `o` / `z` |
| 4 | `kartTipiKodu` | `t` / `s` |
| 5 | `oncelikKodu` | `o` / `a` |
| 6 | `konu` | |
| 7 | `slaytNumarasi` | yalnız Yol A, görselli |
| 8 | `elYazisindanMi` | |

**TUZAK:** `"o"` 3. pozisyonda *orta*, 5. pozisyonda *oncelikli*. Bilinmeyen
pozisyona `null` yazılır, ATLANMAZ (yoksa sıra kayar). `sourcePage` dizide YOK
— backend damgalıyor.

### 6.2 `Flashcard` modelinin persist edilen alanları — 21 alan

Bugünkü v30 çalıştırmasının gerçek JSON'undan okundu. `ÖLÇÜLDÜ`

`id, question, shortAnswer, answer, deckId, topic, note, cardType, priority,
difficulty, difficultyManual, isHandwritten, sourcePage, flagged,
originalQuestion, originalAnswer, intervalDays, easeFactor, repetitions,
lapses, nextReview`

### 6.3 `cardType` — TAM OLARAK İKİ DEĞER

`lib/models/flashcard.dart:28-30`: `temel` ('Temel'), `sinav` ('Sınav Tipi').
Başka değer YOK. `KOD OKUMASIYLA DOĞRULANDI`
Karıştırılmaması gereken ayrı enum: `CardPriority { oncelikli, arkaPlan }`
(`:51-53`).

> **ÖNEMLİ:** v30'un ürettiği "örnek/uygulama kartı" için **AYRI BİR `cardType`
> YOK.** `temel` ya da `sinav` olarak etiketleniyor — yani veri modelinde
> tanınamıyor, ölçülemiyor, filtrelenemiyor. Bkz. §7.1.

### 6.4 `responseSchema` — kullanılıyor ama ÇOK SIĞ

`flashcard_prompt.dart` → `responseSchema`; kullanım `gemini_service.dart:103,
132, 206`. Tam gövdesi:

```dart
{'type': 'ARRAY', 'items': {'type': 'ARRAY',
 'items': {'type': 'STRING', 'nullable': true}}}
```

- **Heterojen ("tuple") dizi Gemini'nin şema alt kümesinde DESTEKLENMİYOR** —
  bir ARRAY'in tek `items` şeması olabilir, pozisyon başına farklı tip
  verilemez. Bu yüzden bool/int de STRING isteniyor (`"true"`, `"12"`);
  ayrıştırıcı native tipleri de kabul ediyor, şema ileride gevşerse kod değişmez.
- `minItems` / `maxItems` **BİLEREK YOK** — nested ARRAY'de kabul edildiği canlı
  doğrulanamamıştı ve reddedilseydi TÜM istekler 400 ile ölürdü.
- **Şema, eleman SAYISINI, SIRASINI ve ANLAMINI hiç doğrulamıyor.** Tek güvence
  prompt metni + `flashcardFromCompactItem`'ın toleransı (asla fırlatmaz, bozuk
  kartı sessizce atlar). `KOD OKUMASIYLA DOĞRULANDI`

---

## 7. BİLİNEN AÇIK SORUNLAR

### 7.1 🔴 Örnek kartı ↔ sınav tipi kart ÖRTÜŞMESİ — ÖNLEM YOK, VERİDE GÖRÜNÜYOR

**Kod tarafında şu an HİÇBİR ÖNLEM YOK.** `KOD OKUMASIYLA DOĞRULANDI`:
prompt'ta iki kuralı hakemleyen tek bir cümle bile yok. Bu **bilinçli** bir
karardı — v26'da iki kuralı "tutarlı hale getirme" girişimi yanlış çıkmış ve
aynı gün geri alınmıştı. Ayrıca §6.3 gereği örnek kartının ayırt edici bir
etiketi olmadığı için **otomatik tespit / filtreleme de mümkün değil.**

**CANLI VERİDE ÖLÇÜLDÜ.** Bugün 11:59'da (v30, `gemini-3.5-flash`, 266 kart,
46 sayfa) işlenen PDF'in kartları analiz edildi. Ölçüt: aynı `kisaCevap`'ı
paylaşan kart grupları — yani aynı bilgiyi iki kez soran aday çiftler.

| hash | prompt | kart | aynı-cevap grubu | gruptaki kart | **oran** | içinde hem `temel` hem `sinav` |
|---|---|---|---|---|---|---|
| `8a4cbd8e` | (yok) | 49 | 0 | 0 | 0,0% | 0 |
| `233814c3` | v16 | 46 | 3 | 6 | 13,0% | 1 |
| `fe752b78` | v16 | 133 | 5 | 10 | 7,5% | 3 |
| `68144c37` | v23 | 238 | 2 | 4 | **1,7%** | 1 |
| **`fb81427e`** | **v30** | **266** | **21** | **52** | **19,5%** | **11** |

Somut örnek (aynı cevap, iki ayrı kart, aynı sayfa):

- `[temel | s.22]` "Ağız, vulva veya peniste saptanan lökoplaki klinik olarak
  hangi maligniteye dönüşme riski taşır?"
- `[sinav | s.22]` "55 yaşında erkek hastanın oral muayenesinde ağız mukozasında
  kazımakla çıkmayan beyaz plaklar (lökoplaki) saptanmıştır…"

**KANIT SEVİYESİ AYRIMI — dikkat:**

- Yukarıdaki oranlar `ÖLÇÜLDÜ` (gerçek `pdf_cache` kayıtları).
- **Bunun v30 kuralından KAYNAKLANDIĞI `TAHMİN`.** Kontrollü karşılaştırma
  değil: farklı PDF'ler, farklı konu (bu çalıştırma onkoloji/epidemiyoloji
  ağırlıklı — "en sık görülen kanser hangisidir" tipi sorular doğal olarak aynı
  cevabı paylaşır). Aynı PDF'in v28 ve v30 ile işlenmiş hâli YOK.
- Aynı cevap ≠ kesin fazlalık; bazıları meşru (prostat kanseri hem "en sık" hem
  "kadmiyum maruziyeti" bağlamında geçiyor). **21 grup bir ÜST SINIR.**

### 7.1b ✅ A/B YAPILDI (2026-08-18) — **KURAL SUÇSUZ ÇIKTI**

Yukarıdaki `TAHMİN` kontrollü deneyle **ÇÜRÜTÜLDÜ.** Kurulum
(`tool/ab_ornek_kurali_test.dart`, pakete dahil değil):

- **Aynı PDF** (`Kanser Epidemiyolojisi-1_...pdf`, üretimdeki v30 kaydının
  kaynağı — 46 sayfa, `max sourcePage` ile birebir uyuştu), aynı sayfalar,
  aynı model (`gemini-3.5-flash`), aynı `generationConfig`
  (temperature 0.4, `maxOutputTokens` 4096, `thinkingBudget` 0).
- **TEK DEĞİŞKEN:** Arm A = prompt'tan `ornekTabanliKartKurali` bloğu string
  olarak çıkarılmış (v28 eşdeğeri, fark 989 karakter — testle doğrulandı);
  Arm B = v30 olduğu gibi.
- Sayfa metni üretimdekiyle **aynı birleştirme mantığıyla** çıkarıldı
  (pdfjs-dist 3.11.174, `items.map(str).join(' ')` — `web/pdf_extract.js` ile
  birebir).
- temperature 0.4 → deterministik değil, bu yüzden **her arm 2 kez** koşuldu.
- Toplam **80 gerçek API çağrısı**, ölçülen maliyet **$1,32** (çağrı başı
  $0,0165; ortalama 5.843 girdi / 859 çıktı token). `ÖLÇÜLDÜ`

**TUR 1 YANILTICIYDI — ve nedeni öğreticidir.** İlk turda "metni en uzun 10
sayfa" seçildi; iki arm da ~%6 çıktı ve "fark yok" gibi göründü. Ama kontrol
edilince o 10 sayfa **üretimin kendi v30 çalıştırmasında da yalnızca %3,5**
fazlalık gösteriyordu — yani ölçülmek istenen olgu o sayfalarda HİÇ YOKTU.
Fazlalık diğer 36 sayfada yoğunlaşıyor (**%21,1**). Örneklem, olgunun
bulunmadığı yerden alınmıştı.

**TUR 2 — üretimde gerçekten fazlalık üretmiş, metni çıkarılabilen 10 sayfa**
(s. 8, 9, 12, 14, 19, 22, 24, 26, 31, 43):

| Arm | kart | fazlalık grubundaki kart | **oran** | tanım+senaryo çifti |
|---|---|---|---|---|
| **A — kural YOK** (v28 eşd.) | 147 | 51 | **%34,7** | **9 grup** |
| **B — kural VAR** (v30) | 150 | 49 | **%32,7** | **7 grup** |

**SONUÇ: `ornekTabanliKartKurali` fazlalığın SEBEBİ DEĞİL.** Kural
kaldırıldığında fazlalık düşmüyor — hatta ölçülen değerler bir tık YÜKSEK
(gürültü sınırları içinde). Kart sayısına etkisi de ihmal edilebilir
(147 → 150, %+2). `ÖLÇÜLDÜ`

**Kuralın gerçek etkisi ölçüldü ve KÜÇÜK ama DOĞRU YÖNDE:**
senaryo/uygulama metni içeren kart payı %25,9 → **%28,7**, `sinav` tipi kart
payı %23,1 → **%26,0**. Yani kural amaçladığı şeyi (tanıma/uygulama kartı)
bir miktar yapıyor ve bunu fazlalık üreterek yapmıyor.

**PEKİ FAZLALIK NEREDEN GELİYOR? İki kaynak, ikisi de v30'dan ESKİ:**
1. **Görsel-ağırlıklı sayfalar.** Üretimdeki fazlalığa en çok katkı veren iki
   sayfa (s.10 → 8 kart, s.20 → 6 kart) **sıfır çıkarılabilir metne** sahip;
   içerikleri tamamen vision'dan geliyor. Metin-only A/B bu sayfaları yapısal
   olarak hiç işleyemez — bu kısım **hâlâ ölçülmedi**.
2. **`sinavTipiKurali` (v30'dan çok eski).** Kural klinik/patolojik HER ilişki
   için normal karta **"EK olarak MUTLAKA"** senaryo kartı istiyor — yani
   yapısı gereği "aynı cevaplı iki kart" üreticisi. Nitekim kuralın hiç
   olmadığı Arm A'da bile 9 tanım+senaryo çifti oluştu. `ÖLÇÜLDÜ`

**KARAR: `ornekTabanliKartKurali`'ne DOKUNMA.** Fazlalık gerçek ama kaynağı bu
kural değil; kuralı kırpmak fazlalığı düşürmez, yalnızca uygulama kartlarını
kaybettirir. Fazlalık hedeflenecekse doğru hedef `sinavTipiKurali`'nin
koşulsuz "EK olarak MUTLAKA" ifadesidir — ve o kural tıp uzmanı geri
bildirimiyle kalibre edildiği için önce sahibine sorulmalı.

### 7.2 Diğer açık konular

| Konu | Durum | KANIT |
|---|---|---|
| Kart sızıntısı (JSON export ile dağıtım) | ÇÖZÜLMEDİ. PDF paylaşımı `pdf_cache` sayesinde artık sorun değil, ama üretilmiş kartların uygulama dışı dağıtımı açık | CLAUDE.md + KOD OKUMASIYLA DOĞRULANDI (export hâlâ var, yalnızca `requireAuth` arkasında) |
| Ödeme / abonelik | YOK. Kota altyapısı hazır, hiçbir plana bağlı değil | KOD OKUMASIYLA DOĞRULANDI |
| İki cihazlı senkron testi | HİÇ YAPILMADI. `kullanici_kutuphane` migration'ı canlıda, kod hazır, uçtan uca doğrulama eksik | CLAUDE.md |
| Öncelikli Mod kapsam sınırı | `priorityModeDeckIds` yalnızca birleşik "Bugün Çalış" kuyruğuna geçiyor; deste-bazlı çalışmada etkisiz. Bilinçli mi eksik mi KAYITLI DEĞİL | KOD OKUMASIYLA DOĞRULANDI |
| Ses kaydından kart üretme | RAFA KALDIRILDI | CLAUDE.md |
| GLM'de fence temizleme yok | Model çıktıyı ```` ```json ```` ile sararsa sayfa sessizce düşer. Sağlayıcı aktif olmadığı için uykuda | KOD OKUMASIYLA DOĞRULANDI |
| `usage_metadata` çıktısı kalıcı değil | Tarayıcı konsoluna gidiyor; sunucu tarafı loglama yapılmadı | KOD OKUMASIYLA DOĞRULANDI |

---

## 8. LAUNCH BLOKERLARI

| # | Blocker | Durum | KANIT |
|---|---|---|---|
| 1 | **Config doğrulaması** | **KISMEN TAMAM** — sunucu secret'larının tamamı mevcut: `GEMINI_API_KEY` (07-28), `MONTHLY_PAGE_CAP` (08-03), `OPENROUTER_API_KEY`, `DEEPSEEK_API_KEY` + Supabase'in kendi 7 secret'ı. İstemcide `.env` yalnızca `SUPABASE_URL` + `SUPABASE_ANON_KEY` (gizli değil, tasarım gereği). **DEĞERLER okunamaz — yalnızca VARLIK doğrulandı**; `MONTHLY_PAGE_CAP`'in gerçekten 500 olduğu teyit EDİLEMEDİ | `ÖLÇÜLDÜ` (`supabase secrets list`) |
| 2 | **Domain + Resend'e kayıt** | **YAPILMADI.** Resend kod tabanında HİÇ entegre değil — yalnızca gizlilik politikası metninde işlemci olarak anılıyor (`lib/content/legal_content.dart:89, 210`). `auth_screen.dart`'taki `_resend*` isimleri "kodu tekrar gönder" sayacı, Resend servisi DEĞİL. E-posta bugün Supabase Auth'un kendi göndericisiyle gidiyor. **Yani yasal metin, henüz kurulmamış bir altyapıyı tarif ediyor** | KOD OKUMASIYLA DOĞRULANDI |
| 3 | **Analytics** | **HİÇ YOK.** `posthog` / `mixpanel` / herhangi bir analytics SDK'sı yok; tek eşleşme `supabase/config.toml`'daki Supabase'in kendi yerel-geliştirme bloğu. Ürün analitiği sıfır. (`pdf_isleme_olcum` yalnızca pipeline telemetrisi, ürün analitiği değil) | KOD OKUMASIYLA DOĞRULANDI |
| 4 | **JSON export/import auth** | **TAMAM.** `settings_screen.dart:92` (export) ve `:139` (import) `requireAuth` ile sarılı; butonlar görünür/tıklanabilir kalıyor (kural: gizleme/disable etme). Kod genelinde 18 `requireAuth` çağrı noktası var | KOD OKUMASIYLA DOĞRULANDI |
| — | Google OAuth | Kod hazır (`auth_service.dart:107`), **Supabase panelinde client ID AYARLANMADI.** E-posta OTP akışı çalışıyor ve tek giriş yolu o | KOD OKUMASIYLA DOĞRULANDI |

---

## 9. BU RAPORDA DÜZELTİLEN VARSAYIMLAR

Rapor talebindeki üç önerme kanıtla örtüşmedi:

1. **"Flex service tier denemesi"** — bu kod tabanında hiçbir izi yok (§4.5).
2. **"Hibrit OCR (görselsiz varsayılan)"** — OCR entegrasyonu yok; en yakın şey
   el yazısı anahtarı ve onun varsayılanı AÇIK (§4.6).
3. **"Örtüşme bugün 3 canlı örnekle tespit edildi"** — bu konuşmada böyle bir
   test çalıştırılmadı. Ancak bugünkü v30 önbellek kaydı bağımsız olarak analiz
   edildi ve 11 karma grup bulundu (§7.1) — yani gözlem **veriyle destekleniyor**,
   kaynağı farklı olsa da sonuç doğrulanıyor.

---

## EN KRİTİK 3 AÇIK İŞ

### 1. ✅ ÇÖZÜLDÜ — v30 kuralı suçsuz; asıl şüpheli `sinavTipiKurali` ve vision yolu

A/B yapıldı (§7.1b, 80 çağrı, $1,32): kural kaldırılınca fazlalık **düşmüyor**
(%34,7 vs %32,7). `ornekTabanliKartKurali`'ne dokunma. **Kalan iş:** (a) görsel
taşıyan sayfalarda aynı A/B'yi yapmak — fazlalığın en yoğun olduğu sayfalar
sıfır metinli ve metin-only test onları kapsayamıyor; (b) `sinavTipiKurali`'nin
koşulsuz "EK olarak MUTLAKA" ifadesi gözden geçirilecekse, o kural tıp uzmanı
kalibrasyonu taşıdığı için önce sahibine sorulmalı.

### 2. 🟠 Launch'ın gerçek blokerleri maliyet değil: domain + Resend, sonra analytics

Maliyet araştırması 2026-08-17'de kapandı ve launch'ı bloklamıyor. Sırada duran
iki şey ürün tarafında. **Gizlilik politikası halihazırda Resend'i işlemci
olarak ilan ediyor ama entegrasyon yok** — bu bir tutarsızlık; launch öncesi ya
kurulmalı ya metin düzeltilmeli. Analytics sıfır: launch'tan sonra hiçbir
kullanıcı davranışı ölçülemeyecek.

### 3. 🟡 Görselli yolda maliyet CANLI ölçülmedi, telemetri de henüz boş

Varsayılan akışın sayfa başı maliyeti ($0,0213) hâlâ bir HESAP. Örtük cache o
yolda ölü, `pdf_cache` isabeti bugün %0, v30 ise +323 token ekledi — yani gerçek
maliyet muhtemelen bu rakamın üstünde. `pdf_isleme_olcum` canlıda ama veri
birikmesi bekleniyor ve anon key'le okunamıyor; `usage_metadata` çıktısı hâlâ
yalnızca tarayıcı konsolunda. **En ucuz düzeltme:** `ai-proxy`'de sunucu tarafı
token loglaması.
