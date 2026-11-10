import 'package:cloud_firestore/cloud_firestore.dart';

/// Roster entry for a class — represents one expected student.
class RosterEntry {
  final String schoolId;
  final String studentName;
  final String? uid;
  final String status; // 'pending' or 'linked'
  final DateTime? addedAt;

  const RosterEntry({
    required this.schoolId,
    required this.studentName,
    this.uid,
    this.status = 'pending',
    this.addedAt,
  });

  factory RosterEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RosterEntry(
      schoolId: doc.id,
      studentName: data['studentName'] as String? ?? '',
      uid: data['uid'] as String?,
      status: data['status'] as String? ?? 'pending',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId,
    'studentName': studentName,
    'uid': uid,
    'status': status,
    'addedAt': addedAt != null
        ? Timestamp.fromDate(addedAt!)
        : FieldValue.serverTimestamp(),
  };
}

/// Manages class rosters — CSV import, manual add, auto-link, and streaming.
class RosterService {
  final FirebaseFirestore _db;
  RosterService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  DocumentReference _rosterDoc(
    String facultyId,
    String classId,
    String schoolId,
  ) => _db.doc('users/$facultyId/class_schedule/$classId/roster/$schoolId');

  CollectionReference _rosterCollection(
    String facultyId,
    String classId,
  ) => _db.collection('users/$facultyId/class_schedule/$classId/roster');

  /// Parse CSV content into roster entries.
  /// Expects at least two columns: School ID and Student Name.
  /// Handles common delimiters (comma, tab, semicolon).
  List<RosterEntry> parseCSV(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    // Detect delimiter
    final firstLine = lines.first;
    String delimiter;
    if (firstLine.contains('\t')) {
      delimiter = '\t';
    } else if (firstLine.contains(';')) {
      delimiter = ';';
    } else {
      delimiter = ',';
    }

    // Check if first line looks like a header
    final firstCols = firstLine
        .split(delimiter)
        .map((c) => c.trim().toLowerCase())
        .toList();
    final hasHeader = firstCols.any((c) =>
        c.contains('id') ||
        c.contains('name') ||
        c.contains('student') ||
        c.contains('school'));
    final startIndex = hasHeader ? 1 : 0;

    final entries = <RosterEntry>[];
    for (var i = startIndex; i < lines.length; i++) {
      final cols = lines[i].split(delimiter).map((c) => c.trim()).toList();
      if (cols.length < 2) continue;
      final schoolId = cols[0].trim();
      final name = cols[1].trim();
      if (schoolId.isEmpty || name.isEmpty) continue;
      entries.add(RosterEntry(schoolId: schoolId, studentName: name));
    }
    return entries;
  }

  /// Add a single roster entry manually.
  Future<void> addRosterEntry({
    required String facultyId,
    required String classId,
    required String schoolId,
    required String studentName,
  }) async {
    final normalized = schoolId.trim();
    if (normalized.isEmpty) throw ArgumentError('School ID is required.');
    if (studentName.trim().isEmpty) {
      throw ArgumentError('Student name is required.');
    }

    final entry = RosterEntry(
      schoolId: normalized,
      studentName: studentName.trim(),
    );
    await _rosterDoc(facultyId, classId, normalized).set(entry.toFirestore());
  }

  /// Batch import roster entries from CSV.
  Future<int> importRoster({
    required String facultyId,
    required String classId,
    required List<RosterEntry> entries,
  }) async {
    if (entries.isEmpty) return 0;
    if (entries.length > 200) {
      throw ArgumentError('A class supports at most 200 roster entries.');
    }

    final batch = _db.batch();
    for (final entry in entries) {
      final ref = _rosterDoc(facultyId, classId, entry.schoolId);
      batch.set(ref, entry.toFirestore(), SetOptions(merge: true));
    }
    await batch.commit();
    return entries.length;
  }

  /// Stream the roster for real-time UI updates.
  Stream<List<RosterEntry>> streamRoster(
    String facultyId,
    String classId,
  ) => _rosterCollection(facultyId, classId)
      .snapshots()
      .map((s) => s.docs.map(RosterEntry.fromFirestore).toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName)));

  /// Delete a single roster entry.
  Future<void> deleteRosterEntry({
    required String facultyId,
    required String classId,
    required String schoolId,
  }) => _rosterDoc(facultyId, classId, schoolId).delete();

  /// Get UIDs of all linked students for session enrollment.
  Future<List<String>> getLinkedStudentIds(
    String facultyId,
    String classId,
  ) async {
    final snapshot = await _rosterCollection(facultyId, classId)
        .where('status', isEqualTo: 'linked')
        .get();
    return snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['uid'] as String?)
        .where((uid) => uid != null)
        .cast<String>()
        .toList();
  }
}
