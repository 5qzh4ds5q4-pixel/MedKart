-- 2026-07-21'de yeni okuma-herkese-açık RLS policy'sini test ederken
-- eklenen deneme satırı temizleniyor.
delete from public.pdf_cache where hash = 'rls-probe-hash';
