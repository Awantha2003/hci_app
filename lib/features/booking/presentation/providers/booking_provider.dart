import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../counselor_dashboard/data/availability_repository.dart';
import '../../../counselor_dashboard/models/availability.dart';
import '../../data/booking_repository.dart';
import '../../models/appointment.dart';
import '../../models/counselor.dart';
import '../../models/session_user.dart';

/// Raised for input the user can fix (shown as a friendly message).
class BookingValidationException implements Exception {
  final String message;
  const BookingValidationException(this.message);

  @override
  String toString() => message;
}

/// State for the booking screens (student) and the counselor dashboard.
///
/// Listens to the signed-in user's appointments in real time, so every
/// screen updates as soon as the other side changes a booking.
class BookingProvider extends ChangeNotifier {
  BookingProvider({
    required this.repository,
    required this.user,
    AvailabilityRepository? availabilityRepository,
  }) : availabilityRepository =
           availabilityRepository ?? InMemoryAvailabilityRepository() {
    final stream = user.isCounselor
        ? repository.watchCounselorAppointments(user.id)
        : repository.watchStudentAppointments(user.id);
    // Show a helpful message instead of an endless spinner if the backend
    // does not answer (offline, or database not created yet).
    _slowTimer = Timer(connectTimeout, () {
      if (!_loadingAppointments) return;
      _loadingAppointments = false;
      _appointmentsError = 'Still connecting… Check your internet connection. If this keeps '
        'happening, the database may not be set up yet.';
      notifyListeners();
    });
    _subscription = stream.listen(
      (list) {
        _slowTimer?.cancel();
        _appointments = list;
        _loadingAppointments = false;
        _appointmentsError = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loadingAppointments = false;
        _appointmentsError = 'Could not load appointments. $e';
        notifyListeners();
      },
    );
  }

  final BookingRepository repository;
  final AvailabilityRepository availabilityRepository;
  final SessionUser user;
  late final StreamSubscription<List<Appointment>> _subscription;
  Timer? _slowTimer;

  static const connectTimeout = Duration(seconds: 12);

  static const maxReasonLength = 300;
  static const maxNoteLength = 500;
  static const maxMeetingInfoLength = 300;

  List<Counselor> _counselors = const [];
  bool _loadingCounselors = false;
  String? _counselorsError;

  List<Appointment> _appointments = const [];
  bool _loadingAppointments = true;
  String? _appointmentsError;

  bool _busy = false;

  List<Counselor> get counselors => _counselors;
  bool get loadingCounselors => _loadingCounselors;
  String? get counselorsError => _counselorsError;

  List<Appointment> get appointments => _appointments;
  bool get loadingAppointments => _loadingAppointments;
  String? get appointmentsError => _appointmentsError;

  /// True while a create/update/delete is in progress.
  bool get busy => _busy;

  /// Pending or confirmed sessions that have not started, soonest first.
  List<Appointment> get upcoming =>
      _appointments.where((a) => a.isUpcoming()).toList();

  /// Everything else (finished, cancelled, declined), newest first.
  List<Appointment> get past =>
      _appointments.where((a) => !a.isUpcoming()).toList().reversed.toList();

  /// Counselor view: future requests waiting for a decision.
  List<Appointment> get pendingRequests =>
      upcoming.where((a) => a.status == AppointmentStatus.pending).toList();

  /// Counselor view: every confirmed session not yet marked completed,
  /// including earlier ones still waiting to be closed off.
  List<Appointment> get confirmedSessions => _appointments
      .where((a) => a.status == AppointmentStatus.confirmed)
      .toList();

  List<Appointment> get todaysSessions {
    final now = DateTime.now();
    return confirmedSessions.where((a) => a.isOn(now)).toList();
  }

  int get completedCount => _appointments
      .where((a) => a.status == AppointmentStatus.completed)
      .length;

  Appointment? byId(String id) {
    for (final a in _appointments) {
      if (a.id == id) return a;
    }
    return null;
  }

  Stream<Set<DateTime>> bookedSlots(String counselorId) =>
      repository.watchBookedSlots(counselorId);

  Future<void> loadCounselors({bool force = false}) async {
    if (_loadingCounselors || (_counselors.isNotEmpty && !force)) return;
    _loadingCounselors = true;
    _counselorsError = null;
    notifyListeners();
    try {
      _counselors = await repository.getCounselors();
    } catch (e) {
      _counselorsError = 'Could not load counselors. $e';
    } finally {
      _loadingCounselors = false;
      notifyListeners();
    }
  }

  /// Live opening hours / meeting types of a counselor.
  Stream<Availability> availabilityFor(String counselorId) =>
      availabilityRepository.watch(counselorId);

  // ---------------------------------------------------------------- Create

