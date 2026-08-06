import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/content_shell.dart';

/// Basit, kaydırılabilir yasal metin görüntüleyici (Gizlilik Politikası /
/// Kullanım Koşulları). İçerik çağıran taraftan gelir (bkz.
/// `lib/content/legal_content.dart`) — bu ekran salt bir vitrin.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ContentShell(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
            child: Text(content, style: theme.textTheme.bodyMedium),
          ),
        ),
      ),
    );
  }
}
