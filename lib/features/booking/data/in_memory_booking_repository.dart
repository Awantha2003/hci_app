import 'dart:async';

import '../models/appointment.dart';
import '../models/counselor.dart';
import 'booking_repository.dart';

/// A [BookingRepository] that keeps everything in memory.
///
/// Used by tests and for running the app before Firebase is configured. It
/// follows the same rules as the Firestore version (one active booking per
/// slot, slots released on cancel/decline/delete).
class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository({
    List<Counselor> counselors = const [],
    List<Appointment> appointments = const [],
  }) : _counselors = [...counselors],
       _appointments = {for (final a in appointments) a.id: a};

  final List<Counselor> _counselors;
  final Map<String, Appointment> _appointments;
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  /// Optional artificial latency so loading states can be seen in demos.
  Duration latency = Duration.zero;

  Future<void> _delay() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  void _notify() => _changes.add(null);

  /// Emits the current value immediately, then again after every change.
  Stream<T> _watch<T>(T Function() read) {
    return Stream<T>.multi((controller) {
      controller.add(read());
      final sub = _changes.stream.listen((_) => controller.add(read()));
      // Not returning the cancel future lets `.first` complete at once.
      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  List<Appointment> _where(bool Function(Appointment) test) =>
      _appointments.values.where(test).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  bool _slotTaken(String counselorId, DateTime slot, {String? exceptId}) =>
      _appointments.values.any(
        (a) =>
            a.id != exceptId &&
            a.isActive &&
            a.counselorId == counselorId &&
            a.dateTime == slot,
      );

  Appointment _require(String id) {
    final a = _appointments[id];
    if (a == null) throw StateError('Appointment $id no longer exists.');
    return a;
  }

  @override
  Future<List<Counselor>> getCounselors() async {
    await _delay();
    return [..._counselors]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Stream<Set<DateTime>> watchBookedSlots(String counselorId) => _watch(
    () =>
        _where((a) => a.isActive && a.counselorId == counselorId)
            .map((a) => a.dateTime)
            .toSet(),
  );

  @override
  Stream<List<Appointment>> watchStudentAppointments(String studentId) =>
      _watch(() => _where((a) => a.studentId == studentId));

  @override
  Stream<List<Appointment>> watchCounselorAppointments(String counselorId) =>
      _watch(() => _where((a) => a.counselorId == counselorId));

  @override
  Future<Appointment> createAppointment(Appointment draft) async {
    await _delay();
    if (_slotTaken(draft.counselorId, draft.dateTime)) {
      throw const SlotUnavailableException();
    }
    final appointment = draft.copyWith(
      id: 'apt_${_nextId++}',
      status: AppointmentStatus.pending,
      updatedAt: DateTime.now(),
    );
    _appointments[appointment.id] = appointment;
    _notify();
    return appointment;
  }

  @override
  Future<Appointment> rescheduleAppointment(
    Appointment appointment,
    DateTime newDateTime,
  ) async {
    await _delay();
    final current = _require(appointment.id);
    if (_slotTaken(current.counselorId, newDateTime, exceptId: current.id)) {
      throw const SlotUnavailableException();
    }
    final updated = current.copyWith(
      dateTime: newDateTime,
      status: AppointmentStatus.pending,
      updatedAt: DateTime.now(),
    );
    _appointments[updated.id] = updated;
    _notify();
    return updated;
  }

  @override
  Future<void> updateStatus(
    Appointment appointment,
    AppointmentStatus status, {
    String? meetingInfo,
    String? declineReason,
  }) async {
    await _delay();
    final current = _require(appointment.id);
    _appointments[current.id] = current.copyWith(
      status: status,
      meetingInfo: meetingInfo,
      declineReason: declineReason,
      updatedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> updateNote(Appointment appointment, String note) async {
    await _delay();
    final current = _require(appointment.id);
    _appointments[current.id] = current.copyWith(
      counselorNote: note,
      updatedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> deleteAppointment(Appointment appointment) async {
    await _delay();
    _appointments.remove(appointment.id);
    _notify();
  }
}
