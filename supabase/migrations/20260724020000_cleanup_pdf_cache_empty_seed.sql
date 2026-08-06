-- Maliyet ölçümü sırasında (2026-07-24) Gemini API kotaya/503'e takıldığı
-- için TÜM sayfalar başarısız oldu, ama ölçüm scripti yine de (bilinçsizce)
-- BOŞ kart listesini `pdf_cache`'e kaydetti — Histoloji_Ders_Notu.pdf'in
-- hash'i artık "işlenmiş ama 0 kart" olarak önbellekte duruyordu. Bu satır
-- kalırsa o PDF'i gerçekten yükleyen bir öğrenci hiç kart alamaz (sessiz
-- önbellek isabeti, 0 kartla). Bu yüzden temizleniyor.
delete from public.pdf_cache
where hash = 'a49c388b0a4015dfcf913a63cf3fe58f882ba6674d70fb860c9541d56d69a2e6';
