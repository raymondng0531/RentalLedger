import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firebase_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../domain/entities/notification_entity.dart';

final notificationDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSource();
});

final notificationsStreamProvider =
    StreamProvider<List<NotificationEntity>>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) return Stream.value([]);

  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final ds = ref.watch(notificationDataSourceProvider);
  return ds.notificationsStream(user.uid);
});

/// Unread notification count, derived from the SAME realtime stream the list
/// renders. There is exactly one source of truth, so marking a notification
/// read (or receiving a new one) updates the count immediately — no separate
/// Firestore count query that can go stale, no competing unread-count source.
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(
    notificationsStreamProvider,
  ).value ?? const <NotificationEntity>[];
  return notifications.where((n) => !n.isRead).length;
});
