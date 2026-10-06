import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import 'booking_ui.dart';

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 16, color: style.color),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: style.color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary of one session. Students see the counselor's name; counselors see
/// only the student's anonymous alias.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.viewerIsCounselor = false,
    this.actions = const [],
    this.onTap,
  });

  final Appointment appointment;
  final bool viewerIsCounselor;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = appointment;
    final who = viewerIsCounselor ? a.studentAlias : a.counselorName;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      // Sage card colour comes from the theme (30% secondary colour).
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DateBadge(date: a.dateTime),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (viewerIsCounselor) ...[
                              Icon(
                                Icons.visibility_off_outlined,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                who,
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          BookingFormat.timeRange(a),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              a.mode.icon,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              a.mode.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppointmentStatusChip(status: a.status),
                ],
              ),
              if (a.reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '“${a.reason}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (a.status == AppointmentStatus.confirmed &&
                  a.meetingInfo.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoBanner(
                  icon: a.mode.icon,
                  title: a.mode.detailsLabel,
                  text: a.meetingInfo,
                  color: scheme.primaryContainer,
                  onColor: scheme.onPrimaryContainer,
                ),
              ],
              if (a.status == AppointmentStatus.declined &&
                  a.declineReason.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoBanner(
                  icon: Icons.info_outline_rounded,
                  title: viewerIsCounselor ? 'Your reason' : 'Counselor said',
                  text: a.declineReason,
                  color: scheme.errorContainer,
                  onColor: scheme.onErrorContainer,
                ),
              ],
              if (viewerIsCounselor && a.counselorNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.counselorNote,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: actions,
                ),
              ] else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            _months[date.month - 1],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Highlighted line inside a card, e.g. the meeting link or decline reason.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: onColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SelectableText(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(color: onColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
