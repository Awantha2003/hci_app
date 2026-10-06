import 'package:cloud_firestore/cloud_firestore.dart';

import '../../booking/models/appointment.dart';
import '../../booking/models/time_slots.dart';

/// When and how a counselor takes sessions: weekly opening hours, the
/// meeting types they offer and individual days off.
///
/// Stored in `availability/{counselorId}`. Counselors without a document use
/// [Availability.defaults] (weekdays 9–5 with a lunch break, every meeting
/// type).
class Availability {
  final String counselorId;

  /// Session start hours for each weekday ([DateTime.monday] = 1 … 7).
  final Map<int, List<int>> hours;
  final Set<SessionMode> meetingTypes;

  /// Dates (time ignored) with no sessions, e.g. leave or exam boards.
  final List<DateTime> daysOff;
  final DateTime? updatedAt;

  const Availability({
    required this.counselorId,
    required this.hours,
    required this.meetingTypes,
    this.daysOff = const [],
    this.updatedAt,
  });

  /// Hours a counselor can choose from in the editor (08:00 – 18:00 starts).
  static const selectableHours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];

  static List<int> get defaultDayHours => [
    for (var h = TimeSlots.firstHour; h <= TimeSlots.lastHour; h++)
      if (h != TimeSlots.lunchHour) h,
  ];

  factory Availability.defaults(String counselorId) => Availability(
    counselorId: counselorId,
    hours: {
      for (var d = DateTime.monday; d <= DateTime.friday; d++)
        d: defaultDayHours,
    },
    meetingTypes: SessionMode.values.toSet(),
  );

  bool isDayOff(DateTime day) {
    final d = TimeSlots.dateOnly(day);
    return daysOff.any((x) => TimeSlots.dateOnly(x) == d);
  }

  /// Bookable start times on [day] (ignores whether they are taken).
  List<DateTime> slotsFor(DateTime day) {
    if (isDayOff(day)) return const [];
    final d = TimeSlots.dateOnly(day);
    final list = [...?hours[d.weekday]]..sort();
    return [for (final h in list) DateTime(d.year, d.month, d.day, h)];
  }

  bool offersSlot(DateTime slot) => slotsFor(slot).contains(slot);

  /// Days in the booking window that have at least one opening.
  List<DateTime> openDays([DateTime? now]) =>
      TimeSlots.windowDays(now).where((d) => slotsFor(d).isNotEmpty).toList();

  int get weeklySlotCount =>
      hours.values.fold(0, (total, list) => total + list.length);

  Availability copyWith({
    Map<int, List<int>>? hours,
    Set<SessionMode>? meetingTypes,
    List<DateTime>? daysOff,
    DateTime? updatedAt,
  }) {
    return Availability(
      counselorId: counselorId,
      hours: hours ?? this.hours,
      meetingTypes: meetingTypes ?? this.meetingTypes,
      daysOff: daysOff ?? this.daysOff,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'counselorId': counselorId,
    'hours': {
      for (final e in hours.entries) '${e.key}': ([...e.value]..sort()),
    },
    'meetingTypes': [for (final m in meetingTypes) m.name],
    'daysOff': [
      for (final d in daysOff) Timestamp.fromDate(TimeSlots.dateOnly(d)),
    ],
    'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
  };

  factory Availability.fromMap(String counselorId, Map<String, dynamic> map) {
    final rawHours = (map['hours'] as Map<String, dynamic>?) ?? const {};
    final types = [
      for (final name in (map['meetingTypes'] as List<dynamic>? ?? const []))
        if (SessionMode.values.asNameMap()[name] case final SessionMode m) m,
    ];
    return Availability(
      counselorId: counselorId,
      hours: {
        for (final e in rawHours.entries)
          if (int.tryParse(e.key) case final int day)
            day: [for (final h in e.value as List<dynamic>) (h as num).toInt()],
      },
      meetingTypes: types.isEmpty ? SessionMode.values.toSet() : types.toSet(),
      daysOff: [
        for (final d in (map['daysOff'] as List<dynamic>? ?? const []))
          Appointment.readDate(d),
      ],
      updatedAt: map['updatedAt'] == null
          ? null
          : Appointment.readDate(map['updatedAt']),
    );
  }
}
