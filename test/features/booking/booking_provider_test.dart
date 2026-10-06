import 'package:flutter_test/flutter_test.dart';
import 'package:mindcheck/features/booking/data/booking_repository.dart';
import 'package:mindcheck/features/booking/data/in_memory_booking_repository.dart';
import 'package:mindcheck/features/booking/models/appointment.dart';
import 'package:mindcheck/features/booking/presentation/providers/booking_provider.dart';
import 'package:mindcheck/features/counselor_dashboard/data/availability_repository.dart';
import 'package:mindcheck/features/counselor_dashboard/models/availability.dart';

import 'test_helpers.dart';

/// Functional tests for the booking feature and counselor dashboard.
/// Test IDs match the functional test case table in the report.
void main() {
  late InMemoryBookingRepository repo;
  late InMemoryAvailabilityRepository availabilityRepo;
  late BookingProvider studentSide;
  late BookingProvider counselorSide;

  /// Lets stream updates reach the providers.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    repo = InMemoryBookingRepository(counselors: [counselor, counselor2]);
    availabilityRepo = InMemoryAvailabilityRepository();
    studentSide = BookingProvider(
      repository: repo,
      availabilityRepository: availabilityRepo,
      user: student,
    );
    counselorSide = BookingProvider(
      repository: repo,
      availabilityRepository: availabilityRepo,
      user: counselorUser,
    );
    await settle();
  });

  tearDown(() {
    studentSide.dispose();
    counselorSide.dispose();
  });

  Future<Appointment> book([DateTime? slot]) => studentSide.book(
        counselor: counselor,
        dateTime: slot ?? futureSlot(),
        mode: SessionMode.online,
        reason: 'Exam stress',
      );

  group('Book Session', () {
    test('TC-B01 loads the counselor list (Read)', () async {
      await studentSide.loadCounselors();
      expect(studentSide.counselors.map((c) => c.id), ['c1', 'c2']);
    });

    test('TC-B02 booking a free slot creates a pending appointment (Create)',
        () async {
      final slot = futureSlot();
      final a = await book(slot);
      await settle();

      expect(a.status, AppointmentStatus.pending);
      expect(a.dateTime, slot);
      expect(a.studentAlias, student.alias);
      expect(studentSide.upcoming.single.id, a.id);
      expect(counselorSide.pendingRequests.single.id, a.id);
    });

    test('TC-B03 a past time is rejected', () {
      expect(
        () => studentSide.book(
          counselor: counselor,
          dateTime: DateTime.now().subtract(const Duration(hours: 1)),
          mode: SessionMode.online,
        ),
        throwsA(isA<BookingValidationException>()),
      );
    });

    test('TC-B04 a time outside working hours is rejected', () {
      expect(
        () => book(futureSlot(hour: 20)),
        throwsA(isA<BookingValidationException>()),
      );
      expect(
        () => book(futureSlot(hour: 12)), // lunch break
        throwsA(isA<BookingValidationException>()),
      );
    });

    test('TC-B05 the same slot cannot be booked twice', () async {
      final slot = futureSlot();
      await book(slot);
      final other = BookingProvider(repository: repo, user: otherStudent);
      addTearDown(other.dispose);

      await expectLater(
        other.book(
          counselor: counselor,
          dateTime: slot,
          mode: SessionMode.inPerson,
        ),
        throwsA(isA<SlotUnavailableException>()),
      );
    });

    test('TC-B06 booked slots are reported to the slot picker', () async {
      final slot = futureSlot();
      await book(slot);
      expect(await repo.watchBookedSlots(counselor.id).first, {slot});
      expect(await repo.watchBookedSlots(counselor2.id).first, isEmpty);
    });

    test('TC-B07 a reason over 300 characters is rejected', () {
      expect(
        () => studentSide.book(
          counselor: counselor,
          dateTime: futureSlot(),
          mode: SessionMode.online,
          reason: 'x' * 301,
        ),
        throwsA(isA<BookingValidationException>()),
      );
    });
  });

  group('My Appointments & Reschedule', () {
    test('TC-B08 reschedule moves the session and frees the old slot (Update)',
        () async {
      final oldSlot = futureSlot(hour: 10);
      final newSlot = futureSlot(n: 2, hour: 14);
      final a = await book(oldSlot);
      await counselorSide.confirm(a);
      await settle();

      final moved = await studentSide.reschedule(studentSide.byId(a.id)!, newSlot);
      await settle();

      expect(moved.dateTime, newSlot);
      expect(moved.status, AppointmentStatus.pending,
          reason: 'counselor must re-confirm a new time');
      expect(await repo.watchBookedSlots(counselor.id).first, {newSlot});
    });

    test('TC-B09 reschedule to a taken slot is rejected', () async {
      final taken = futureSlot(hour: 9);
      final other = BookingProvider(repository: repo, user: otherStudent);
      addTearDown(other.dispose);
      await other.book(
          counselor: counselor, dateTime: taken, mode: SessionMode.online);
      final mine = await book(futureSlot(hour: 10));

      await expectLater(
        studentSide.reschedule(mine, taken),
        throwsA(isA<SlotUnavailableException>()),
      );
    });

    test('TC-B10 cancel marks the session cancelled and frees the slot',
        () async {
      final a = await book();
      await settle();
      await studentSide.cancel(a);
      await settle();

      expect(studentSide.upcoming, isEmpty);
      expect(studentSide.past.single.status, AppointmentStatus.cancelled);
      expect(await repo.watchBookedSlots(counselor.id).first, isEmpty);
    });

    test('TC-B11 delete removes the session from history (Delete)', () async {
      final a = await book();
      await studentSide.cancel(a);
      await settle();
      await studentSide.delete(studentSide.byId(a.id)!);
      await settle();

      expect(studentSide.appointments, isEmpty);
    });

    test('TC-B12 a student cannot change another student\'s booking',
        () async {
      final a = await book();
      final other = BookingProvider(repository: repo, user: otherStudent);
      addTearDown(other.dispose);

      expect(() => other.cancel(a), throwsA(isA<BookingValidationException>()));
      expect(() => other.delete(a), throwsA(isA<BookingValidationException>()));
    });

    test('TC-B13 a cancelled session cannot be cancelled again', () async {
      final a = await book();
      await studentSide.cancel(a);
      await settle();
      expect(
        () => studentSide.cancel(studentSide.byId(a.id)!),
        throwsA(isA<BookingValidationException>()),
      );
    });
  });

  group('Counselor Dashboard', () {
    test('TC-D01 accepting a request confirms it for the student (Update)',
        () async {
      final a = await book();
      await settle();
      await counselorSide.confirm(counselorSide.pendingRequests.single);
      await settle();

      expect(counselorSide.pendingRequests, isEmpty);
      expect(counselorSide.confirmedSessions.single.id, a.id);
      expect(studentSide.byId(a.id)!.status, AppointmentStatus.confirmed);
    });

    test('TC-D02 declining a request frees the slot', () async {
      final a = await book();
      await settle();
      await counselorSide.decline(counselorSide.byId(a.id)!);
      await settle();

      expect(studentSide.byId(a.id)!.status, AppointmentStatus.declined);
      expect(await repo.watchBookedSlots(counselor.id).first, isEmpty);
    });

    test('TC-D03 completing a session updates the completed count', () async {
      final a = await book();
      await counselorSide.confirm(a);
      await settle();
      await counselorSide.complete(counselorSide.byId(a.id)!);
      await settle();

      expect(counselorSide.completedCount, 1);
      expect(counselorSide.confirmedSessions, isEmpty);
    });

    test('TC-D04 counselor can save a private session note', () async {
      final a = await book();
      await settle();
      await counselorSide.saveNote(counselorSide.byId(a.id)!, '  Follow up  ');
      await settle();

      expect(counselorSide.byId(a.id)!.counselorNote, 'Follow up');
    });

    test('TC-D05 a student cannot accept their own request', () async {
      final a = await book();
      expect(
        () => studentSide.confirm(a),
        throwsA(isA<BookingValidationException>()),
      );
    });

    test('TC-D06 students are shown to counselors only by alias', () async {
      await book();
      await settle();
      final seen = counselorSide.pendingRequests.single;
      expect(seen.studentAlias, student.alias);
      expect(seen.studentAlias, isNot(contains(student.name)));
    });
  });

  group('Availability & meeting types', () {
    test('TC-A01 counselor saves weekly hours; students only get those '
        '(Create/Update + Read)', () async {
      final slot = futureSlot(hour: 10);
      final closed = Availability.defaults(counselor.id).copyWith(
        hours: {slot.weekday: [14]},
      );
      await counselorSide.saveAvailability(closed);

      final seen = await studentSide.availabilityFor(counselor.id).first;
      expect(seen.slotsFor(slot).map((s) => s.hour), [14]);
      await expectLater(
        book(slot),
        throwsA(isA<BookingValidationException>()),
      );
      await book(DateTime(slot.year, slot.month, slot.day, 14));
    });

    test('TC-A02 a day off blocks booking that day', () async {
      final slot = futureSlot();
      await counselorSide.saveAvailability(
        Availability.defaults(counselor.id).copyWith(daysOff: [slot]),
      );
      await expectLater(
        book(slot),
        throwsA(isA<BookingValidationException>()),
      );
    });

    test('TC-A03 only offered meeting types can be booked', () async {
      await counselorSide.saveAvailability(
        Availability.defaults(counselor.id)
            .copyWith(meetingTypes: {SessionMode.inPerson}),
      );
      await expectLater(
        studentSide.book(
          counselor: counselor,
          dateTime: futureSlot(),
          mode: SessionMode.online,
        ),
        throwsA(isA<BookingValidationException>()),
      );
      final ok = await studentSide.book(
        counselor: counselor,
        dateTime: futureSlot(),
        mode: SessionMode.inPerson,
      );
      expect(ok.mode, SessionMode.inPerson);
    });

    test('TC-A04 at least one meeting type is required', () {
      expect(
        () => counselorSide.saveAvailability(
          Availability.defaults(counselor.id).copyWith(meetingTypes: {}),
        ),
        throwsA(isA<BookingValidationException>()),
      );
    });

    test('TC-A05 students cannot change a counselor\'s availability', () {
      expect(
        () => studentSide.saveAvailability(Availability.defaults(counselor.id)),
        throwsA(isA<BookingValidationException>()),
      );
    });

    test('TC-A06 reset deletes the saved schedule (Delete)', () async {
      await counselorSide.saveAvailability(
        Availability.defaults(counselor.id).copyWith(hours: {}),
      );
      await counselorSide.resetAvailability();
      final a = await studentSide.availabilityFor(counselor.id).first;
      expect(a.weeklySlotCount, Availability.defaults('x').weeklySlotCount);
    });

    test('TC-D07 accepting shares meeting details with the student',
        () async {
      final a = await book();
      await counselorSide.confirm(a, meetingInfo: '  Room 2  ');
      await settle();
      expect(studentSide.byId(a.id)!.meetingInfo, 'Room 2');
    });

    test('TC-D08 declining shares the reason with the student', () async {
      final a = await book();
      await counselorSide.decline(a, reason: 'Fully booked this week');
      await settle();
      final seen = studentSide.byId(a.id)!;
      expect(seen.status, AppointmentStatus.declined);
      expect(seen.declineReason, 'Fully booked this week');
    });
  });
}
