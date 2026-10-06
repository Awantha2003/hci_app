import '../../booking/models/appointment.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;

  /// Set when the sender edits the message after sending it.
  final DateTime? editedAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.editedAt,
  });

  static const maxLength = 1000;

  bool get isEdited => editedAt != null;

  bool isMine(String userId) => senderId == userId;

  ChatMessage copyWith({String? text, DateTime? editedAt}) => ChatMessage(
    id: id,
    senderId: senderId,
    text: text ?? this.text,
    sentAt: sentAt,
    editedAt: editedAt ?? this.editedAt,
  );

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'sentAt': sentAt,
    'editedAt': editedAt,
  };

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      sentAt: Appointment.readDate(map['sentAt']),
      editedAt: map['editedAt'] == null
          ? null
          : Appointment.readDate(map['editedAt']),
    );
  }
}
