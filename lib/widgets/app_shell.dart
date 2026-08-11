import 'package:flutter/material.dart';

import '../screens/exam_sim_screen.dart';
import '../screens/mcq_setup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stats_screen.dart';
import '../theme/app_theme.dart';
import 'side_nav_bar.dart';

export 'side_nav_bar.dart' show SideNavItem;

/// Uygulamanın TEK ana ekran iskeleti — sol `SideNavBar` + opsiyonel üst
/// şerit + içerik.
///
/// 2026-08-11: Deneme Sınavı kurulum ekranının sidebar'ı hiç yoktu (hâlâ eski
/// `Scaffold(appBar: ...)` kalıbındaydı, `deck_list_screen.dart`/
/// `mcq_setup_screen.dart`'ın kendi kodlarına gömdüğü sidebar'dan habersiz).
/// Bunun BİR DAHA olmaması için: artık her ana ekran kendi Scaffold/Row/
/// `SideNavBar` kodunu YAZMAK yerine bu widget'ı sarmalıyor — sidebar'ın
/// KENDİSİ zaten paylaşılıyordu (bkz. `SideNavBar`), navigasyon MANTIĞI da
/// (hangi ikon nereye gider, "zaten oradaysan no-op") artık TEK yerde.
/// Yeni bir ana ekran eklerken bu widget'ı kullanmadan sidebar'ı elle
/// kurmaya kalkma — tam da bu unutmayı önlemek için var.
///
/// [active] hangi sidebar ikonunun vurgulanacağını VE hangi callback'in
/// no-op kalacağını belirler (zaten o ekrandaysan tıklama hiçbir şey
/// yapmaz). "Ana Sayfa"/"Destelerim" HER ZAMAN deste listesine döner
/// (`Navigator.popUntil((r) => r.isFirst)` — `main.dart`'ın `home:` route'u
/// hep `DeckListScreen`); deste listesinin KENDİSİNDEN çağrıldığında bu
/// zaten en üstteki route olduğu için no-op'tur, ayrıca özel bir dal
/// GEREKMEZ.
///
/// Deste listesinin BOŞ/karşılama durumu bilinçli olarak bu widget'ı
/// KULLANMIYOR (`DeckListScreen._EmptyState` dalı) — o ekranın sidebar'ı hiç
/// olmaması ayrı, belgelenmiş bir tasarım kararı (bkz. `DeckListScreen.
/// build` doc yorumu), buraya taşınmadı.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.active,
    required this.body,
    this.topBar,
    this.floatingActionButton,
  });

  final SideNavItem active;

  /// Sidebar'ın sağındaki içerik — bu widget zaten `Expanded` içine
  /// konuyor, ayrıca sarmalamaya gerek yok.
  final Widget body;

  /// `body`'nin ÜSTÜNDE, sabit yükseklikte bir şerit (geri oku + başlık gibi)
  /// — `null` verilirse hiç yer kaplamaz. Bkz. `AppShellTopBar` (ortak "geri +
  /// başlık" deseni); deste listesi kendi `_DashboardTopBar`'ını (yalnızca
  /// profil balonu, geri oku yok — zaten en üstteki ekran) veriyor.
  final Widget? topBar;

  final Widget? floatingActionButton;

  static void _goHome(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  static void _openIfNotActive(
    BuildContext context,
    SideNavItem target,
    SideNavItem current,
    WidgetBuilder builder,
  ) {
    if (target == current) return;
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: ColoredBox(
          color: isDark
              ? AppTheme.heroBackground
              : AppTheme.dashboardBackground,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SideNavBar(
                active: active,
                onOpenHome: () => _goHome(context),
                onOpenLibrary: () => _goHome(context),
                onOpenQuiz: () => _openIfNotActive(
                  context,
                  SideNavItem.quiz,
                  active,
                  (_) => const McqSetupScreen(),
                ),
                onOpenExam: () => _openIfNotActive(
                  context,
                  SideNavItem.exam,
                  active,
                  (_) => const ExamSimSetupScreen(),
                ),
                onOpenStats: () => _openIfNotActive(
                  context,
                  SideNavItem.stats,
                  active,
                  (_) => const StatsScreen(),
                ),
                onOpenSettings: () => _openIfNotActive(
                  context,
                  SideNavItem.settings,
                  active,
                  (_) => const SettingsScreen(),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    ?topBar,
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sidebar'ın yanındaki standart "geri oku + başlık" şeridi.
///
/// `Scaffold.appBar` DEĞİL bilinçli olarak — `AppBar` tüm genişliği kaplar
/// (sidebar'ın ÜSTÜNE biner), sidebar tam yükseklikte durabilsin diye bu
/// şerit gövdenin İÇİNE, sidebar'ın sağındaki sütuna konuyor. Kendini Test
/// Et/Deneme Sınavı/İstatistik/Ayarlar hepsi bunu kullanıyor.
class AppShellTopBar extends StatelessWidget {
  const AppShellTopBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final ghostBg = isDark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).maybePop(),
              // `Tooltip(message: 'Back')`: sabit Flutter `AppBar`'ın
              // otomatik geri butonu bunu zaten kendiliğinden taşıyordu;
              // `WidgetTester.pageBack()` TAM OLARAK bu tooltip metnini
              // arıyor (bkz. Flutter test framework kaynağı) — bu özel
              // (Scaffold.appBar DEĞİL) geri butonunda elle eklenmezse
              // mevcut testler "One back button expected on screen" ile
              // patlıyor. Ayrıca ekran okuyucu için de doğru davranış.
              child: Tooltip(
                message: 'Back',
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ghostBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, size: 18, color: fg),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
