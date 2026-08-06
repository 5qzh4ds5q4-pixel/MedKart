-- Faz 2 (kullanıcı-bazlı bulut senkronu): giriş yapmış bir kullanıcının tüm
-- kütüphanesi (desteler + kartlar + SM-2 ilerlemesi + studyLog) TEK BİR JSONB
-- blobunda saklanır — istemcideki shared_preferences formatıyla BİREBİR aynı
-- (bkz. lib/services/library_codec.dart, LibraryCodec.toMap/fromMap). Yeni
-- bir sunucu-tarafı şema icat edilmedi, mevcut istemci kodu aynen yeniden
-- kullanılıyor.
--
-- pdf_cache/kullanim_kota'nın aksine bu tabloya İSTEMCİ DOĞRUDAN erişiyor
-- (Edge Function yok) — Supabase client zaten oturum JWT'sini taşıyor,
-- auth.uid() bunu otomatik sağlıyor. RLS bu yüzden "deny all" değil,
-- kullanıcının YALNIZCA kendi satırına eriştiği açık policy'lerle kurulu.
create table if not exists public.kullanici_kutuphane (
  user_id uuid primary key references auth.users (id) on delete cascade,
  library_data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.kullanici_kutuphane enable row level security;

create policy "kendi kütüphanesini okuyabilir"
  on public.kullanici_kutuphane for select
  to authenticated
  using (auth.uid() = user_id);

create policy "kendi kütüphanesini oluşturabilir"
  on public.kullanici_kutuphane for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "kendi kütüphanesini güncelleyebilir"
  on public.kullanici_kutuphane for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
