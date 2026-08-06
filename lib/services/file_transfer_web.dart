// Web (tarayıcı) uygulaması: dosya indirme ve seçme için tarayıcı API'si.
//
// dart:html güncel SDK'da kullanımdan kaldırılmaya aday olsa da hâlâ çalışır ve
// ek bağımlılık gerektirmez; prototip web hedefi için yeterli.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

const bool fileTransferSupported = true;

/// [content] metnini [filename] adıyla bir dosya olarak indirir.
Future<void> downloadText(String filename, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob(<Object>[bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Ham baytları (ör. üretilmiş bir PDF) [filename] adıyla indirir.
Future<void> downloadBytes(
  String filename,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Kullanıcıya dosya seçtirir ve içeriğini metin olarak döner.
/// Seçim iptal edilirse null döner.
Future<String?> pickTextFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json';
  input.click();

  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;

  final reader = html.FileReader()..readAsText(files.first);
  await reader.onLoadEnd.first;

  final result = reader.result;
  return result is String ? result : null;
}

/// Kullanıcıya görsel/PDF seçtirir (çoklu) ve baytlarını döner.
/// Seçim iptal edilirse boş liste döner.
Future<List<({Uint8List bytes, String mimeType, String name})>>
pickMediaFiles() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*,application/pdf'
    ..multiple = true;
  input.click();

  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return [];

  final result = <({Uint8List bytes, String mimeType, String name})>[];
  for (final file in files) {
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    final data = reader.result;
    final Uint8List bytes;
    if (data is ByteBuffer) {
      bytes = data.asUint8List();
    } else if (data is Uint8List) {
      bytes = data;
    } else {
      continue;
    }

    result.add((
      bytes: bytes,
      mimeType: _mimeType(file.type, file.name),
      name: file.name,
    ));
  }
  return result;
}

/// Kullanıcıya tek bir PDF seçtirir ve baytlarını döner. İptal edilirse null.
Future<({Uint8List bytes, String name})?> pickPdfFile() async {
  final input = html.FileUploadInputElement()..accept = 'application/pdf,.pdf';
  input.click();

  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;

  final file = files.first;
  final reader = html.FileReader()..readAsArrayBuffer(file);
  await reader.onLoadEnd.first;

  final data = reader.result;
  final Uint8List bytes;
  if (data is ByteBuffer) {
    bytes = data.asUint8List();
  } else if (data is Uint8List) {
    bytes = data;
  } else {
    return null;
  }
  return (bytes: bytes, name: file.name);
}

/// Tarayıcı bazen boş MIME türü verir; dosya uzantısından tahmin et.
String _mimeType(String reported, String name) {
  if (reported.isNotEmpty) return reported;
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return '';
}
