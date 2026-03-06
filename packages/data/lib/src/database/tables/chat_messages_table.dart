import 'package:drift/drift.dart';

import 'chat_sessions_table.dart';

class ChatMessagesTable extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(ChatSessionsTable, #id)();
  TextColumn get role => text()(); // 'user', 'assistant', 'system'
  TextColumn get content => text().nullable()();
  TextColumn get imagePaths => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get parsedCoursesJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
