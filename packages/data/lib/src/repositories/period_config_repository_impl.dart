import 'package:domain/domain.dart';
import 'package:rxdart/rxdart.dart';

import '../database/daos/period_time_dao.dart';
import '../database/daos/settings_dao.dart';
import '../mappers/period_time_mapper.dart';

class PeriodConfigRepositoryImpl implements PeriodConfigRepository {
  final PeriodTimeDao _periodTimeDao;
  final SettingsDao _settingsDao;

  PeriodConfigRepositoryImpl(this._periodTimeDao, this._settingsDao);

  @override
  Stream<PeriodConfig> watchConfig() {
    final periodsStream =
        _periodTimeDao.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());
    final totalPeriodsStream = _settingsDao
        .watchValue('totalPeriods')
        .map((v) => v != null ? int.tryParse(v) ?? 12 : 12);
    final presetIdStream = _settingsDao.watchValue('presetId');

    return Rx.combineLatest3(
      periodsStream,
      totalPeriodsStream,
      presetIdStream,
      (List<PeriodTime> periods, int totalPeriods, String? presetId) =>
          PeriodConfig(
        totalPeriods: totalPeriods,
        periods: periods,
        presetId: presetId,
      ),
    );
  }

  @override
  Future<PeriodConfig> getConfig() async {
    final rows = await _periodTimeDao.getAll();
    final periods = rows.map((r) => r.toDomain()).toList();
    final totalPeriodsStr = await _settingsDao.getValue('totalPeriods');
    final totalPeriods =
        totalPeriodsStr != null ? int.tryParse(totalPeriodsStr) ?? 12 : 12;
    final presetId = await _settingsDao.getValue('presetId');
    return PeriodConfig(
      totalPeriods: totalPeriods,
      periods: periods,
      presetId: presetId,
    );
  }

  @override
  Future<void> saveConfig(PeriodConfig config) async {
    await _settingsDao.setValue('totalPeriods', config.totalPeriods.toString());
    if (config.presetId != null) {
      await _settingsDao.setValue('presetId', config.presetId!);
    } else {
      await _settingsDao.deleteKey('presetId');
    }
    await _periodTimeDao
        .replaceAll(config.periods.map((p) => p.toCompanion()).toList());
  }

  @override
  Future<void> applyPreset(String presetId) async {
    final preset = kSchoolPresets.cast<SchoolPreset?>().firstWhere(
        (p) => p!.id == presetId,
        orElse: () => null);
    if (preset == null) return;
    await saveConfig(PeriodConfig(
      totalPeriods: preset.totalPeriods,
      periods: preset.periods,
      presetId: preset.id,
    ));
  }
}
