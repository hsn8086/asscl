import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

import '../database/app_database.dart';

extension TaskRowToDomain on TasksTableData {
  domain.Task toDomain({List<domain.SubTask> subtasks = const []}) =>
      domain.Task(
        id: id,
        title: title,
        description: description,
        priority: priority,
        isDone: isDone,
        dueDate: dueDate,
        courseId: courseId,
        subtasks: subtasks,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension TaskDomainToCompanion on domain.Task {
  TasksTableCompanion toCompanion() => TasksTableCompanion(
        id: Value(id),
        title: Value(title),
        description: Value(description),
        priority: Value(priority),
        isDone: Value(isDone),
        dueDate: Value(dueDate),
        courseId: Value(courseId),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      );
}

extension SubTaskRowToDomain on SubTasksTableData {
  domain.SubTask toDomain() => domain.SubTask(
        id: id,
        title: title,
        isDone: isDone,
      );
}

extension SubTaskDomainToCompanion on domain.SubTask {
  SubTasksTableCompanion toCompanion(String taskId) => SubTasksTableCompanion(
        id: Value(id),
        taskId: Value(taskId),
        title: Value(title),
        isDone: Value(isDone),
      );
}
