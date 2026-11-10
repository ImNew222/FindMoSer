import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/core/user_model.dart';
import 'package:findmoser_app/features/presence/models/location_model.dart';
import 'package:findmoser_app/features/attendance/models/schedule_model.dart';
import 'package:findmoser_app/features/assistant/services/faculty_assistant.dart';
import 'package:findmoser_app/features/presence/services/location_policy.dart';
import 'package:findmoser_app/features/attendance/services/beacon_stability.dart';

class MemoryFacultyRepository implements FacultyRepository {
  List<AppUser> people = [
    const AppUser(
      uid: 'ana',
      displayName: 'Ana Cruz',
      email: '',
      role: 'faculty',
      department: 'BSIT',
      availability: 'available',
    ),
  ];
  FacultyLocation? record;
  bool fail = false;
  int scheduleReads = 0;
  @override
  Future<List<AppUser>> faculty() async {
    if (fail) throw StateError('offline');
    return people;
  }

  @override
  Future<FacultyLocation?> location(String id) async => record;
  @override
  Future<List<ClassSchedule>> schedule(String id) async {
    scheduleReads++;
    return [
      const ClassSchedule(
        id: 'one',
        dayOfWeek: 'Thursday',
        startTime: '09:00',
        endTime: '10:00',
        roomName: 'Room 202',
        subject: 'Programming',
      ),
    ];
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 24, 1, 30);
  late MemoryFacultyRepository repo;
  late FacultyAssistant assistant;
  FacultyLocation location({
    Duration age = const Duration(minutes: 1),
    bool visible = true,
  }) => FacultyLocation(
    facultyId: 'ana',
    currentRoom: 'Room 101',
    zoneName: 'IT Department',
    beaconId: 'b',
    timestamp: now.subtract(age),
    isVisible: visible,
  );
  setUp(() {
    repo = MemoryFacultyRepository()..record = location();
    assistant = FacultyAssistant(repo, clock: () => now);
  });
  test('fresh answer comes from records and identifies the source', () async {
    final answer = await assistant.answer('Where is Ana Cruz?');
    expect(answer.text, contains('Detected in IT Department'));
    expect(answer.text, contains('Source: FindMoSer'));
    expect(answer.facultyIds, ['ana']);
    expect(answer.verified, true);
  });
  test('stale record is never described as a current detection', () async {
    repo.record = location(age: const Duration(hours: 2));
    final answer = await assistant.answer('Where is Ana?');
    expect(answer.text, contains('No fresh location'));
    expect(answer.text, contains('Last detected'));
  });
  test('hidden location also prevents schedule retrieval', () async {
    repo.record = location(visible: false);
    final answer = await assistant.answer('Ana Cruz schedule');
    expect(answer.text, isNot(contains('Room 101')));
    expect(answer.text, isNot(contains('Room 202')));
    expect(repo.scheduleReads, 0);
  });
  test('off hours suppress location and schedule', () async {
    repo.people = [
      repo.people.first.copyWith(workStartTime: '10:00', workEndTime: '17:00'),
    ];
    final answer = await assistant.answer('Ana schedule');
    expect(answer.text, contains('not shared'));
    expect(repo.scheduleReads, 0);
  });
  test('missing records do not trigger predictions', () async {
    repo.record = null;
    final answer = await assistant.answer('Where is Ana?');
    expect(answer.text, contains('not shared'));
    expect(answer.text, isNot(contains('Usually')));
  });
  test('followup uses the previously selected faculty', () async {
    final first = await assistant.answer('Where is Ana Cruz?');
    final second = await assistant.answer(
      'What about her schedule?',
      previousFacultyIds: first.facultyIds,
    );
    expect(second.text, contains('Programming'));
    expect(second.text, contains('planned, not a live location'));
  });
  test('an explicit new name overrides previous context', () async {
    repo.people.add(
      const AppUser(
        uid: 'ben',
        displayName: 'Ben Reyes',
        email: '',
        role: 'faculty',
        department: 'BSCS',
      ),
    );
    final answer = await assistant.answer(
      'Where is Ben Reyes?',
      previousFacultyIds: ['ana'],
    );
    expect(answer.facultyIds, ['ben']);
  });
  test('ambiguous names require clarification', () async {
    repo.people.add(
      const AppUser(
        uid: 'ben',
        displayName: 'Ben Cruz',
        email: '',
        role: 'faculty',
        department: 'BSCS',
      ),
    );
    final answer = await assistant.answer('Where is Cruz?');
    expect(answer.text, contains('Which faculty member'));
    expect(answer.text, isNot(contains('Room 101')));
  });
  test('full names resolve shared surnames', () async {
    repo.people.add(
      const AppUser(
        uid: 'ben',
        displayName: 'Ben Cruz',
        email: '',
        role: 'faculty',
        department: 'BSCS',
      ),
    );
    expect((await assistant.answer('Where is Ana Cruz?')).facultyIds, ['ana']);
  });
  test('name matching uses words, not substrings', () async {
    final answer = await assistant.answer('Explain banana chemistry');
    expect(answer.facultyIds, isEmpty);
    expect(answer.text, isNot(contains('Room 101')));
  });
  test('typos suggest a name rather than silently picking it', () async {
    final answer = await assistant.answer('Where is Crux?');
    expect(answer.text, contains('Did you mean Ana Cruz'));
    expect(answer.facultyIds, isEmpty);
  });
  test('database failure never becomes an ungrounded answer', () async {
    repo.fail = true;
    final answer = await assistant.answer('Where is Ana?');
    expect(answer.verified, false);
    expect(answer.text, contains('could not verify'));
  });
  test('global query excludes hidden and stale records', () async {
    repo.record = location(age: const Duration(hours: 3));
    expect(
      (await assistant.answer('Who has a recent location?')).text,
      isNot(contains('Room 101')),
    );
    repo.record = location(visible: false);
    expect(
      (await assistant.answer('Who has a recent location?')).text,
      isNot(contains('Room 101')),
    );
  });
  test('unsupported questions have a clear boundary', () async {
    expect(
      (await assistant.answer('What is the school refund policy?')).text,
      contains('do not have verified school policies'),
    );
  });
  test('tomorrow looks up the requested day rather than today', () async {
    final answer = await assistant.answer('Ana schedule tomorrow');
    expect(answer.text, contains('Friday schedule'));
    expect(answer.text, isNot(contains('Programming')));
  });
  test('freshness expires at five minutes and rejects future timestamps', () {
    expect(
      LocationPolicy.isFresh(location(age: const Duration(minutes: 5)), now),
      false,
    );
    expect(
      LocationPolicy.isFresh(location(age: const Duration(seconds: -1)), now),
      false,
    );
  });
  test('overnight sharing hours and exclusive end are supported', () {
    final user = repo.people.first.copyWith(
      workStartTime: '22:00',
      workEndTime: '06:00',
    );
    expect(
      LocationPolicy.withinHours(user, DateTime.utc(2026, 9, 24, 15)),
      true,
    );
    expect(
      LocationPolicy.withinHours(user, DateTime.utc(2026, 9, 23, 21)),
      true,
    );
    expect(
      LocationPolicy.withinHours(user, DateTime.utc(2026, 9, 23, 22)),
      false,
    );
  });
  test('room switching requires two consecutive wins', () {
    final stability = BeaconStability();
    expect(stability.observe('A'), null);
    expect(stability.observe('A'), 'A');
    expect(stability.observe('B'), null);
    expect(stability.observe('A'), 'A');
    expect(stability.observe('B'), null);
    expect(stability.observe('B'), 'B');
  });
  test('missing scans reset candidate evidence', () {
    final stability = BeaconStability();
    stability.observe('A');
    stability.observe(null);
    expect(stability.observe('A'), null);
  });
}
