import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pdf_card_pipeline.dart';

/// PDF → kart pipeline'ının ÇALIŞTIRMA BAŞINA ölçümünü buluta yazar.
///
/// Amaç tek bir soruyu biriken gerçek veriyle yanıtlamak: **sayfaların yüzde
/// kaçı modele gidip boş dizi (`[]`) dönüyor**, yani "kart üretmeye değmez"
/// bulunuyor (bkz. [PipelineResult.emptyResultPages]). 2026-08-18'e kadar bu
/// hiçbir yerde tutulmuyordu ve ancak `pdf_cache`'teki `sourcePage`
/// boşluklarından TAHMİN edilebiliyordu.
///
/// **Best-effort, kullanıcıyı ASLA etkilemez:** giriş yoksa, Supabase
/// yapılandırılmadıysa ya da ağ/yetki sorunu varsa sessizce no-op döner.
/// Çağıran taraf `unawaited` ile çağırmalı — bu bir telemetri yazımı, kart
/// üretiminin başarısı buna bağlı değil.
class PipelineMetricsService {
  PipelineMetricsService({SupabaseClient? client}) : _clientOverride = client;

  /// Testlerde sahte bir istemci enjekte etmek için.
  final SupabaseClient? _clientOverride;

  static const String table = 'pdf_isleme_olcum';

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      // Supabase.initialize hiç çağrılmadı (.env eksik).
      return null;
    }
  }

  /// Buluta yazılacak satırı kurar. SAF fonksiyon — ağ yok, testler doğrudan
  /// çağırır.
  ///
  /// Paydaların toplamı [PipelineResult.totalPages]'e eşit olmalı:
  /// `metin_yok + hatali + bos_donen + kart_ureten`. Yeni bir sayfa sonucu
  /// kategorisi eklersen bu eşitliği koru — yoksa oran hesabı sessizce bozulur
  /// (bkz. `pipeline_metrics_test.dart`'taki eşitlik testi).
  static Map<String, dynamic> buildRow(
    PipelineResult result, {
    required String userId,
    String? pdfHash,
    bool? visionEnabled,
    String? modelVersion,
    String? promptVersion,
  }) {
    final bosDonen = result.emptyResultPages.length;
    return {
      'user_id': userId,
      'pdf_hash': pdfHash,
      'toplam_sayfa': result.totalPages,
      'metin_yok_sayfa': result.emptyTextPages.length,
      'hatali_sayfa': result.failedPages.length,
      'bos_donen_sayfa': bosDonen,
      'kart_ureten_sayfa': result.billedPages - bosDonen,
      'uretilen_kart': result.cardCount,
      'bos_sayfa_no': result.emptyResultPages,
      'prompt_version': promptVersion,
      'model_version': modelVersion,
      'gorsel_acik': visionEnabled,
      'kota_kesildi': result.quotaExhausted,
    };
  }

  /// Ölçümü yazar. Hata durumunda YUTAR (yalnızca konsola not düşer).
  Future<void> record(
    PipelineResult result, {
    String? pdfHash,
    bool? visionEnabled,
    String? modelVersion,
    String? promptVersion,
  }) async {
    final client = _client;
    if (client == null) return;

    final userId = client.auth.currentUser?.id;
    // Girişsiz çalıştırma: RLS zaten reddederdi, boşuna istek atma.
    // (PDF yükleme requireAuth kapısının ardında olduğu için pratikte
    // buraya düşmemeli — savunmacı bir dal.)
    if (userId == null) return;

    try {
      await client.from(table).insert(
        buildRow(
          result,
          userId: userId,
          pdfHash: pdfHash,
          visionEnabled: visionEnabled,
          modelVersion: modelVersion,
          promptVersion: promptVersion,
        ),
      );
    } catch (e) {
      debugPrint('pipeline ölçümü yazılamadı (kartlar etkilenmedi): $e');
    }
  }
}
