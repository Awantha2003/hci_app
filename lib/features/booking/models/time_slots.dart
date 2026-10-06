/// Counseling-unit working hours and the bookable one-hour slots.
class TimeSlots {
  TimeSlots._();

  /// First and last session start hours (09:00 – 16:00, ends by 17:00).
  static const firstHour = 9;
  static const lastHour = 16;

  /// Lunch break; no sessions start at this hour.
  static const lunchHour = 12;

  /// How far ahead a student may book.
  static const bookingWindowDays = 14;

  static bool isWorkingDay(DateTime day) =>
      day.weekday != DateTime.saturday && day.weekday != DateTime.sunday;

  /// Every day from today (inclusive) within the booking window.
  static List<DateTime> windowDays([DateTime? now]) {
    final today = dateOnly(now ?? DateTime.now());
    return [
      for (var i = 0; i < bookingWindowDays; i++) today.add(Duration(days: i)),
    ];
  }

  /// Working days from today (inclusive) within the booking window.
  static List<DateTime> bookableDays([DateTime? now]) {
    final today = dateOnly(now ?? DateTime.now());
    return [
      for (var i = 0; i < bookingWindowDays; i++) today.add(Duration(days: i)),
    ].where(isWorkingDay).toList();
  }

  /// All slot start times on [day], whether booked or not.
  static List<DateTime> slotsFor(DateTime day) {
    final d = dateOnly(day);
    return [
      for (var h = firstHour; h <= lastHour; h++)
        if (h != lunchHour) DateTime(d.year, d.month, d.day, h),
    ];
  }

  /// A slot is selectable when it is in the future and not already taken.
  static bool isSelectable(
    DateTime slot,
    Set<DateTime> booked, [
    DateTime? now,
  ]) => slot.isAfter(now ?? DateTime.now()) && !booked.contains(slot);

  /// A stable key used as the Firestore document id for a counselor's slot,
  /// e.g. `c1_202610071000`. One document per slot prevents double booking.
  static String slotKey(String counselorId, DateTime slot) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${counselorId}_${slot.year}${two(slot.month)}${two(slot.day)}'
        '${two(slot.hour)}${two(slot.minute)}';
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
