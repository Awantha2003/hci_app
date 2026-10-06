import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../models/appointment.dart';
import '../providers/booking_provider.dart';
import '../widgets/appointment_card.dart';
import '../widgets/booking_ui.dart';
import 'book_session_screen.dart';
import 'reschedule_screen.dart';

/// Interface: My Appointments (student).
///
/// CRUD: Read the student's appointments (live), Update (cancel), Delete
/// (remove a past or cancelled session from history).
class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  static const routeName = '/booking/mine';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My appointments'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Upcoming (${provider.upcoming.length})'),
              Tab(text: 'Past (${provider.past.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookSessionScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Book session'),
        ),
        body: Builder(
          builder: (context) {
            if (provider.loadingAppointments) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.appointmentsError != null) {
              return EmptyMessage(
                icon: Icons.cloud_off,
                title: 'Could not load your appointments',
                message: provider.appointmentsError!,
              );
            }
            return TabBarView(
              children: [
                _AppointmentList(
                  appointments: provider.upcoming,
                  upcoming: true,
                ),
                _AppointmentList(appointments: provider.past, upcoming: false),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({required this.appointments, required this.upcoming});

  final List<Appointment> appointments;
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return upcoming
          ? EmptyMessage(
              icon: Icons.event_note_outlined,
              title: 'No upcoming sessions',
              message:
                  'Talking to someone can help. Book a confidential '
                  'session with a university counselor.',
              action: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookSessionScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Book a session'),
              ),
            )
          : const EmptyMessage(
              icon: Icons.history,
              title: 'No past sessions',
              message: 'Completed and cancelled sessions will appear here.',
            );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: appointments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = appointments[i];
        return AppointmentCard(
          appointment: a,
          actions: upcoming
              ? [
                  TextButton.icon(
                    onPressed: () => _openChat(context, a),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Message'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RescheduleScreen(appointmentId: a.id),
                      ),
                    ),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Reschedule'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _cancel(context, a),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                  ),
                ]
              : [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _delete(context, a),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                  ),
                ],
        );
      },
    );
  }

  Future<void> _cancel(BuildContext context, Appointment a) async {
    final provider = context.read<BookingProvider>();
    final ok = await confirmAction(
      context,
      title: 'Cancel this session?',
      message:
          'Your session with ${a.counselorName} on '
          '${BookingFormat.day(a.dateTime)} at '
          '${BookingFormat.time(a.dateTime)} will be cancelled and the time '
          'freed for other students.',
      confirmLabel: 'Cancel session',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await provider.cancel(a);
      if (context.mounted) showMessage(context, 'Session cancelled.');
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, Appointment a) async {
    final provider = context.read<BookingProvider>();
    final ok = await confirmAction(
      context,
      title: 'Remove from history?',
      message: 'This permanently deletes the record of this session.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await provider.delete(a);
      if (context.mounted) showMessage(context, 'Session removed.');
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _openChat(BuildContext context, Appointment a) async {
    final chat = context.read<ChatProvider>();
    try {
      final thread = await chat.openForBooking(
        studentId: a.studentId,
        studentAlias: a.studentAlias,
        counselorId: a.counselorId,
        counselorName: a.counselorName,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(thread: thread)),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }
}
