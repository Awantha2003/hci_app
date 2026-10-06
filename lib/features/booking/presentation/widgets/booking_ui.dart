import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/booking_repository.dart';
import '../../models/appointment.dart';
import '../providers/booking_provider.dart';

/// Date/time formatting and small UI helpers shared by the booking, chat and
/// counselor dashboard screens.
class BookingFormat {
  BookingFormat._();

  static String day(DateTime d) => DateFormat('EEE, d MMM').format(d);
  static String fullDate(DateTime d) => DateFormat('EEEE, d MMMM y').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);
  static String timeRange(Appointment a) =>
      '${time(a.dateTime)} – ${time(a.endTime)}';

  /// "Today", "Yesterday", a weekday, or a date, for chat timestamps.
  static String relative(DateTime d, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return time(d);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(d);
    return DateFormat('d MMM').format(d);
  }
}

/// Turns repository/validation errors into text a student can act on.
String friendlyError(Object error) {
  if (error is BookingValidationException) return error.message;
  if (error is SlotUnavailableException) return error.toString();
  if (error is ArgumentError) return '${error.message}';
  return 'Something went wrong. Please check your connection and try again.';
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? scheme.error : null,
      ),
    );
}

/// Asks the user to confirm a destructive or important action.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Colour and icon for each status, drawn from the team palette (no harsh
/// red). Status is always shown as icon + text, never colour alone, so it
/// stays readable for colour-blind users.
({Color color, IconData icon}) statusStyle(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending => (
      color: const Color(0xFFB0662F),
      icon: Icons.schedule,
    ),
    AppointmentStatus.confirmed => (
      color: AppColors.sageDark,
      icon: Icons.check_circle_outline,
    ),
    AppointmentStatus.declined => (color: AppColors.error, icon: Icons.block),
    AppointmentStatus.cancelled => (
      color: AppColors.textSecondary,
      icon: Icons.cancel_outlined,
    ),
    AppointmentStatus.completed => (
      color: AppColors.purpleDark,
      icon: Icons.task_alt,
    ),
  };
}

/// Friendly empty-list placeholder.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
