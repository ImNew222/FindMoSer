import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_model.dart';

/// Keeps rejected submissions visible after Firestore rolls back its local write.
/// Each account has a separate local key; this is not an authorization store.
class AttendanceOutbox {
  final _changes = StreamController<String>.broadcast();
  Future<void> _tail = Future.value();
  Stream<String> get changes => _changes.stream;
  String _key(String uid) => 'attendance_outbox_v1_$uid';

  Future<List<AttendanceRecord>> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(uid));
    if (value == null) return [];
    return (jsonDecode(value) as List)
        .map((entry) {
          final map = Map<String, dynamic>.from(entry as Map);
          return AttendanceRecord.fromMap(map['id'] as String, map);
        })
        .where((r) => r.studentId == uid)
        .toList();
  }

  Future<void> put(AttendanceRecord record) =>
      _change(record.studentId, (items) {
        items.removeWhere((r) => r.id == record.id);
        items.add(record);
      });
  Future<void> remove(String uid, String id) =>
      _change(uid, (items) => items.removeWhere((r) => r.id == id));

  Future<void> _change(String uid, void Function(List<AttendanceRecord>) edit) {
    final next = _tail.then((_) async {
      final items = await read(uid);
      edit(items);
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        _key(uid),
        jsonEncode(items.map((r) => r.toLocalMap()).toList()),
      );
      if (!saved) {
        throw StateError(
          'Could not save the attendance receipt on this phone.',
        );
      }
      _changes.add(uid);
    });
    // A failed disk operation must not poison later operations.
    _tail = next.catchError((Object _) {});
    return next;
  }
}
