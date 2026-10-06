import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/booking/booking_chat_scope.dart';
import '../features/booking/data/booking_repository.dart';
import '../features/booking/models/session_user.dart';
import '../features/booking/presentation/screens/student_home_screen.dart';
import '../features/booking/presentation/screens/my_appointments_screen.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/screens/chat_list_screen.dart';
import '../features/counselor_dashboard/data/availability_repository.dart';
import '../features/counselor_dashboard/presentation/screens/counselor_dashboard_screen.dart';
import '../firebase_options.dart';
import 'demo_data.dart';

/// Stand-alone entry point for the Booking, Chat and Counselor Dashboard
/// module (Rathnayaka's workload), so it can be run, demonstrated and
/// usability-tested before the rest of the app is merged.
///
///   flutter run -t lib/dev/booking_chat_demo_main.dart
///   flutter run -t lib/dev/booking_chat_demo_main.dart --dart-define=USE_FIREBASE=false
///
/// On Android the data is stored in Cloud Firestore (project
/// mindcheck-app-c6452). With USE_FIREBASE=false, or on platforms Firebase is
/// not configured for (web, desktop), sample data lives in memory instead and
/// resets on restart.
const _firebaseFlag = bool.fromEnvironment('USE_FIREBASE', defaultValue: true);

bool get _useFirebase =>
    _firebaseFlag && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Problem signing in to Firebase, shown on the start screen.
String? _authProblem;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firestore rules only allow signed-in users. Until the login feature is
    // merged, the demo signs in anonymously so `request.auth` is set.
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      _authProblem = e.code == 'operation-not-allowed' ||
              e.code == 'admin-restricted-operation'
          ? 'Anonymous sign-in is turned off. Enable it in Firebase Console '
              '> Authentication > Sign-in method > Anonymous.'
          : 'Could not sign in to Firebase (${e.code}). Check the internet '
              'connection.';
    } catch (e) {
      _authProblem = 'Could not sign in to Firebase: $e';
    }
  }
  runApp(const BookingChatDemoApp());
}

/// The demo student. With Firebase, the signed-in (anonymous) account's uid
/// is used, so bookings belong to a real Firebase user.
SessionUser get _demoStudent {
  final uid = _useFirebase ? FirebaseAuth.instance.currentUser?.uid : null;
  return uid == null
      ? DemoData.student
      : SessionUser(
          id: uid,
          name: DemoData.student.name,
          role: UserRole.student,
        );
}

class BookingChatDemoApp extends StatefulWidget {
  const BookingChatDemoApp({super.key});

  @override
  State<BookingChatDemoApp> createState() => _BookingChatDemoAppState();
}

class _BookingChatDemoAppState extends State<BookingChatDemoApp> {
  // Shared by both roles so a booking made as the student shows up on the
  // counselor's dashboard after switching user.
  late final BookingRepository _booking = _useFirebase
      ? FirestoreBookingRepository()
      : DemoData.bookingRepository();
  late final AvailabilityRepository _availability = _useFirebase
      ? FirestoreAvailabilityRepository()
      : DemoData.availabilityRepository();
  late final ChatRepository _chat = _useFirebase
      ? FirestoreChatRepository()
      : DemoData.chatRepository();

  SessionUser? _user;

  void _signOut() => setState(() => _user = null);

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return MaterialApp(
      // A fresh navigator per user, so no screens leak between roles.
      key: ValueKey(user?.id),
      title: 'MindCheck – Booking & Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // The scope wraps the Navigator so every pushed screen (Reschedule,
      // Chat, …) can reach the providers.
      builder: (context, child) => user == null
          ? child!
          : BookingChatScope(
              user: user,
              bookingRepository: _booking,
              chatRepository: _chat,
              availabilityRepository: _availability,
              child: child!,
            ),
      home: user == null
          ? _RolePicker(onPick: (u) => setState(() => _user = u))
          : user.isCounselor
          ? _CounselorShell(onSignOut: _signOut)
          : _StudentShell(onSignOut: _signOut),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.onPick});

  final ValueChanged<SessionUser> onPick;

  Future<void> _seedCounselors(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final users = FirebaseFirestore.instance.collection('users');
    final batch = FirebaseFirestore.instance.batch();
    for (final c in DemoData.counselors) {
      batch.set(users.doc(c.id), c.toMap(), SetOptions(merge: true));
    }
    try {
      await batch.commit().timeout(const Duration(seconds: 15));
      messenger.showSnackBar(
        const SnackBar(content: Text('Demo counselors added to Firestore.')),
      );
    } catch (e) {
      // Usually the Firestore rules: see docs/booking_chat_module.md.
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Could not write to Firestore: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.favorite_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'MindCheck',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              'Booking, Chat & Counselor Dashboard',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _useFirebase ? 'Connected to Firebase' : 'Offline demo data',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_authProblem != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _authProblem!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _RoleCard(
              icon: Icons.school_outlined,
              title: 'Continue as student',
              subtitle:
                  '${_demoStudent.name} · counselors see '
                  '"${_demoStudent.alias}"',
              onTap: () => onPick(_demoStudent),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.medical_services_outlined,
              title: 'Continue as counselor',
              subtitle: DemoData.counselorUser.name,
              onTap: () => onPick(DemoData.counselorUser),
            ),
            if (_useFirebase) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _seedCounselors(context),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Add demo counselors to Firestore'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Stand-in for the app's bottom navigation (owned by the navigation
/// feature) so the student screens can be reached in the demo.
class _StudentShell extends StatefulWidget {
  const _StudentShell({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<_StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<_StudentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          StudentHomeScreen(
            onViewAppointments: () => setState(() => _index = 1),
          ),
          const MyAppointmentsScreen(),
          const ChatListScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) =>
            i == 3 ? widget.onSignOut() : setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Switch',
          ),
        ],
      ),
    );
  }
}

class _CounselorShell extends StatefulWidget {
  const _CounselorShell({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<_CounselorShell> createState() => _CounselorShellState();
}

class _CounselorShellState extends State<_CounselorShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CounselorDashboardScreen(
            onOpenMessages: () => setState(() => _index = 1),
          ),
          const ChatListScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) =>
            i == 2 ? widget.onSignOut() : setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Switch',
          ),
        ],
      ),
    );
  }
}
