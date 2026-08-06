import 'dart:typed_data';

/// Web dışı platformlar için yer tutucu. Dosya indir/seç yalnızca web'de
/// desteklenir; burada işlemler nazikçe reddedilir.

const bool fileTransferSupported = false;

Future<void> downloadText(String filename, String content) async {
  throw UnsupportedError('Dosya indirme yalnızca web sürümünde desteklenir.');
}

Future<void> downloadBytes(
  String filename,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  throw UnsupportedError('Dosya indirme yalnızca web sürümünde desteklenir.');
}

Future<String?> pickTextFile() async {
  throw UnsupportedError('Dosya seçme yalnızca web sürümünde desteklenir.');
}

Future<List<({Uint8List bytes, String mimeType, String name})>>
pickMediaFiles() async {
  throw UnsupportedError('Dosya seçme yalnızca web sürümünde desteklenir.');
}

Future<({Uint8List bytes, String name})?> pickPdfFile() async {
  throw UnsupportedError('Dosya seçme yalnızca web sürümünde desteklenir.');
}
