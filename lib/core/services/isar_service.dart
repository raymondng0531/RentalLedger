import 'package:flutter/foundation.dart';

/// Offline cache service using Isar.
///
/// Isar is used to cache Firestore data for offline access
/// and faster loading on subsequent app launches.
///
/// This is a placeholder that will be fully implemented
/// during the offline-support sprint.
class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  bool _initialized = false;

  /// Whether Isar has been initialized.
  bool get isInitialized => _initialized;

  /// Initializes Isar and opens the local database.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // TODO: Initialize Isar instance when offline feature is implemented.
      // final dir = await getApplicationDocumentsDirectory();
      // final isar = await Isar.open(
      //   [ExpenseSchema, CategorySchema],
      //   directory: dir.path,
      // );
      _initialized = true;
      debugPrint('[IsarService] Initialized successfully.');
    } catch (e, stackTrace) {
      debugPrint('[IsarService] Failed to initialize: $e');
      debugPrint('[IsarService] Stack trace: $stackTrace');
    }
  }
}
