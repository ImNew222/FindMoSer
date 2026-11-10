import '../../../core/user_model.dart';
import '../../presence/models/location_model.dart';
import '../../attendance/models/schedule_model.dart';
import '../../presence/services/location_policy.dart';
import '../../../core/campus_time.dart';

abstract class FacultyRepository {
  Future<List<AppUser>> faculty();
  Future<FacultyLocation?> location(String id);
  Future<List<ClassSchedule>> schedule(String id);
}

abstract class ForecastRepository {
  Future<String?> forecastSummary(String id);
}

class AssistantAnswer {
  final String text;
  final List<String> facultyIds;
  final bool verified;
  const AssistantAnswer(
    this.text, {
    this.facultyIds = const [],
    this.verified = false,
  });
}

/// Faculty facts are rendered deterministically. No language model is allowed to
/// invent a location or turn a schedule into proof of physical presence.
class FacultyAssistant {
  final FacultyRepository repository;
  final DateTime Function() now;
  FacultyAssistant(this.repository, {DateTime Function()? clock})
    : now = clock ?? DateTime.now;

  static const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll("'", "")
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  static Set<String> words(String value) =>
      normalize(value).split(' ').where((s) => s.isNotEmpty).toSet();
  static const titles = {
    'sir',
    'ser',
    'maam',
    'mam',
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'professor',
  };

