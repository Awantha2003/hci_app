import 'package:mindcheck/features/booking/models/counselor.dart';
import 'package:mindcheck/features/booking/models/session_user.dart';
import 'package:mindcheck/features/booking/models/time_slots.dart';

const student = SessionUser(id: 's1', name: 'Test Student', role: UserRole.student);
const otherStudent =
    SessionUser(id: 's2', name: 'Other Student', role: UserRole.student);
const counselorUser =
    SessionUser(id: 'c1', name: 'Dr. Test', role: UserRole.counselor);

const counselor = Counselor(id: 'c1', name: 'Dr. Test');
const counselor2 = Counselor(id: 'c2', name: 'Mr. Second');

/// A slot on the [n]-th working day after today, at [hour].
DateTime futureSlot({int n = 1, int hour = 10}) {
  var d = TimeSlots.dateOnly(DateTime.now());
  var found = 0;
  while (found < n) {
    d = d.add(const Duration(days: 1));
    if (TimeSlots.isWorkingDay(d)) found++;
  }
  return DateTime(d.year, d.month, d.day, hour);
}
