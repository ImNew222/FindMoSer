import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/services/availability_predictor.dart';
import 'package:findmoser_app/models/schedule_model.dart';

void main() {
  final now = DateTime.utc(2026, 9, 24, 1, 30);
  const schedule = [
    ClassSchedule(
      id: 's',
      dayOfWeek: 'Monday',
      startTime: '13:00',
      endTime: '14:00',
      roomName: 'private',
      subject: 'IT',
    ),
  ];
  final engine = AvailabilityPredictor();
  List<AvailabilityObservation> history() => [
    for (final offset in [7, 14, 21])
      for (final hour in [1, 2, 3, 7])
        AvailabilityObservation(
          recordedAt: DateTime.utc(2026, 9, 24 - offset, hour, 30),
          available: hour != 7,
          inZone: true,
          teaching: false,
        ),
  ];
  AvailabilityForecast run(List<AvailabilityObservation> data) =>
      engine.predict(
        at: now,
        knowledgeAt: now,
        inZone: true,
        schedule: schedule,
        observations: data,
      );
  test(
    'no labels means abstention, not guessed availability',
    () => expect(run([]).status, 'insufficient_data'),
  );
  test('one day of many observations is not sufficient', () {
    final records = [
      for (var i = 0; i < 24; i++)
        AvailabilityObservation(
          recordedAt: now.subtract(Duration(hours: 12, minutes: i * 30)),
          available: i.isEven,
          inZone: true,
          teaching: false,
        ),
    ];
    expect(run(records).status, 'insufficient_data');
  });
  test('past comparable labelled observations produce a pilot estimate', () {
    final value = run(history());
    expect(value.status, 'likely_available');
    expect(value.samples, 5);
    expect(value.days, 3);
    expect(value.reason, contains('uncalibrated'));
  });
  test('future labels cannot influence present predictions', () {
    final data = history()
        .map(
          (o) => AvailabilityObservation(
            recordedAt: now.add(const Duration(days: 1)),
            available: o.available,
            inZone: true,
            teaching: false,
          ),
        )
        .toList();
    expect(run(data).status, 'insufficient_data');
  });
  test('repeated observations in one half-hour do not inflate support', () {
    final data = [
      for (var i = 0; i < 40; i++)
        AvailabilityObservation(
          recordedAt: now.subtract(Duration(days: 1, seconds: i)),
          available: i.isEven,
          inZone: true,
          teaching: false,
        ),
    ];
    expect(run(data).status, 'insufficient_data');
  });
  test('missing timetable is an explicit fallback', () {
    expect(
      engine
          .predict(
            at: now,
            knowledgeAt: now,
            inZone: true,
            schedule: [],
            observations: history(),
          )
          .status,
      'insufficient_data',
    );
  });
  test('scheduled class takes precedence over learned availability', () {
    const s = [
      ClassSchedule(
        id: 'x',
        dayOfWeek: 'Thursday',
        startTime: '09:00',
        endTime: '10:00',
        roomName: 'secret',
        subject: 'IT',
      ),
    ];
    expect(
      engine
          .predict(
            at: now,
            knowledgeAt: now,
            inZone: true,
            schedule: s,
            observations: history(),
          )
          .status,
      'scheduled_class',
    );
  });
  test('labels older than sixty days are excluded', () {
    final data = history()
        .map(
          (o) => AvailabilityObservation(
            recordedAt: o.recordedAt.subtract(const Duration(days: 80)),
            available: o.available,
            inZone: true,
            teaching: false,
          ),
        )
        .toList();
    expect(run(data).status, 'insufficient_data');
  });
  test('all-positive labels cannot masquerade as a validated classifier', () {
    final data = history()
        .map(
          (o) => AvailabilityObservation(
            recordedAt: o.recordedAt,
            available: true,
            inZone: true,
            teaching: false,
          ),
        )
        .toList();
    expect(run(data).status, 'insufficient_data');
  });
}
