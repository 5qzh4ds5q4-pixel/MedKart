// PDF metin+görüntü çıkarma yardımcısı.
//
// Dart tarafı window.medkartExtractPdf(bytes) çağırır; her sayfanın metnini
// VE render edilmiş görüntüsünü çıkarıp JSON dizisi
// ("[{page, text, image, mime}, ...]") olarak string döner.
// pdf.js (window.pdfjsLib) index.html'de CDN'den yüklenir.
//
// HER SAYFA HEM METİN HEM GÖRÜNTÜ (2026-07-18): önceki sürüm görüntüyü yalnızca
// metin katmanı zayıf (<200 karakter) sayfalarda render ediyordu (renkli/görsel
// tablo sorunu için). Artık el yazısı not, highlight (renkli işaret) ve altı
// çizili yerleri yakalamak için HER sayfa görüntüsü render edilir — bunlar
// metin katmanına hiç girmez ama sınavda kritik olabilir. Dart tarafı
// (gemini_service.dart generateForPage) ikisini birlikte gönderir ve görseldeki
// el yazısı/highlight'ı öncelikli işaret olarak yorumlar.
//
// TOKEN MALİYETİ: her sayfa artık görüntü de taşıdığı için istek başına maliyet
// arttı. Bunu dengelemek için görüntü TARGET_WIDTH genişliğe küçültülüp JPEG
// (PNG değil — kalite parametresi yalnızca JPEG/WebP'de anlamlı) olarak
// JPEG_QUALITY kalitede kodlanıyor; el yazısı hâlâ okunabilir kalırken boyut
// önemli ölçüde küçülüyor.
(function () {
  var WORKER_SRC =
    'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
  var TARGET_WIDTH = 1024;
  var MAX_RENDER_SCALE = 2.0;
  var JPEG_QUALITY = 0.85;
  var IMAGE_MIME = 'image/jpeg';

  async function renderPageToBase64Jpeg(page) {
    var baseViewport = page.getViewport({ scale: 1.0 });
    var scale = Math.min(MAX_RENDER_SCALE, TARGET_WIDTH / baseViewport.width);
    var viewport = page.getViewport({ scale: scale });
    var canvas = document.createElement('canvas');
    canvas.width = viewport.width;
    canvas.height = viewport.height;
    var ctx = canvas.getContext('2d');
    await page.render({ canvasContext: ctx, viewport: viewport }).promise;
    var dataUrl = canvas.toDataURL(IMAGE_MIME, JPEG_QUALITY);
    // "data:image/jpeg;base64," ön ekini at, yalnızca base64 gövdeyi döndür.
    return dataUrl.substring(dataUrl.indexOf(',') + 1);
  }

  // [includeImages=false] (kullanıcı "bu notta el yazısı/işaretleme yok"
  // dediğinde, bkz. add_cards_screen.dart) render adımını TAMAMEN atlar —
  // yalnızca gereksiz veri göndermeyiz, canvas render'ı da hiç çalışmaz
  // (daha hızlı çıkarım + sıfır görsel token maliyeti).
  window.medkartExtractPdf = async function (bytes, includeImages) {
    if (typeof window.pdfjsLib === 'undefined') {
      throw new Error('pdf.js yüklenemedi (internet bağlantısı gerekli).');
    }
    if (includeImages === undefined) includeImages = true;
    window.pdfjsLib.GlobalWorkerOptions.workerSrc = WORKER_SRC;

    var doc = await window.pdfjsLib.getDocument({ data: bytes }).promise;
    var pages = [];
    for (var i = 1; i <= doc.numPages; i++) {
      var page = await doc.getPage(i);
      var content = await page.getTextContent();
      var text = content.items
        .map(function (it) { return it.str; })
        .join(' ');

      var image = null;
      if (includeImages) {
        try {
          image = await renderPageToBase64Jpeg(page);
        } catch (e) {
          console.log('[PDF-EXTRACT s.' + i + '] görsel render hatası: ' + e);
        }
      }

      // TEŞHİS: her sayfanın çıkarılan metin uzunluğu + ilk 80 karakter +
      // görüntü render edilip edilmediği.
      console.log(
        '[PDF-EXTRACT s.' + i + '] ' + text.length + ' karakter | ' +
          JSON.stringify(text.slice(0, 80)) +
          ' | GÖRÜNTÜ: ' + (image
            ? 'render edildi'
            : (includeImages ? 'BAŞARISIZ' : 'atlandı (kullanıcı seçimi)'))
      );
      pages.push({ page: i, text: text, image: image, mime: IMAGE_MIME });
      // Belleği şişirmemek için sayfayı serbest bırak.
      if (page.cleanup) page.cleanup();
    }
    return JSON.stringify(pages);
  };
})();
