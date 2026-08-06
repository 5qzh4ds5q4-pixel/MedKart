-- Cache HIT sayacı: kullanıcıya "bu set daha önce N kez çalışıldı" gibi
-- olumlu/motive edici bir geri bildirim gösterebilmek için (bkz. `pdf-cache`
-- Edge Function, `PdfCacheService.lookup`). Yalnızca lookup'ta HIT
-- (kayıt bulundu) olduğunda artırılır — MISS'te (kayıt yoksa/yeni
-- kaydedilirken) hiç dokunulmaz.
alter table public.pdf_cache
  add column if not exists hit_count integer not null default 0;

-- Yarış koşullarına (aynı anda birden fazla kullanıcı aynı PDF'i açması)
-- karşı atomik artırım — `kullanim_kota_artir` ile aynı desen. Tek bir
-- UPDATE...RETURNING olduğu için önce oku-sonra-yaz aralığında ikinci bir
-- HIT'in sayacı kaçırması mümkün değil; her çağrı sayacı tam olarak bir kez
-- artırır ve güncel değeri döner.
create or replace function public.pdf_cache_hit_artir(p_hash text)
returns integer
language sql
security definer
set search_path = public
as $$
  update public.pdf_cache
  set hit_count = hit_count + 1
  where hash = p_hash
  returning hit_count;
$$;

revoke all on function public.pdf_cache_hit_artir from public;
