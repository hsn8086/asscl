import '../entities/period_config.dart';

abstract interface class PeriodConfigRepository {
  Stream<PeriodConfig> watchConfig();
  Future<PeriodConfig> getConfig();
  Future<void> saveConfig(PeriodConfig config);
  Future<void> applyPreset(String presetId);
}
