-- PDF -> kart pipeline'inin CALISTIRMA BASINA olcumu (2026-08-18).
--
-- NEDEN: modele gidip bos dizi ([]) donen sayfa -- yani modelin "burada test
-- edilecek bilgi yok" dedigi kapak/ajanda/gecis/kapanis slayti -- o gune dek
-- HICBIR YERDE kaydedilmiyordu; PipelineResult'ta ne failedPages'e ne
-- emptyTextPages'e giriyor, sessizce "islendi" sayiliyordu. Bu yuzden
-- "sayfalarin yuzde kaci kart uretmeye degmez bulunuyor" sorusu ancak
-- pdf_cache'teki sourcePage BOSLUKLARINDAN tahmin edilebiliyordu (2026-08-17
-- olcumu: ~%13, ama 4 PDF'lik ornek + numaralandirma kaymasi gurultusu).
-- Bu tablo o soruyu dogrudan, biriken gercek veriyle yanitlar.
--
-- NEDEN pdf_cache'e SUTUN DEGIL, AYRI TABLO:
--   1) pdf_cache SATIR BASINA BIR PDF tutar, bu tablo CALISTIRMA BASINA bir
--      satir -- zaman serisi ancak boyle olusur (ayni PDF iki kez yuklenirse
--      iki olcum).
--   2) pdf_cache'e yazma yalnizca (a) TAM PDF islendiginde, (b) cache MISS
--      oldugunda, (c) en az 1 kart uretildiginde oluyor. Yani konu/sayfa
--      araligiyla DARALTILMIS calistirmalar, cache HIT'ler ve HIC kart
--      uretmeyen calistirmalar sistematik olarak disarida kalirdi -- tam da
--      olcmek istedigimiz uc durum.
--   3) pdf_cache'e sutun eklemek `pdf-cache` Edge Function'ini degistirip
--      DEPLOY etmeyi gerektirirdi (canli cache yazma yolunu riske atar).
--      Bu tabloya istemci DOGRUDAN yaziyor (kullanici_kutuphane deseni),
--      hicbir Edge Function degismiyor.
create table if not exists public.pdf_isleme_olcum (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),

  -- Dolu ise TAM PDF islendi (pdf_cache rafiyla ayni hash). NULL ise
  -- calistirma konu/sayfa araligiyla daraltilmisti -- bu satirlar pdf_cache'te
  -- HIC gorunmez, olcumun asil kazanci burada.
  pdf_hash text,

  -- Paydalar. Toplam = metin_yok + hatali + bos_donen + kart_ureten.
  toplam_sayfa integer not null,
  metin_yok_sayfa integer not null,   -- modele HIC gitmedi (on-filtre)
  hatali_sayfa integer not null,      -- modele gitti, istisna firlatti
  bos_donen_sayfa integer not null,   -- modele gitti, [] dondu  <-- OLCULEN
  kart_ureten_sayfa integer not null,

  uretilen_kart integer not null,
  bos_sayfa_no jsonb,                 -- hangi sayfalar (tanı icin)

  prompt_version text,
  model_version text,
  gorsel_acik boolean,                -- el yazisi anahtari (vision) acik miydi
  kota_kesildi boolean not null default false
);

create index if not exists pdf_isleme_olcum_created_at_idx
  on public.pdf_isleme_olcum (created_at desc);

-- kullanici_kutuphane ile ayni desen: istemci DOGRUDAN yaziyor, RLS
-- auth.uid() = user_id ile kilitli. PDF yukleme zaten requireAuth kapisinin
-- ardinda (bkz. CLAUDE.md "Zorunlu Login / Faz 3"), yani her gercek
-- calistirmanin bir user_id'si var.
alter table public.pdf_isleme_olcum enable row level security;

create policy "kendi olcumunu yazabilir"
  on public.pdf_isleme_olcum for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "kendi olcumunu okuyabilir"
  on public.pdf_isleme_olcum for select
  to authenticated
  using (auth.uid() = user_id);

-- UPDATE/DELETE'e BILEREK policy yok: olcum kaydi gecmiste olmus bir olaydir,
-- istemci sonradan degistirememeli (exam_results'taki "birlestirme degil
-- toplama" mantigiyla ayni gerekce). Toplu analiz Supabase panelinden
-- service_role ile yapilir, o zaten RLS'i bypass eder.
