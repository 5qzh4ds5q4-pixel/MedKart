-- 2026-07-21'de RLS okuma-politikası + iki-cihaz uçtan uca testini
-- doğrularken gerçek bir PDF'in (Histoloji_Ders_Notu.pdf) hash'ine sahte
-- kartlar seed edilmişti. Bu satır kalıcı önbellekte kalırsa o PDF'i
-- gerçekten yükleyen bir öğrenci sahte test kartlarını görür — temizleniyor.
delete from public.pdf_cache
where hash = 'a49c388b0a4015dfcf913a63cf3fe58f882ba6674d70fb860c9541d56d69a2e6';
