import 'package:equatable/equatable.dart';

import '../enums/priority.dart';

class Task extends Equatable {
  final String id;
  final String title;
  final String? description;
  final Priority priority;
  final bool isDone;
  final DateTime? dueDate;
  final String? courseId;
  final List<SubTask> subtasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.priority = Priority.medium,
    this.isDone = false,
    this.dueDate,
    this.courseId,
    this.subtasks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? Function()? description,
    Priority? priority,
    bool? isDone,
    DateTime? Function()? dueDate,
    String? Function()? courseId,
    List<SubTask>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description != null ? description() : this.description,
      priority: priority ?? this.priority,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate != null ? dueDate() : this.dueDate,
      courseId: courseId != null ? courseId() : this.courseId,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        priority,
        isDone,
        dueDate,
        courseId,
        subtasks,
        createdAt,
        updatedAt,
      ];
}

class SubTask extends Equatable {
  final String id;
  final String title;
  final bool isDone;

  const SubTask({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  SubTask copyWith({
    String? id,
    String? title,
    bool? isDone,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  @override
  List<Object?> get props => [id, title, isDone];
}
