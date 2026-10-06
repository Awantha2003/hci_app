import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../widgets/appointment_card.dart';
import '../widgets/booking_ui.dart';

enum ConfirmationAction { viewAppointments, done }

/// Interface: Booking Confirmation, shown after a successful booking.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key, required this.appointment});

  static const routeName = '/booking/confirmation';

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = appointment;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Booking requested'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(
                    Icons.event_available,
                    size: 52,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your request has been sent!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${a.counselorName} will review it shortly. You will see the '
              'status change to "Confirmed" in My Appointments.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(
                      context,
                      Icons.person_outline,
                      'Counselor',
                      a.counselorName,
                    ),
                    _row(
                      context,
                      Icons.calendar_today_outlined,
                      'Date',
                      BookingFormat.fullDate(a.dateTime),
                    ),
                    _row(
                      context,
                      Icons.access_time,
                      'Time',
                      BookingFormat.timeRange(a),
                    ),
                    _row(context, a.mode.icon, 'Type', a.mode.label),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 32),
                          Text('Status', style: theme.textTheme.bodyMedium),
                          const Spacer(),
                          AppointmentStatusChip(status: a.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Need to change plans? You can reschedule or cancel from '
                    'My Appointments at any time before the session.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    ConfirmationAction.viewAppointments,
                  ),
                  child: const Text('View my appointments'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pop(context, ConfirmationAction.done),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
