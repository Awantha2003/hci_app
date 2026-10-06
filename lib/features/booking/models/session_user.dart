import '../../chat/models/anonymous_alias.dart';

enum UserRole { student, counselor }

/// The signed-in user as seen by the Booking, Chat and Counselor Dashboard
/// features.
///
/// Kept deliberately small so these features do not depend on the full auth
/// model. When auth is wired in, build it from the logged-in `AppUser`
/// (uid, name, role).
class SessionUser {
  final String id;
  final String name;
  final UserRole role;

  const SessionUser({required this.id, required this.name, required this.role});

  bool get isCounselor => role == UserRole.counselor;

  /// Anonymous display name shown to counselors instead of the real name.
  String get alias => AnonymousAlias.forUser(id);
}
