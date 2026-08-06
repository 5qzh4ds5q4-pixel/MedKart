// Test-only script: güçlendirilmiş "tablo satırı atlama" kuralının gerçek
// etkisini doğrular — Endokrin_Fizyoloji_Ders_Notu.pdf sayfa 3 (Hipofiz Ön
// Lob tablosu, 5 satır: GH/TSH/ACTH/FSH-LH/Prolaktin) ve sayfa 6 (Pankreas +
// Kalsiyum-Fosfat) metniyle gerçek GeminiService.generateForPage çağrısı.
// Uygulama koduna dahil değil.
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/gemini_service.dart';

const page3Text = '''
2 Hipotalamus-Hipofiz Aksi

Hipofiz Ön Lob (Adenohipofiz) Hormonları

Hormon         Hipotalamik Uyarıcı             Hedef Organ               Etki
GH (Büyüme     GHRH (+) / Somatostatin         Karaciğer (IGF-1), kemik, Büyüme, protein sentezi, lipoliz
Hormonu)       (-)                             kas
TSH            TRH (+)                         Tiroid                    T3/T4 sentez ve salınımı
ACTH           CRH (+)                         Adrenal korteks           Kortizol sentezi
FSH / LH       GnRH (+)                        Gonadlar                  Gametogenez, seks hormon
                                                                          sentezi
Prolaktin      Dopamin (-, tonik baskı)        Meme bezi                 Süt üretimi

Hipofiz Arka Lob (Nörohipofiz)

Arka lob hormon sentezlemez -- hipotalamusta (supraoptik ve paraventriküler çekirdeklerde) üretilip akson
aracılığıyla taşınır, burada sadece depolanıp salınır.

Hormon         Uyarı                           Etki
ADH                                            Toplayıcı kanalda su reabsorpsiyonu (V2 reseptör); yüksek
(Vazopressin)  Plazma osmolaritesi artışı, kan  dozda vazokonstriksiyon (V1)
Oksitosin      hacmi düşüşü                     Süt "let-down" refleksi, uterus kontraksiyonu (pozitif feedback)

               Meme emme refleksi, serviks
               gerilmesi

KLİNİK KORELASYON

ADH eksikliği: Diabetes İnsipidus (çok sulu, az yoğun idrar). ADH fazlalığı (SIADH): hiponatremi, konsantre
idrar.
''';

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
  test('Sayfa 3 — Hipofiz ön lob tablosu: 5 satırın hepsi kart üretmeli', () async {
    dotenv.loadFromString(envString: File('.env').readAsStringSync());
    final service = GeminiService();

    final cards = await service.generateForPage(page3Text, 3);

    print('--- SAYFA 3: ${cards.length} kart ---');
    for (final c in cards) {
      print('  [${c.difficulty.name}/${c.cardType.name}] ${c.question} => ${c.answer}');
    }

    final allText = cards.map((c) => '${c.question} ${c.answer}'.toLowerCase()).join(' | ');
    final hasGH = allText.contains('gh') || allText.contains('büyüme hormonu');
    final hasFshLh = allText.contains('fsh') || allText.contains('lh') || allText.contains('gonadotropin');
    final hasTsh = allText.contains('tsh');
    final hasActh = allText.contains('acth');
    final hasProlaktin = allText.contains('prolaktin');

    print('GH kartı var mı: $hasGH');
    print('FSH/LH kartı var mı: $hasFshLh');
    print('TSH kartı var mı: $hasTsh');
    print('ACTH kartı var mı: $hasActh');
    print('Prolaktin kartı var mı: $hasProlaktin');

    expect(cards, isNotEmpty);
    expect(hasGH, isTrue, reason: 'GH satırı için kart üretilmedi');
    expect(hasFshLh, isTrue, reason: 'FSH/LH satırı için kart üretilmedi');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Sayfa 6 — Pankreas + Kalsiyum-Fosfat tabloları', () async {
    dotenv.loadFromString(envString: File('.env').readAsStringSync());
    final service = GeminiService();

    final cards = await service.generateForPage(page6Text, 6);

    print('--- SAYFA 6: ${cards.length} kart ---');
    for (final c in cards) {
      print('  [${c.difficulty.name}/${c.cardType.name}] ${c.question} => ${c.answer}');
    }

    expect(cards, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
