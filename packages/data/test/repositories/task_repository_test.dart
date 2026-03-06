import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:domain/domain.dart' as domain;
import 'package:data/data.dart';

void main() {
  late AppDatabase db;
  late TaskRepositoryImpl repo;

  final now = DateTime(2026, 3, 5);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskRepositoryImpl(TaskDao(db));
  });

  tearDown(() => db.close());

  domain.Task makeTask({
    String id = '1',
    String title = 'Homework',
    List<domain.SubTask> subtasks = const [],
  }) =>
      domain.Task(
        id: id,
        title: title,
        subtasks: subtasks,
        createdAt: now,
        updatedAt: now,
      );

  test('save and findById with subtasks', () async {
    final task = makeTask(
      subtasks: [
        const domain.SubTask(id: 's1', title: 'Part A'),
        const domain.SubTask(id: 's2', title: 'Part B', isDone: true),
      ],
    );
    await repo.save(task);
    final found = await repo.findById('1');
    expect(found, isNotNull);
    expect(found!.title, 'Homework');
    expect(found.subtasks.length, 2);
    expect(found.subtasks[1].isDone, true);
  });

  test('save replaces subtasks on update', () async {
    await repo.save(makeTask(
      subtasks: [const domain.SubTask(id: 's1', title: 'Part A')],
    ));
    await repo.save(makeTask(
      subtasks: [const domain.SubTask(id: 's2', title: 'Part B')],
    ));
    final found = await repo.findById('1');
    expect(found!.subtasks.length, 1);
    expect(found.subtasks.first.title, 'Part B');
  });

  test('markDone updates isDone', () async {
    await repo.save(makeTask());
    await repo.markDone('1', done: true);
    final found = await repo.findById('1');
    expect(found!.isDone, true);
  });

  test('delete removes task and subtasks', () async {
    await repo.save(makeTask(
      subtasks: [const domain.SubTask(id: 's1', title: 'Part A')],
    ));
    await repo.delete('1');
    final found = await repo.findById('1');
    expect(found, isNull);
  });
}
