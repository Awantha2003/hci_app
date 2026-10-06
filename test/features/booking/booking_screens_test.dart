import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindcheck/features/booking/booking_chat_scope.dart';
import 'package:mindcheck/features/booking/data/in_memory_booking_repository.dart';
import 'package:mindcheck/features/booking/models/appointment.dart';
import 'package:mindcheck/features/booking/models/session_user.dart';
import 'package:mindcheck/features/booking/presentation/screens/book_session_screen.dart';
import 'package:mindcheck/features/booking/presentation/screens/counselor_details_screen.dart';
import 'package:mindcheck/features/booking/presentation/screens/my_appointments_screen.dart';
import 'package:mindcheck/features/booking/presentation/screens/student_home_screen.dart';
import 'package:mindcheck/features/booking/presentation/widgets/counselor_card.dart';
import 'package:mindcheck/features/booking/presentation/widgets/slot_picker.dart';
import 'package:mindcheck/features/chat/data/in_memory_chat_repository.dart';
import 'package:mindcheck/features/counselor_dashboard/data/availability_repository.dart';
import 'package:mindcheck/features/chat/presentation/screens/chat_screen.dart';
import 'package:mindcheck/features/counselor_dashboard/presentation/screens/counselor_dashboard_screen.dart';

import 'test_helpers.dart';

/// UI-level functional tests: drive the real screens like a user would.
void main() {
  late InMemoryBookingRepository bookingRepo;
  late InMemoryChatRepository chatRepo;

  setUp(() {
    bookingRepo = InMemoryBookingRepository(counselors: [counselor]);
    chatRepo = InMemoryChatRepository();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    SessionUser user = student,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => BookingChatScope(
        user: user,
        bookingRepository: bookingRepo,
        chatRepository: chatRepo,
        availabilityRepository: InMemoryAvailabilityRepository(),
        child: child!,
      ),
      home: home,
    ));
    await tester.pumpAndSettle();
  }

  /// Lets any snack bar time out so no timers are left pending.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Appointment seeded(AppointmentStatus status, {DateTime? at}) {
    final now = DateTime.now();
    return Appointment(
      id: 'seed',
      studentId: student.id,
      studentAlias: student.alias,
      counselorId: counselor.id,
      counselorName: counselor.name,
      dateTime: at ?? futureSlot(),
      mode: SessionMode.online,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('TC-UI01 student books a session end to end', (tester) async {
    await pumpApp(tester, const BookSessionScreen());

    final confirm = find.widgetWithText(FilledButton, 'Confirm booking');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull,
        reason: 'disabled until a counselor and time are chosen');

    await tester.tap(find.text(counselor.name));
    await tester.pumpAndSettle();

    final freeSlot = tester
        .widgetList<TimeSlotPill>(find.byType(TimeSlotPill))
        .firstWhere((p) => p.onTap != null);
    await tester.tap(find.byWidget(freeSlot));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Your request has been sent!'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    final saved = await bookingRepo.watchStudentAppointments(student.id).first;
    expect(saved.single.status, AppointmentStatus.pending);
  });

  testWidgets('TC-UI02 student cancels an upcoming session', (tester) async {
    bookingRepo = InMemoryBookingRepository(
      counselors: [counselor],
      appointments: [seeded(AppointmentStatus.confirmed)],
    );
    await pumpApp(tester, const MyAppointmentsScreen());

    expect(find.text('Upcoming (1)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this session?'), findsOneWidget);

    await tester.tap(find.text('Cancel session'));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming (0)'), findsOneWidget);
    expect(find.text('No upcoming sessions'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('TC-UI03 counselor accepts a pending request', (tester) async {
    bookingRepo = InMemoryBookingRepository(
      counselors: [counselor],
      appointments: [seeded(AppointmentStatus.pending)],
    );
    await pumpApp(tester, const CounselorDashboardScreen(),
        user: counselorUser);

    expect(find.text(student.alias), findsOneWidget);
    expect(find.text(student.name), findsNothing);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm session'), findsWidgets);
    await tester.enterText(
      find.byType(TextField).last,
      'https://meet.example.com/abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm session'));
    await tester.pumpAndSettle();

    final list = await bookingRepo.watchCounselorAppointments(counselor.id).first;
    expect(list.single.status, AppointmentStatus.confirmed);
    expect(list.single.meetingInfo, 'https://meet.example.com/abc');
    expect(find.text('No requests waiting. 🎉'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('TC-UI04 chat send button is disabled until text is typed',
      (tester) async {
    final thread = await chatRepo.openThread(
      studentId: student.id,
      studentAlias: student.alias,
      counselorId: counselor.id,
      counselorName: counselor.name,
    );
    await pumpApp(tester, ChatScreen(thread: thread));

    IconButton sendButton() =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

    expect(sendButton().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'I feel anxious today');
    await tester.pump();
    expect(sendButton().onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('I feel anxious today'), findsOneWidget);
    expect(sendButton().onPressed, isNull, reason: 'input clears after send');
  });

  testWidgets('TC-UI05 home lists counselors and search filters them',
      (tester) async {
    bookingRepo = InMemoryBookingRepository(counselors: [counselor, counselor2]);
    await pumpApp(tester, const StudentHomeScreen());

    expect(find.byType(CounselorGridCard), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pumpAndSettle();
    expect(find.byType(CounselorGridCard), findsOneWidget);
    expect(find.text(counselor2.name), findsOneWidget);
  });

  testWidgets('TC-UI06 booking from the counselor details page',
      (tester) async {
    await pumpApp(tester, const CounselorDetailsScreen(counselor: counselor));

    final freeSlot = tester
        .widgetList<TimeSlotPill>(find.byType(TimeSlotPill))
        .firstWhere((p) => p.onTap != null);
    await tester.tap(find.byWidget(freeSlot));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book Appointment'));
    await tester.pumpAndSettle();

    expect(find.text('Your request has been sent!'), findsOneWidget);
    final saved = await bookingRepo.watchStudentAppointments(student.id).first;
    expect(saved.single.counselorId, counselor.id);
  });
}
