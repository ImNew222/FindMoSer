import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:findmoser_app/core/app_theme.dart';
import 'package:findmoser_app/features/presence/models/location_model.dart';
import 'package:findmoser_app/features/assistant/screens/ai_chat_screen.dart';
import 'package:findmoser_app/features/assistant/services/faculty_assistant.dart';
import 'faculty_assistant_test.dart' show MemoryFacultyRepository;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final output = Platform.environment['PREVIEW_OUTPUT'];
    if (output == null) return;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('assistant answers and follows up without loading a model', (
    tester,
  ) async {
    phone(tester);
    final key = GlobalKey();
    final now = DateTime.utc(2026, 9, 24, 1, 30);
    final repo = MemoryFacultyRepository()
      ..record = FacultyLocation(
        facultyId: 'ana',
        currentRoom: 'AC-205',
        zoneName: 'IT Department',
        beaconId: 'b',
        timestamp: now.subtract(const Duration(minutes: 1)),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          facultyAssistantProvider.overrideWithValue(
            FacultyAssistant(repo, clock: () => now),
          ),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const AiChatScreen(),
          ),
        ),
      ),
    );
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Where is Ana Cruz?');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Detected in IT Department', findRichText: true),
      findsOneWidget,
    );
    await capture(tester, key, 'faculty-assistant');
    await tester.enterText(find.byType(TextField), 'What about her schedule?');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Programming', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('New conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Who are you looking for?'), findsOneWidget);
  });
}
