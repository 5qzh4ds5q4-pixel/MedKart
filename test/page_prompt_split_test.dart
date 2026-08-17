import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/services/flashcard_prompt.dart';

/// `buildPagePrompt`'un statik (systemInstruction) ve sayfaya-özel (contents)
/// parçalara bölünmesini koruyan testler.
///
/// Bu dosyanın ASIL İŞİ Gemini'ın %90 indirimli context cache'ini korumak:
/// statik bloğa sayfaya göre değişen bir şey sızarsa cache tamamen kapanır ve
/// sayfa başı maliyet artar — bu tam olarak v27'de olmuş, canlı ölçümle
/// yakalanmıştı (bkz. CLAUDE.md "Context caching").
void main() {
  group('buildPageSystemInstruction — CACHE DEĞİŞMEZİ', () {
    test('sayfa numarası başlığını ve metin sınırlayıcısını İÇERMEZ', () {
      final sys = buildPageSystemInstruction(hasImage: true);
      // NOT: "TEK BİR SAYFASININ" ve "basit bir sayfa 2-3 kart" gibi
      // ifadeler MEŞRU statik kural metni — yasak olan sayfaya ÖZEL VERİ:
      // "SAYFA <numara>" başlığı ve sayfa metnini saran sınırlayıcı.
      expect(RegExp(r'SAYFA \d').hasMatch(sys), isFalse);
      expect(sys.contains('"""'), isFalse);
    });

    test(
      'İKİ FARKLI SAYFANIN prompt\'u tam olarak system instruction kadar '
      'ortak ön ek paylaşır (cache değişmezi, uçtan uca)',
      () {
        // Asıl güvence bu: statik bloğa sayfaya göre değişen bir şey sızarsa
        // ortak ön ek kısalır ve cache kapanır (v27'de tam olarak bu oldu).
        final a = buildPagePrompt('İlk sayfanın metni.', 1, hasImage: true);
        final b = buildPagePrompt('Bambaşka bir metin.', 137, hasImage: true);

        var ortak = 0;
        while (ortak < a.length &&
            ortak < b.length &&
            a.codeUnitAt(ortak) == b.codeUnitAt(ortak)) {
          ortak++;
        }

        final sys = buildPageSystemInstruction(hasImage: true);
        // Ortak ön ek en az system instruction kadar olmalı (aradaki "\n\n"
        // de ortak, o yüzden >=).
        expect(ortak, greaterThanOrEqualTo(sys.length));
      },
    );

    test('iki farklı sayfa için BİREBİR AYNI (görselsiz)', () {
      expect(
        buildPageSystemInstruction(hasImage: false),
        equals(buildPageSystemInstruction(hasImage: false)),
      );
    });

    test('görselli/görselsiz farklı bloklar üretir', () {
      final gorselli = buildPageSystemInstruction(hasImage: true);
      final gorselsiz = buildPageSystemInstruction(hasImage: false);
      expect(gorselli, isNot(equals(gorselsiz)));
      // Görsele bağlı kurallar yalnızca görselli sürümde. NOT: "EL YAZISI
      // İŞARETİ" ifadesi kartEtiketleriKurali'nda ATIF olarak her iki sürümde
      // de geçiyor — ayırt edici marker olarak belirsizElYazisiKurali'nın
      // kendi başlığı kullanılıyor.
      expect(gorselli.contains('BELİRSİZ/OKUNAKSIZ EL YAZISI'), isTrue);
      expect(gorselsiz.contains('BELİRSİZ/OKUNAKSIZ EL YAZISI'), isFalse);
      expect(gorselli.contains('SLAYT NUMARASI'), isTrue);
      expect(gorselsiz.contains('SLAYT NUMARASI'), isFalse);
    });

    test('cache eşiğini aşacak kadar uzun (>4096 token mertebesi)', () {
      // Ölçülen oran ~3,06 karakter/token (bkz. CLAUDE.md canlı ölçüm).
      // Eşik 4.096 token => ~12.500 karakter. Blok bunun altına düşerse
      // cache HİÇ devreye girmez.
      final sys = buildPageSystemInstruction(hasImage: false);
      expect(sys.length / 3.06, greaterThan(4096));
    });
  });

  group('buildPageUserContent', () {
    test('sayfa numarasını ve metni taşır', () {
      final user = buildPageUserContent('Mitral kapak iki yaprakçıklıdır.', 12);
      expect(user, contains('SAYFA 12 METNİ:'));
      expect(user, contains('Mitral kapak iki yaprakçıklıdır.'));
    });

    test('farklı sayfalar için farklı çıktı verir', () {
      expect(
        buildPageUserContent('a', 1),
        isNot(equals(buildPageUserContent('a', 2))),
      );
    });
  });

  group('buildPagePrompt — GERİYE DÖNÜK UYUMLULUK', () {
    // GLM (`glm_service.dart:158`) ve DeepSeek (`deepseek_service.dart:117`)
    // hâlâ birleşik hali kullanıyor; bölme onların çıktısını DEĞİŞTİRMEMELİ.
    test('iki parçanın birleşimine eşittir', () {
      const metin = 'Sinoatriyal düğüm sağ atriyumdadır.';
      expect(
        buildPagePrompt(metin, 7, hasImage: true),
        equals(
          '${buildPageSystemInstruction(hasImage: true)}\n\n'
          '${buildPageUserContent(metin, 7)}',
        ),
      );
    });

    test('içerik kuralları ve sayfa metni birlikte duruyor', () {
      final p = buildPagePrompt('Aort kapağı üç yaprakçıklıdır.', 3);
      expect(p, contains('TABLO VE SAYISAL VERİ'));
      expect(p, contains('ÇIKTI BİÇİMİ'));
      expect(p, contains('SAYFA 3 METNİ:'));
      expect(p, contains('Aort kapağı üç yaprakçıklıdır.'));
    });

    test('sayfa metni prompt\'un SONUNDA (ön ek bozulmasın)', () {
      const metin = 'BENZERSIZ_ISARET_12345';
      final p = buildPagePrompt(metin, 1);
      // İşaretin bulunduğu yer, prompt'un son %15'i içinde olmalı.
      expect(p.indexOf(metin), greaterThan(p.length * 0.85));
    });
  });
}
