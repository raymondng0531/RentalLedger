import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

/// Centralized Firebase initialization and access service.
///
/// All Firebase services are accessed through this class to ensure
/// proper initialization before use.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;

  /// Whether Firebase has been initialized.
  bool get isInitialized => _initialized;

  /// Firebase Auth instance.
  FirebaseAuth get auth => FirebaseAuth.instance;

  /// Firestore instance.
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Firebase Storage instance.
  FirebaseStorage get storage => FirebaseStorage.instance;

  /// Initializes Firebase and all dependent services.
  ///
  /// Must be called once before any Firebase interactions.
  /// Call this from `main.dart` before `runApp()`.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Configure Firestore settings for better offline support.
      // Best-effort: web and some platforms don't support these knobs, so a
      // settings failure must not be reported as an init failure.
      //
      // Web uses Firestore's in-memory cache instead of its IndexedDB one.
      // In the iPhone Home Screen (PWA) app the IndexedDB cache could leave
      // reads hanging after Google sign-in, so the dashboard sat on its
      // loading skeletons while the same account worked in a Safari tab. The
      // web app needs a connection anyway, and native keeps its offline cache.
      try {
        firestore.settings = const Settings(
          persistenceEnabled: !kIsWeb,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        debugPrint('[FirebaseService] Firestore settings skipped: $e');
      }

      // Only mark initialized once everything above has succeeded, so a
      // failure can be retried.
      _initialized = true;
      debugPrint('[FirebaseService] Initialized successfully.');
    } catch (e, stackTrace) {
      debugPrint('[FirebaseService] Failed to initialize: $e');
      debugPrint('[FirebaseService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

// ───── Firebase Init Result ─────

/// Encapsulates the outcome of Firebase initialization.
class FirebaseInitResult {
  const FirebaseInitResult(this.isSuccess, [this.errorMessage]);

  static const success = FirebaseInitResult(true);

  final bool isSuccess;
  final String? errorMessage;
}

/// Riverpod provider that exposes whether Firebase initialized successfully.
///
/// Set via [ProviderOverride] in main.dart before launching the app.
final firebaseInitResultProvider = Provider<FirebaseInitResult>((ref) {
  return FirebaseInitResult.success;
});
