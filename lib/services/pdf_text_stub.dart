import 'dart:typed_data';

import '../models/pdf_page.dart';

/// Web dışı platformlar için yer tutucu.
const bool pdfSupported = false;

Future<List<PdfPage>> extractPdfPages(
  Uint8List bytes, {
  bool includeImages = true,
}) async {
  throw UnsupportedError('PDF işleme yalnızca web sürümünde desteklenir.');
}
