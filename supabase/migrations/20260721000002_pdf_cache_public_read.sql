-- Önceki migration `pdf_cache`'i RLS "deny all" (hiçbir policy yok) ile
-- kurmuştu — yalnızca `pdf-cache` Edge Function'ı (service_role, RLS'i
-- bypass eder) erişebiliyordu, anon/authenticated hiç okuyamıyordu.
--
-- Kullanıcı isteğiyle: okuma HERKESE açık olsun (paylaşılan, herkese açık
-- bir önbellek — içerik hassas değil, yalnızca üretilmiş kartlar), yazma
-- yine yalnızca Edge Function'a (service_role) özel kalsın. Bunun için
-- INSERT/UPDATE/DELETE'e policy EKLENMİYOR (policy yoksa varsayılan "deny"
-- geçerli olmaya devam eder, service_role zaten RLS'i bypass eder) —
-- yalnızca SELECT için anon+authenticated'e açık bir policy ekleniyor.
create policy "pdf_cache herkese okunur"
  on public.pdf_cache
  for select
  to anon, authenticated
  using (true);
