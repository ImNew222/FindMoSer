import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findmoser_app/features/assistant/screens/ai_chat_screen.dart';
import 'package:findmoser_app/shared/widgets/app_navigation.dart';

void main() {
  testWidgets('assistant opens without Firebase or a downloaded model', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AiChatScreen())),
    );
    expect(find.text('Faculty assistant'), findsOneWidget);
    expect(find.text('Who are you looking for?'), findsOneWidget);
    expect(find.textContaining('No model download needed'), findsOneWidget);
  });
  testWidgets(
    'phone navigation has visible labels and no overflow at large text',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: AppNavigation(
                index: 0,
                onChanged: (_) {},
                destinations: const [
                  (Icons.home, 'Home'),
                  (Icons.search, 'Find'),
                  (Icons.history, 'Activity'),
                  (Icons.person, 'Profile'),
                ],
                child: const Text('Content'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
