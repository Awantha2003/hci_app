import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../counselor_dashboard/models/availability.dart';
import '../../models/time_slots.dart';
import 'booking_ui.dart';

/// Lets the user pick a day and a free one-hour slot from the counselor's
/// published availability.
///
/// Only days the counselor has opened are listed; booked and past slots are
/// disabled and labelled, so the user never picks a time that will be
/// rejected. [currentSlot] (when rescheduling) is shown as "Current".
class SlotPicker extends StatefulWidget {
  const SlotPicker({
    super.key,
    required this.availability,
    required this.bookedSlots,
    required this.selected,
    required this.onSelected,
    this.currentSlot,
  });

  /// Live opening hours of the chosen counselor.
  final Stream<Availability> availability;

  /// Live set of taken slots for the chosen counselor.
  final Stream<Set<DateTime>> bookedSlots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final DateTime? currentSlot;

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  DateTime? _day;

  DateTime _initialDay(Availability availability, List<DateTime> days) {
    final preferred = widget.selected ?? widget.currentSlot;
    if (preferred != null) {
      final d = TimeSlots.dateOnly(preferred);
      if (days.contains(d)) return d;
    }
    // Skip days whose slots have all passed (e.g. late today).
    final now = DateTime.now();
    return days.firstWhere(
      (d) => availability.slotsFor(d).any((s) => s.isAfter(now)),
      orElse: () => days.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<Availability>(
      stream: widget.availability,
      builder: (context, availabilitySnap) {
        if (availabilitySnap.hasError) {
          return Text(
            'Could not load availability. Please try again.',
            style: TextStyle(color: scheme.error),
          );
        }
        if (!availabilitySnap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final availability = availabilitySnap.data!;
        final days = availability.openDays();
        if (days.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No open times in the next 2 weeks. Try another '
                    'counselor or send them a message.',
                  ),
                ),
              ],
            ),
          );
        }
        final day = (_day != null && days.contains(_day))
            ? _day!
            : _initialDay(availability, days);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM y').format(day),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _DayPill(
                  day: days[i],
                  selected: days[i] == day,
                  onTap: () => setState(() => _day = days[i]),
                ),
              ),
            ),
            const SizedBox(height: 18),
            StreamBuilder<Set<DateTime>>(
              stream: widget.bookedSlots,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Could not load booked times. Please try again.',
                    style: TextStyle(color: scheme.error),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final booked = snapshot.data!;
                final now = DateTime.now();
                final slots = availability.slotsFor(day);
                final anyFree = slots.any(
                  (s) => TimeSlots.isSelectable(s, booked, now),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final slot in slots) _pill(slot, booked, now),
                      ],
                    ),
                    if (!anyFree) ...[
                      const SizedBox(height: 12),
                      Text(
                        'No free slots on this day. Try another date.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _pill(DateTime slot, Set<DateTime> booked, DateTime now) {
    final isCurrent = slot == widget.currentSlot;
    final isPast = !slot.isAfter(now);
    final isBooked = booked.contains(slot);
    final enabled = !isCurrent && !isPast && !isBooked;

    return TimeSlotPill(
      time: slot,
      selected: slot == widget.selected,
      note: isCurrent
          ? 'Current'
          : isBooked
          ? 'Booked'
          : null,
      onTap: enabled ? () => widget.onSelected(slot) : null,
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: BookingFormat.fullDate(day),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 60,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('EEE').format(day),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? fg : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A selectable time slot. Disabled when [onTap] is null.
class TimeSlotPill extends StatelessWidget {
  const TimeSlotPill({
    super.key,
    required this.time,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final DateTime time;
  final bool selected;
  final VoidCallback? onTap;

  /// Extra label such as "Booked" or "Current".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final label = BookingFormat.time(time);

    final Color bg;
    final Color fg;
    if (selected) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (enabled) {
      bg = scheme.surfaceContainerLowest;
      fg = scheme.onSurface;
    } else {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant.withValues(alpha: 0.7);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: note == null ? label : '$label, $note',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 96, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected || !enabled
                  ? Colors.transparent
                  : scheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  decoration: note == 'Booked'
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
