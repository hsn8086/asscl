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
    // First pump: FutureProvider resolves. Second pump: router redirects.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('欢迎使用课程表'), findsOneWidget);
  });
}
