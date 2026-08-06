/// PDF'ten sayfa bazında metin çıkarma — platformdan bağımsız arayüz.
///
/// Web'de pdf.js (tarayıcı) kullanılır; diğer platformlarda desteklenmez
/// ([pdfSupported] false). Koşullu import sayesinde web-only kod diğer
/// derlemelere sızmaz.
export 'pdf_text_stub.dart' if (dart.library.js_interop) 'pdf_text_web.dart';
