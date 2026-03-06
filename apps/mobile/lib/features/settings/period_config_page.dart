import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/period_config_providers.dart';

class PeriodConfigPage extends ConsumerStatefulWidget {
  const PeriodConfigPage({super.key});

  @override
  ConsumerState<PeriodConfigPage> createState() => _PeriodConfigPageState();
}

class _PeriodConfigPageState extends ConsumerState<PeriodConfigPage> {
  String? _selectedPresetId;
  int _totalPeriods = 12;
  List<PeriodTime> _periods = [];
  bool _isLoaded = false;

  void _loadFromConfig(PeriodConfig config) {
    if (_isLoaded) return;
    _isLoaded = true;
    _selectedPresetId = config.presetId;
    _totalPeriods = config.totalPeriods;
    _periods = List.of(config.periods);
  }

  bool get _isPresetMode => _selectedPresetId != null;

  void _onPresetChanged(String? presetId) {
    setState(() {
      _selectedPresetId = presetId;
      if (presetId != null) {
        final preset = kSchoolPresets.firstWhere((p) => p.id == presetId);
        _totalPeriods = preset.totalPeriods;
        _periods = List.of(preset.periods);
      }
    });
  }

  void _onTotalPeriodsChanged(int value) {
    setState(() {
      _totalPeriods = value;
      if (_periods.length > value) {
        _periods = _periods.sublist(0, value);
      }
    });
  }

  Future<void> _editPeriodTime(int periodNumber) async {
    final existing =
        _periods.where((p) => p.periodNumber == periodNumber).firstOrNull;

    final startTime = await showTimePicker(
      context: context,
      initialTime: existing != null
          ? TimeOfDay(hour: existing.startHour, minute: existing.startMinute)
          : const TimeOfDay(hour: 8, minute: 0),
      helpText: '第$periodNumber节 上课时间',
    );
    if (startTime == null || !mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: existing != null
          ? TimeOfDay(hour: existing.endHour, minute: existing.endMinute)
          : TimeOfDay(hour: startTime.hour, minute: startTime.minute + 45),
      helpText: '第$periodNumber节 下课时间',
    );
    if (endTime == null || !mounted) return;

    setState(() {
      _periods.removeWhere((p) => p.periodNumber == periodNumber);
      _periods.add(PeriodTime(
        periodNumber: periodNumber,
        startHour: startTime.hour,
        startMinute: startTime.minute,
        endHour: endTime.hour,
        endMinute: endTime.minute,
      ));
      _periods.sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    });
  }

  Future<void> _savePeriodConfig() async {
    final config = PeriodConfig(
      totalPeriods: _totalPeriods,
      periods: _periods,
      presetId: _selectedPresetId,
    );
    await ref.read(periodConfigRepositoryProvider).saveConfig(config);
    ref.invalidate(periodConfigProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('节次设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(periodConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('节次时间配置')),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (config) {
          _loadFromConfig(config);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _selectedPresetId,
                decoration: const InputDecoration(
                  labelText: '学校预设',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('自定义')),
                  ...kSchoolPresets.map((p) => DropdownMenuItem(
                      value: p.id, child: Text(p.name))),
                ],
                onChanged: _onPresetChanged,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('总节数: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _totalPeriods,
                    items: List.generate(
                      16,
                      (i) => DropdownMenuItem(
                          value: i + 1, child: Text('${i + 1}')),
                    ),
                    onChanged: _isPresetMode
                        ? null
                        : (v) {
                            if (v != null) _onTotalPeriodsChanged(v);
                          },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_totalPeriods, (i) {
                final periodNum = i + 1;
                final pt = _periods
                    .where((p) => p.periodNumber == periodNum)
                    .firstOrNull;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('第$periodNum节'),
                  subtitle: pt != null
                      ? Text('${pt.startTimeStr} - ${pt.endTimeStr}')
                      : const Text('未设置时间',
                          style: TextStyle(color: Colors.grey)),
                  trailing:
                      _isPresetMode ? null : const Icon(Icons.edit, size: 20),
                  onTap:
                      _isPresetMode ? null : () => _editPeriodTime(periodNum),
                );
              }),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _savePeriodConfig,
                icon: const Icon(Icons.save),
                label: const Text('保存节次设置'),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
