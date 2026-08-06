/// Yasal metinlerin içeriği.
///
/// [LegalScreen] bu metinleri düz `Text()` widget'ıyla gösterir (markdown
/// render ETMEZ) — bu yüzden burada markdown biçimlendirmesi (`##`, `**`,
/// tablo) KULLANILMAZ; başlıklar/listeler/tablo satırları okunaklı düz
/// metne çevrilmiş halde tutulur.
///
/// [version] onay kaydında (`kvkk_metin_surumu`) saklanır — metinlerin
/// gerçek içeriği değiştiğinde bu değer de güncellenmeli ki hangi kullanıcının
/// hangi sürümü onayladığı geriye dönük izlenebilsin.
class LegalContent {
  const LegalContent._();

  static const String version = '2026-07-26';

  static const String privacyPolicyTitle = 'Gizlilik Politikası';

  static const String privacyPolicy = '''
MedKart Gizlilik Politikası

Son güncelleme: 26/07/2026

Bu metin, MedKart uygulamasını kullandığınızda hangi kişisel verilerinizin işlendiğini, bu verilerin neden ve nasıl kullanıldığını ve haklarınızı açıklar.

1. Veri Sorumlusu

MedKart, Kerem Can Cülhacı tarafından şahsen işletilmektedir.

İletişim: keremculhaci98@gmail.com

6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında veri sorumlusu yukarıda belirtilen kişidir.

2. İşlenen Kişisel Veriler

MedKart'ı kullandığınızda aşağıdaki veriler işlenir:

Hesap verileri
• E-posta adresiniz (giriş ve kimlik doğrulama için)
• Google ile giriş yapmayı seçerseniz, Google hesabınızdan gelen temel kimlik bilgileri (e-posta adresi)

Kullanım ve içerik verileri
• Uygulamaya yüklediğiniz PDF ders belgelerinin içeriği
• Bu belgelerden üretilen çalışma kartları (soru, cevap, açıklama, konu bilgisi)
• Oluşturduğunuz desteler ve bunların isimleri
• Çalışma ilerlemeniz (tekrar aralıkları, zorluk seviyeleri, doğru/yanlış geçmişi, çalışma günleri)
• Deneme sınavı ve test sonuçlarınız

Teknik veriler
• Cihazınıza atanan anonim bir tanımlayıcı (kullanım kotasının takibi için)
• Aylık işlenen sayfa sayısı gibi kullanım sayaçları

MedKart; adınızı, telefon numaranızı, adresinizi, kimlik numaranızı veya ödeme kartı bilgilerinizi toplamaz.

Bu verilerin bir kısmı, hizmetin sunulabilmesi için sözleşmenin kurulması ve ifası kapsamında; yurt dışına aktarım gerektiren kısmı ise açık rızanıza dayalı olarak işlenir (bkz. Madde 5).

3. Verilerin İşlenme Amaçları

Verileriniz şu amaçlarla işlenir:
• Hesabınızı oluşturmak ve giriş yapmanızı sağlamak
• Yüklediğiniz belgelerden çalışma kartları üretmek
• Çalışma ilerlemenizi kaydetmek ve aralıklı tekrar algoritmasını çalıştırmak
• Verilerinizi cihazlarınız arasında senkronize etmek ve veri kaybını önlemek
• Kullanım kotalarını takip etmek ve hizmetin kötüye kullanımını önlemek
• Hizmeti iyileştirmek ve teknik sorunları gidermek

4. Belge Önbelleği Hakkında Önemli Bilgi

Lütfen bu bölümü dikkatlice okuyun.

MedKart, maliyetleri düşürmek ve işlemleri hızlandırmak için bir paylaşımlı önbellek sistemi kullanır.

Bir PDF belgesi yüklediğinizde, belgenin içeriğinden matematiksel bir özet (hash) çıkarılır. Aynı belge daha önce başka bir kullanıcı tarafından yüklenmişse, daha önce üretilmiş kartlar size sunulur ve belge yeniden işlenmez.

Bunun anlamı şudur:
• Yüklediğiniz bir belgeden üretilen kartlar, aynı belgeyi yükleyen diğer MedKart kullanıcılarına da sunulabilir.
• Bu önbellek kullanıcıya özel değildir; kart içerikleri sizin hesabınızla ilişkilendirilmeden saklanır.
• Bu nedenle kişisel, gizli veya üçüncü kişilere ait bilgi içeren belgeleri yüklememeniz gerekir.

Özellikle: Hasta bilgisi, sağlık kaydı, kimlik bilgisi veya benzeri kişisel veri içeren belgeleri MedKart'a yüklemeyiniz. MedKart yalnızca ders materyali ve eğitim amaçlı belgeler için tasarlanmıştır.

Çalışma ilerlemeniz, deste isimleriniz ve kişisel çalışma geçmişiniz bu önbelleğe dahil değildir; bunlar yalnızca sizin hesabınıza aittir ve başka kullanıcılarla paylaşılmaz.

5. Verilerin Aktarıldığı Taraflar ve Yurt Dışına Aktarım

MedKart'ın çalışabilmesi için verileriniz aşağıdaki hizmet sağlayıcılara aktarılır. Bu sağlayıcıların sunucuları Türkiye dışında bulunmaktadır; dolayısıyla verileriniz yurt dışına aktarılmaktadır.

• Supabase — Hesap bilgileri, kartlar, çalışma ilerlemesi, kullanım sayaçları — Veritabanı ve kimlik doğrulama altyapısı
• Google (Gemini API) — Yüklediğiniz PDF belgelerinin içeriği (metin ve sayfa görüntüleri) — Yapay zekâ ile çalışma kartı üretimi
• Resend — E-posta adresiniz — Giriş kodu e-postalarının gönderimi
• Google (OAuth) — Temel hesap bilgileri — Google ile giriş seçeneği

Verilerinizin yurt dışına aktarılabilmesi için KVKK uyarınca açık rızanız gereklidir. Bu açık rıza, hesap oluşturma sırasında karşınıza çıkan ve önceden işaretlenmemiş olan onay kutusunu bizzat işaretlemeniz yoluyla alınır. Onay vermemeniz hâlinde hesap oluşturulamaz ve hizmetten yararlanamazsınız; çünkü yukarıda belirtilen aktarımlar hizmetin çalışması için teknik olarak zorunludur.

Verdiğiniz açık rızayı dilediğiniz zaman keremculhaci98@gmail.com adresine yazarak geri alabilirsiniz. Rızanızı geri almanız hâlinde hesabınız ve size ait veriler silinir.

Bu sağlayıcıların kendi gizlilik politikaları geçerlidir ve MedKart bu politikalardan sorumlu değildir.

6. Verilerin Saklanma Süresi
• Hesap ve kütüphane verileriniz: Hesabınız aktif olduğu sürece saklanır.
• Hesap silme talebinde: Hesabınıza ait kartlar, desteler ve çalışma ilerlemesi silinir.
• Paylaşımlı belge önbelleği: Kartlar kullanıcıya bağlı olmadığı için hesap silindiğinde önbellekten kaldırılmaz; ancak bu kayıtlar sizinle ilişkilendirilemez.
• Kullanım sayaçları: Kötüye kullanımın önlenmesi amacıyla makul bir süre saklanır.

7. Veri Güvenliği
• Yapay zekâ servislerine yapılan çağrılar sunucu tarafından yönetilir; API anahtarları uygulama içinde bulunmaz.
• Veritabanında satır düzeyinde güvenlik (RLS) uygulanır; her kullanıcı yalnızca kendi verisine erişebilir.
• Giriş işlemleri şifre yerine e-posta ile gönderilen tek kullanımlık kod veya Google hesabı üzerinden yapılır.

Hiçbir sistem %100 güvenli değildir; makul teknik ve idari tedbirler alınmakla birlikte mutlak güvenlik garanti edilemez.

8. KVKK Kapsamındaki Haklarınız

KVKK'nın 11. maddesi uyarınca şu haklara sahipsiniz:
• Kişisel verilerinizin işlenip işlenmediğini öğrenme
• İşlenmişse buna ilişkin bilgi talep etme
• İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
• Yurt içinde veya yurt dışında verilerin aktarıldığı üçüncü kişileri bilme
• Eksik veya yanlış işlenmiş verilerin düzeltilmesini isteme
• Verilerinizin silinmesini veya yok edilmesini isteme
• Düzeltme, silme ve yok etme işlemlerinin verilerin aktarıldığı üçüncü kişilere bildirilmesini isteme
• İşlenen verilerin münhasıran otomatik sistemlerle analiz edilmesi suretiyle aleyhinize bir sonuç ortaya çıkmasına itiraz etme
• Verilerinizin kanuna aykırı işlenmesi sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme

Bu haklarınızı kullanmak için keremculhaci98@gmail.com adresine yazabilirsiniz. Talebiniz en geç 30 gün içinde sonuçlandırılır.

9. Çocukların Kullanımı

MedKart, yükseköğrenim öğrencilerine yöneliktir. 18 yaşından küçük kişilerin uygulamayı veli izni olmaksızın kullanmaması gerekir.

10. Değişiklikler

Bu politika zaman zaman güncellenebilir. Önemli değişiklikler uygulama içinde duyurulur. Güncel sürüm her zaman bu sayfada yayımlanır.
''';

