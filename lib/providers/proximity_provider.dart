import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

final allFacultyProvider = StreamProvider<List<AppUser>>(
  (ref) => FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'faculty')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AppUser.fromFirestore).toList()),
);
