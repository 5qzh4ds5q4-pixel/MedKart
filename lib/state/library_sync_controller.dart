import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'flashcard_store.dart';

/// Giriş yapıldığında kütüphaneyi (Faz 2) buluta/bulut'tan senkronlar.
///
/// Zorunlu login kapısı YOK: bu denetleyici yalnızca [AuthService.
/// authStateChanges] `signedIn` olayını dinler, o ana kadar hiçbir şey
/// yapmaz — anonim kullanım tamamen etkilenmeden sürer.
///
/// Akış (giriş anında): buluttan indir → bulut boşsa lokali olduğu gibi
/// buluta yaz; bulutta veri varsa [SyncService.mergeLibraries] ile birleştir,
/// sonucu HEM lokale (`store.replaceLibrary`) HEM buluta yaz. Sonraki
/// kütüphane değişikliklerinde (yeni kart, SM-2 güncellemesi vb.) 8 saniyelik
/// debounce ile buluta yazılır — her küçük değişiklikte ayrı istek atılmaz.
class LibrarySyncController extends ChangeNotifier {
  LibrarySyncController({
    required FlashcardStore store,
    AuthService? authService,
    SyncService? syncService,
  }) : _store = store,
       _auth = authService ?? AuthService(),
       _sync = syncService ?? SyncService() {
    _authSub = _auth.authStateChanges.listen(_onAuthStateChange);
    final user = _auth.currentUser;
    if (user != null) _runLoginSync(user.id);
  }

  /// Buluta yazmadan önce beklenecek sessizlik süresi (debounce).
  static const Duration uploadDebounce = Duration(seconds: 8);

  final FlashcardStore _store;
  final AuthService _auth;
  final SyncService _sync;

  StreamSubscription<AuthState>? _authSub;
  VoidCallback? _storeListener;
  Timer? _debounce;
  String? _syncedUserId;

  bool _isSyncing = false;

  /// Giriş sonrası indir/birleştir/yükleme akışı sürüyor mu — UI bunu
  /// "Verilerin senkronize ediliyor..." göstergesi için izler.
  bool get isSyncing => _isSyncing;

  void _onAuthStateChange(AuthState state) {
    final user = state.session?.user;
    if (state.event == AuthChangeEvent.signedIn && user != null) {
      _runLoginSync(user.id);
    } else if (state.event == AuthChangeEvent.signedOut) {
      _stopWatchingStore();
      _syncedUserId = null;
    }
  }

  Future<void> _runLoginSync(String userId) async {
    if (_syncedUserId == userId) return;
    _syncedUserId = userId;

    _setSyncing(true);
    try {
      final remote = await _sync.downloadLibrary(userId);
      if (remote == null || remote.isEmpty) {
        await _sync.uploadLibrary(userId, _store.libraryData);
      } else {
        final merged = SyncService.mergeLibraries(_store.libraryData, remote);
        _store.replaceLibrary(merged);
        await _sync.uploadLibrary(userId, merged);
      }
    } finally {
      _setSyncing(false);
      _watchStoreForUpload(userId);
    }
  }

  void _watchStoreForUpload(String userId) {
    _stopWatchingStore();
    _storeListener = () => _scheduleUpload(userId);
    _store.addListener(_storeListener!);
  }

  void _scheduleUpload(String userId) {
    _debounce?.cancel();
    _debounce = Timer(uploadDebounce, () {
      _sync.uploadLibrary(userId, _store.libraryData);
    });
  }

  void _stopWatchingStore() {
    _debounce?.cancel();
    _debounce = null;
    final listener = _storeListener;
    if (listener != null) {
      _store.removeListener(listener);
      _storeListener = null;
    }
  }

  void _setSyncing(bool value) {
    if (_isSyncing == value) return;
    _isSyncing = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _stopWatchingStore();
    super.dispose();
  }
}
