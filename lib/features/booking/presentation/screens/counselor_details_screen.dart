import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../counselor_dashboard/models/availability.dart';
import '../../data/booking_repository.dart';
import '../../models/appointment.dart';
import '../../models/counselor.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';
import '../widgets/counselor_card.dart';
import '../widgets/home_widgets.dart';
import '../widgets/meeting_type_picker.dart';
import '../widgets/slot_picker.dart';
import 'booking_confirmation_screen.dart';

/// Interface: Counselor Details & Booking (student).
///
/// CRUD: Read the counselor's profile and live availability, Create an
/// appointment. Also starts an anonymous chat with the counselor.
class CounselorDetailsScreen extends StatefulWidget {
  const CounselorDetailsScreen({
    super.key,
    required this.counselor,
    this.onViewAppointments,
  });

  static const routeName = '/booking/counselor';

  final Counselor counselor;

  /// Called after booking when the user picks "View my appointments".
  final VoidCallback? onViewAppointments;

  @override
  State<CounselorDetailsScreen> createState() => _CounselorDetailsScreenState();
}

class _CounselorDetailsScreenState extends State<CounselorDetailsScreen> {
  final _reasonController = TextEditingController();
  late final Stream<Set<DateTime>> _bookedSlots = context
      .read<BookingProvider>()
      .bookedSlots(widget.counselor.id);
  late final Stream<Availability> _availability = context
      .read<BookingProvider>()
      .availabilityFor(widget.counselor.id);
  DateTime? _slot;
  SessionMode _mode = SessionMode.online;

  /// Meeting types the counselor currently offers (from availability).
  Set<SessionMode> _offered = SessionMode.values.toSet();
  bool _showReason = false;

  SessionMode get _effectiveMode =>
      _offered.contains(_mode) ? _mode : _offered.first;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Counselor get c => widget.counselor;

  Future<void> _book() async {
    final slot = _slot;
    if (slot == null) return;
    final provider = context.read<BookingProvider>();
    final navigator = Navigator.of(context);

    final Appointment appointment;
    try {
      appointment = await provider.book(
        counselor: c,
        dateTime: slot,
        mode: _effectiveMode,
        reason: _reasonController.text,
      );
    } on SlotUnavailableException catch (e) {
      if (!mounted) return;
      setState(() => _slot = null);
      showMessage(context, e.toString(), error: true);
      return;
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
      return;
    }

    final result = await navigator.push<ConfirmationAction>(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(appointment: appointment),
      ),
    );
    if (!mounted) return;
    navigator.pop();
    if (result == ConfirmationAction.viewAppointments) {
      widget.onViewAppointments?.call();
    }
  }

  Future<void> _message() async {
    final chat = context.read<ChatProvider>();
    try {
      final thread = await chat.openWithCounselor(c);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(thread: thread)),
      );
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  void _showInfoSheet({
    required IconData icon,
    required String title,
    required List<String> lines,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(
                        icon,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(title, style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(line, style: theme.textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = context.watch<BookingProvider>().busy;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Details'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          CounselorBanner(
            counselor: c,
            height: 190,
            avatarRadius: 46,
            radius: 26,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'University',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.badge_outlined, text: c.title),
          _InfoLine(
            icon: Icons.psychology_alt_outlined,
            text: c.specialization,
          ),
          _InfoLine(
            icon: Icons.translate_rounded,
            text: c.languages.join(', '),
          ),
          if (c.about.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              c.about,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CategoryTile(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Message',
                selected: true,
                onTap: _message,
              ),
              CategoryTile(
                icon: Icons.location_on_outlined,
                label: 'Location',
                onTap: () => _showInfoSheet(
                  icon: Icons.location_on_outlined,
                  title: 'Student Counseling Unit',
                  lines: const [
                    'Ground floor, Main Building',
                    'Open Monday – Friday, 9:00 AM – 5:00 PM',
                    'In-person sessions take place here. Online sessions '
                        'use a private video link sent before the session.',
                  ],
                ),
              ),
              CategoryTile(
                icon: Icons.schedule_rounded,
                label: 'Hours',
                onTap: () => _showInfoSheet(
                  icon: Icons.schedule_rounded,
                  title: 'Session hours',
                  lines: const [
                    'Weekdays, 9:00 AM – 5:00 PM',
                    'Each session is 1 hour. Lunch break 12:00 – 1:00 PM.',
                    'You can book up to 2 weeks ahead.',
                  ],
                ),
              ),
              CategoryTile(
                icon: Icons.support_agent_rounded,
                label: 'Helpline',
                onTap: () => _showInfoSheet(
                  icon: Icons.support_agent_rounded,
                  title: 'Need help right now?',
                  lines: const [
                    'National Mental Health Helpline: 1926',
                    'Free, confidential and available 24/7.',
                    'If you are in immediate danger, call 119.',
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Available slots',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SlotPicker(
            availability: _availability,
            bookedSlots: _bookedSlots,
            selected: _slot,
            onSelected: (slot) => setState(() => _slot = slot),
          ),
          const SizedBox(height: 22),
          Text(
            'Meeting type',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<Availability>(
            stream: _availability,
            builder: (context, snapshot) {
              final offered = snapshot.data?.meetingTypes;
              if (offered != null && offered.isNotEmpty) _offered = offered;
              return MeetingTypePicker(
                available: _offered,
                selected: _effectiveMode,
                onChanged: (m) => setState(() => _mode = m),
              );
            },
          ),
          const SizedBox(height: 16),
          if (!_showReason)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showReason = true),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Add a note for the counselor (optional)'),
              ),
            )
          else
            TextField(
              controller: _reasonController,
              autofocus: true,
              maxLength: BookingProvider.maxReasonLength,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What would you like to talk about?',
                hintText: 'e.g. Exam stress, trouble sleeping…',
                helperText: 'Only your counselor can see this.',
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 58,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _slot == null || busy ? null : _book,
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      _slot == null
                          ? 'Select a time'
                          : 'Book Appointment · ${BookingFormat.day(_slot!)}, '
                                '${BookingFormat.time(_slot!)}',
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
