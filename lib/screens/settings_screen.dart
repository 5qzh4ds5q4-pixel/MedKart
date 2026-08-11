import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;

import '../content/legal_content.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/file_transfer.dart';
import '../state/flashcard_store.dart';
import '../state/study_settings.dart';
import '../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/app_shell.dart';
import '../widgets/content_shell.dart';
import '../widgets/daily_goal_dialog.dart';
import '../widgets/daily_limit_dialog.dart';
import 'auth_screen.dart';
import 'legal_screen.dart';

/// Ayarlar ekranı: görünüm (tema), günlük çalışma limiti ve yedekleme.
///
/// Ayrı bir "ayarlar" veri modeli yok — burası daha önce ana ekranın
/// AppBar'ına dağılmış olan kontrolleri (tema, günlük limit, yedek
/// dışa/içe aktarma) tek bir yüzeyde toplar.
///
/// 2026-08-11: "ayarlar ekranı.png" referans tasarımından kart-ızgara
/// düzenine çevrildi (bkz. `StatsScreen`'in aynı deseni — sol/sağ sütun,
/// her bölüm kendi başlığını/ikonunu İÇİNDE taşıyan bir kart). Business
/// mantığının TAMAMI (aşağıdaki `_editDailyLimit`/`_editDailyGoal`/
/// `_exportBackup`/`_importBackup`/`requireAuth`) HİÇ değişmedi — yalnızca
/// görsel katman değişti.
///
/// **BİLİNÇLİ VERİ DÜZELTMESİ:** referans tasarımdaki profil kartı
/// "Pro Plan'a 3 gün kaldı" yazıyordu — uygulamada gerçek bir abonelik
/// sistemi YOK (bkz. proje hafızasının "Bilinmeyen / Henüz
/// Kararlaştırılmamış" bölümü), bu yüzden o metin KOPYALANMADI. Bunun
/// yerine (bkz. [_ProfileHeaderRow]) yalnızca giriş yapmış kullanıcıda
/// gerçek veriye dayalı bir durum satırı (`StudyLog.currentStreak`)
/// gösteriliyor; seri 0 ise ya da hiç giriş yapılmamışsa satır/kart hiç
/// gösterilmiyor — uydurma bir "Pro" ya da "gün kaldı" iddiası hiçbir
/// dalda YOK.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editDailyLimit(BuildContext context) async {
    final settings = context.read<StudySettings>();
    final value = await DailyLimitDialog.show(
      context,
      currentLimit: settings.dailyNewCardLimit,
    );
    if (value == null) return;
    settings.setDailyNewCardLimit(value);
  }

  Future<void> _editDailyGoal(BuildContext context) async {
    final settings = context.read<StudySettings>();
    final result = await DailyGoalDialog.show(
      context,
      currentGoal: settings.dailyGoal,
    );
    // null = iptal; result.goal == null = kullanıcı hedefi kaldırdı.
    if (result == null) return;
    settings.setDailyGoal(result.goal);
  }

  void _openLegalScreen(BuildContext context, String title, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalScreen(title: title, content: content),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Yedekleme (dışa/içe aktarma) girişe tabi — buton görünür kalır, basılınca
  /// [requireAuth] kapısından geçer.
  static const _backupAuthReason =
      'Yedek almak/geri yüklemek için giriş yapman gerekiyor.';

  /// Her desteyi AYRI bir JSON dosyası olarak indirir (deste başına bir
  /// dosya; önceden tüm kütüphane tek dosyaya iniyordu).
  Future<void> _exportBackup(BuildContext context) async {
    await requireAuth(
      context,
      () => _runExportBackup(context),
      reason: _backupAuthReason,
    );
  }

  Future<void> _runExportBackup(BuildContext context) async {
    final store = context.read<FlashcardStore>();

    if (!fileTransferSupported) {
      _snack(context, 'Yedek indirme yalnızca web sürümünde çalışır.');
      return;
    }
    if (store.decks.isEmpty) {
      _snack(context, 'Yedeklenecek deste yok.');
      return;
    }

    try {
      final decks = store.decks;
      for (var i = 0; i < decks.length; i++) {
        await downloadText(
          BackupService.suggestedDeckFileName(decks[i].name),
          BackupService.exportDeck(store.libraryData, decks[i]),
        );
        // Tarayıcılar art arda tetiklenen indirmeleri sessizce düşürebiliyor;
        // dosyalar arasına kısa bir nefes bırak.
        if (i < decks.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      if (context.mounted) {
        _snack(
          context,
          decks.length == 1
              ? 'Deste JSON olarak indirildi.'
              : '${decks.length} deste ayrı JSON dosyaları olarak indirildi.',
        );
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Yedek indirilemedi.');
    }
  }

  /// JSON yedek dosyası seçip kütüphaneyi geri yükler (mevcut veriyi değiştirir).
  Future<void> _importBackup(BuildContext context) async {
    await requireAuth(
      context,
      () => _runImportBackup(context),
      reason: _backupAuthReason,
    );
  }

  Future<void> _runImportBackup(BuildContext context) async {
    final store = context.read<FlashcardStore>();

    if (!fileTransferSupported) {
      _snack(context, 'Yedekten geri yükleme yalnızca web sürümünde çalışır.');
      return;
    }

    String? content;
    try {
      content = await pickTextFile();
    } catch (e) {
      if (context.mounted) _snack(context, 'Dosya okunamadı.');
      return;
    }
    if (content == null || !context.mounted) return;

    final data = BackupService.tryImport(content);
    if (data == null) {
      _snack(context, 'Geçersiz yedek dosyası.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek geri yüklensin mi?'),
        content: Text(
          '${data.decks.length} deste ve ${data.cards.length} kart yüklenecek. '
          'Şu anki bütün desteler, kartlar ve çalışma ilerlemen bununla '
          'değiştirilecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    store.replaceLibrary(data);
    _snack(context, 'Yedek geri yüklendi.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<StudySettings>();
    final dailyLimit = settings.dailyNewCardLimit;
    final dailyGoal = settings.dailyGoal;
    final streak = context
        .watch<FlashcardStore>()
        .studyLog
        .currentStreak(DateTime.now());

    final primaryTextColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    final gorunumCard = _SettingsCard(
      icon: Icons.desktop_windows_outlined,
      accent: _Accent.violet,
      title: 'Görünüm',
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tema',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uygulama görünümünü tercihine göre seç.',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: _ThemePreviewCard(
                  dark: true,
                  label: 'Koyu',
                  selected: isDark,
                  appIsDark: isDark,
                  onTap: () =>
                      context.read<ThemeController>().setMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: _ThemePreviewCard(
                  dark: false,
                  label: 'Açık',
                  selected: !isDark,
                  appIsDark: isDark,
                  onTap: () => context.read<ThemeController>().setMode(
                    ThemeMode.light,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final calismaCard = _SettingsCard(
      icon: Icons.track_changes_outlined,
      accent: _Accent.pink,
      title: 'Çalışma',
      isDark: isDark,
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.tune_outlined,
            accent: _Accent.violet,
            isDark: isDark,
            title: 'Günlük yeni kart limiti',
            subtitle: 'Günde en fazla $dailyLimit yeni kart',
            trailing: _ValuePill(
              text: '$dailyLimit kart',
              accent: _Accent.violet,
              isDark: isDark,
            ),
            onTap: () => _editDailyLimit(context),
          ),
          const SizedBox(height: AppTheme.space12),
          _SettingsRow(
            icon: Icons.flag_outlined,
            accent: _Accent.pink,
            isDark: isDark,
            title: 'Günlük hedef (opsiyonel)',
            subtitle: dailyGoal == null
                ? 'Belirlenmedi — istatistikte hedef halkası gösterilmez'
                : 'Günde $dailyGoal kart',
            trailing: _ValuePill(
              text: dailyGoal == null ? 'Belirlenmedi' : '$dailyGoal kart',
              accent: dailyGoal == null ? null : _Accent.pink,
              isDark: isDark,
            ),
            onTap: () => _editDailyGoal(context),
          ),
        ],
      ),
    );

    final hesapCard = _SettingsCard(
      icon: Icons.person_outline,
      accent: _Accent.violet,
      title: 'Hesap',
      isDark: isDark,
      child: _HesapCardBody(isDark: isDark),
    );

    final veriCard = _SettingsCard(
      icon: Icons.storage_outlined,
      accent: _Accent.violet,
      title: 'Veri',
      isDark: isDark,
      child: _VeriCardBody(
        isDark: isDark,
        onExport: () => _exportBackup(context),
        onImport: () => _importBackup(context),
      ),
    );

    final yasalCard = _SettingsCard(
      icon: Icons.shield_outlined,
      accent: _Accent.violet,
      title: 'Yasal',
      isDark: isDark,
      child: Column(
        children: [
          _ChevronRow(
            icon: Icons.description_outlined,
            isDark: isDark,
            title: 'Kullanım Koşulları',
            onTap: () => _openLegalScreen(
              context,
              LegalContent.termsOfServiceTitle,
              LegalContent.termsOfService,
            ),
          ),
          Divider(
            height: AppTheme.space24,
            color: isDark
                ? AppTheme.heroBorder
                : AppTheme.dashboardSubtleBorder,
          ),
          _ChevronRow(
            icon: Icons.privacy_tip_outlined,
            isDark: isDark,
            title: 'Gizlilik Politikası',
            onTap: () => _openLegalScreen(
              context,
              LegalContent.privacyPolicyTitle,
              LegalContent.privacyPolicy,
            ),
          ),
        ],
      ),
    );

    return AppShell(
      active: SideNavItem.settings,
      topBar: const AppShellTopBar(title: 'Ayarlar'),
      body: ContentShell(
        // Kart-ızgara düzeni artık `StatsScreen` ile aynı geniş sütuna
        // ihtiyaç duyuyor — varsayılan `contentMaxWidth` (760, okunacak
        // METİN sütunu içindir) iki yan yana kartı sıkıştırırdı.
        maxWidth: AppTheme.dashboardMaxWidth,
        child: ResponsiveBuilder(
          builder: (context, size) {
            final horizontal = responsiveHorizontalPadding(size);
            final columns = size.isDesktop ? 2 : 1;
            return ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
              children: [
                _ProfileHeaderRow(streak: streak),
                _SettingsGrid(
                  columns: columns,
                  left: [gorunumCard, hesapCard, yasalCard],
                  right: [calismaCard, veriCard],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _Accent { violet, pink, danger }

/// Auth durumunu (giriş yapmış kullanıcı) dinleyip yeniden çizen ortak
/// sarmalayıcı — [_ProfileHeaderRow] ve [_HesapCardBody] AYNI deseni
/// kullanıyor (bkz. `ProfileBubble`'daki orijinal desen). Her ikisi kendi
/// `AuthService`/abonelik örneğini tutar; ekranda aynı anda iki yerde
/// gösterildikleri için paylaşmak yerine ayrı örnek bilerek tercih edildi
/// (basitlik, ikisi de zaten `Supabase.instance` tekil istemcisine bakıyor).
class _AuthWatcher extends StatefulWidget {
  const _AuthWatcher({required this.builder});

  final Widget Function(BuildContext context, AuthService auth, User? user)
  builder;

  @override
  State<_AuthWatcher> createState() => _AuthWatcherState();
}

class _AuthWatcherState extends State<_AuthWatcher> {
  final AuthService _auth = AuthService();
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _auth.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _auth, _auth.currentUser);
}

/// Sağ üstteki profil kartı — YALNIZCA giriş yapılmışsa gösterilir (boş
/// kimlik göstermek yanlış veri olurdu). Bkz. sınıf başı doküman yorumu:
/// referans tasarımdaki "Pro Plan'a 3 gün kaldı" YOK, yerine gerçek
/// `StudyLog.currentStreak` — o da 0 ise satır tamamen atlanır, sahte bir
/// "0 günlük serin var" cümlesi kurulmaz.
class _ProfileHeaderRow extends StatelessWidget {
  const _ProfileHeaderRow({required this.streak});

  final int streak;

  static String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Kullanıcı';
    return local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthWatcher(
      builder: (context, auth, user) {
        if (user == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final email = user.email ?? '';
        final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
        // OTP e-posta akışında ayrı bir "ad" alanı yok (bkz. AuthService doc
        // yorumu) — Google ile girişte varsa userMetadata'daki adı kullan,
        // yoksa e-postanın @ öncesini sade bir görünen ada çevir. Uydurma
        // bir isim YOK, ikisi de gerçek hesap verisinden türüyor.
        final metaName =
            (user.userMetadata?['full_name'] ?? user.userMetadata?['name'])
                as String?;
        final displayName = (metaName != null && metaName.trim().isNotEmpty)
            ? metaName.trim()
            : _nameFromEmail(email);

        final primaryTextColor = isDark
            ? AppTheme.textPrimaryDark
            : AppTheme.dashboardTextPrimary;
        final mutedColor = isDark
            ? AppTheme.textTertiaryDark
            : AppTheme.dashboardTextMuted;
        final flameColor = isDark
            ? AppTheme.dashboardPink
            : AppTheme.dashboardPinkHot;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.heroSurface : AppTheme.dashboardSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.25 : 0.04,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.dashboardCtaGradient,
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark
                          ? AppTheme.heroBackground
                          : AppTheme.dashboardSurfaceElevated,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: primaryTextColor,
                        ),
                      ),
                      if (streak > 0) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: flameColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$streak günlük serin var',
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bölüm kartlarının ortak kabuğu: ikon rozeti + başlık İÇERİDE (referans
/// tasarımdaki gibi, `StatsScreen._SectionCard`'ın aksine — orada ikon
/// nötrdü, burada `accent`e göre renkli). `Card` DEĞİL: kullanıcı "tüm
/// kartlar border yok, elevation only" istedi ve `Card` widget'ı bu
/// uygulamanın global `cardTheme`'i yüzünden HER ZAMAN bir kenarlık çiziyor
/// (bkz. `flashcard_tile.dart`/`exam_sim_screen.dart _DashCard`'daki aynı
/// bulgu) — o yüzden düz `Container` + `boxShadow`.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.isDark,
    required this.child,
  });

  final IconData icon;
  final _Accent accent;
  final String title;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.heroSurface : AppTheme.dashboardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon, accent: accent),
              const SizedBox(width: AppTheme.space12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.dashboardTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          child,
        ],
      ),
    );
  }
}

/// Dolu renkli daire içinde beyaz ikon — hem kart başlıklarında hem satır
/// öncesinde kullanılıyor. Solid mor/pembe/kırmızı zaten hem açık hem koyu
/// zeminde yeterli kontrastta, moda göre ayrı bir ton gerekmiyor.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.accent});

  final IconData icon;
  final _Accent accent;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final bg = switch (accent) {
      _Accent.violet => AppTheme.dashboardVioletDeep,
      _Accent.pink => AppTheme.dashboardPinkHot,
      _Accent.danger => Theme.of(context).colorScheme.error,
    };
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: _size * 0.5),
    );
  }
}

/// Bir ayar satırı: ikon rozeti + başlık/alt metin + trailing. [onTap]
/// `null` verilirse (Veri kartındaki satırlar gibi — orada asıl aksiyon
/// trailing'deki BUTON'un kendisi) satır kendisi tıklanabilir olmaz.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.accent,
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final _Accent accent;
  final bool isDark;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _IconBadge(icon: icon, accent: accent),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        trailing,
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

/// Salt-görüntü değer pili (ör. "20 kart", "Belirlenmedi") — Veri kartındaki
/// gerçek aksiyon BUTONLARIYLA karıştırılmasın diye ayrı, tıklanamaz bir
/// widget (satırın tamamı zaten [_SettingsRow.onTap] ile tıklanabiliyor).
class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text, required this.accent, required this.isDark});

  final String text;

  /// `null` = nötr ("Belirlenmedi" gibi henüz ayarlanmamış bir değer).
  final _Accent? accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (accent == null) {
      final borderColor = isDark
          ? AppTheme.heroBorderStrong
          : AppTheme.dashboardSubtleBorder;
      final fg = isDark ? AppTheme.textTertiaryDark : AppTheme.dashboardTextMuted;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
        ),
      );
    }

    final base = accent == _Accent.pink
        ? AppTheme.dashboardPinkHot
        : AppTheme.dashboardVioletDeep;
    final fg = isDark
        ? (accent == _Accent.pink ? AppTheme.dashboardPink : AppTheme.dashboardViolet)
        : base;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: base.withValues(alpha: isDark ? 0.22 : 0.12),
        border: Border.all(color: base.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Dolu mor→pembe gradyanlı küçük buton — gerçek `FilledButton`'ı gradyan
/// bir `Container`a sararak elde ediliyor (`SegmentedButton`/`FilledButton`
/// tek düz renk destekliyor, bkz. `exam_sim_screen.dart`'taki aynı desen).
class _GradientPillButton extends StatelessWidget {
  const _GradientPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.dashboardCtaGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Çerçeveli, dolgusuz aksiyon butonu — "İçe aktar" (yıkıcı/üzerine yazan bir
/// işlem) ve "Çıkış Yap" için; [color] verilmezse mor vurgu, verilirse
/// (içe aktarmada `colorScheme.error`) o renk kullanılır.
class _OutlinedPillButton extends StatelessWidget {
  const _OutlinedPillButton({
    required this.label,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent =
        color ?? (isDark ? AppTheme.dashboardViolet : AppTheme.dashboardVioletDeep);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Hesap kartının içeriği: giriş yapılmamışsa "Giriş yap / Kayıt ol"
/// gradyan butonu (eski "Hesap (deneme)" satırının yerini alıyor — iş
/// mantığı [AuthScreen]'i açmaktan ibaret, değişmedi); giriş yapılmışsa
/// e-posta + "Çıkış Yap".
class _HesapCardBody extends StatelessWidget {
  const _HesapCardBody({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final mutedColor = isDark
        ? AppTheme.textTertiaryDark
        : AppTheme.dashboardTextMuted;

    return _AuthWatcher(
      builder: (context, auth, user) {
        final signedIn = user != null;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    signedIn ? 'Hesap' : 'Hesap (deneme)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signedIn
                        ? (user.email ?? '')
                        : 'Giriş yap / kayıt ol — test aşamasında, '
                              'zorunlu değil',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            if (signedIn)
              _OutlinedPillButton(
                label: 'Çıkış Yap',
                isDark: isDark,
                onTap: () => auth.signOut(),
              )
            else
              _GradientPillButton(
                label: 'Giriş yap / Kayıt ol',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(authService: auth),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Veri kartının içeriği: bulut illüstrasyonu + dışa/içe aktarma satırları.
/// Satırların KENDİSİ tıklanabilir değil — asıl aksiyon trailing'deki
/// butonda (bkz. [_SettingsRow.onTap] doküman notu); dar ekranda taşmayı
/// önlemek için illüstrasyon satırların ÜSTÜNE alınır (bkz. [LayoutBuilder]).
class _VeriCardBody extends StatelessWidget {
  const _VeriCardBody({
    required this.isDark,
    required this.onExport,
    required this.onImport,
  });

  final bool isDark;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      children: [
        _SettingsRow(
          icon: Icons.download_outlined,
          accent: _Accent.violet,
          isDark: isDark,
          title: 'Yedeği dışa aktar',
          subtitle: 'Her desteyi ayrı bir JSON dosyası olarak indir',
          trailing: _GradientPillButton(label: 'Dışa aktar', onTap: onExport),
        ),
        const SizedBox(height: AppTheme.space12),
        _SettingsRow(
          icon: Icons.upload_outlined,
          accent: _Accent.danger,
          isDark: isDark,
          title: 'Yedekten içe aktar',
          subtitle: 'Mevcut verinin yerine bir JSON yedeği yükle',
          trailing: _OutlinedPillButton(
            label: 'İçe aktar',
            isDark: isDark,
            color: Theme.of(context).colorScheme.error,
            onTap: onImport,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sidebar sabit genişlikte olduğu için dar ekranlarda kart genişliği
        // illüstrasyon + iki satırı yan yana taşımaya yetmeyebilir — o
        // aralıkta illüstrasyon satırların üstüne alınır.
        final compact = constraints.maxWidth < 420;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CloudIllustration(isDark: isDark),
              const SizedBox(height: AppTheme.space16),
              rows,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CloudIllustration(isDark: isDark),
            const SizedBox(width: AppTheme.space16),
            Expanded(child: rows),
          ],
        );
      },
    );
  }
}

/// Saf dekoratif bulut+indirme illüstrasyonu (referans tasarımdaki gibi) —
/// hiçbir veriye/duruma bağlı değil.
class _CloudIllustration extends StatelessWidget {
  const _CloudIllustration({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.heroNeutralFill : AppTheme.dashboardSurfaceElevated;
    final fg = isDark ? AppTheme.textTertiaryDark : AppTheme.dashboardTextMuted;
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.cloud_outlined, size: 44, color: fg),
          Positioned(
            bottom: 16,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.dashboardCtaGradient,
              ),
              child: const Icon(Icons.arrow_downward, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chevron'lu, salt gezinme satırı — Yasal kartındaki iki madde.
class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.icon,
    required this.isDark,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final bool isDark;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = isDark
        ? AppTheme.textPrimaryDark
        : AppTheme.dashboardTextPrimary;
    final mutedColor = isDark ? AppTheme.textTertiaryDark : AppTheme.dashboardTextMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: mutedColor),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tema seçimi için tıklanabilir önizleme kartı. [dark] bu kartın TEMSİL
/// ETTİĞİ modu belirtir (uygulamanın o anki temasından bağımsız — bir
/// önizleme her zaman kendi modunun renklerini gösterir); [appIsDark]
/// yalnızca SEÇİLİ-DEĞİL çerçevesinin rengini uygulamanın mevcut
/// parlaklığına göre ayarlamak için.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.dark,
    required this.label,
    required this.selected,
    required this.appIsDark,
    required this.onTap,
  });

  final bool dark;
  final String label;
  final bool selected;
  final bool appIsDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewBg = dark ? AppTheme.heroBackground : AppTheme.dashboardBackground;
    final previewSurface = dark ? AppTheme.heroSurface : AppTheme.dashboardSurface;
    final previewLine = dark
        ? AppTheme.heroNeutralFill
        : AppTheme.dashboardSurfaceElevated;
    final previewText = dark ? AppTheme.textPrimaryDark : AppTheme.dashboardTextPrimary;
    final neutralBorder = appIsDark ? AppTheme.heroBorder : AppTheme.dashboardSubtleBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: previewBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.dashboardVioletDeep : neutralBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    height: 64,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: previewSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: previewLine,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 6,
                          width: 70,
                          decoration: BoxDecoration(
                            color: previewLine,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 6,
                          width: 100,
                          decoration: BoxDecoration(
                            color: previewLine,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    dark ? Icons.dark_mode : Icons.light_mode,
                    size: 20,
                    color: previewText,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: previewText,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.dashboardCtaGradient,
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İki sütunlu bölüm ızgarası — `StatsScreen._SectionGrid` ile aynı desen
/// (dar ekranda tek sütuna düşer, sütun sırası left→right akar).
class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.columns, required this.left, required this.right});

  final int columns;
  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    if (columns < 2) {
      // Tek sütuna düşünce sol/sağı ARDIŞIK değil, SATIR SATIR (Görünüm,
      // Çalışma, Hesap, Veri, Yasal) diziyoruz — ızgaradaki eşleşmeyi
      // (satır 1: Görünüm|Çalışma, satır 2: Hesap|Veri) korur, hem de "tüm
      // sol sütun önce" sıralamasının Çalışma kartını (limit/hedef, testler
      // buradan tıklıyor) gereksiz yere aşağı itmesini önler.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spaced(_rowMajor(left, right)),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(left),
          ),
        ),
        const SizedBox(width: AppTheme.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(right),
          ),
        ),
      ],
    );
  }

  static List<Widget> _rowMajor(List<Widget> left, List<Widget> right) {
    final merged = <Widget>[];
    final maxLen = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < maxLen; i++) {
      if (i < left.length) merged.add(left[i]);
      if (i < right.length) merged.add(right[i]);
    }
    return merged;
  }

  static List<Widget> _spaced(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) result.add(const SizedBox(height: AppTheme.space16));
    }
    return result;
  }
}
