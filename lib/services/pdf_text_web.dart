// Web uygulaması: pdf.js ile PDF'ten sayfa metni çıkarma.
//
// index.html'de tanımlı window.medkartExtractPdf(bytes) çağrılır; sonucu JSON
// string olarak alıp [PdfPage] listesine çevirir.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../models/pdf_page.dart';

const bool pdfSupported = true;

@JS('medkartExtractPdf')
external JSPromise<JSString> _medkartExtractPdf(
  JSUint8Array bytes,
  JSBoolean includeImages,
);

/// [includeImages] false ise (kullanıcı "bu notta el yazısı/işaretleme yok"
/// dediğinde) sayfa görüntüsü JS tarafında HİÇ render edilmez — yalnızca
/// pdf.js'in çıkardığı düz metin gönderilir (bkz. `web/pdf_extract.js`).
Future<List<PdfPage>> extractPdfPages(
  Uint8List bytes, {
  bool includeImages = true,
}) async {
  final JSString jsResult =
      await _medkartExtractPdf(bytes.toJS, includeImages.toJS).toDart;
  final decoded = jsonDecode(jsResult.toDart);
  if (decoded is! List) return const [];

  return [
    for (final item in decoded)
      if (item is Map)
        PdfPage(
          page: (item['page'] as num?)?.toInt() ?? 0,
          text: (item['text'] as String?) ?? '',
          imageBase64: item['image'] as String?,
          imageMimeType: (item['mime'] as String?) ?? 'image/png',
        ),
  ];
}
