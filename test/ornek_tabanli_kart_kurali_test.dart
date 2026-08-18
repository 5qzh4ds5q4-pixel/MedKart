import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/flashcard_prompt.dart';

/// [ornekTabanliKartKurali] (v30) HER İKİ YOLA da girmeli.
///
/// Bu proje daha önce tam bu hatayı yaptı: "boş dizi döndür" kuralı uzun süre
/// yalnızca Yol A'daydı ve bir kullanıcı Yol B'den (fotoğraf) alakasız bir
/// görsel yükleyince model uydurma kart üretti (bkz. CLAUDE.md, v21/v22).
/// Yeni bir içerik kuralı eklerken iki yolu da kapsadığını doğrula.
void main() {
  group('ornekTabanliKartKurali içeriği', () {
    test('tanım kartının YERİNE değil EK olduğunu söyler', () {
      expect(ornekTabanliKartKurali, contains('EK OLARAK'));
      expect(ornekTabanliKartKurali, contains('YERİNE DEĞİL'));
    });

    test('yanlış/doğru örnek çifti taşır (soyut tarif yeterli olmuyor)', () {
      expect(ornekTabanliKartKurali, contains('YANLIŞ'));
      expect(ornekTabanliKartKurali, contains('DOĞRU'));
      expect(ornekTabanliKartKurali, contains('Neoantijen örnekleri nelerdir?'));
      expect(ornekTabanliKartKurali, contains('KRAS'));
    });

    test(
      'örnek yoksa üretme + uydurma yasağı — kuralın EN KRİTİK maddesi',
      () {
        expect(ornekTabanliKartKurali, contains('ÜRETME'));
        expect(ornekTabanliKartKurali, contains('UYDURMA'));
        expect(ornekTabanliKartKurali, contains('kaynak sadakati'));
      },
    );
  });

  group('her iki yola da giriyor', () {
    test('Yol A — sayfa prompt\'unda (görselli ve görselsiz)', () {
      expect(
        buildPagePrompt('Sayfa metni.', 3, hasImage: true),
        contains(ornekTabanliKartKurali),
      );
      expect(
        buildPagePrompt('Sayfa metni.', 3, hasImage: false),
        contains(ornekTabanliKartKurali),
      );
    });

    test('Yol B — genel prompt\'ta (medyalı ve medyasız)', () {
      expect(
        buildGeneralPrompt('Ders notu metni.', hasMedia: false),
        contains(ornekTabanliKartKurali),
      );
      expect(
        buildGeneralPrompt('', hasMedia: true),
        contains(ornekTabanliKartKurali),
      );
    });

    test(
      'Yol A statik bloğunda duruyor — yani cache ön ekinin İÇİNDE, sayfaya '
      'özel kuyrukta DEĞİL',
      () {
        expect(
          buildPageSystemInstruction(hasImage: true),
          contains(ornekTabanliKartKurali),
        );
        expect(
          buildPageUserContent('Sayfa metni.', 3),
          isNot(contains(ornekTabanliKartKurali)),
        );
      },
    );
  });

  test('kPromptVersion v30 (içerik kuralı değişti, sürüm artmalı)', () {
    expect(kPromptVersion, 'v30');
    // İçerik kuralı olduğu için önbellek eşiği de bu sürüme çekildi.
    expect(kMinCacheablePromptVersion, 30);
  });
}
