import 'dart:typed_data';

import '../models/flashcard.dart';

/// Kart üretimine kaynak olan bir görsel eki.
///
/// Gemini multimodal olduğundan bu ekler doğrudan modele gönderilip
/// slayttaki içerikten kart üretilir. PDF burada YOK — PDF için tek yol
/// sayfa-bazlı pipeline'dır (bkz. [FlashcardGenerator.generateForPage]).
class MediaAttachment {
  const MediaAttachment({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });

  final Uint8List bytes;

  /// ör. image/png, image/jpeg, image/webp
  final String mimeType;

  /// Kullanıcıya gösterilen dosya adı.
  final String name;

  int get sizeBytes => bytes.length;
}

/// Kart üretiminin soyut arayüzü.
///
/// Şu an tek uygulaması [GeminiService] — API anahtarını .env'den okuyup
/// Gemini'a doğrudan istemciden istek atar. Bu prototip için kabul edilebilir
/// ama gerçek dağıtımda anahtar istemcide bulunmamalı.
///
/// Backend proxy'ye geçerken: bu arayüzü uygulayan yeni bir sınıf yazıp
/// (ör. `ProxyService`, kendi sunucunuza POST atan), main.dart'taki tek
/// satırlık kurulumu değiştirmek yeterli. UI ve state katmanı değişmez.
abstract class FlashcardGenerator {
  /// Verilen ders notundan ve/veya ekli görsellerden flashcard üretir.
  ///
  /// [sourceText] ve [media]'dan en az biri dolu olmalıdır. Başarısızlıkta
  /// [FlashcardGenerationException] fırlatır; mesajı doğrudan kullanıcıya
  /// gösterilebilecek Türkçe bir metindir.
  Future<List<Flashcard>> generate(
    String sourceText, {
    List<MediaAttachment> media = const [],
  });

  /// Tek bir PDF sayfasının metninden kart üretir (büyük PDF pipeline'ı için).
  ///
  /// Sayfa test edilecek bilgi içermiyorsa **boş liste** döner (hata fırlatmaz);
  /// HTTP/ağ hatasında fırlatır ki pipeline sayfayı yeniden denesin. Üretilen
  /// kartlara [sourcePage] damgalanır.
  ///
  /// [imageBase64] doluysa render edilmiş sayfa görüntüsü metinle BİRLİKTE
  /// modele eklenir — metinde olmayan el yazısı not/highlight/altı çizili
  /// işaretleri ve renkli/görsel tabloları vision ile okumak için.
  Future<List<Flashcard>> generateForPage(
    String pageText,
    int sourcePage, {
    String? imageBase64,
    String imageMimeType = 'image/png',
  });
}

/// Kullanıcıya gösterilmeye hazır, Türkçe mesaj taşıyan hata.
class FlashcardGenerationException implements Exception {
  const FlashcardGenerationException(
    this.message, {
    this.isQuota = false,
    this.isTimeout = false,
  });

  final String message;

  /// 429 (kota/hız limiti) kaynaklı mı? Pipeline bunu görünce o sayfayı boşuna
  /// tekrar tekrar denemez ve tüm işlemi durdurup kullanıcıya net "kota doldu"
  /// mesajı gösterir — 100 sayfayı sırayla başarısız denemek yerine.
  final bool isQuota;

  /// İstek zaman aşımına mı uğradı (yanıt hiç dönmedi)?
  ///
  /// MALİYET KRİTİK: zaman aşımı "istek başarısız oldu" demek DEĞİL — yalnızca
  /// yanıtı biz zamanında alamadık demek. Sağlayıcı üretimi tamamlamış ve
  /// FATURALAMIŞ olabilir. Bu yüzden pipeline zaman aşımına uğrayan sayfayı
  /// TEKRAR DENEMEZ (bkz. `PdfCardPipeline._generateWithRetry`): aynı sayfa
  /// için 2. ve 3. kez ödeme yapma riski, o sayfanın kartlarını kaçırmaktan
  /// daha pahalı. Sayfa "işlenemedi" olarak işaretlenir ve mevcut kısmi-başarı
  /// akışıyla kullanıcıya bildirilir.
  ///
  /// [isQuota]'dan farkı: kota TÜM işlemi durdurur, zaman aşımı yalnızca O
  /// SAYFAYI atlar — diğer sayfalar işlenmeye devam eder.
  final bool isTimeout;

  @override
  String toString() => message;
}
