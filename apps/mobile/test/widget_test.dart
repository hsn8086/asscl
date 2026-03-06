import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asscl/app.dart';

void main() {
  testWidgets('App renders with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('课程表'), findsOneWidget);
    expect(find.text('任务'), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
  });
}
