import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../counselor_dashboard/models/availability.dart';
import '../../data/booking_repository.dart';
import '../providers/booking_provider.dart';
import '../widgets/appointment_card.dart';
import '../widgets/booking_ui.dart';
import '../widgets/slot_picker.dart';

/// Interface: Reschedule (student).
///
/// CRUD: Read the current booking and live availability, Update the
/// session's date and time.
class RescheduleScreen extends StatefulWidget {
  const RescheduleScreen({super.key, required this.appointmentId});

  static const routeName = '/booking/reschedule';

  final String appointmentId;

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  Stream<Set<DateTime>>? _bookedSlots;
  Stream<Availability>? _availability;
  DateTime? _newSlot;

  Future<void> _save() async {
    final provider = context.read<BookingProvider>();
    final appointment = provider.byId(widget.appointmentId);
    final slot = _newSlot;
    if (appointment == null || slot == null) return;

    final ok = await confirmAction(
      context,
      title: 'Move your session?',
      message:
          'From ${BookingFormat.day(appointment.dateTime)}, '
          '${BookingFormat.time(appointment.dateTime)}\n'
          'To ${BookingFormat.day(slot)}, ${BookingFormat.time(slot)}\n\n'
          '${appointment.counselorName} will need to confirm the new time.',
      confirmLabel: 'Reschedule',
    );
    if (!ok || !mounted) return;

    try {
      await provider.reschedule(appointment, slot);
      if (!mounted) return;
      showMessage(
        context,
        'Rescheduled to ${BookingFormat.day(slot)} at '
        '${BookingFormat.time(slot)}.',
      );
      Navigator.pop(context);
    } on SlotUnavailableException catch (e) {
      if (!mounted) return;
      setState(() => _newSlot = null);
      showMessage(context, e.toString(), error: true);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final appointment = provider.byId(widget.appointmentId);
    final theme = Theme.of(context);

    if (appointment == null || !appointment.isUpcoming()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reschedule')),
        body: const EmptyMessage(
          icon: Icons.event_busy,
          title: 'This session can no longer be changed',
          message: 'It may have been cancelled, declined or already started.',
        ),
      );
    }

    _bookedSlots ??= provider.bookedSlots(appointment.counselorId);
    _availability ??= provider.availabilityFor(appointment.counselorId);

    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule session')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Current booking', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          AppointmentCard(appointment: appointment),
          const SizedBox(height: 24),
          Text('Choose a new time', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Showing ${appointment.counselorName}\'s free slots.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SlotPicker(
            availability: _availability!,
            bookedSlots: _bookedSlots!,
            selected: _newSlot,
            currentSlot: appointment.dateTime,
            onSelected: (slot) => setState(() => _newSlot = slot),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _newSlot == null || provider.busy ? null : _save,
              child: provider.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      _newSlot == null
                          ? 'Select a new time'
                          : 'Move to ${BookingFormat.day(_newSlot!)}, '
                                '${BookingFormat.time(_newSlot!)}',
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
