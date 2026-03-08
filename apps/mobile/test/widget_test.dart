import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asscl/app.dart';
import 'package:asscl/providers/onboarding_provider.dart';

void main() {
  testWidgets('App shows onboarding on first launch',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompletedProvider.overrideWith((_) async => false),
        ],
        child: const App(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('欢迎使用课程表'), findsOneWidget);
  });
}
