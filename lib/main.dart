import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/deck_list_screen.dart';
import 'services/ai_provider_config.dart';
import 'services/card_storage.dart';
import 'services/deepseek_service.dart';
import 'services/flashcard_generator.dart';
import 'services/gemini_service.dart';
import 'services/glm_service.dart';
import 'state/flashcard_store.dart';
import 'state/library_sync_controller.dart';
import 'state/study_settings.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';

/// Aktif [FlashcardGenerator]'ı [activeAiProvider] switch'ine göre kurar.
/// Yalnızca burada dallanır — geri kalan her yer [FlashcardGenerator]
/// arayüzünü kullanır, hangi somut sınıfın koştuğunu bilmez.
FlashcardGenerator _buildGenerator() {
  switch (activeAiProvider) {
    case AiProvider.gemini:
      return GeminiService();
    case AiProvider.deepseek:
      return DeepSeekService();
    case AiProvider.glm:
      return GlmService();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('TEMP-DEBUG: binding ready');

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('TEMP-DEBUG: dotenv loaded');
  } catch (e) {
    // .env yoksa uygulama yine açılsın — eksik anahtar, kart üretilmeye
    // çalışıldığında nazik bir hata mesajıyla bildirilir.
    debugPrint('.env yüklenemedi: $e');
  }

  // Supabase Auth (FAZ 1 — iskelet): .env'deki URL/anon key ile başlatılır.
  // Başlatılamazsa (env eksik/ağ yok) uygulama YİNE anonim açılır — zorunlu
  // login kapısı bu fazda yok, AuthService bunu "yapılandırma eksik" olarak
  // kibarca raporlar (bkz. lib/services/auth_service.dart).
  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL')?.trim();
  final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim();
  if (supabaseUrl != null &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      debugPrint('TEMP-DEBUG: supabase initialized');
    } catch (e) {
      debugPrint('Supabase başlatılamadı (anonim akış sürüyor): $e');
    }
  }
  debugPrint('TEMP-DEBUG: past supabase block');

  // Kayıtlı desteler/kartlar açılışta okunur; okuma başarısız olursa
  // uygulama boş kütüphaneyle açılır.
  final storage = SharedPrefsCardStorage();
  final savedData = await storage.load();
  debugPrint('TEMP-DEBUG: storage loaded');
  final themeMode = await ThemeController.load();
  debugPrint('TEMP-DEBUG: theme loaded');
  final dailyNewCardLimit = await StudySettings.load();
  final priorityModeDeckIds = await StudySettings.loadPriorityModeDeckIds();
  final dailyGoal = await StudySettings.loadDailyGoal();
  debugPrint('TEMP-DEBUG: study settings loaded, about to runApp');

  runApp(
    MedKartApp(
      storage: storage,
      initialData: savedData,
      initialThemeMode: themeMode,
      initialDailyNewCardLimit: dailyNewCardLimit,
      initialPriorityModeDeckIds: priorityModeDeckIds,
      initialDailyGoal: dailyGoal,
    ),
  );
}

class MedKartApp extends StatelessWidget {
  const MedKartApp({
    super.key,
    required this.storage,
    this.initialData = const LibraryData(),
    this.initialThemeMode = ThemeMode.system,
    this.initialDailyNewCardLimit = StudySettings.defaultDailyNewCardLimit,
    this.initialPriorityModeDeckIds = const {},
    this.initialDailyGoal,
  });

  final CardStorage storage;
  final LibraryData initialData;
  final ThemeMode initialThemeMode;
  final int initialDailyNewCardLimit;
  final Set<String> initialPriorityModeDeckIds;

  /// Opsiyonel günlük hedef; `null` = hedef belirlenmemiş (varsayılan).
  final int? initialDailyGoal;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          // Backend proxy'ye geçince değişecek tek satır burası:
          // GeminiService() yerine ProxyService() verilecek.
          create: (_) => FlashcardStore(
            _buildGenerator(),
            storage: storage,
            initialData: initialData,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController(initialMode: initialThemeMode),
        ),
        ChangeNotifierProvider(
          create: (_) => StudySettings(
            initialDailyNewCardLimit: initialDailyNewCardLimit,
            initialPriorityModeDeckIds: initialPriorityModeDeckIds,
            initialDailyGoal: initialDailyGoal,
          ),
        ),
        // Faz 2: giriş yapılmışsa kütüphaneyi buluta/bulut'tan senkronlar.
        // FlashcardStore her zaman aynı örnek olduğu için `update` yeniden
        // kurmadan öncekini döner — bağımlılık yalnızca ilk oluşturmada kullanılır.
        ChangeNotifierProxyProvider<FlashcardStore, LibrarySyncController>(
          create: (context) =>
              LibrarySyncController(store: context.read<FlashcardStore>()),
          update: (context, store, previous) => previous!,
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) => MaterialApp(
          title: 'MedKart',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.mode,
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const DeckListScreen(),
          builder: (context, child) => Stack(
            children: [
              if (child != null) child,
              const _SyncStatusBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giriş sonrası indir/birleştir/yükleme akışı sürerken üstte görünen ince
/// senkron göstergesi. `LibrarySyncController.isSyncing` false iken hiçbir
/// şey render etmez (ekranın geri kalanına dokunmaz).
class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner();

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.select<LibrarySyncController, bool>(
      (c) => c.isSyncing,
    );
    if (!isSyncing) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Verilerin senkronize ediliyor...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
