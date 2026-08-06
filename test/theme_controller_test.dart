import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcard/screens/deck_list_screen.dart';
import 'package:medcard/services/card_storage.dart';
import 'package:medcard/services/flashcard_generator.dart';
import 'package:medcard/models/flashcard.dart';
import 'package:medcard/state/flashcard_store.dart';
import 'package:medcard/state/study_settings.dart';
import 'package:medcard/state/theme_controller.dart';
import 'package:medcard/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopGenerator implements FlashcardGenerator {
  @override
  Future<List<Flashcard>> generate(
    String sourceText, {
    List<MediaAttachment> media = const [],
  }) async => const [];

  @override
  Future<List<Flashcard>> generateForPage(
    String pageText,
    int sourcePage, {
    String? imageBase64,
    String imageMimeType = 'image/png',
  }) async => const [];
}

Widget _app(ThemeController controller) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => FlashcardStore(_NoopGenerator())),
      ChangeNotifierProvider.value(value: controller),
      ChangeNotifierProvider(create: (_) => StudySettings()),
    ],
    child: Consumer<ThemeController>(
      builder: (context, c, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: c.mode,
        home: const DeckListScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ThemeController', () {
    test('kayıt yokken sistem modu döner', () async {
      expect(await ThemeController.load(), ThemeMode.system);
    });

    test('kaydedilen tercih sonraki açılışta okunur', () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.storageKey: 'dark',
      });
      expect(await ThemeController.load(), ThemeMode.dark);
    });

    test('setMode diske yazar ve dinleyicileri uyarır', () async {
      final controller = ThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.setMode(ThemeMode.dark);

      expect(controller.mode, ThemeMode.dark);
      expect(notified, 1);
      // Fire-and-forget yazımın tamamlanmasını bekle.
      await Future<void>.delayed(Duration.zero);
      expect(await ThemeController.load(), ThemeMode.dark);
    });

    test('toggle görünen parlaklığın tersine geçer', () {
      final controller = ThemeController(initialMode: ThemeMode.light);
      controller.toggle(isCurrentlyDark: false);
      expect(controller.mode, ThemeMode.dark);
      controller.toggle(isCurrentlyDark: true);
      expect(controller.mode, ThemeMode.light);
    });
  });

  testWidgets('toggle butonu temayı koyuya çevirir', (tester) async {
    final controller = ThemeController(initialMode: ThemeMode.light);
    await tester.pumpWidget(_app(controller));

    // Tema butonu artık Ayarlar ekranında.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Açık modda ay ikonu (karanlığa geç daveti) görünür.
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();

    expect(controller.mode, ThemeMode.dark);
    // Koyu moda geçince ikon güneşe döner.
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}
