import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TaskRepositoryImpl(TaskDao(db));
});

final watchTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchAll();
});

final taskDetailProvider =
    FutureProvider.family<Task?, String>((ref, id) {
  return ref.watch(taskRepositoryProvider).findById(id);
});
