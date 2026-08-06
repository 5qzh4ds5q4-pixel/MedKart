-- Kullanım/kota altyapısı: şimdilik hiçbir istek reddedilmiyor (sınırsız),
-- yalnızca aylık sayaç tutuluyor. İleride abonelik planına bağlanacak.
create table if not exists public.kullanim_kota (
  id uuid primary key default gen_random_uuid(),
  kullanici_id text not null,
  ay text not null, -- 'YYYY-MM' (UTC)
  saglayici text not null, -- 'gemini' | 'deepseek'
  islenen_sayfa integer not null default 0,
  guncellenme_tarihi timestamptz not null default now(),
  unique (kullanici_id, ay, saglayici)
);

-- İstemci (Flutter/web) bu tabloya HİÇBİR ZAMAN doğrudan erişmiyor; yalnızca
-- ai-proxy Edge Function'ı (service_role anahtarıyla, RLS'i bypass ederek)
-- okuyup yazıyor. Bilinçli olarak hiçbir policy eklenmedi: RLS "deny all"
-- varsayılanıyla anon/authenticated rolleri için erişim tamamen kapalı.
alter table public.kullanim_kota enable row level security;

-- Yarış koşullarına (aynı anda birden fazla sayfa isteği) karşı atomik
-- artırım. Edge Function bunu service_role ile çağırır.
create or replace function public.kullanim_kota_artir(
  p_kullanici_id text,
  p_ay text,
  p_saglayici text,
  p_artis integer
) returns void
language sql
security definer
set search_path = public
as $$
  insert into public.kullanim_kota (kullanici_id, ay, saglayici, islenen_sayfa)
  values (p_kullanici_id, p_ay, p_saglayici, p_artis)
  on conflict (kullanici_id, ay, saglayici)
  do update set
    islenen_sayfa = kullanim_kota.islenen_sayfa + excluded.islenen_sayfa,
    guncellenme_tarihi = now();
$$;

revoke all on function public.kullanim_kota_artir from public;
