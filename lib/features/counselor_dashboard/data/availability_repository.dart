import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/availability.dart';

/// Data access for counselor availability.
///
/// CRUD summary:
/// * Create / Update – [save] (weekly hours, meeting types, days off)
/// * Read            – [watch]
/// * Delete          – [reset] (back to the default schedule)
abstract class AvailabilityRepository {
  /// Live availability; emits [Availability.defaults] when none is saved.
  Stream<Availability> watch(String counselorId);

  Future<void> save(Availability availability);

  Future<void> reset(String counselorId);
}

/// Cloud Firestore implementation: `availability/{counselorId}`.
class FirestoreAvailabilityRepository implements AvailabilityRepository {
  FirestoreAvailabilityRepository([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String counselorId) =>
      _db.collection('availability').doc(counselorId);

  @override
  Stream<Availability> watch(String counselorId) {
    return _doc(counselorId).snapshots().map((snap) {
      final data = snap.data();
      return data == null
          ? Availability.defaults(counselorId)
          : Availability.fromMap(counselorId, data);
    });
  }

  @override
  Future<void> save(Availability availability) {
    return _doc(availability.counselorId).set(availability.toMap());
  }

  @override
  Future<void> reset(String counselorId) => _doc(counselorId).delete();
}

/// In-memory implementation for tests and the offline demo.
class InMemoryAvailabilityRepository implements AvailabilityRepository {
  InMemoryAvailabilityRepository([List<Availability> initial = const []])
    : _data = {for (final a in initial) a.counselorId: a};

  final Map<String, Availability> _data;
  final _changes = StreamController<void>.broadcast();

  Availability _read(String id) => _data[id] ?? Availability.defaults(id);

  @override
  Stream<Availability> watch(String counselorId) {
    return Stream<Availability>.multi((controller) {
      controller.add(_read(counselorId));
      final sub = _changes.stream.listen(
        (_) => controller.add(_read(counselorId)),
      );
      // Not returning the cancel future lets `.first` complete at once.
      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  @override
  Future<void> save(Availability availability) async {
    _data[availability.counselorId] = availability.copyWith(
      updatedAt: DateTime.now(),
    );
    _changes.add(null);
  }

  @override
  Future<void> reset(String counselorId) async {
    _data.remove(counselorId);
    _changes.add(null);
  }
}
