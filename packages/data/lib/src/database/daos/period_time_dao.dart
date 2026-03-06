import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/period_times_table.dart';

part 'period_time_dao.g.dart';

@DriftAccessor(tables: [PeriodTimesTable])
class PeriodTimeDao extends DatabaseAccessor<AppDatabase>
    with _$PeriodTimeDaoMixin {
  PeriodTimeDao(super.db);

  Stream<List<PeriodTimesTableData>> watchAll() =>
      (select(periodTimesTable)
            ..orderBy([(t) => OrderingTerm.asc(t.periodNumber)]))
          .watch();

  Future<List<PeriodTimesTableData>> getAll() =>
      (select(periodTimesTable)
            ..orderBy([(t) => OrderingTerm.asc(t.periodNumber)]))
          .get();

  Future<void> replaceAll(List<PeriodTimesTableCompanion> entries) =>
      transaction(() async {
        await delete(periodTimesTable).go();
        for (final entry in entries) {
          await into(periodTimesTable).insert(entry);
        }
      });

  Future<void> deleteAll() => delete(periodTimesTable).go();
}
