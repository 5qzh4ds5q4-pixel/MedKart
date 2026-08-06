-- Test/doğrulama sırasında (2026-07-21) `pdf-cache` Edge Function'ının
-- lookup/save akışını canlı ortamda kanıtlamak için gerçek bir PDF'in
-- (Endokrin_Fizyoloji_Ders_Notu.pdf) hash'ine SAHTE kartlar seed edilmişti.
-- Bu satır kalıcı önbellekte kalırsa o PDF'i gerçekten yükleyen bir öğrenci
-- sahte test kartlarını görür — bu yüzden temizleniyor.
delete from public.pdf_cache
where hash = 'c674d0efecfb1a0b32d82de7717e5ef00f222710dc1b5445003af6df1533f720';
