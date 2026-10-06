import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../counselor_dashboard/models/availability.dart';
import '../../data/booking_repository.dart';
import '../../models/appointment.dart';
import '../../models/counselor.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';
import '../widgets/counselor_card.dart';
import '../widgets/meeting_type_picker.dart';
import '../widgets/slot_picker.dart';
import 'booking_confirmation_screen.dart';
import 'my_appointments_screen.dart';

/// Interface: Book a Session (student).
///
/// CRUD: Read counselors and live slot availability, Create an appointment.
class BookSessionScreen extends StatefulWidget {
  const BookSessionScreen({
    super.key,
    this.initialCounselorId,
    this.onViewAppointments,
  });

  static const routeName = '/booking/new';

  final String? initialCounselorId;

  /// Called when the user taps "View my appointments" after booking, when
  /// this screen is a tab (e.g. to switch the bottom navigation tab).
  final VoidCallback? onViewAppointments;

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  final _reasonController = TextEditingController();
  Counselor? _counselor;
  Stream<Set<DateTime>>? _bookedSlots;
  Stream<Availability>? _availability;
  DateTime? _slot;
  SessionMode _mode = SessionMode.online;

  /// Meeting types the selected counselor offers.
  Set<SessionMode> _offered = SessionMode.values.toSet();

  SessionMode get _effectiveMode =>
      _offered.contains(_mode) ? _mode : _offered.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<BookingProvider>();
      await provider.loadCounselors();
      if (!mounted || widget.initialCounselorId == null) return;
      for (final c in provider.counselors) {
        if (c.id == widget.initialCounselorId) _selectCounselor(c);
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _selectCounselor(Counselor counselor) {
    if (_counselor?.id == counselor.id) return;
    setState(() {
      _counselor = counselor;
      final provider = context.read<BookingProvider>();
      _bookedSlots = provider.bookedSlots(counselor.id);
      _availability = provider.availabilityFor(counselor.id);
      _offered = SessionMode.values.toSet();
      _slot = null;
    });
  }

  void _resetForm() {
    setState(() {
      _counselor = null;
      _bookedSlots = null;
      _availability = null;
      _slot = null;
      _mode = SessionMode.online;
      _reasonController.clear();
    });
  }

  Future<void> _submit() async {
    final counselor = _counselor;
    final slot = _slot;
    if (counselor == null || slot == null) return;

    final provider = context.read<BookingProvider>();
    final navigator = Navigator.of(context);
    final Appointment appointment;
    try {
      appointment = await provider.book(
        counselor: counselor,
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
      if (!mounted) return;
      showMessage(context, friendlyError(e), error: true);
      return;
    }

    final result = await navigator.push<ConfirmationAction>(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(appointment: appointment),
      ),
    );
    if (!mounted) return;
    _resetForm();

    if (navigator.canPop()) {
      // Opened from My Appointments: go straight back there.
      navigator.pop();
    } else if (result == ConfirmationAction.viewAppointments) {
      if (widget.onViewAppointments != null) {
        widget.onViewAppointments!();
      } else {
        navigator.push(
          MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final theme = Theme.of(context);
    final canSubmit = _counselor != null && _slot != null && !provider.busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Book a session')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PrivacyBanner(alias: provider.user.alias),
          const SizedBox(height: 20),
          const _StepTitle(number: 1, title: 'Choose a counselor'),
          const SizedBox(height: 10),
          _buildCounselors(provider),
          const SizedBox(height: 24),
          const _StepTitle(number: 2, title: 'Pick a date and time'),
          const SizedBox(height: 10),
          if (_counselor == null)
            Text(
              'Select a counselor to see their free times.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            SlotPicker(
              key: ValueKey(_counselor!.id),
              availability: _availability!,
              bookedSlots: _bookedSlots!,
              selected: _slot,
              onSelected: (slot) => setState(() => _slot = slot),
            ),
          const SizedBox(height: 24),
          const _StepTitle(number: 3, title: 'Meeting type'),
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
          const SizedBox(height: 24),
          const _StepTitle(
            number: 4,
            title: 'What would you like to talk about?',
            optional: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonController,
            maxLength: BookingProvider.maxReasonLength,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Exam stress, trouble sleeping…',
              border: OutlineInputBorder(),
              helperText: 'Only your counselor can see this.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_counselor != null && _slot != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_counselor!.name} · ${BookingFormat.day(_slot!)} · '
                    '${BookingFormat.time(_slot!)}',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  child: provider.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Confirm booking'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounselors(BookingProvider provider) {
    if (provider.loadingCounselors && provider.counselors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.counselorsError != null) {
      return Column(
        children: [
          Text(provider.counselorsError!),
          TextButton.icon(
            onPressed: () => provider.loadCounselors(force: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );
    }
    if (provider.counselors.isEmpty) {
      return const Text('No counselors are available right now.');
    }
    return Column(
      children: [
        for (final c in provider.counselors) ...[
          CounselorCard(
            counselor: c,
            selected: _counselor?.id == c.id,
            onTap: () => _selectCounselor(c),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.number,
    required this.title,
    this.optional = false,
  });

  final int number;
  final String title;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: Text('$number', style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: title,
              children: [
                if (optional)
                  TextSpan(
                    text: '  (optional)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.alias});

  final String alias;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your booking is confidential. Counselors see you as '
              '"$alias", not your real name.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
