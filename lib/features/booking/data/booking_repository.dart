import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/counselor.dart';
import '../models/time_slots.dart';

/// Thrown when a student tries to book a slot someone else already holds.
class SlotUnavailableException implements Exception {
  const SlotUnavailableException();

  @override
  String toString() =>
      'That time slot was just booked by someone else. Please pick another.';
}

/// Data access for counselling appointments.
///
/// CRUD summary:
/// * Create – [createAppointment]
/// * Read   – [getCounselors], [watchBookedSlots], [watchStudentAppointments],
///            [watchCounselorAppointments]
/// * Update – [rescheduleAppointment], [updateStatus], [updateNote]
/// * Delete – [deleteAppointment]
abstract class BookingRepository {
  Future<List<Counselor>> getCounselors();

  /// Start times of every slot currently held for [counselorId].
  Stream<Set<DateTime>> watchBookedSlots(String counselorId);

  Stream<List<Appointment>> watchStudentAppointments(String studentId);

  Stream<List<Appointment>> watchCounselorAppointments(String counselorId);

  /// Saves [draft] as a new pending appointment and reserves its slot.
  /// Throws [SlotUnavailableException] if the slot is already taken.
  Future<Appointment> createAppointment(Appointment draft);

  /// Moves [appointment] to [newDateTime]; it goes back to pending so the
  /// counselor can re-confirm. Throws [SlotUnavailableException].
  Future<Appointment> rescheduleAppointment(
    Appointment appointment,
    DateTime newDateTime,
  );

  /// Cancel (student), confirm / decline / complete (counselor). Releases the
  /// slot when the new status no longer holds it. [meetingInfo] (on confirm)
  /// and [declineReason] (on decline) are shown to the student.
  Future<void> updateStatus(
    Appointment appointment,
    AppointmentStatus status, {
    String? meetingInfo,
    String? declineReason,
  });

  Future<void> updateNote(Appointment appointment, String note);

  /// Permanently removes [appointment] from the student's history.
  Future<void> deleteAppointment(Appointment appointment);
}

/// Cloud Firestore implementation.
///
/// Collections:
/// * `users/{uid}`             – counselors have `role: 'counselor'`
/// * `appointments/{id}`       – see [Appointment.toMap]
/// * `booked_slots/{slotKey}`  – one document per reserved counselor slot.
///   Creating it inside a transaction is what prevents double booking.
class FirestoreBookingRepository implements BookingRepository {
  FirestoreBookingRepository([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _appointments =>
      _db.collection('appointments');
  CollectionReference<Map<String, dynamic>> get _slots =>
      _db.collection('booked_slots');

  DocumentReference<Map<String, dynamic>> _slotRef(
    String counselorId,
    DateTime slot,
  ) => _slots.doc(TimeSlots.slotKey(counselorId, slot));

  Map<String, dynamic> _slotData(Appointment a, DateTime slot) => {
    'counselorId': a.counselorId,
    'studentId': a.studentId,
    'appointmentId': a.id,
    'dateTime': Timestamp.fromDate(slot),
  };

  static List<Appointment> _sorted(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs.map((d) => Appointment.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Future<List<Counselor>> getCounselors() async {
    final snap = await _users.where('role', isEqualTo: 'counselor').get();
    return snap.docs.map((d) => Counselor.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Stream<Set<DateTime>> watchBookedSlots(String counselorId) {
    // Single-field equality query, so no composite index is needed.
    return _slots
        .where('counselorId', isEqualTo: counselorId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Appointment.readDate(d.data()['dateTime']))
              .toSet(),
        );
  }

  @override
  Stream<List<Appointment>> watchStudentAppointments(String studentId) {
    return _appointments
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(_sorted);
  }

  @override
  Stream<List<Appointment>> watchCounselorAppointments(String counselorId) {
    return _appointments
        .where('counselorId', isEqualTo: counselorId)
        .snapshots()
        .map(_sorted);
  }

  @override
  Future<Appointment> createAppointment(Appointment draft) async {
    final ref = _appointments.doc();
    final now = DateTime.now();
    final appointment = draft.copyWith(
      id: ref.id,
      status: AppointmentStatus.pending,
      updatedAt: now,
    );
    final slotRef = _slotRef(appointment.counselorId, appointment.dateTime);

    await _db.runTransaction((tx) async {
      final slot = await tx.get(slotRef);
      if (slot.exists) throw const SlotUnavailableException();
      tx.set(slotRef, _slotData(appointment, appointment.dateTime));
      tx.set(ref, appointment.toMap());
    });
    return appointment;
  }

  @override
  Future<Appointment> rescheduleAppointment(
    Appointment appointment,
    DateTime newDateTime,
  ) async {
    final updated = appointment.copyWith(
      dateTime: newDateTime,
      status: AppointmentStatus.pending,
      updatedAt: DateTime.now(),
    );
    final oldSlot = _slotRef(appointment.counselorId, appointment.dateTime);
    final newSlot = _slotRef(appointment.counselorId, newDateTime);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(newSlot);
      if (existing.exists &&
          existing.data()?['appointmentId'] != appointment.id) {
        throw const SlotUnavailableException();
      }
      if (appointment.isActive) tx.delete(oldSlot);
      tx.set(newSlot, _slotData(updated, newDateTime));
      tx.update(_appointments.doc(appointment.id), {
        'dateTime': Timestamp.fromDate(newDateTime),
        'status': updated.status.name,
        'updatedAt': Timestamp.fromDate(updated.updatedAt),
      });
    });
    return updated;
  }

  @override
  Future<void> updateStatus(
    Appointment appointment,
    AppointmentStatus status, {
    String? meetingInfo,
    String? declineReason,
  }) async {
    final batch = _db.batch();
    batch.update(_appointments.doc(appointment.id), {
      'status': status.name,
      'updatedAt': Timestamp.now(),
      'meetingInfo': ?meetingInfo,
      'declineReason': ?declineReason,
    });
    // Only release the slot while this appointment still owns it.
    if (appointment.isActive && !status.holdsSlot) {
      batch.delete(_slotRef(appointment.counselorId, appointment.dateTime));
    }
    await batch.commit();
  }

  @override
  Future<void> updateNote(Appointment appointment, String note) {
    return _appointments.doc(appointment.id).update({
      'counselorNote': note,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> deleteAppointment(Appointment appointment) async {
    final batch = _db.batch();
    batch.delete(_appointments.doc(appointment.id));
    if (appointment.isActive) {
      batch.delete(_slotRef(appointment.counselorId, appointment.dateTime));
    }
    await batch.commit();
  }
}
