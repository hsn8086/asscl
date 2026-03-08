import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

/// Whether the user has completed the onboarding flow.
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final value = await dao.getValue('onboardingCompleted');
  return value == 'true';
});
