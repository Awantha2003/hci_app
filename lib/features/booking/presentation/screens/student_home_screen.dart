import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/counselor.dart';
import '../providers/booking_provider.dart';
import '../widgets/appointment_card.dart';
import '../widgets/booking_ui.dart';
import '../widgets/counselor_card.dart';
import '../widgets/home_widgets.dart';
import 'book_session_screen.dart';
import 'counselor_details_screen.dart';
import 'my_appointments_screen.dart';

/// Interface: Student Home dashboard.
///
/// CRUD: Read counselors (searchable, filterable by topic) and the student's
/// next session; leads to booking (Create) from the counselor cards.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, this.onViewAppointments});

  static const routeName = '/home';

  /// Switches to the appointments tab when the home is part of a tab bar.
  final VoidCallback? onViewAppointments;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _Topic {
  const _Topic(this.label, this.icon, this.keywords);
  final String label;
  final IconData icon;
  final List<String> keywords;

  bool matches(Counselor c) {
    if (keywords.isEmpty) return true;
    final s = c.specialization.toLowerCase();
    return keywords.any(s.contains);
  }
}

const _topics = [
  _Topic('All', Icons.grid_view_rounded, []),
  _Topic('Stress', Icons.self_improvement_rounded, ['stress', 'anxiety']),
  _Topic('Academic', Icons.school_rounded, ['academic', 'career', 'study']),
  _Topic('Relationships', Icons.favorite_rounded, ['relationship', 'family']),
  _Topic('Sleep', Icons.bedtime_rounded, ['sleep']),
];

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Topic _topic = _topics.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<BookingProvider>().loadCounselors(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Counselor> _filtered(List<Counselor> all) {
    final q = _query.trim().toLowerCase();
    return all.where((c) {
      final matchesQuery =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.specialization.toLowerCase().contains(q) ||
          c.languages.any((l) => l.toLowerCase().contains(q));
      return matchesQuery && _topic.matches(c);
    }).toList();
  }

  void _openAppointments() {
    if (widget.onViewAppointments != null) {
      widget.onViewAppointments!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
      );
    }
  }

  void _openCounselor(Counselor c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CounselorDetailsScreen(
          counselor: c,
          onViewAppointments: widget.onViewAppointments,
        ),
      ),
    );
  }

  void _openBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookSessionScreen()),
    );
  }

  void _showUpdates(List<Appointment> updates) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (context, controller) => Column(
          children: [
            Text(
              'Booking updates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              child: updates.isEmpty
                  ? const EmptyMessage(
                      icon: Icons.notifications_none_rounded,
                      title: 'No updates yet',
                      message: 'Changes to your bookings will appear here.',
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: updates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = updates[i];
                        final style = statusStyle(a.status);
                        return ListTile(
                          tileColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: style.color.withValues(
                              alpha: 0.12,
                            ),
                            child: Icon(style.icon, color: style.color),
                          ),
                          title: Text('${a.counselorName} · ${a.status.label}'),
                          subtitle: Text(
                            '${BookingFormat.day(a.dateTime)}, '
                            '${BookingFormat.time(a.dateTime)}',
                          ),
                          trailing: Text(
                            BookingFormat.relative(a.updatedAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final user = provider.user;
    final next = provider.upcoming.isEmpty ? null : provider.upcoming.first;
    final updates = [...provider.appointments]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentUpdates = updates.take(8).toList();
    final hasConfirmedNext = provider.upcoming.any(
      (a) => a.status == AppointmentStatus.confirmed,
    );
    final counselors = _filtered(provider.counselors);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadCounselors(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              GreetingHeader(
                name: user.name,
                avatar: InitialsAvatar(text: user.name),
                actions: [
                  RoundIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Booking updates',
                    showDot: hasConfirmedNext,
                    onPressed: () => _showUpdates(recentUpdates),
                  ),
                  RoundIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Book a session',
                    filled: true,
                    onPressed: _openBooking,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              HomeSearchField(
                controller: _search,
                hint: 'Search counselor, topic, language…',
                onChanged: (v) => setState(() => _query = v),
                onClear: _query.isEmpty
                    ? null
                    : () {
                        _search.clear();
                        setState(() => _query = '');
                      },
              ),
              const SizedBox(height: 22),
              if (next != null)
                HeroCard(
                  label: 'Your next session',
                  title: next.counselorName,
                  decorIcon: Icons.spa_rounded,
                  trailingChip: AppointmentStatusChip(status: next.status),
                  lines: [
                    (
                      Icons.calendar_today_rounded,
                      BookingFormat.fullDate(next.dateTime),
                    ),
                    (Icons.access_time_rounded, BookingFormat.timeRange(next)),
                    (next.mode.icon, next.mode.label),
                  ],
                  onTap: _openAppointments,
                )
              else
                HeroCard(
                  label: 'You are not alone',
                  title: 'Talk to a counselor, confidentially',
                  decorIcon: Icons.self_improvement_rounded,
                  lines: [
                    (Icons.lock_outline_rounded, 'Shown as "${user.alias}"'),
                    (Icons.schedule_rounded, 'Weekdays, 9 AM – 5 PM'),
                  ],
                  onTap: _openBooking,
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _topics.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, i) => CategoryTile(
                    icon: _topics[i].icon,
                    label: _topics[i].label,
                    selected: _topics[i] == _topic,
                    onTap: () => setState(() => _topic = _topics[i]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SectionHeader(
                title: 'Counselors',
                actionLabel: 'See all',
                onAction: _openBooking,
              ),
              const SizedBox(height: 8),
              _buildGrid(provider, counselors),
              const SizedBox(height: 24),
              const _HelplineCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BookingProvider provider, List<Counselor> counselors) {
    if (provider.loadingCounselors && provider.counselors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.counselorsError != null) {
      return Column(
        children: [
          Text(provider.counselorsError!, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: () => provider.loadCounselors(force: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      );
    }
    if (counselors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          provider.counselors.isEmpty
              ? 'No counselors are available right now.'
              : 'No counselors match your search.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      itemCount: counselors.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: 206,
      ),
      itemBuilder: (context, i) {
        final c = counselors[i];
        return CounselorGridCard(
          counselor: c,
          onTap: () => _openCounselor(c),
          onBook: () => _openCounselor(c),
        );
      },
    );
  }
}

class _HelplineCard extends StatelessWidget {
  const _HelplineCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.tertiary,
            child: Icon(Icons.support_agent_rounded, color: scheme.onTertiary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help right now?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Call the National Mental Health Helpline 1926 '
                  '(free, 24/7).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
