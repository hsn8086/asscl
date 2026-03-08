import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/semester_providers.dart';
import '../../providers/view_providers.dart';
import 'widgets/week_grid_view.dart';
import 'widgets/time_stream_view.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final week = ref.read(selectedWeekProvider);
    _pageController = PageController(initialPage: week - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setAsCurrentWeek(
    BuildContext context,
    int weekNumber,
  ) async {
    final semester = ref.read(activeSemesterProvider);
    if (semester == null) return;

    // Calculate new startDate so that currentWeek() == weekNumber
    // currentWeek = ((today - startDate).inDays ~/ 7) + 1 == weekNumber
    // => startDate = thisMonday - (weekNumber - 1) * 7 days
    final now = DateTime.now();
    final thisMonday =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final newStartDate = thisMonday.subtract(Duration(days: (weekNumber - 1) * 7));

    final updated = Semester(
      id: semester.id,
      name: semester.name,
      startDate: newStartDate,
      totalWeeks: semester.totalWeeks,
      createdAt: semester.createdAt,
    );
    await ref.read(semesterRepositoryProvider).save(updated);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将第$weekNumber周设为本周')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewType = ref.watch(viewTypeProvider);
    final weekNumber = ref.watch(selectedWeekProvider);
    final realWeek = ref.watch(currentWeekProvider);
    final semester = ref.watch(activeSemesterProvider);
    final maxWeek = semester?.totalWeeks ?? 30;

    // Sync PageView when week changes from buttons/chips.
    if (_pageController.hasClients &&
        _pageController.page?.round() != weekNumber - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            weekNumber - 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: weekNumber > 1
                  ? () => ref.read(selectedWeekProvider.notifier).state--
                  : null,
            ),
            GestureDetector(
              onTap: () => context.push('/settings'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  '第$weekNumber周',
                  style: weekNumber != realWeek
                      ? TextStyle(
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: weekNumber < maxWeek
                  ? () => ref.read(selectedWeekProvider.notifier).state++
                  : null,
            ),
            if (weekNumber != realWeek)
              GestureDetector(
                onTap: () =>
                    ref.read(selectedWeekProvider.notifier).state = realWeek,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '本周',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(viewType == ViewType.weekGrid
                ? Icons.view_agenda
                : Icons.grid_view),
            tooltip: viewType == ViewType.weekGrid ? '时间流视图' : '周视图',
            onPressed: () {
              ref.read(viewTypeProvider.notifier).state =
                  viewType == ViewType.weekGrid
                      ? ViewType.timeStream
                      : ViewType.weekGrid;
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'set_current_week':
                  _setAsCurrentWeek(context, weekNumber);
                case 'settings':
                  context.push('/settings');
              }
            },
            itemBuilder: (_) => [
              if (weekNumber != realWeek)
                const PopupMenuItem(
                  value: 'set_current_week',
                  child: Text('设置为本周'),
                ),
              const PopupMenuItem(value: 'settings', child: Text('设置')),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: maxWeek,
        onPageChanged: (index) {
          ref.read(selectedWeekProvider.notifier).state = index + 1;
        },
        itemBuilder: (context, index) {
          return viewType == ViewType.weekGrid
              ? const WeekGridView()
              : const TimeStreamView();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/schedule/course/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
