import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:findmoser_app/config/app_theme.dart';
import 'package:findmoser_app/providers/ble_provider.dart';
import 'package:findmoser_app/providers/favorites_provider.dart';
import 'package:findmoser_app/models/user_model.dart';
import 'package:findmoser_app/models/location_model.dart';
import 'package:findmoser_app/screens/student/find_faculty_screen.dart';
import 'package:findmoser_app/screens/student/ai_chat_screen.dart';
import 'package:findmoser_app/widgets/app_navigation.dart';
import 'package:findmoser_app/services/assistant/faculty_assistant.dart';
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

  testWidgets('faculty filters work and the phone layout fits', (tester) async {
    phone(tester);
    final key = GlobalKey();
    final people = [
      const AppUser(
        uid: 'ana',
        displayName: 'Ana Cruz',
        email: '',
        role: 'faculty',
        department: 'BSIT',
        availability: 'available',
      ),
      const AppUser(
        uid: 'ben',
        displayName: 'Benjamin Reyes',
        email: '',
        role: 'faculty',
        department: 'BSCS',
        availability: 'teaching',
      ),
      const AppUser(
        uid: 'maria',
        displayName: 'Maria Santos',
        email: '',
        role: 'faculty',
        department: 'BSIT',
      ),
    ];
    final cards = people
        .asMap()
        .entries
        .map(
          (e) => FacultyLocationWithName(
            user: e.value,
            displayName: e.value.displayName,
            department: e.value.department,
            location: FacultyLocation(
              facultyId: e.value.uid,
              currentRoom: e.key == 0 ? 'AC-205' : 'Faculty Office',
              beaconId: '',
              timestamp: DateTime.now().subtract(
                Duration(minutes: e.key == 1 ? 28 : 1),
              ),
              isVisible: e.key != 2,
            ),
          ),
        )
        .toList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allFacultyLocationsProvider.overrideWithValue(AsyncData(cards)),
          locationCacheProvider.overrideWithValue(false),
          favoritesProvider.overrideWith((ref) => Stream.value({'ana'})),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: Scaffold(
              appBar: AppBar(title: const Text('FindMoSer')),
              body: AppNavigation(
                index: 1,
                onChanged: (_) {},
                destinations: const [
                  (Icons.home_outlined, 'Home'),
                  (Icons.search, 'Find'),
                  (Icons.history, 'Activity'),
                  (Icons.person_outline, 'Profile'),
                ],
                child: const FindFacultyScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'find-faculty');
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('Benjamin Reyes'), findsNothing);
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'BSCS');
    await tester.pumpAndSettle();
    expect(find.text('Ana Cruz'), findsNothing);
    expect(find.text('Benjamin Reyes'), findsOneWidget);
  });
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
