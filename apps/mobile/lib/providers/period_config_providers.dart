import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

final periodConfigRepositoryProvider = Provider<PeriodConfigRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PeriodConfigRepositoryImpl(PeriodTimeDao(db), SettingsDao(db));
});

final periodConfigProvider = StreamProvider<PeriodConfig>((ref) {
  return ref.watch(periodConfigRepositoryProvider).watchConfig();
});
