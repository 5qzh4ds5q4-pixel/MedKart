import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/auth_screen.dart';
import '../services/auth_service.dart';

/// Testlerde gerçek Supabase'e hiç dokunmadan giriş durumunu sabitlemek
/// için. `null` ise (üretimde HER ZAMAN böyledir) gerçek
/// [AuthService.currentUser] kontrol edilir; testler `setUp`'ta `true`/
/// `false` atayıp `tearDown`'da mutlaka `null`'a geri döndürmeli.
bool? debugRequireAuthSignedInOverride;

/// "Bakmak serbest, yapmak üye": giriş gerektiren bir eylemden hemen önce
/// çağrılır. Kullanıcı zaten girişliyse [action] hiç UI göstermeden çalışır;
/// değilse tam sayfa [AuthScreen] açılır ([reason] verilirse ekranda hangi
/// eylemin tetiklediği kısa mesaj olarak gösterilir) ve [action] o an
/// ÇALIŞTIRILMAZ. Kullanıcı giriş yapmayı BAŞARIRSA (`AuthScreen` `pop(true)`
/// ile döner) [action] otomatik çalıştırılır — kullanıcı baştan başlamak
/// zorunda kalmaz. Girişten vazgeçer/başarısız olursa [action] hiç çalışmaz,
/// sessizce geri dönülür.
///
/// Çağıran taraftaki buton bu kontrolden ETKİLENMEZ — asla gizlenmez/devre
/// dışı bırakılmaz, yalnızca basılınca bu kontrolden geçer.
Future<void> requireAuth(
  BuildContext context,
  FutureOr<void> Function() action, {
  String? reason,
}) async {
  final signedIn =
      debugRequireAuthSignedInOverride ?? (AuthService().currentUser != null);

  if (signedIn) {
    await action();
    return;
  }

  final loggedIn = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => AuthScreen(reason: reason)),
  );

  if (loggedIn == true && context.mounted) {
    await action();
  }
}
