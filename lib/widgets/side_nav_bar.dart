import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sol sabit sidebar'da hangi ikonun "aktif" (vurgulu) göründüğü.
enum SideNavItem { home, library, quiz, exam, stats, settings }

/// Uygulamanın TEK sol sidebar navigasyonu — koyu/açık mod ortak.
///
/// 2026-08-11: `deck_list_screen.dart`'tan ÇIKARILDI (eskiden oradaki private
/// `_SideNavBar`/`_SideNavIcon` idi) — `mcq_setup_screen.dart` da AYNI
/// sidebar'ı göstermeye başladığı için artık paylaşılan bir widget. Görsel
/// olarak HİÇBİR ŞEY değişmedi, yalnızca dosya taşındı ve "hangi ekrandayız"
/// bilgisi hardcoded `active: true/false` yerine [SideNavItem] enum'una
/// çevrildi.
///
/// "Ana Sayfa" dashboard'a (`DeckListScreen`) döner; "Destelerim" ise
/// 2026-08-17'den beri AYRI bir ekran açar (`DeckLibraryScreen` — sade deste
/// listesi). Öncesinde ikisi de aynı şeyi yapıyordu (`popUntil`), ayrı bir
/// kütüphane ekranı yoktu. Bu widget hangi callback'in ne yaptığını BİLMEZ;
/// yönlendirme mantığı tek yerde, `AppShell`'de.
class SideNavBar extends StatelessWidget {
  const SideNavBar({
    super.key,
    required this.active,
    required this.onOpenHome,
    required this.onOpenLibrary,
    required this.onOpenQuiz,
    required this.onOpenExam,
    required this.onOpenStats,
    required this.onOpenSettings,
  });

  final SideNavItem active;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenExam;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenSettings;

  static const double width = 80;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      decoration: BoxDecoration(
        // Koyu modda kullanıcının verdiği tam hex (#13181F) — sayfa
        // zemininden (`heroBackground`, #0D1321) hafif farklı, bilinçli.
        color: isDark ? const Color(0xFF13181F) : AppTheme.dashboardSurface,
        border: isDark
            ? null
            : const Border(
                right: BorderSide(color: AppTheme.dashboardSubtleBorder),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppTheme.space16),
            Text(
              'M',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.dashboardVioletDeep,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            _SideNavIcon(
              icon: Icons.home,
              label: 'Ana Sayfa',
              active: active == SideNavItem.home,
              isDark: isDark,
              onTap: onOpenHome,
            ),
            _SideNavIcon(
              icon: Icons.library_books_outlined,
              label: 'Destelerim',
              active: active == SideNavItem.library,
              isDark: isDark,
              onTap: onOpenLibrary,
            ),
            _SideNavIcon(
              icon: Icons.quiz_outlined,
              label: 'Kendini Test Et',
              active: active == SideNavItem.quiz,
              isDark: isDark,
              onTap: onOpenQuiz,
            ),
            _SideNavIcon(
              icon: Icons.timer_outlined,
              label: 'Deneme Sınavı',
              active: active == SideNavItem.exam,
              isDark: isDark,
              onTap: onOpenExam,
            ),
            _SideNavIcon(
              icon: Icons.insights_outlined,
              label: 'İstatistikler',
              active: active == SideNavItem.stats,
              isDark: isDark,
              onTap: onOpenStats,
            ),
            const Spacer(),
            _SideNavIcon(
              icon: Icons.settings_outlined,
              label: 'Ayarlar',
              active: active == SideNavItem.settings,
              isDark: isDark,
              onTap: onOpenSettings,
            ),
            const SizedBox(height: AppTheme.space16),
          ],
        ),
      ),
    );
  }
}

class _SideNavIcon extends StatelessWidget {
  const _SideNavIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.dashboardVioletDeep;
    final inactiveColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;
    final activeBackground = isDark
        ? AppTheme.dashboardVioletDeep.withValues(alpha: 0.20)
        : const Color(0xFFEDE9FE);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: label,
        // Dashboard tasarım sistemi: tooltip her iki temada da aynı SABİT
        // açık kart gibi görünüyor (isDark'a göre dallanmıyor) — OS'un
        // kendi tooltip'leri de genelde uygulama temasından bağımsız açık
        // durur, aynı desen burada bilinçli tekrarlandı. Konumlandırma
        // (sidebar'ın sağında) ekstra kod GEREKTİRMEDİ: sidebar zaten ekranın
        // sol kenarına yapışık olduğu için Tooltip'in kendi ekran-kenarı
        // kenetleme mantığı (positionDependentBox) tooltip'i otomatik olarak
        // sağa doğru iter. Hover (masaüstü/web) ve uzun basma (dokunmatik)
        // tetikleyicileri de Tooltip'in VARSAYILAN davranışı — ayrıca
        // triggerMode ayarlamaya gerek yok.
        decoration: BoxDecoration(
          color: AppTheme.dashboardSurfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: AppTheme.dashboardTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active ? activeBackground : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
