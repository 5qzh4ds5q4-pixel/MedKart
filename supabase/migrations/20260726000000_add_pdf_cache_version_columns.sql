-- pdf_cache'e hangi model + prompt sürümüyle üretildiği bilgisini ekler.
-- Amaç: prompt/model ileride güncellendiğinde eski (artık güncel prompt
-- kurallarını yansıtmayan) cache kayıtlarını yenilerinden ayırt edebilmek.
--
-- ŞİMDİLİK yalnızca KAYDEDİLİYOR — okuma/lookup tarafında bu sürüme göre
-- filtreleme YOK, cache-hit davranışı değişmedi (bkz. `PdfCacheService`).
-- Eski kayıtlarda bu alanlar NULL kalır, bu beklenen ve zararsız.
alter table public.pdf_cache
  add column if not exists model_version text,
  add column if not exists prompt_version text;
