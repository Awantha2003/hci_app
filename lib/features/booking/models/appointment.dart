import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show IconData, Icons;

enum AppointmentStatus { pending, confirmed, declined, cancelled, completed }

/// Meeting type. `online` is a video call (name kept for stored data).
enum SessionMode { online, phone, inPerson, chat }

extension AppointmentStatusX on AppointmentStatus {
  String get label => switch (this) {
    AppointmentStatus.pending => 'Pending',
    AppointmentStatus.confirmed => 'Confirmed',
    AppointmentStatus.declined => 'Declined',
    AppointmentStatus.cancelled => 'Cancelled',
    AppointmentStatus.completed => 'Completed',
  };

  /// Pending and confirmed sessions hold a counselor time slot.
  bool get holdsSlot =>
      this == AppointmentStatus.pending || this == AppointmentStatus.confirmed;
}

extension SessionModeX on SessionMode {
  String get label => switch (this) {
    SessionMode.online => 'Video call',
    SessionMode.phone => 'Phone call',
    SessionMode.inPerson => 'In person',
    SessionMode.chat => 'Text chat',
  };

  IconData get icon => switch (this) {
    SessionMode.online => Icons.videocam_outlined,
    SessionMode.phone => Icons.call_outlined,
    SessionMode.inPerson => Icons.location_on_outlined,
    SessionMode.chat => Icons.chat_bubble_outline_rounded,
  };

  /// What the counselor fills in when accepting, shown to the student.
  String get detailsLabel => switch (this) {
    SessionMode.online => 'Video call link',
    SessionMode.phone => 'Phone call details',
    SessionMode.inPerson => 'Room / location',
    SessionMode.chat => 'Chat instructions',
  };

  String get detailsHint => switch (this) {
    SessionMode.online => 'e.g. https://meet.google.com/abc-defg-hij',
    SessionMode.phone => 'e.g. I will call you from the unit number',
    SessionMode.inPerson => 'e.g. Counseling Unit, Room 2, Main Building',
    SessionMode.chat => 'e.g. I will message you here at the start time',
  };
}

class Appointment {
  final String id;
  final String studentId;

  /// Anonymous name shown to the counselor instead of the student's name.
  final String studentAlias;
  final String counselorId;
  final String counselorName;
  final DateTime dateTime;
  final SessionMode mode;
  final String reason;
  final AppointmentStatus status;

  /// Private note the counselor can keep about the session.
  final String counselorNote;

  /// Meeting details the counselor adds when accepting (link, room…).
  final String meetingInfo;

  /// Why the counselor declined, shown to the student.
  final String declineReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.studentId,
    required this.studentAlias,
    required this.counselorId,
    required this.counselorName,
    required this.dateTime,
    required this.mode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reason = '',
    this.counselorNote = '',
    this.meetingInfo = '',
    this.declineReason = '',
  });

  static const sessionLength = Duration(hours: 1);

  DateTime get endTime => dateTime.add(sessionLength);

  bool get isActive => status.holdsSlot;

  /// Upcoming sessions can still be rescheduled or cancelled.
  bool isUpcoming([DateTime? now]) =>
      isActive && dateTime.isAfter(now ?? DateTime.now());

  bool isOn(DateTime day) =>
      dateTime.year == day.year &&
      dateTime.month == day.month &&
      dateTime.day == day.day;

  Appointment copyWith({
    String? id,
    DateTime? dateTime,
    SessionMode? mode,
    String? reason,
    AppointmentStatus? status,
    String? counselorNote,
    String? meetingInfo,
    String? declineReason,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      studentId: studentId,
      studentAlias: studentAlias,
      counselorId: counselorId,
      counselorName: counselorName,
      dateTime: dateTime ?? this.dateTime,
      mode: mode ?? this.mode,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      counselorNote: counselorNote ?? this.counselorNote,
      meetingInfo: meetingInfo ?? this.meetingInfo,
      declineReason: declineReason ?? this.declineReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'studentAlias': studentAlias,
    'counselorId': counselorId,
    'counselorName': counselorName,
    'dateTime': Timestamp.fromDate(dateTime),
    'mode': mode.name,
    'reason': reason,
    'status': status.name,
    'counselorNote': counselorNote,
    'meetingInfo': meetingInfo,
    'declineReason': declineReason,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Appointment.fromMap(String id, Map<String, dynamic> map) {
    return Appointment(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentAlias: map['studentAlias'] as String? ?? 'Anonymous',
      counselorId: map['counselorId'] as String? ?? '',
      counselorName: map['counselorName'] as String? ?? 'Counselor',
      dateTime: readDate(map['dateTime']),
      mode: SessionMode.values.asNameMap()[map['mode']] ?? SessionMode.online,
      reason: map['reason'] as String? ?? '',
      status:
          AppointmentStatus.values.asNameMap()[map['status']] ??
          AppointmentStatus.pending,
      counselorNote: map['counselorNote'] as String? ?? '',
      meetingInfo: map['meetingInfo'] as String? ?? '',
      declineReason: map['declineReason'] as String? ?? '',
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
    );
  }

  /// Accepts a Firestore [Timestamp], a [DateTime] or epoch milliseconds.
  static DateTime readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
