import 'package:flutter/material.dart';

/// Building blocks for the home dashboards (student and counselor): soft
/// white cards, greeting header, search field, section headers, category
/// tiles and action tiles. Colours come from the app theme.

const _softShadow = [
  BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 6)),
];

/// White rounded surface with a soft shadow, used across the dashboards.
BoxDecoration softCardDecoration(BuildContext context, {double radius = 20}) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: _softShadow,
  );
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.text,
    this.radius = 26,
    this.icon,
  });

  final String text;
  final double radius;

  /// Shown instead of initials (e.g. for anonymous students).
  final IconData? icon;

  static String initialsOf(String name) {
    final parts = name
        .replaceAll(RegExp(r'^(Dr\.|Mr\.|Ms\.|Mrs\.)\s*'), '')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      child: icon != null
          ? Icon(icon, size: radius)
          : Text(
              initialsOf(text),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.65,
              ),
            ),
    );
  }
}

/// Round icon button: white with a soft shadow, or filled with the accent
/// colour. Shows an optional badge dot or count.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.badgeCount = 0,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final int badgeCount;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Material(
      color: filled ? scheme.primary : scheme.surfaceContainerLowest,
      shape: const CircleBorder(),
      elevation: filled ? 4 : 2,
      shadowColor: filled
          ? scheme.primary.withValues(alpha: 0.5)
          : const Color(0x33000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(
            icon,
            color: filled ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      child: Badge(
        isLabelVisible: badgeCount > 0 || showDot,
        smallSize: 10,
        backgroundColor: scheme.tertiary,
        textColor: scheme.onTertiary,
        offset: const Offset(-4, 4),
        label: badgeCount > 0 ? Text('$badgeCount') : null,
        child: button,
      ),
    );
  }
}

/// "Welcome back, `name`" header with an avatar and trailing actions.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    required this.avatar,
    this.greeting = 'Welcome back,',
    this.actions = const [],
  });

  final String name;
  final Widget avatar;
  final String greeting;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 10), a],
      ],
    );
  }
}

class HomeSearchField extends StatelessWidget {
  const HomeSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.onClear,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  /// Shows a clear button when not null.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: softCardDecoration(context, radius: 18),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: scheme.surfaceContainerLowest,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.count,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Square rounded icon tile with a label underneath (categories, quick
/// actions). The selected/highlighted tile is filled with the accent colour.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.size = 64,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: size,
                height: size,
                decoration: selected
                    ? BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      )
                    : softCardDecoration(context, radius: 18),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: size + 16,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// Large accent-coloured "hero" card used at the top of the dashboards.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.title,
    required this.lines,
    required this.decorIcon,
    this.onTap,
    this.trailingChip,
  });

  final String label;
  final String title;
  final List<(IconData, String)> lines;
  final IconData decorIcon;
  final VoidCallback? onTap;
  final Widget? trailingChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onAccent = scheme.onPrimary;

    final radius = BorderRadius.circular(26);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  Color.lerp(scheme.primary, Colors.black, 0.18)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles and icon on the right.
                Positioned(
                  right: -30,
                  top: -30,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    child: Icon(
                      decorIcon,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ?trailingChip,
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(right: 110),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: onAccent,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final (icon, text) in lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 110),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: onAccent.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: onAccent.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (onTap != null)
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.north_east_rounded,
                            color: scheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White stat tile with an icon bubble, a number and a label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: softCardDecoration(context, radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: highlighted
                    ? scheme.primary
                    : scheme.secondaryContainer,
                child: Icon(
                  icon,
                  size: 20,
                  color: highlighted
                      ? scheme.onPrimary
                      : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
