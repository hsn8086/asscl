// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_dao.dart';

// ignore_for_file: type=lint
mixin _$ChatSessionDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChatSessionsTableTable get chatSessionsTable =>
      attachedDatabase.chatSessionsTable;
  $ChatMessagesTableTable get chatMessagesTable =>
      attachedDatabase.chatMessagesTable;
  ChatSessionDaoManager get managers => ChatSessionDaoManager(this);
}

class ChatSessionDaoManager {
  final _$ChatSessionDaoMixin _db;
  ChatSessionDaoManager(this._db);
  $$ChatSessionsTableTableTableManager get chatSessionsTable =>
      $$ChatSessionsTableTableTableManager(
        _db.attachedDatabase,
        _db.chatSessionsTable,
      );
  $$ChatMessagesTableTableTableManager get chatMessagesTable =>
      $$ChatMessagesTableTableTableManager(
        _db.attachedDatabase,
        _db.chatMessagesTable,
      );
}
