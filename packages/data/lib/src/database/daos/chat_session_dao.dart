import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/chat_sessions_table.dart';
import '../tables/chat_messages_table.dart';

part 'chat_session_dao.g.dart';

@DriftAccessor(tables: [ChatSessionsTable, ChatMessagesTable])
class ChatSessionDao extends DatabaseAccessor<AppDatabase>
    with _$ChatSessionDaoMixin {
  ChatSessionDao(super.db);

  /// Get all sessions ordered by most recent first.
  Future<List<ChatSessionsTableData>> getAllSessions() =>
      (select(chatSessionsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  /// Watch all sessions.
  Stream<List<ChatSessionsTableData>> watchAllSessions() =>
      (select(chatSessionsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  /// Get a single session by id.
  Future<ChatSessionsTableData?> getSession(String id) =>
      (select(chatSessionsTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Create or update a session.
  Future<void> upsertSession(ChatSessionsTableCompanion session) =>
      into(chatSessionsTable).insertOnConflictUpdate(session);

  /// Delete a session and its messages (cascade).
  Future<void> deleteSession(String id) =>
      (delete(chatSessionsTable)..where((t) => t.id.equals(id))).go();

  /// Get all messages for a session, ordered by creation time.
  Future<List<ChatMessagesTableData>> getMessages(String sessionId) =>
      (select(chatMessagesTable)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Watch messages for a session.
  Stream<List<ChatMessagesTableData>> watchMessages(String sessionId) =>
      (select(chatMessagesTable)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// Insert a message.
  Future<void> insertMessage(ChatMessagesTableCompanion message) =>
      into(chatMessagesTable).insert(message);

  /// Delete all messages for a session.
  Future<void> deleteMessages(String sessionId) =>
      (delete(chatMessagesTable)..where((t) => t.sessionId.equals(sessionId)))
          .go();

  /// Encode image paths to JSON string.
  static String encodeImagePaths(List<String> paths) => jsonEncode(paths);

  /// Decode image paths from JSON string.
  static List<String> decodeImagePaths(String json) =>
      (jsonDecode(json) as List<dynamic>).cast<String>();
}
