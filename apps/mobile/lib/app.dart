import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:presentation/presentation.dart';

import 'providers/semester_providers.dart';
import 'providers/widget_providers.dart';
import 'router/app_router.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateWidgets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateWidgets();
    }
  }

  void _updateWidgets() {
    final semester = ref.read(activeSemesterProvider);
    ref.read(widgetServiceProvider).updateWidgets(
          semesterName: semester?.name ?? '',
        );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '课程表',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: routerProvider,
      debugShowCheckedModeBanner: false,
    );
  }
}
