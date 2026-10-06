import '../../booking/models/appointment.dart';

/// A one-to-one anonymous conversation between a student and a counselor.
class ChatThread {
  final String id;
  final String studentId;
  final String studentAlias;
  final String counselorId;
  final String counselorName;
  final String lastMessage;
  final DateTime updatedAt;

  const ChatThread({
    required this.id,
    required this.studentId,
    required this.studentAlias,
    required this.counselorId,
    required this.counselorName,
    required this.updatedAt,
    this.lastMessage = '',
  });

  /// One thread per student/counselor pair, so reopening a chat continues
  /// the same conversation.
  static String idFor(String studentId, String counselorId) =>
      '${studentId}_$counselorId';

  List<String> get participants => [studentId, counselorId];

  /// The name to show in the header: counselors see the student's alias,
  /// students see the counselor's name.
  String titleFor(String userId) =>
      userId == counselorId ? studentAlias : counselorName;

  ChatThread copyWith({String? lastMessage, DateTime? updatedAt}) => ChatThread(
    id: id,
    studentId: studentId,
    studentAlias: studentAlias,
    counselorId: counselorId,
    counselorName: counselorName,
    lastMessage: lastMessage ?? this.lastMessage,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'studentAlias': studentAlias,
    'counselorId': counselorId,
    'counselorName': counselorName,
    'participants': participants,
    'lastMessage': lastMessage,
    'updatedAt': updatedAt,
  };

  factory ChatThread.fromMap(String id, Map<String, dynamic> map) {
    return ChatThread(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentAlias: map['studentAlias'] as String? ?? 'Anonymous',
      counselorId: map['counselorId'] as String? ?? '',
      counselorName: map['counselorName'] as String? ?? 'Counselor',
      lastMessage: map['lastMessage'] as String? ?? '',
      updatedAt: Appointment.readDate(map['updatedAt']),
    );
  }
}
