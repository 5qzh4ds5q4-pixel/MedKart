// Tanı amaçlı: sayfa 6 için Gemini'nin HAM yanıtını (finishReason, candidate
// sayısı, olası kesilme) inceler — kural/prompt sorunu mu yoksa API/yanıt
// kesilmesi mi olduğunu ayırt etmek için. Uygulama koduna dahil değil.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/flashcard_prompt.dart' as prompt;
import 'package:medcard/services/gemini_transport.dart';

const page6Text = '''
5 Pankreas Endokrin Fonksiyonu

Langerhans Adacık Hücreleri

Hücre Tipi       Oran    Salgı                    Ana Etki
Beta             ~%70    İnsülin                  Hipoglisemik (glukoz alımını artırır)
Alfa             ~%20    Glukagon                 Hiperglisemik (glikojenoliz, glukoneogenez)
Delta            ~%5     Somatostatin             İnsülin/glukagon salgısını baskılar

İnsülin -- Salgı ve Etki Mekanizması

Kan glukozu yükselir -> GLUT2 ile beta hücresine giriş -> ATP artar, K+ kanalı kapanır -> Depolarizasyon,
Ca2+ girişi, insülin salınır

Doku             İnsülin Etkisi
Kas              GLUT4 translokasyonu ile glukoz alımı, glikojen sentezi
Karaciğer        Glikojenez artar, glukoneogenez azalır, lipogenez artar
Yağ dokusu       Trigliserid sentezi artar, lipoliz azalır

DİYABET AYRIMI

Tip 1: otoimmün beta-hücre yıkımı, mutlak insülin eksikliği. Tip 2: insülin direnci + göreceli insülin
eksikliği, obezite ile ilişkili.

6 Kalsiyum-Fosfat Dengesi

Hormon           Kaynak                Uyaran      Etki
PTH              Paratiroid bezi                   Kemik rezorpsiyonu artar, böbrekte Ca2+
(Parathormon)                          Serum Ca2+  reabsorpsiyonu artar / fosfat atılımı artar, aktif Vit D
                                       düşmesi     sentezini uyarır
Kalsitonin                                         Osteoklast aktivitesini baskılar (etkisi zayıf)
                 Tiroid parafoliküler  Serum Ca2+
Aktif Vitamin D  (C) hücreleri        yükselmesi   Bağırsaktan Ca2+ ve fosfat emilimini artırır
(Kalsitriol)
                 Deri, karaciğer,      PTH, düşük
                 böbrek (aktivasyon)   fosfat

Vitamin D Aktivasyon Basamakları

Deride UV ile D3 (kolekalsiferol) sentezlenir, karaciğerde 25-hidroksilasyon, böbrekte (PTH uyarısıyla) 1-
alfa-hidroksilasyon ile kalsitriol (aktif form) oluşur.

KLİNİK KORELASYON

Primer hiperparatiroidi: PTH yüksek, Ca2+ yüksek, fosfat düşük (genelde paratiroid adenomu). Kronik böbrek
yetmezliği: aktif Vit D sentezi azalır, hipokalsemi gelişir, sekonder hiperparatiroidi oluşur.
''';

void main() {
  test('Sayfa 6 ham yanıt tanısı', () async {
    dotenv.loadFromString(envString: File('.env').readAsStringSync());
    final transport = GeminiTransport();

    final body = jsonEncode({
      'contents': [
        {'parts': [{'text': prompt.buildPagePrompt(page6Text, 6, hasImage: false)}]},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': prompt.responseSchema,
        'temperature': 0.4,
        'maxOutputTokens': 8192,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    final response = await transport.send(model: 'gemini-3.5-flash', body: body);
    print('HTTP status: ${response.statusCode}');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    print('candidate sayısı: ${candidates?.length}');
    if (candidates != null && candidates.isNotEmpty) {
      final c = candidates.first as Map<String, dynamic>;
      print('finishReason: ${c['finishReason']}');
      final usage = decoded['usageMetadata'];
      print('usageMetadata: $usage');
      final parts = (c['content'] as Map?)?['parts'] as List?;
      print('parça sayısı: ${parts?.length}');
      final text = parts?.map((p) => (p as Map)['text']).where((t) => t != null).join();
      print('--- ÜRETİLEN HAM METİN (uzunluk: ${text?.length}) ---');
      print(text);
    } else {
      print('promptFeedback: ${decoded['promptFeedback']}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
