import '../entities/period_time.dart';
import '../entities/school_preset.dart';

/// Hardcoded school presets.
/// See docs/contributing_presets.md for how to add your school.
const List<SchoolPreset> kSchoolPresets = [
  SchoolPreset(
    id: 'shaoguan_university',
    name: '韶关学院',
    totalPeriods: 10,
    periods: [
      PeriodTime(periodNumber: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45),
      PeriodTime(periodNumber: 2, startHour: 8, startMinute: 55, endHour: 9, endMinute: 40),
      PeriodTime(periodNumber: 3, startHour: 10, startMinute: 0, endHour: 10, endMinute: 45),
      PeriodTime(periodNumber: 4, startHour: 10, startMinute: 55, endHour: 11, endMinute: 40),
      PeriodTime(periodNumber: 5, startHour: 14, startMinute: 40, endHour: 15, endMinute: 25),
      PeriodTime(periodNumber: 6, startHour: 15, startMinute: 35, endHour: 16, endMinute: 20),
      PeriodTime(periodNumber: 7, startHour: 16, startMinute: 40, endHour: 17, endMinute: 25),
      PeriodTime(periodNumber: 8, startHour: 17, startMinute: 25, endHour: 18, endMinute: 10),
      PeriodTime(periodNumber: 9, startHour: 19, startMinute: 30, endHour: 20, endMinute: 15),
      PeriodTime(periodNumber: 10, startHour: 20, startMinute: 25, endHour: 21, endMinute: 10),
    ],
    aiPromptHint: '韶关学院课表，每天10节课，上午4节(8:00-11:40)、下午4节(14:40-18:10)、晚上2节(19:30-21:10)。',
  ),
];
