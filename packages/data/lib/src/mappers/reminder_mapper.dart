import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

import '../database/app_database.dart';

extension ReminderRowToDomain on RemindersTableData {
  domain.Reminder toDomain() => domain.Reminder(
        id: id,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        type: type,
        linkedEntityId: linkedEntityId,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ReminderDomainToCompanion on domain.Reminder {
  RemindersTableCompanion toCompanion() => RemindersTableCompanion(
        id: Value(id),
        title: Value(title),
        body: Value(body),
        scheduledAt: Value(scheduledAt),
        type: Value(type),
        linkedEntityId: Value(linkedEntityId),
        isActive: Value(isActive),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      );
}
