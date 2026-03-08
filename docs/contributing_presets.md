# 贡献学校时间预设

感谢你愿意为项目添加学校时间预设！这份指南将帮助你完成贡献。

## 你需要准备什么

你所在学校的**作息时间表**——每节课的上课和下课时间。通常可以在学校官网、教务系统或学生手册中找到。

## 步骤

### 1. Fork 并克隆仓库

```bash
git clone https://github.com/<your-username>/asscl.git
cd asscl
git checkout -b preset/<your-school-id>
```

### 2. 编辑预设文件

打开 `packages/domain/lib/src/data/school_presets.dart`，在 `kSchoolPresets` 列表中添加一个新的 `SchoolPreset`。

### 3. 数据结构说明

```dart
SchoolPreset(
  id: 'your_school_id',        // 唯一 ID，使用小写英文 + 下划线
  name: '你的学校名称',          // 显示给用户的中文名称
  totalPeriods: 10,             // 每天的总节数
  periods: [
    PeriodTime(
      periodNumber: 1,          // 第几节（从 1 开始）
      startHour: 8,             // 上课时间 - 小时（24 小时制）
      startMinute: 0,           // 上课时间 - 分钟
      endHour: 8,               // 下课时间 - 小时
      endMinute: 45,            // 下课时间 - 分钟
    ),
    // ... 每节课都需要一条 PeriodTime
  ],
  aiPromptHint: '简要描述你的学校作息安排，供 AI 助手参考。',
)
```

### 4. 完整示例

以韶关学院为例：

```dart
SchoolPreset(
  id: 'shaoguan_university',
  name: '韶关学院',
  totalPeriods: 10,
  periods: [
    PeriodTime(periodNumber: 1,  startHour: 8,  startMinute: 0,  endHour: 8,  endMinute: 45),
    PeriodTime(periodNumber: 2,  startHour: 8,  startMinute: 55, endHour: 9,  endMinute: 40),
    PeriodTime(periodNumber: 3,  startHour: 10, startMinute: 0,  endHour: 10, endMinute: 45),
    PeriodTime(periodNumber: 4,  startHour: 10, startMinute: 55, endHour: 11, endMinute: 40),
    PeriodTime(periodNumber: 5,  startHour: 14, startMinute: 40, endHour: 15, endMinute: 25),
    PeriodTime(periodNumber: 6,  startHour: 15, startMinute: 35, endHour: 16, endMinute: 20),
    PeriodTime(periodNumber: 7,  startHour: 16, startMinute: 40, endHour: 17, endMinute: 25),
    PeriodTime(periodNumber: 8,  startHour: 17, startMinute: 25, endHour: 18, endMinute: 10),
    PeriodTime(periodNumber: 9,  startHour: 19, startMinute: 30, endHour: 20, endMinute: 15),
    PeriodTime(periodNumber: 10, startHour: 20, startMinute: 25, endHour: 21, endMinute: 10),
  ],
  aiPromptHint: '韶关学院课表，每天10节课，上午4节(8:00-11:40)、下午4节(14:40-18:10)、晚上2节(19:30-21:10)。',
),
```

### 5. 检查清单

提交前请确认：

- [ ] `id` 使用小写英文和下划线，在列表中唯一
- [ ] `name` 使用学校官方名称
- [ ] `totalPeriods` 与 `periods` 列表长度一致
- [ ] `periodNumber` 从 1 开始，连续编号
- [ ] 时间使用 24 小时制，每节课的结束时间早于下一节课的开始时间
- [ ] `aiPromptHint` 简要概括了作息安排（节数、时间段）
- [ ] 运行 `cd packages/domain && flutter test` 通过

### 6. 提交 PR

```bash
git add packages/domain/lib/src/data/school_presets.dart
git commit -m "feat(preset): 添加 XX 大学时间预设"
git push origin preset/<your-school-id>
```

然后在 GitHub 上创建 Pull Request。

## 注意事项

- 每所学校只需一个预设，如果学校有多个校区且作息不同，可以用 `school_campus_a` / `school_campus_b` 区分
- 如果你的学校作息表发生了变更，也欢迎提交更新
