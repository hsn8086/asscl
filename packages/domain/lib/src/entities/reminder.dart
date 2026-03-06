import 'package:equatable/equatable.dart';

import '../enums/reminder_type.dart';

class Reminder extends Equatable {
  final String id;
  final String title;
  final String? body;
  final DateTime scheduledAt;
  final ReminderType type;
  final String? linkedEntityId; // courseId or taskId
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reminder({
    required this.id,
    required this.title,
    this.body,
    required this.scheduledAt,
    this.type = ReminderType.custom,
    this.linkedEntityId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? Function()? body,
    DateTime? scheduledAt,
    ReminderType? type,
    String? Function()? linkedEntityId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body != null ? body() : this.body,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      type: type ?? this.type,
      linkedEntityId:
          linkedEntityId != null ? linkedEntityId() : this.linkedEntityId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        scheduledAt,
        type,
        linkedEntityId,
        isActive,
        createdAt,
        updatedAt,
      ];
}
