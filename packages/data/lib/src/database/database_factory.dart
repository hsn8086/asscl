import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'app_database.dart';

AppDatabase openAppDatabase() {
  return AppDatabase(LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'asscl.db'));
    return NativeDatabase.createInBackground(file);
  }));
}

AppDatabase openInMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
