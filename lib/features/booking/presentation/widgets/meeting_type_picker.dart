import 'package:flutter/material.dart';

import '../../models/appointment.dart';

/// Grid of meeting types (video, phone, in person, chat). Only the types in
/// [available] can be chosen; the others are shown disabled so students can
/// see what the counselor does not offer.
class MeetingTypePicker extends StatelessWidget {
  const MeetingTypePicker({
    super.key,
    required this.available,
    required this.selected,
    required this.onChanged,
  });

  final Set<SessionMode> available;
  final SessionMode selected;
  final ValueChanged<SessionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
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
            selected: mode == selected,
            onTap: available.contains(mode) ? () => onChanged(mode) : null,
          ),
      ],
    );
  }
}

class MeetingTypeOption extends StatelessWidget {
  const MeetingTypeOption({
    super.key,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SessionMode mode;
  final bool selected;

  /// Null when this type is not offered.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final fg = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : selected
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: enabled ? mode.label : '${mode.label}, not offered',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: !enabled
                ? scheme.surfaceContainerHigh
                : selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected && enabled
                  ? scheme.primary
                  : enabled
                  ? scheme.outlineVariant
                  : Colors.transparent,
              width: selected && enabled ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(mode.icon, color: selected && enabled ? scheme.primary : fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  enabled ? mode.label : '${mode.label} ✕',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
