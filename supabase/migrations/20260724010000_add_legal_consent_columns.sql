-- Yasal onay (KVKK/Kullanım Koşulları) kaydı: kullanıcı hesabını
-- oluştururken hangi metin sürümünü ne zaman onayladığını saklar (bkz.
-- lib/services/sync_service.dart, SyncService.recordLegalConsent).
--
-- `library_data`'ya varsayılan boş obje eklendi: onay kaydı, kütüphane
-- senkronundan (LibrarySyncController) ÖNCE çalışırsa bu satırı
-- `library_data` göndermeden oluşturmak zorunda kalıyor (bkz.
-- recordLegalConsent yorumu) — NOT NULL kısıtlaması varsayılansız insert'i
-- reddederdi. Sonradan gelen gerçek senkron upsert'i yalnızca
-- `library_data`/`updated_at` sütunlarını günceller, kvkk sütunlarına
-- dokunmaz.
alter table public.kullanici_kutuphane
  alter column library_data set default '{}'::jsonb;

alter table public.kullanici_kutuphane
  add column if not exists kvkk_onay_tarihi timestamptz,
  add column if not exists kvkk_metin_surumu text;
