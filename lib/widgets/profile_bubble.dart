import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_screen.dart';
import '../services/auth_service.dart';

/// Ana ekranın sağ üst köşesinde her zaman görünen dairesel profil butonu.
///
/// Giriş kapısı/zorunluluk YOK — yalnızca durum göstergesi + giriş/çıkış
/// kısayolu. Giriş yapılmamışsa gri/boş bir avatar ikonu gösterilir,
/// dokununca tam sayfa [AuthScreen] açılır. Giriş yapılmışsa e-postanın ilk
/// harfi (amber zemin — `colorScheme.primary`, koyu harf — `onPrimary`,
/// ikisi de zaten [AppTheme]'in amber marka rengine kurulu) gösterilir;
/// dokununca e-posta (salt bilgi) + "Çıkış Yap" içeren küçük bir menü açılır.
class ProfileBubble extends StatefulWidget {
  const ProfileBubble({super.key, this.authService});

  /// Testlerde sahte servis enjekte etmek için; verilmezse gerçek servis.
  final AuthService? authService;

  @override
  State<ProfileBubble> createState() => _ProfileBubbleState();
}

enum _ProfileMenuAction { signOut }

class _ProfileBubbleState extends State<ProfileBubble> {
  late final AuthService _auth = widget.authService ?? AuthService();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Google OAuth dönüşü gibi form dışı oturum değişikliklerinde de
    // baloncuk kendini tazelesin.
    _authSub = _auth.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _openAuthScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AuthScreen(authService: _auth)));
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _auth.currentUser;

    if (user == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          onPressed: _openAuthScreen,
          tooltip: 'Giriş yap',
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.person_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final email = user.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: PopupMenuButton<_ProfileMenuAction>(
        tooltip: 'Hesap',
        position: PopupMenuPosition.under,
        onSelected: (action) {
          if (action == _ProfileMenuAction.signOut) _signOut();
        },
        itemBuilder: (context) => [
          PopupMenuItem<_ProfileMenuAction>(
            enabled: false,
            child: Text(
              email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<_ProfileMenuAction>(
            value: _ProfileMenuAction.signOut,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout),
              title: Text('Çıkış Yap'),
            ),
          ),
        ],
        child: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            initial,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
