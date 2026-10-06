import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../booking/models/appointment.dart';
import '../../../booking/models/time_slots.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../booking/presentation/widgets/booking_ui.dart';
import '../../../booking/presentation/widgets/home_widgets.dart';
import '../../../booking/presentation/widgets/meeting_type_picker.dart';
import '../../models/availability.dart';

/// Interface: My Availability (counselor).
///
/// CRUD: Read the saved schedule, Create/Update weekly hours, meeting types
/// and days off, Delete days off or reset the whole schedule.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  static const routeName = '/counselor/availability';

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late final StreamSubscription<Availability> _sub;
  Availability? _draft;
  bool _dirty = false;

  static const _weekdays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<BookingProvider>();
    // Keep the editor in sync with the saved schedule until the user starts
    // editing, so their changes are never overwritten.
    _sub = provider.availabilityFor(provider.user.id).listen((a) {
      if (!_dirty && mounted) setState(() => _draft = a);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _update(Availability Function(Availability a) change) {
    setState(() {
      _draft = change(_draft!);
      _dirty = true;
    });
  }

  void _toggleType(SessionMode mode) {
    _update((a) {
      final types = {...a.meetingTypes};
      if (!types.remove(mode)) types.add(mode);
      return a.copyWith(meetingTypes: types);
    });
  }

  void _setDayHours(int weekday, List<int> hours) {
    _update((a) => a.copyWith(hours: {...a.hours, weekday: hours..sort()}));
  }

  void _toggleHour(int weekday, int hour) {
    final current = [...?_draft!.hours[weekday]];
    if (!current.remove(hour)) current.add(hour);
    _setDayHours(weekday, current);
  }

  void _copyMondayToWeekdays() {
    final monday = [...?_draft!.hours[DateTime.monday]];
    _update(
      (a) => a.copyWith(
        hours: {
          ...a.hours,
          for (var d = DateTime.tuesday; d <= DateTime.friday; d++)
            d: [...monday],
        },
      ),
    );
  }

  Future<void> _addDayOff() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: TimeSlots.dateOnly(now),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Choose a day off',
    );
    if (picked == null || _draft!.isDayOff(picked)) return;
    _update(
      (a) => a.copyWith(
        daysOff: [...a.daysOff, TimeSlots.dateOnly(picked)]
          ..sort((x, y) => x.compareTo(y)),
      ),
    );
  }

  void _removeDayOff(DateTime day) {
    _update(
      (a) => a.copyWith(
        daysOff: a.daysOff
            .where((d) => TimeSlots.dateOnly(d) != TimeSlots.dateOnly(day))
            .toList(),
      ),
    );
  }

  Future<void> _save() async {
    final provider = context.read<BookingProvider>();
    try {
      await provider.saveAvailability(_draft!);
      if (!mounted) return;
      setState(() => _dirty = false);
      showMessage(
        context,
        'Availability saved. Students now see your new times.',
      );
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _reset() async {
    final provider = context.read<BookingProvider>();
    final ok = await confirmAction(
      context,
      title: 'Reset to default hours?',
      message:
          'Your saved schedule will be deleted and replaced by '
          'weekdays 9 AM – 5 PM with all meeting types.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      _dirty = false;
      await provider.resetAvailability();
      if (mounted) showMessage(context, 'Schedule reset to default.');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirmAction(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes to your availability.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = context.watch<BookingProvider>().busy;
    final draft = _draft;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _dirty = false;
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My availability'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'reset') _reset();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    leading: Icon(Icons.restart_alt_rounded),
                    title: Text('Reset to default'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: draft == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _SummaryCard(availability: draft),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Meeting types I offer'),
                  const SizedBox(height: 4),
                  Text(
                    'Students can only choose the types you switch on.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.9,
                    children: [
                      for (final mode in SessionMode.values)
                        MeetingTypeOption(
                          mode: mode,
                          selected: draft.meetingTypes.contains(mode),
                          onTap: () => _toggleType(mode),
                        ),
                    ],
                  ),
                  if (draft.meetingTypes.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Choose at least one meeting type.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Weekly hours',
                    actionLabel: 'Copy Mon → Fri',
                    onAction: _copyMondayToWeekdays,
                  ),
                  const SizedBox(height: 8),
                  for (final day in _weekdays) ...[
                    _DayHoursCard(
                      weekday: day,
                      hours: draft.hours[day] ?? const [],
                      onToggleDay: (on) => _setDayHours(
                        day,
                        on ? Availability.defaultDayHours : [],
                      ),
                      onToggleHour: (h) => _toggleHour(day, h),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  SectionHeader(
                    title: 'Days off',
                    count: draft.daysOff.length,
                    actionLabel: 'Add',
                    onAction: _addDayOff,
                  ),
                  const SizedBox(height: 8),
                  if (draft.daysOff.isEmpty)
                    Text(
                      'No days off planned. Add leave days so students '
                      'cannot book them.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final d in draft.daysOff)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: softCardDecoration(context, radius: 14),
                          child: ListTile(
                            leading: const Icon(Icons.beach_access_rounded),
                            title: Text(BookingFormat.fullDate(d)),
                            trailing: IconButton(
                              tooltip: 'Remove day off',
                              onPressed: () => _removeDayOff(d),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed:
                    draft == null ||
                        !_dirty ||
                        busy ||
                        draft.meetingTypes.isEmpty
                    ? null
                    : _save,
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_dirty ? 'Save changes' : 'All changes saved'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.availability});

  final Availability availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = availability.hours.values.where((h) => h.isNotEmpty).length;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSecondary,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.secondary, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          stat('$days', 'days a week'),
          stat('${availability.weeklySlotCount}', 'slots a week'),
          stat('${availability.meetingTypes.length}', 'meeting types'),
          stat('${availability.daysOff.length}', 'days off'),
        ],
      ),
    );
  }
}

class _DayHoursCard extends StatelessWidget {
  const _DayHoursCard({
    required this.weekday,
    required this.hours,
    required this.onToggleDay,
    required this.onToggleHour,
  });

  final int weekday;
  final List<int> hours;
  final ValueChanged<bool> onToggleDay;
  final ValueChanged<int> onToggleHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final open = hours.isNotEmpty;
    // 2024-01-01 is a Monday, used only to get the weekday name.
    final name = DateFormat('EEEE').format(DateTime(2024, 1, weekday));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: softCardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      open
                          ? '${hours.length} slot${hours.length == 1 ? '' : 's'}'
                          : 'Closed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: open, onChanged: onToggleDay),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in Availability.selectableHours)
                  FilterChip(
                    label: Text(
                      DateFormat('h a').format(DateTime(2024, 1, 1, h)),
                    ),
                    selected: hours.contains(h),
                    showCheckmark: false,
                    selectedColor: scheme.primary,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: hours.contains(h)
                          ? scheme.onPrimary
                          : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => onToggleHour(h),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