  Future<AssistantAnswer> answer(
    String question, {
    List<String> previousFacultyIds = const [],
  }) async {
    final q = normalize(question);
    final tokens = words(question);
    if (q.isEmpty) {
      return const AssistantAnswer(
        'Enter a faculty name or ask who has a recent location.',
      );
    }
    try {
      final directory = await repository.faculty();
      if (directory.isEmpty) {
        return const AssistantAnswer(
          'The faculty directory is empty. No location or schedule can be verified.',
        );
      }
      final matches = directory.where((f) {
        final names = words(
          f.displayName,
        ).difference(titles).where((n) => n.length > 2);
        return names.any(tokens.contains);
      }).toList();
      // A full name takes precedence over a shared first name or surname.
      final exact = directory
          .where((f) => (' $q ').contains(' ${normalize(f.displayName)} '))
          .toList();
      var selected = exact.isNotEmpty ? exact : matches;
      final department = directory
          .where(
            (f) =>
                f.department.isNotEmpty &&
                tokens.contains(f.department.toLowerCase()),
          )
          .toList();
      if (selected.isNotEmpty && department.isNotEmpty && exact.isEmpty) {
        final ids = department.map((f) => f.uid).toSet();
        selected = selected.where((f) => ids.contains(f.uid)).toList();
        if (selected.isEmpty) {
          return const AssistantAnswer(
            'That name does not match the requested department. Please check the name and department.',
          );
        }
      }
      final followup =
          tokens.intersection({
            'his',
            'her',
            'their',
            'he',
            'she',
            'they',
            'them',
            'consultation',
            'status',
            'available',
          }).isNotEmpty ||
          q.startsWith('what about') ||
          q == 'schedule' ||
          q == 'location' ||
          q == 'availability' ||
          q == 'consultation' ||
          q == 'status';
      if (selected.isEmpty && department.isEmpty && followup) {
        selected = directory
            .where((f) => previousFacultyIds.contains(f.uid))
            .toList();
      }
      final directoryQuery =
          q == 'who are the faculty members' ||
          q == 'list faculty' ||
          q == 'faculty';
      final globalQuery =
          q == 'who has a recent location' ||
          q == 'who is on campus' ||
          q == 'where are the faculty';
      final availableQuery =
          q == 'who is available' ||
          q == 'who is available for consultation' ||
          q == 'who is free for consultation' ||
          q == 'who is free' ||
          q == 'available faculty' ||
          q == 'consultation' ||
          q == 'who can be consulted';
      if (directoryQuery) {
        return AssistantAnswer(
          'Faculty directory:\n\n${directory.map((f) => '- ${f.displayName} — ${f.department}').join('\n')}\n\nAsk for a name to see location, schedule or availability.',
          verified: true,
        );
      }
      if (selected.isEmpty && availableQuery) {
        final available = directory
            .where((f) => f.availability == 'available')
            .toList();
        if (available.isEmpty) {
          return const AssistantAnswer(
            'No faculty members are currently marked as available for consultation.',
            verified: true,
          );
        }
        final summaries = available
            .map((f) => '- ${f.displayName} (${f.department}): Available for consultation')
            .join('\n');
        return AssistantAnswer(
          'Faculty available for consultation:\n\n$summaries\n\nAsk for a specific faculty name to see their room location or schedule.',
          facultyIds: available.map((f) => f.uid).toList(),
          verified: true,
        );
      }
      if (selected.isEmpty && department.isNotEmpty) selected = department;
      if (selected.isEmpty && globalQuery) {
        final summaries = <String>[];
        final time = now();
        for (final f in directory) {
          final loc = await repository.location(f.uid);
          if (LocationPolicy.canShare(f, loc, time) &&
              loc!.isWithinCampus &&
              LocationPolicy.isFresh(loc, time)) {
            summaries.add(
              '- ${f.displayName}: ${loc.publicZone} (detected ${_age(loc, time)})',
            );
          }
        }
        return AssistantAnswer(
          summaries.isEmpty
              ? 'No shared faculty locations were detected in the last 5 minutes. This does not mean everyone is off campus.'
              : 'Recent shared detections:\n\n${summaries.join('\n')}\n\nDetection does not confirm consultation availability.',
          verified: true,
        );
      }
      if (selected.isEmpty) {
        // Offer possible spellings, but never silently resolve a fuzzy name.
        final suggestions = directory
            .where(
              (f) => words(f.displayName)
                  .difference(titles)
                  .any(
                    (name) =>
                        name.length > 3 &&
                        tokens.any((t) => t.length > 3 && _oneEdit(t, name)),
                  ),
            )
            .take(4)
            .toList();
        if (suggestions.isNotEmpty) {
          return AssistantAnswer(
            'Did you mean ${suggestions.map((f) => f.displayName).join(' or ')}? Please use the full name.',
          );
        }
        return const AssistantAnswer(
          'I can look up faculty locations, schedules and availability. Include a faculty name or department, or ask “Who has a recent location?” I do not have verified school policies or general tutoring information.',
        );
      }
      if (selected.length > 1 && department.isEmpty) {
        return AssistantAnswer(
          'Which faculty member do you mean?\n\n${selected.map((f) => '- ${f.displayName} (${f.department})').join('\n')}\n\nPlease enter the full name.',
          facultyIds: selected.map((f) => f.uid).toList(),
        );
      }
      final requestedDay = days
          .where(
            (d) =>
                (tokens.contains(d.toLowerCase()) ||
                tokens.contains(d.substring(0, 3).toLowerCase())),
          )
          .firstOrNull;
      final day =
          requestedDay ??
          days[(CampusTime.wallClock(now()).weekday -
                  1 +
                  (tokens.contains('tomorrow') ? 1 : 0)) %
              7];
      final wantsSchedule =
          tokens.intersection({
            'schedule',
            'schedules',
            'class',
            'classes',
            'teaching',
            'tomorrow',
          }).isNotEmpty ||
          requestedDay != null;
      final blocks = <String>[];
      for (final f in selected.take(15)) {
        final time = now();
        final loc = await repository.location(f.uid);
        final b = StringBuffer('**${f.displayName}** · ${f.department}\n\n');

        // 1. Consultation / Availability status is ALWAYS displayed
        b.writeln('${LocationPolicy.availabilityLabel(f.availability)}\n');

        if (!LocationPolicy.canShare(f, loc, time)) {
          b.writeln('Location and schedule details are not shared right now.');
        } else {
          if (repository is ForecastRepository) {
            final summary = await (repository as ForecastRepository)
                .forecastSummary(f.uid);
            if (summary != null) {
              b.writeln('$summary\n');
            }
          }
          if (!loc!.isWithinCampus) {
            b.writeln('No shared on-campus detection.');
          } else if (loc.currentRoom.isEmpty && loc.zoneName.isEmpty) {
            b.writeln('No classroom beacon detected yet.');
          } else if (LocationPolicy.isFresh(loc, time)) {
            b.writeln(
              'Detected in ${loc.publicZone}, ${_age(loc, time)}. This is not a guarantee they are still there.',
            );
          } else {
            b.writeln(
              'No fresh location. Last detected in ${loc.publicZone}, ${_age(loc, time)}.',
            );
          }
          if (f.workStartTime != null && f.workEndTime != null) {
            b.writeln(
              'Sharing hours: ${CampusTime.hhmm12(f.workStartTime!)}–${CampusTime.hhmm12(f.workEndTime!)}.',
            );
          }
          if (wantsSchedule) {
            try {
              final schedule =
                  (await repository.schedule(f.uid))
                      .where(
                        (s) =>
                            s.dayOfWeek == day ||
                            s.dayOfWeek == day.substring(0, 3),
                      )
                      .toList()
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));
              b.writeln('\n$day schedule (planned, not a live location):');
              if (schedule.isEmpty) {
                b.writeln(
                  'No classes recorded. This does not confirm availability.',
                );
              }
              for (final s in schedule) {
                b.writeln(
                  '- ${CampusTime.hhmm12(s.startTime)}–${CampusTime.hhmm12(s.endTime)}: ${s.subject}, Location withheld; see shared zone',
                );
              }
            } catch (_) {
              // Students are not allowed to read the faculty schedule.
              b.writeln(
                '\nSchedule details are private. Ask the faculty member directly.',
              );
            }
          }
        }
        blocks.add(b.toString().trim());
      }
      return AssistantAnswer(
        '${blocks.join('\n\n')}\n\nSource: FindMoSer records checked now.${selected.length > 15 ? ' Showing the first 15 matches; narrow by name.' : ''}',
        facultyIds: selected.map((f) => f.uid).toList(),
        verified: true,
      );
    } catch (_) {
      return const AssistantAnswer(
        'I could not verify the faculty records. Check your connection and try again. I have not guessed a location or schedule.',
      );
    }
  }

  static String _age(FacultyLocation loc, DateTime now) {
    if (loc.timestamp.millisecondsSinceEpoch == 0) return 'time unknown';
    final age = now.difference(loc.timestamp);
    if (age.isNegative) return 'timestamp needs verification';
    if (age.inMinutes < 1) return 'less than a minute ago';
    if (age.inHours < 1) {
      return '${age.inMinutes} ${age.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (age.inDays < 1) return '${age.inHours} hours ago';
    return '${age.inDays} days ago';
  }

  static bool _oneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    var i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length >= b.length) i++;
      if (b.length >= a.length) j++;
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }
}
