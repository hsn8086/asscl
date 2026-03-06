import '../entities/period_time.dart';
import '../entities/school_preset.dart';

/// Hardcoded school presets. Add more as needed.
const List<SchoolPreset> kSchoolPresets = [
  SchoolPreset(
    id: 'example_university',
    name: '示例大学',
    totalPeriods: 12,
    periods: [
      PeriodTime(periodNumber: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45),
      PeriodTime(periodNumber: 2, startHour: 8, startMinute: 55, endHour: 9, endMinute: 40),
      PeriodTime(periodNumber: 3, startHour: 10, startMinute: 0, endHour: 10, endMinute: 45),
      PeriodTime(periodNumber: 4, startHour: 10, startMinute: 55, endHour: 11, endMinute: 40),
      PeriodTime(periodNumber: 5, startHour: 14, startMinute: 0, endHour: 14, endMinute: 45),
      PeriodTime(periodNumber: 6, startHour: 14, startMinute: 55, endHour: 15, endMinute: 40),
      PeriodTime(periodNumber: 7, startHour: 16, startMinute: 0, endHour: 16, endMinute: 45),
      PeriodTime(periodNumber: 8, startHour: 16, startMinute: 55, endHour: 17, endMinute: 40),
      PeriodTime(periodNumber: 9, startHour: 19, startMinute: 0, endHour: 19, endMinute: 45),
      PeriodTime(periodNumber: 10, startHour: 19, startMinute: 55, endHour: 20, endMinute: 40),
      PeriodTime(periodNumber: 11, startHour: 20, startMinute: 50, endHour: 21, endMinute: 35),
      PeriodTime(periodNumber: 12, startHour: 21, startMinute: 45, endHour: 22, endMinute: 30),
    ],
    aiPromptHint: '这是一个标准大学课表，每天最多12节课，上午4节、下午4节、晚上4节。',
  ),
];
