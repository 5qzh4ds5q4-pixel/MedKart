import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/legal_content.dart';
import '../services/backup_service.dart';
import '../services/file_transfer.dart';
import '../state/flashcard_store.dart';
import '../state/study_settings.dart';
import '../utils/breakpoints.dart';
import '../utils/require_auth.dart';
import '../widgets/content_shell.dart';
import '../widgets/daily_goal_dialog.dart';
import '../widgets/daily_limit_dialog.dart';
import '../widgets/theme_toggle_button.dart';
import 'auth_screen.dart';
import 'legal_screen.dart';

/// Ayarlar ekranı: görünüm (tema), günlük çalışma limiti ve yedekleme.
///
/// Ayrı bir "ayarlar" veri modeli yok — burası daha önce ana ekranın
/// AppBar'ına dağılmış olan kontrolleri (tema, günlük limit, yedek
/// dışa/içe aktarma) tek bir yüzeyde toplar.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: ContentShell(
          child: ResponsiveBuilder(
            builder: (context, size) {
              final horizontal = responsiveHorizontalPadding(size);
              return ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
                children: [
                  _SectionTitle('Görünüm'),
                  const SizedBox(height: 4),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                      ),
                      title: const Text('Tema'),
                      subtitle: Text(isDark ? 'Koyu' : 'Açık'),
                      trailing: const ThemeToggleButton(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Çalışma'),
                  const SizedBox(height: 4),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.tune_outlined),
                          title: const Text('Günlük yeni kart limiti'),
                          subtitle: Text(
                            'Günde en fazla $dailyLimit yeni kart',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _editDailyLimit(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title: const Text('Günlük hedef (opsiyonel)'),
                          subtitle: Text(
                            dailyGoal == null
                                ? 'Belirlenmedi — istatistikte hedef halkası '
                                      'gösterilmez'
                                : 'Günde $dailyGoal kart',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _editDailyGoal(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // FAZ 1 (auth iskeleti): zorunlu kapı yok, anonim akış
                  // aynen sürüyor — bu giriş yalnızca auth'u test etmek için.
                  _SectionTitle('Hesap'),
                  const SizedBox(height: 4),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: const Text('Hesap (deneme)'),
                      subtitle: const Text(
                        'Giriş yap / kayıt ol — test aşamasında, zorunlu değil',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Veri'),
                  const SizedBox(height: 4),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.download_outlined),
                          title: const Text('Yedeği dışa aktar'),
                          subtitle: const Text(
                            'Her desteyi ayrı bir JSON dosyası olarak indir',
                          ),
                          onTap: () => _exportBackup(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.upload_outlined),
                          title: const Text('Yedekten içe aktar'),
                          subtitle: const Text(
                            'Mevcut verinin yerine bir JSON yedeği yükle',
                          ),
                          onTap: () => _importBackup(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Yasal'),
                  const SizedBox(height: 4),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('Kullanım Koşulları'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openLegalScreen(
                            context,
                            LegalContent.termsOfServiceTitle,
                            LegalContent.termsOfService,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Gizlilik Politikası'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openLegalScreen(
                            context,
                            LegalContent.privacyPolicyTitle,
                            LegalContent.privacyPolicy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}