  Future<Appointment> book({
    required Counselor counselor,
    required DateTime dateTime,
    required SessionMode mode,
    String reason = '',
  }) {
    _validateNotPast(dateTime);
    final trimmed = reason.trim();
    if (trimmed.length > maxReasonLength) {
      throw const BookingValidationException(
        'Please keep the reason under $maxReasonLength characters.',
      );
    }
    final now = DateTime.now();
    return _run(() async {
      await _validateAgainstAvailability(counselor.id, dateTime, mode: mode);
      return repository.createAppointment(
        Appointment(
          id: '',
          studentId: user.id,
          studentAlias: user.alias,
          counselorId: counselor.id,
          counselorName: counselor.name,
          dateTime: dateTime,
          mode: mode,
          reason: trimmed,
          status: AppointmentStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  // ---------------------------------------------------------------- Update

  Future<Appointment> reschedule(Appointment appointment, DateTime newTime) {
    _requireOwner(appointment);
    if (!appointment.isUpcoming()) {
      throw const BookingValidationException(
        'Only upcoming sessions can be rescheduled.',
      );
    }
    if (newTime == appointment.dateTime) {
      throw const BookingValidationException(
        'Pick a different time from your current booking.',
      );
    }
    _validateNotPast(newTime);
    return _run(() async {
      await _validateAgainstAvailability(appointment.counselorId, newTime);
      return repository.rescheduleAppointment(appointment, newTime);
    });
  }

  Future<void> cancel(Appointment appointment) {
    _requireOwner(appointment);
    return _setStatus(appointment, AppointmentStatus.cancelled);
  }

  /// Accepts a request. [meetingInfo] (link, room, call details) is shown
  /// to the student.
  Future<void> confirm(Appointment appointment, {String meetingInfo = ''}) {
    _requireCounselor(appointment);
    final info = meetingInfo.trim();
    if (info.length > maxMeetingInfoLength) {
      throw const BookingValidationException(
        'Meeting details are limited to $maxMeetingInfoLength characters.',
      );
    }
    return _setStatus(
      appointment,
      AppointmentStatus.confirmed,
      meetingInfo: info,
    );
  }

  /// Declines a request and frees the slot. [reason] is shown to the
  /// student.
  Future<void> decline(Appointment appointment, {String reason = ''}) {
    _requireCounselor(appointment);
    final trimmed = reason.trim();
    if (trimmed.length > maxReasonLength) {
      throw const BookingValidationException(
        'Please keep the reason under $maxReasonLength characters.',
      );
    }
    return _setStatus(
      appointment,
      AppointmentStatus.declined,
      declineReason: trimmed,
    );
  }

  Future<void> complete(Appointment appointment) {
    _requireCounselor(appointment);
    return _setStatus(appointment, AppointmentStatus.completed);
  }

  Future<void> saveNote(Appointment appointment, String note) {
    _requireCounselor(appointment);
    final trimmed = note.trim();
    if (trimmed.length > maxNoteLength) {
      throw const BookingValidationException(
        'Notes are limited to $maxNoteLength characters.',
      );
    }
    return _run(() => repository.updateNote(appointment, trimmed));
  }

  /// Counselor: saves weekly hours, meeting types and days off.
  Future<void> saveAvailability(Availability availability) {
    if (!user.isCounselor || availability.counselorId != user.id) {
      throw const BookingValidationException(
        'Only the counselor can change their availability.',
      );
    }
    if (availability.meetingTypes.isEmpty) {
      throw const BookingValidationException(
        'Offer at least one meeting type.',
      );
    }
    return _run(() => availabilityRepository.save(availability));
  }

  // ---------------------------------------------------------------- Delete

  /// Counselor: removes the saved schedule (back to the default hours).
  Future<void> resetAvailability() {
    if (!user.isCounselor) {
      throw const BookingValidationException(
        'Only the counselor can change their availability.',
      );
    }
    return _run(() => availabilityRepository.reset(user.id));
  }

  Future<void> delete(Appointment appointment) {
    _requireOwner(appointment);
    return _run(() => repository.deleteAppointment(appointment));
  }

  // --------------------------------------------------------------- Helpers

  Future<void> _setStatus(
    Appointment a,
    AppointmentStatus status, {
    String? meetingInfo,
    String? declineReason,
  }) {
    if (!a.isActive) {
      throw BookingValidationException(
        'This session is already ${a.status.label.toLowerCase()}.',
      );
    }
    return _run(
      () => repository.updateStatus(
        a,
        status,
        meetingInfo: meetingInfo,
        declineReason: declineReason,
      ),
    );
  }

  void _validateNotPast(DateTime dateTime) {
    if (!dateTime.isAfter(DateTime.now())) {
      throw const BookingValidationException(
        'That time has already passed. Please choose a future slot.',
      );
    }
  }

  /// The slot must be one the counselor has opened, and the meeting type
  /// one they offer.
  Future<void> _validateAgainstAvailability(
    String counselorId,
    DateTime dateTime, {
    SessionMode? mode,
  }) async {
    final availability = await availabilityRepository.watch(counselorId).first;
    if (!availability.offersSlot(dateTime)) {
      throw const BookingValidationException(
        'The counselor is not available at that time. '
        'Please pick one of the open slots.',
      );
    }
    if (mode != null && !availability.meetingTypes.contains(mode)) {
      throw BookingValidationException(
        'This counselor does not offer ${mode.label.toLowerCase()} sessions.',
      );
    }
  }

  void _requireOwner(Appointment a) {
    if (a.studentId != user.id) {
      throw const BookingValidationException(
        'You can only change your own bookings.',
      );
    }
  }

  void _requireCounselor(Appointment a) {
    if (!user.isCounselor || a.counselorId != user.id) {
      throw const BookingValidationException(
        'Only the assigned counselor can do this.',
      );
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