  static const String termsOfServiceTitle = 'Kullanım Koşulları';

  static const String termsOfService = '''
MedKart Kullanım Koşulları

Son güncelleme: 26/07/2026

MedKart'ı kullanarak aşağıdaki koşulları kabul etmiş olursunuz. Kabul etmiyorsanız lütfen uygulamayı kullanmayınız.

1. Hizmetin Tanımı

MedKart, yüklediğiniz ders belgelerinden yapay zekâ yardımıyla çalışma kartları üreten ve aralıklı tekrar yöntemiyle çalışmanızı sağlayan bir eğitim uygulamasıdır.

Hizmet, Kerem Can Cülhacı tarafından şahsen sunulmaktadır.

2. Hesap ve Kullanım
• Uygulamada işlem yapabilmek için geçerli bir e-posta adresiyle hesap oluşturmanız gerekir.
• Hesap oluştururken, Kullanım Koşulları'nı ve Gizlilik Politikası'nı okuyup kabul ettiğinizi ve verilerinizin yurt dışına aktarılmasına açık rıza gösterdiğinizi belirten onay kutusunu işaretlemeniz gerekir. Bu onay olmadan hesap oluşturulamaz.
• Hesabınızın güvenliğinden ve hesabınız üzerinden yapılan işlemlerden siz sorumlusunuz.
• Hesabınızı başkalarıyla paylaşmamalısınız.
• Tek bir kişi için tasarlanmış hesapların çok sayıda kişiyle paylaşılması hâlinde hesabınız askıya alınabilir.

3. Yükleyebileceğiniz İçerikler

MedKart'a yalnızca eğitim amaçlı ders materyalleri yükleyebilirsiniz.

Yüklememeniz gerekenler:
• Hasta bilgisi, sağlık kaydı, kimlik bilgisi veya herhangi bir kişisel veri içeren belgeler
• Üçüncü kişilere ait gizli bilgiler
• Yükleme hakkına sahip olmadığınız telif korumalı materyaller
• Hukuka aykırı, zararlı veya rahatsız edici içerikler

Yüklediğiniz içeriğin hukuka uygunluğundan ve yükleme hakkına sahip olduğunuzdan siz sorumlusunuz.

Önemli: Yüklediğiniz belgelerden üretilen kartlar, maliyet optimizasyonu amacıyla paylaşımlı bir önbellekte saklanır ve aynı belgeyi yükleyen diğer kullanıcılara sunulabilir. Ayrıntılar için Gizlilik Politikası'na bakınız.

4. Yapay Zekâ Üretimi İçerik ve Sorumluluk Reddi

Bu bölüm önemlidir, lütfen dikkatle okuyunuz.
• MedKart'ta üretilen çalışma kartları yapay zekâ tarafından otomatik olarak oluşturulur.
• Üretilen içerik hatalı, eksik veya yanıltıcı olabilir.
• Kartlar, kaynak belgenizdeki bilgiye sadık kalacak şekilde üretilir; kaynak belgede hata varsa bu hata kartlara da yansıyabilir.
• MedKart tıbbi tavsiye vermez. Üretilen içerik hiçbir şekilde tanı, tedavi veya klinik karar için kullanılamaz.
• Sınav başarısı, akademik sonuç veya öğrenme çıktısı konusunda hiçbir garanti verilmez.
• Çalıştığınız bilginin doğruluğunu kendi ders kaynaklarınızdan teyit etmek sizin sorumluluğunuzdadır.

5. Kullanım Sınırları ve Adil Kullanım
• Hizmetin belirli kullanım kotaları vardır. Bu kotalar uygulama içinde belirtilir.
• Otomatik araçlarla toplu istek göndermek, sistemi aşırı yüklemek veya kotaları aşmaya çalışmak yasaktır.
• Hizmeti tersine mühendislikle çözmeye, güvenlik önlemlerini aşmaya veya izinsiz erişim sağlamaya çalışmak yasaktır.
• Uygulamadan elde ettiğiniz içeriği ticari amaçla yeniden satmanız veya dağıtmanız yasaktır.

Bu kurallara aykırı davranış hâlinde hesabınız uyarısız askıya alınabilir veya kapatılabilir.

6. Ücretlendirme
• Uygulamanın belirli özellikleri ücretsiz olarak sunulabilir; bazı özellikler ücretli paketlere tabi olabilir.
• Paket içerikleri, sınırlar ve fiyatlar uygulama içinde belirtilir ve değiştirilebilir.
• Fiyat değişiklikleri önceden duyurulur ve mevcut abonelik dönemini etkilemez.

7. Hizmetin Sürekliliği
• MedKart geliştirme aşamasındadır. Özellikler değişebilir, eklenebilir veya kaldırılabilir.
• Hizmetin kesintisiz veya hatasız çalışacağı garanti edilmez.
• Bakım, teknik sorun veya üçüncü taraf servis kesintileri nedeniyle hizmet geçici olarak durabilir.
• Hizmetin sonlandırılması hâlinde, verilerinizi dışa aktarmanız için makul bir süre tanınmaya çalışılır.

8. Fikri Mülkiyet
• Yüklediğiniz belgelerin hakları size veya asıl hak sahibine aittir; MedKart bu belgeler üzerinde mülkiyet iddia etmez.
• Uygulamanın kendisi (arayüz, tasarım, kod, marka) MedKart'a aittir ve izinsiz kullanılamaz.
• Üretilen kartları kendi çalışmanız için serbestçe kullanabilirsiniz.

9. Sorumluluğun Sınırlandırılması

Yürürlükteki mevzuatın izin verdiği azami ölçüde:
• MedKart, hizmetin kullanımından doğan doğrudan veya dolaylı zararlardan sorumlu tutulamaz.
• Veri kaybı, sınav başarısızlığı, akademik sonuçlar veya üretilen içeriğin hatalı olmasından kaynaklanan zararlardan sorumluluk kabul edilmez.
• Üçüncü taraf servislerin (Supabase, Google, Resend vb.) kesinti veya hatalarından sorumluluk kabul edilmez.

10. Hesabın Kapatılması
• Hesabınızı dilediğiniz zaman kapatabilirsiniz. Kapatma talebiniz için keremculhaci98@gmail.com adresine yazabilirsiniz.
• Bu koşullara aykırı davranış hâlinde hesabınız tarafımızca kapatılabilir.

11. Değişiklikler ve Uygulanacak Hukuk
• Bu koşullar zaman zaman güncellenebilir; önemli değişiklikler uygulama içinde duyurulur.
• Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır.
• Uyuşmazlıklarda Türkiye Cumhuriyeti mahkemeleri ve icra daireleri yetkilidir.

12. İletişim

Sorularınız için: keremculhaci98@gmail.com
''';
}
