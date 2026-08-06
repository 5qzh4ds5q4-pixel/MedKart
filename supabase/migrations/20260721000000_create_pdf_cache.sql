-- Paylaşılan PDF->kart önbelleği: aynı PDF (SHA-256 hash'i içerik bazlı,
-- dosya adından BAĞIMSIZ) birden fazla öğrenci tarafından yüklenirse, ikinci
-- ve sonraki yüklemeler Gemini'a hiç gitmeden bu tablodan anında servis
-- edilir (tıp fakültesinde aynı ders slaytının onlarca öğrenci tarafından
-- ayrı ayrı işlenmesini önlemek için — maliyet optimizasyonu).
--
-- Kullanıcıya özel DEĞİL: tüm kullanıcılar için paylaşılan tek bir önbellek.
create table if not exists public.pdf_cache (
  hash text primary key,
  generated_cards jsonb not null,
  created_at timestamptz not null default now()
);

-- İstemci bu tabloya HİÇBİR ZAMAN doğrudan erişmiyor; yalnızca yeni
-- `pdf-cache` Edge Function'ı (service_role anahtarıyla, RLS'i bypass
-- ederek) okuyup yazıyor. Bilinçli olarak hiçbir policy eklenmedi:
-- RLS "deny all" varsayılanıyla anon/authenticated rolleri için erişim
-- tamamen kapalı (bkz. `kullanim_kota` tablosundaki aynı desen).
alter table public.pdf_cache enable row level security;
