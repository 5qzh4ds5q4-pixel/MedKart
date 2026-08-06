/// Metin dosyası indir/seç işlemleri için platformdan bağımsız arayüz.
///
/// Web'de tarayıcı API'siyle (`dart:html`) gerçek indirme/yükleme yapılır;
/// diğer platformlarda desteklenmez ([fileTransferSupported] false döner) ve
/// arayüz kullanıcıya nazik bir mesaj gösterir. Koşullu import sayesinde
/// `dart:html` Android/masaüstü derlemesine sızmaz ve ek bağımlılık gerekmez.
export 'file_transfer_stub.dart'
    if (dart.library.html) 'file_transfer_web.dart';
