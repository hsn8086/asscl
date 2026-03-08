import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/onboarding_page.dart';
import '../features/schedule/schedule_page.dart';
import '../features/schedule/course_detail_page.dart';
import '../features/schedule/course_form_page.dart';
import '../features/schedule/ai_import_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/period_config_page.dart';
import '../features/settings/semester_manage_page.dart';
import '../features/settings/shortened_names_page.dart';
import '../features/settings/bot_settings_page.dart';
import '../features/settings/ai_config_page.dart';
import '../features/settings/proxy_settings_page.dart';
import '../features/settings/weather_settings_page.dart';
import '../features/settings/webdav_settings_page.dart';
import '../features/settings/developer_page.dart';
import '../features/tasks/tasks_page.dart';
import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_form_page.dart';
import '../features/reminders/reminders_page.dart';
import '../features/reminders/reminder_detail_page.dart';
import '../features/reminders/reminder_form_page.dart';
import '../providers/onboarding_provider.dart';
import 'main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Use nullable bool: null = still loading, false = needs onboarding,
  // true = onboarding completed. This prevents the onboarding page from
  // flashing briefly on startup while the async value resolves.
  final onboardingState = ValueNotifier<bool?>(
    ref.read(onboardingCompletedProvider).valueOrNull,
  );

  ref.listen(onboardingCompletedProvider, (_, next) {
    onboardingState.value = next.valueOrNull;
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/schedule',
    refreshListenable: onboardingState,
    redirect: (context, state) {
      final onboarded = onboardingState.value;
      final goingToOnboarding = state.matchedLocation == '/onboarding';

      // Still loading — stay on current route (schedule shows loading).
      if (onboarded == null) return null;

      if (!onboarded && !goingToOnboarding) return '/onboarding';
      if (onboarded && goingToOnboarding) return '/schedule';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'period-config',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const PeriodConfigPage(),
          ),
          GoRoute(
            path: 'semesters',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const SemesterManagePage(),
          ),
          GoRoute(
            path: 'shortened-names',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const ShortenedNamesPage(),
          ),
          GoRoute(
            path: 'bot',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const BotSettingsPage(),
          ),
          GoRoute(
            path: 'ai-config',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const AiConfigPage(),
          ),
          GoRoute(
            path: 'proxy',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const ProxySettingsPage(),
          ),
          GoRoute(
            path: 'weather',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const WeatherSettingsPage(),
          ),
          GoRoute(
            path: 'webdav',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const WebDavSettingsPage(),
          ),
          GoRoute(
            path: 'developer',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const DeveloperPage(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/schedule',
              builder: (_, __) => const SchedulePage(),
              routes: [
                GoRoute(
                  path: 'course/new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, __) => const CourseFormPage(),
                ),
                GoRoute(
                  path: 'course/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, state) => CourseDetailPage(
                    courseId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, state) => CourseFormPage(
                        courseId: state.pathParameters['id'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/agent',
              builder: (_, __) => const AiImportPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tasks',
              builder: (_, __) => const TasksPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, __) => const TaskFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, state) => TaskDetailPage(
                    taskId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, state) => TaskFormPage(
                        taskId: state.pathParameters['id'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reminders',
              builder: (_, __) => const RemindersPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, __) => const ReminderFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, state) => ReminderDetailPage(
                    reminderId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, state) => ReminderFormPage(
                        reminderId: state.pathParameters['id'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
