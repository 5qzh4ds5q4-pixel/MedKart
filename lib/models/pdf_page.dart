/// PDF'ten çıkarılmış tek bir sayfanın metni VE render edilmiş görüntüsü.
///
/// Kapsam garantisi için her sayfa bir işleme birimidir; metni çıkmayan sayfa
/// bile atlanmaz, işaretlenir ([hasExtractableText] false) ve özet sayımına
/// girer. Her sayfa AYRICA bir görüntü ([imageBase64]) olarak render edilir
/// (yalnızca metin katmanı zayıf sayfalarda değil — bkz. [pdf_extract.js]);
/// Gemini'a metin+görüntü birlikte gönderilir. Görüntü, metin katmanına hiç
/// girmeyen el yazısı not/highlight/altı çizili gibi işaretleri VE renkli/
/// görsel tabloları vision ile yakalamak için gerekli.
class PdfPage {
  const PdfPage({
    required this.page,
    required this.text,
    this.imageBase64,
    this.imageMimeType = 'image/png',
  });

  /// 1 tabanlı sayfa numarası.
  final int page;

  /// Sayfadan çıkarılan düz metin.
  final String text;

  /// Render edilmiş sayfa görüntüsü (base64, ön eksiz). Render başarısız
  /// olursa `null`.
  final String? imageBase64;

  final String imageMimeType;

  /// Kart üretmeye yetecek metin var mı? Çok kısa/boşsa sayfa muhtemelen
  /// görsel ağırlıklıdır ve metinden kart çıkmaz.
  bool get hasExtractableText => text.trim().length >= 20;

  /// Render edilmiş bir sayfa görüntüsü var mı?
  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;
}
