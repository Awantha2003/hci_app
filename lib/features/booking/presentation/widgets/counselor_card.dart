import 'package:flutter/material.dart';

import '../../models/counselor.dart';
import 'home_widgets.dart';

class CounselorAvatar extends StatelessWidget {
  const CounselorAvatar({super.key, required this.counselor, this.radius = 24});

  final Counselor counselor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      child: Text(
        counselor.initials,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: radius * 0.7),
      ),
    );
  }
}

/// A selectable counselor tile used on the Book Session screen.
class CounselorCard extends StatelessWidget {
  const CounselorCard({
    super.key,
    required this.counselor,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final Counselor counselor;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${counselor.name}, ${counselor.specialization}',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CounselorAvatar(counselor: counselor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(counselor.name, style: theme.textTheme.titleMedium),
                      Text(
                        counselor.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Tag(
                            icon: Icons.psychology_outlined,
                            text: counselor.specialization,
                          ),
                          _Tag(
                            icon: Icons.translate,
                            text: counselor.languages.join(', '),
                          ),
                        ],
                      ),
                      if (counselor.about.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          counselor.about,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner art for a counselor: a sage gradient with the counselor's initials
/// and an icon for their specialization. Used on grid cards and the details
/// page in place of a photo.
class CounselorBanner extends StatelessWidget {
  const CounselorBanner({
    super.key,
    required this.counselor,
    this.height = 110,
    this.avatarRadius = 30,
    this.radius = 18,
  });

  final Counselor counselor;
  final double height;
  final double avatarRadius;
  final double radius;

  static IconData iconFor(Counselor c) {
    final s = c.specialization.toLowerCase();
    if (s.contains('stress') || s.contains('anxiety')) {
      return Icons.self_improvement_rounded;
    }
    if (s.contains('academic') || s.contains('career')) {
      return Icons.school_rounded;
    }
    if (s.contains('relationship') || s.contains('family')) {
      return Icons.favorite_rounded;
    }
    if (s.contains('sleep')) return Icons.bedtime_rounded;
    return Icons.psychology_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [scheme.secondaryContainer, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -height * 0.15,
            bottom: -height * 0.2,
            child: Icon(
              iconFor(counselor),
              size: height * 0.9,
              color: Colors.white.withValues(alpha: 0.28),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: InitialsAvatar(text: counselor.name, radius: avatarRadius),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid card for the student home: banner, name, specialization and a round
/// "+" button to book.
class CounselorGridCard extends StatelessWidget {
  const CounselorGridCard({
    super.key,
    required this.counselor,
    required this.onTap,
    required this.onBook,
  });

  final Counselor counselor;
  final VoidCallback onTap;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: '${counselor.name}, ${counselor.specialization}',
      child: DecoratedBox(
        decoration: softCardDecoration(context),
        child: Material(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CounselorBanner(counselor: counselor),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      counselor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            counselor.specialization,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          tooltip: 'Book ${counselor.name}',
                          onPressed: onBook,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
