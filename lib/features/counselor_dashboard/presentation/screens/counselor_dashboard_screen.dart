import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../booking/models/appointment.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../booking/presentation/widgets/appointment_card.dart';
import '../../../booking/presentation/widgets/booking_ui.dart';
import '../../../booking/presentation/widgets/home_widgets.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../models/availability.dart';
import 'availability_screen.dart';

/// Interface: Counselor Dashboard.
///
/// CRUD: Read the counselor's requests and sessions (live), Update (accept,
/// decline, mark completed), Create/Update a private session note.
class CounselorDashboardScreen extends StatelessWidget {
  const CounselorDashboardScreen({super.key, this.onOpenMessages});

  static const routeName = '/counselor';

  /// Switches to the messages tab when the dashboard is part of a tab bar.
  final VoidCallback? onOpenMessages;

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final conversations = context.watch<ChatProvider>().threads.length;

    return Scaffold(
      body: SafeArea(
        child: booking.loadingAppointments
            ? const Center(child: CircularProgressIndicator())
            : booking.appointmentsError != null
            ? EmptyMessage(
                icon: Icons.cloud_off,
                title: 'Could not load sessions',
                message: booking.appointmentsError!,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  GreetingHeader(
                    name: booking.user.name,
                    avatar: InitialsAvatar(text: booking.user.name),
                    actions: [
                      RoundIconButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        tooltip: 'Messages',
                        badgeCount: conversations,
                        onPressed: () => _openMessages(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildHero(context, booking),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      StatTile(
                        icon: Icons.mark_email_unread_outlined,
                        value: booking.pendingRequests.length,
                        label: 'New requests',
                        highlighted: booking.pendingRequests.isNotEmpty,
                      ),
                      const SizedBox(width: 12),
                      StatTile(
                        icon: Icons.today_rounded,
                        value: booking.todaysSessions.length,
                        label: 'Today',
                      ),
                      const SizedBox(width: 12),
                      StatTile(
                        icon: Icons.task_alt_rounded,
                        value: booking.completedCount,
                        label: 'Completed',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _AvailabilityCard(
                    stream: booking.availabilityFor(booking.user.id),
                    onManage: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AvailabilityScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'New requests',
                    count: booking.pendingRequests.length,
                  ),
                  const SizedBox(height: 8),
                  if (booking.pendingRequests.isEmpty)
                    const _InlineEmpty(text: 'No requests waiting. 🎉')
                  else
                    for (final a in booking.pendingRequests) ...[
                      _RequestCard(
                        appointment: a,
                        onDecline: () => _decline(context, a),
                        onAccept: () => _accept(context, a),
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: 'Confirmed sessions',
                    count: booking.confirmedSessions.length,
                  ),
                  const SizedBox(height: 8),
                  if (booking.confirmedSessions.isEmpty)
                    const _InlineEmpty(
                      text: 'Accepted sessions will show up here.',
                    )
                  else
                    for (final a in booking.confirmedSessions) ...[
                      AppointmentCard(
                        appointment: a,
                        viewerIsCounselor: true,
                        actions: [
                          IconButton(
                            tooltip: 'Message ${a.studentAlias}',
                            onPressed: () => _openChat(context, a),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                          ),
                          IconButton(
                            tooltip: a.counselorNote.isEmpty
                                ? 'Add note'
                                : 'Edit note',
                            onPressed: () => _editNote(context, a),
                            icon: const Icon(Icons.edit_note_rounded),
                          ),
                          _CompleteButton(appointment: a),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: 'Recent history',
                    count: _history(booking).length,
                  ),
                  const SizedBox(height: 8),
                  if (_history(booking).isEmpty)
                    const _InlineEmpty(text: 'No past sessions yet.')
                  else
                    for (final a in _history(booking).take(5)) ...[
                      AppointmentCard(
                        appointment: a,
                        viewerIsCounselor: true,
                        actions: [
                          if (a.status == AppointmentStatus.completed)
                            TextButton.icon(
                              onPressed: () => _editNote(context, a),
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 18,
                              ),
                              label: Text(
                                a.counselorNote.isEmpty
                                    ? 'Add note'
                                    : 'Edit note',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, BookingProvider booking) {
    final now = DateTime.now();
    final next = booking.confirmedSessions
        .where((a) => a.endTime.isAfter(now))
        .firstOrNull;

    if (next != null) {
      final live = next.dateTime.isBefore(now);
      return HeroCard(
        label: live ? 'Happening now' : 'Next session',
        title: next.studentAlias,
        decorIcon: Icons.spa_rounded,
        lines: [
          (Icons.calendar_today_rounded, BookingFormat.fullDate(next.dateTime)),
          (Icons.access_time_rounded, BookingFormat.timeRange(next)),
          (next.mode.icon, next.mode.label),
        ],
        onTap: () => _openChat(context, next),
      );
    }
    final pending = booking.pendingRequests.length;
    final plural = pending == 1 ? 'request' : 'requests';
    return HeroCard(
      label: pending > 0 ? 'Action needed' : 'All caught up',
      title: pending > 0
          ? '$pending new $plural waiting'
          : 'No sessions scheduled',
      decorIcon: pending > 0
          ? Icons.mark_email_unread_outlined
          : Icons.self_improvement_rounded,
      lines: [
        (
          Icons.info_outline_rounded,
          pending > 0 ? 'Review them below' : 'New requests will appear here',
        ),
        (Icons.visibility_off_outlined, 'Students are shown anonymously'),
      ],
    );
  }

  void _openMessages(BuildContext context) {
    if (onOpenMessages != null) {
      onOpenMessages!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    }
  }

  static List<Appointment> _history(BookingProvider booking) =>
      booking.past.where((a) => !a.isActive).toList();

  static Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (context.mounted) showMessage(context, success);
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _accept(BuildContext context, Appointment a) async {
    final booking = context.read<BookingProvider>();
    final info = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AcceptSheet(appointment: a),
    );
    if (info == null || !context.mounted) return;
    await _run(
      context,
      () => booking.confirm(a, meetingInfo: info),
      'Session confirmed with ${a.studentAlias}.',
    );
  }

  Future<void> _decline(BuildContext context, Appointment a) async {
    final booking = context.read<BookingProvider>();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DeclineSheet(appointment: a),
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      () => booking.decline(a, reason: reason),
      'Request declined. The slot is free again.',
    );
  }

  Future<void> _editNote(BuildContext context, Appointment a) async {
    final booking = context.read<BookingProvider>();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(initial: a.counselorNote),
    );
    if (note == null || !context.mounted) return;
    await _run(context, () => booking.saveNote(a, note), 'Note saved.');
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

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final started = appointment.dateTime.isBefore(DateTime.now());
    final button = FilledButton.tonal(
      onPressed: started
          ? () => CounselorDashboardScreen._run(
              context,
              () => context.read<BookingProvider>().complete(appointment),
              'Marked as completed.',
            )
          : null,
      child: const Text('Complete'),
    );
    return started
        ? button
        : Tooltip(
            message: 'Available once the session has started',
            child: button,
          );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});

  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: BookingProvider.maxNoteLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Private notes – only you can see these.',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// A pending request: who (alias), when, how, why, and Decline / Accept.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.appointment,
    required this.onDecline,
    required this.onAccept,
  });

  final Appointment appointment;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = appointment;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const InitialsAvatar(
                text: '',
                radius: 22,
                icon: Icons.visibility_off_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.studentAlias,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${BookingFormat.day(a.dateTime)} · '
                      '${BookingFormat.timeRange(a)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      a.mode.icon,
                      size: 14,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      a.mode.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (a.reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '“${a.reason}”',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }
}

/// Summary of the counselor's published hours with a "Manage" button.
class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.stream, required this.onManage});

  final Stream<Availability> stream;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return StreamBuilder<Availability>(
      stream: stream,
      builder: (context, snapshot) {
        final a = snapshot.data;
        final days = a == null
            ? 0
            : a.hours.values.where((h) => h.isNotEmpty).length;
        return Material(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onManage,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.secondary,
                    child: Icon(
                      Icons.event_available_rounded,
                      color: scheme.onSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My availability',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a == null
                              ? 'Loading…'
                              : '$days days · ${a.weeklySlotCount} slots a week'
                                    ' · ${a.daysOff.length} days off',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        if (a != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final m in SessionMode.values)
                                if (a.meetingTypes.contains(m))
                                  Icon(
                                    m.icon,
                                    size: 18,
                                    color: scheme.onSecondaryContainer,
                                    semanticLabel: m.label,
                                  ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: onManage,
                    child: const Text('Manage'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Accept flow: review the request and add meeting details for the student.
class _AcceptSheet extends StatefulWidget {
  const _AcceptSheet({required this.appointment});

  final Appointment appointment;

  @override
  State<_AcceptSheet> createState() => _AcceptSheetState();
}

class _AcceptSheetState extends State<_AcceptSheet> {
  late final _controller = TextEditingController(
    text: switch (widget.appointment.mode) {
      SessionMode.inPerson =>
        'Student Counseling Unit, Ground floor, '
            'Main Building',
      SessionMode.chat =>
        'I will message you here in MindCheck at the session time.',
      _ => '',
    },
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = widget.appointment;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm session',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetLine(Icons.visibility_off_outlined, a.studentAlias),
                _SheetLine(
                  Icons.calendar_today_rounded,
                  BookingFormat.fullDate(a.dateTime),
                ),
                _SheetLine(
                  Icons.access_time_rounded,
                  BookingFormat.timeRange(a),
                ),
                _SheetLine(a.mode.icon, a.mode.label),
                if (a.reason.isNotEmpty)
                  _SheetLine(Icons.format_quote_rounded, a.reason),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            maxLength: BookingProvider.maxMeetingInfoLength,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '${a.mode.detailsLabel} (shared with the student)',
              hintText: a.mode.detailsHint,
              prefixIcon: Icon(a.mode.icon),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, _controller.text),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirm session'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decline flow: pick or write a short reason the student will see.
class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet({required this.appointment});

  final Appointment appointment;

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  static const _reasons = [
    'I am not available at this time',
    'Please choose another time',
    'Another counselor suits this topic better',
    'Fully booked this week',
  ];

  final _controller = TextEditingController();
  String? _picked;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _reason {
    final custom = _controller.text.trim();
    return custom.isNotEmpty ? custom : (_picked ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = widget.appointment;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Decline request',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${a.studentAlias} · ${BookingFormat.day(a.dateTime)}, '
            '${BookingFormat.time(a.dateTime)}. The slot will be freed and '
            'the student will see your reason.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _reasons)
                ChoiceChip(
                  label: Text(r),
                  selected: _picked == r,
                  showCheckmark: false,
                  onSelected: (sel) => setState(() => _picked = sel ? r : null),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLength: BookingProvider.maxReasonLength,
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Or write your own message (optional)',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, _reason),
              icon: const Icon(Icons.block_rounded),
              label: const Text('Decline request'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetLine extends StatelessWidget {
  const _SheetLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
