import 'package:flutter_test/flutter_test.dart';
import 'package:mindcheck/features/booking/models/appointment.dart';
import 'package:mindcheck/features/booking/models/time_slots.dart';
import 'package:mindcheck/features/chat/models/anonymous_alias.dart';

void main() {
  test('slots run 9:00–16:00 hourly and skip the lunch hour', () {
    final hours = TimeSlots.slotsFor(DateTime(2026, 10, 7)).map((s) => s.hour);
    expect(hours, [9, 10, 11, 13, 14, 15, 16]);
  });

  test('weekends are not bookable', () {
    expect(TimeSlots.isWorkingDay(DateTime(2026, 10, 10)), isFalse); // Sat
    expect(TimeSlots.isWorkingDay(DateTime(2026, 10, 11)), isFalse); // Sun
    expect(TimeSlots.isWorkingDay(DateTime(2026, 10, 12)), isTrue); // Mon
    expect(
      TimeSlots.bookableDays(DateTime(2026, 10, 9)).every(TimeSlots.isWorkingDay),
      isTrue,
    );
  });

  test('past and booked slots are not selectable', () {
    final now = DateTime(2026, 10, 7, 11, 30);
    final booked = {DateTime(2026, 10, 7, 14)};
    expect(TimeSlots.isSelectable(DateTime(2026, 10, 7, 11), booked, now),
        isFalse);
    expect(TimeSlots.isSelectable(DateTime(2026, 10, 7, 14), booked, now),
        isFalse);
    expect(TimeSlots.isSelectable(DateTime(2026, 10, 7, 15), booked, now),
        isTrue);
  });

  test('slot key is unique per counselor and time', () {
    expect(TimeSlots.slotKey('c1', DateTime(2026, 10, 7, 9)), 'c1_202610070900');
  });

  test('anonymous alias is stable and differs between users', () {
    expect(AnonymousAlias.forUser('abc'), AnonymousAlias.forUser('abc'));
    expect(AnonymousAlias.forUser('abc'), matches(RegExp(r'^\w+ \w+$')));
    final aliases = {
      for (var i = 0; i < 20; i++) AnonymousAlias.forUser('user$i'),
    };
    expect(aliases.length, greaterThan(10));
  });

  test('appointment survives a round trip through its map form', () {
    final a = Appointment(
      id: 'a1',
      studentId: 's1',
      studentAlias: 'Calm Owl',
      counselorId: 'c1',
      counselorName: 'Dr. Test',
      dateTime: DateTime(2026, 10, 7, 9),
      mode: SessionMode.inPerson,
      status: AppointmentStatus.confirmed,
      reason: 'Stress',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 2),
    );
    final b = Appointment.fromMap('a1', a.toMap());
    expect(b.dateTime, a.dateTime);
    expect(b.mode, SessionMode.inPerson);
    expect(b.status, AppointmentStatus.confirmed);
    expect(b.reason, 'Stress');
  });
}
