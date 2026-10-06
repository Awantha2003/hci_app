import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../chat/data/chat_repository.dart';
import '../chat/presentation/providers/chat_provider.dart';
import '../counselor_dashboard/data/availability_repository.dart';
import 'data/booking_repository.dart';
import 'models/session_user.dart';
import 'presentation/providers/booking_provider.dart';

/// Provides [BookingProvider] and [ChatProvider] for the signed-in user to
/// everything below it (Book Session, My Appointments, Reschedule, Chat and
/// Counselor Dashboard).
///
/// It must sit *above* the app's Navigator, otherwise screens pushed with
/// `Navigator.push` (Reschedule, Chat…) cannot find the providers. Integrate
/// it in `MaterialApp.builder` once auth is ready:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => appUser == null
///       ? child!
///       : BookingChatScope(
///           user: SessionUser(
///             id: appUser.uid,
///             name: appUser.name,
///             role: appUser.role == 'counselor'
///                 ? UserRole.counselor
///                 : UserRole.student,
///           ),
///           child: child!,
///         ),
///   ...
/// )
/// ```
///
/// Repositories default to Cloud Firestore; pass in-memory ones for tests or
/// demos.
class BookingChatScope extends StatelessWidget {
  const BookingChatScope({
    super.key,
    required this.user,
    required this.child,
    this.bookingRepository,
    this.chatRepository,
    this.availabilityRepository,
  });

  final SessionUser user;
  final Widget child;
  final BookingRepository? bookingRepository;
  final ChatRepository? chatRepository;
  final AvailabilityRepository? availabilityRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Keyed by user so signing in as someone else starts fresh state.
      key: ValueKey(user.id),
      providers: [
        ChangeNotifierProvider(
          create: (_) => BookingProvider(
            repository: bookingRepository ?? FirestoreBookingRepository(),
            availabilityRepository:
                availabilityRepository ?? FirestoreAvailabilityRepository(),
            user: user,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            repository: chatRepository ?? FirestoreChatRepository(),
            user: user,
          ),
        ),
      ],
      child: child,
    );
  }
}
