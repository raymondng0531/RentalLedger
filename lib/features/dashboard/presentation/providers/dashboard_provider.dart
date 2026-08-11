import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../domain/entities/dashboard_data.dart';

/// Provides the [DashboardRemoteDataSource].
final dashboardDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource();
});

/// Streams dashboard data for the current house in real-time.
///
/// Updates automatically whenever the house balance, expenses, or
/// transactions change in Firestore.
final dashboardDataProvider = StreamProvider<DashboardData>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) {
    return Stream.error(const FirebaseFailure('Firebase is not configured.'));
  }

  final house = ref.watch(currentHouseProvider);
  if (house == null) {
    return Stream.error(const NotFoundFailure('No house found.'));
  }

  final dataSource = ref.watch(dashboardDataSourceProvider);
  return dataSource.fetchDashboardStream(house.houseId);
});
