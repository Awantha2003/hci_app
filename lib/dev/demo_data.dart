import '../features/booking/data/in_memory_booking_repository.dart';
import '../features/booking/models/appointment.dart';
import '../features/booking/models/counselor.dart';
import '../features/booking/models/session_user.dart';
import '../features/booking/models/time_slots.dart';
import '../features/chat/data/in_memory_chat_repository.dart';
import '../features/chat/models/chat_message.dart';
import '../features/chat/models/chat_thread.dart';
import '../features/counselor_dashboard/data/availability_repository.dart';
import '../features/counselor_dashboard/models/availability.dart';

/// Sample users and data for demos, usability testing and screenshots when
/// Firebase is not connected.
class DemoData {
  DemoData._();

  static const student = SessionUser(
    id: 'student_kasun',
    name: 'Kasun Perera',
    role: UserRole.student,
  );

  static const counselors = [
    Counselor(
      id: 'counselor_nimali',
      name: 'Dr. Nimali Fernando',
      title: 'Senior Student Counselor',
      specialization: 'Stress & anxiety',
      about:
          'Helps students manage exam pressure, anxiety and burnout '
          'using CBT-based techniques.',
      languages: ['English', 'Sinhala'],
    ),
    Counselor(
      id: 'counselor_ruwan',
      name: 'Mr. Ruwan Jayasinghe',
      title: 'Student Wellbeing Officer',
      specialization: 'Academic & career',
      about:
          'Supports students with study planning, motivation and career '
          'decisions.',
      languages: ['English', 'Sinhala'],
    ),
    Counselor(
      id: 'counselor_priya',
      name: 'Ms. Priya Ramanathan',
      title: 'Counseling Psychologist',
      specialization: 'Relationships & family',
      about:
          'A safe space to talk about relationships, homesickness and '
          'family concerns.',
      languages: ['English', 'Tamil'],
    ),
  ];

  static SessionUser get counselorUser => SessionUser(
    id: counselors.first.id,
    name: counselors.first.name,
    role: UserRole.counselor,
  );

  static const _otherStudents = ['student_amaya', 'student_dinuka'];

  /// The n-th working day from today (0 = next working day after today).
  static DateTime _workingDay(int n, {bool forward = true}) {
    var d = TimeSlots.dateOnly(DateTime.now());
    var found = -1;
    while (found < n) {
      d = d.add(Duration(days: forward ? 1 : -1));
      if (TimeSlots.isWorkingDay(d)) found++;
    }
    return d;
  }

  static DateTime _at(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);

  static Appointment _appointment(
    String id,
    String studentId,
    Counselor counselor,
    DateTime when,
    AppointmentStatus status, {
    SessionMode mode = SessionMode.online,
    String reason = '',
    String note = '',
  }) {
    final created = when.subtract(const Duration(days: 3));
    return Appointment(
      id: id,
      studentId: studentId,
      studentAlias: SessionUser(
        id: studentId,
        name: '',
        role: UserRole.student,
      ).alias,
      counselorId: counselor.id,
      counselorName: counselor.name,
      dateTime: when,
      mode: mode,
      reason: reason,
      status: status,
      counselorNote: note,
      createdAt: created,
      updatedAt: created,
    );
  }

  static InMemoryBookingRepository bookingRepository() {
    final nimali = counselors[0];
    final ruwan = counselors[1];
    final now = DateTime.now();
    // A session that started an hour ago, so "Complete" can be demonstrated.
    final startedToday = DateTime(now.year, now.month, now.day, now.hour - 1);

    return InMemoryBookingRepository(
      counselors: counselors,
      appointments: [
        _appointment(
          'demo_1',
          student.id,
          nimali,
          _at(_workingDay(1), 10),
          AppointmentStatus.confirmed,
          reason: 'Feeling overwhelmed before mid-semester exams.',
        ),
        _appointment(
          'demo_2',
          student.id,
          ruwan,
          _at(_workingDay(3), 14),
          AppointmentStatus.pending,
          mode: SessionMode.inPerson,
          reason: 'Need help planning my final-year project.',
        ),
        _appointment(
          'demo_3',
          student.id,
          nimali,
          _at(_workingDay(4, forward: false), 11),
          AppointmentStatus.completed,
        ),
        _appointment(
          'demo_4',
          student.id,
          ruwan,
          _at(_workingDay(8, forward: false), 9),
          AppointmentStatus.cancelled,
        ),
        _appointment(
          'demo_5',
          _otherStudents[0],
          nimali,
          _at(_workingDay(0), 9),
          AppointmentStatus.pending,
          reason: 'Trouble sleeping and focusing.',
        ),
        _appointment(
          'demo_6',
          _otherStudents[1],
          nimali,
          _at(_workingDay(2), 15),
          AppointmentStatus.pending,
          mode: SessionMode.inPerson,
        ),
        _appointment(
          'demo_7',
          _otherStudents[1],
          nimali,
          startedToday,
          AppointmentStatus.confirmed,
          reason: 'Follow-up session.',
        ),
        _appointment(
          'demo_8',
          _otherStudents[0],
          nimali,
          _at(_workingDay(2, forward: false), 13),
          AppointmentStatus.completed,
          note: 'Discussed sleep hygiene. Follow up in 2 weeks.',
        ),
      ],
    )..latency = const Duration(milliseconds: 400);
  }

  /// Varied schedules so the demo shows availability and meeting types:
  /// Ruwan works Mon/Wed/Fri by video or chat; Priya also opens Saturday
  /// mornings; Nimali uses the default schedule.
  static InMemoryAvailabilityRepository availabilityRepository() {
    final ruwan = counselors[1];
    final priya = counselors[2];
    return InMemoryAvailabilityRepository([
      Availability(
        counselorId: ruwan.id,
        hours: {
          DateTime.monday: [10, 11, 14],
          DateTime.wednesday: [10, 11, 14, 15],
          DateTime.friday: [9, 10],
        },
        meetingTypes: {SessionMode.online, SessionMode.chat},
      ),
      Availability.defaults(priya.id).copyWith(
        hours: {
          ...Availability.defaults(priya.id).hours,
          DateTime.saturday: [9, 10, 11],
        },
        meetingTypes: {
          SessionMode.inPerson,
          SessionMode.online,
          SessionMode.phone,
        },
        daysOff: [_workingDay(2)],
      ),
    ]);
  }

  static InMemoryChatRepository chatRepository() {
    final nimali = counselors[0];
    final threadId = ChatThread.idFor(student.id, nimali.id);
    final now = DateTime.now();
    final messages = [
      ChatMessage(
        id: 'm1',
        senderId: student.id,
        text: 'Hi, I have been feeling really stressed about exams lately.',
        sentAt: now.subtract(const Duration(hours: 20)),
      ),
      ChatMessage(
        id: 'm2',
        senderId: nimali.id,
        text:
            'Thank you for reaching out. That sounds hard. What part of '
            'the exams worries you the most?',
        sentAt: now.subtract(const Duration(hours: 19, minutes: 40)),
      ),
      ChatMessage(
        id: 'm3',
        senderId: student.id,
        text: 'Mostly that I will not finish revising in time.',
        sentAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];
    return InMemoryChatRepository(
      threads: [
        ChatThread(
          id: threadId,
          studentId: student.id,
          studentAlias: student.alias,
          counselorId: nimali.id,
          counselorName: nimali.name,
          lastMessage: messages.last.text,
          updatedAt: messages.last.sentAt,
        ),
      ],
      messages: {threadId: messages},
    );
  }
}
