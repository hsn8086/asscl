import 'package:equatable/equatable.dart';

/// A saved chat session with the AI agent.
class ChatSession extends Equatable {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt];
}

/// A single persisted chat message within a session.
class ChatMessageEntity extends Equatable {
  final String id;
  final String sessionId;
  final String role; // 'user', 'assistant', 'system'
  final String? text;
  final List<String> imagePaths; // file system paths
  final String? parsedCoursesJson; // JSON-encoded List<AiParsedCourse>
  final DateTime createdAt;

  const ChatMessageEntity({
    required this.id,
    required this.sessionId,
    required this.role,
    this.text,
    this.imagePaths = const [],
    this.parsedCoursesJson,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, sessionId, role, text, imagePaths, parsedCoursesJson, createdAt];
}
