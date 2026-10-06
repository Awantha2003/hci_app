import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/chat_thread.dart';

/// Data access for anonymous student–counselor chat.
///
/// CRUD summary:
/// * Create – [openThread], [sendMessage]
/// * Read   – [watchThreads], [watchMessages]
/// * Update – [editMessage]
/// * Delete – [deleteMessage], [deleteThread]
abstract class ChatRepository {
  /// Conversations [userId] takes part in that have at least one message,
  /// newest first.
  Stream<List<ChatThread>> watchThreads(String userId);

  /// Returns the existing thread for this student/counselor pair, or creates
  /// an empty one.
  Future<ChatThread> openThread({
    required String studentId,
    required String studentAlias,
    required String counselorId,
    required String counselorName,
  });

  /// Messages in [threadId], oldest first, updated in real time.
  Stream<List<ChatMessage>> watchMessages(String threadId);

  Future<void> sendMessage(String threadId, String senderId, String text);

  Future<void> editMessage(String threadId, String messageId, String text);

  Future<void> deleteMessage(String threadId, String messageId);

  /// Deletes the conversation and all of its messages.
  Future<void> deleteThread(String threadId);
}

/// Cloud Firestore implementation.
///
/// Collections:
/// * `chats/{studentId_counselorId}`            – see [ChatThread.toMap]
/// * `chats/{threadId}/messages/{messageId}`    – see [ChatMessage.toMap]
class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String threadId) =>
      _chats.doc(threadId).collection('messages');

  @override
  Stream<List<ChatThread>> watchThreads(String userId) {
    return _chats
        .where('participants', arrayContains: userId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => ChatThread.fromMap(d.id, d.data()))
                  .where((t) => t.lastMessage.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
        );
  }

  @override
  Future<ChatThread> openThread({
    required String studentId,
    required String studentAlias,
    required String counselorId,
    required String counselorName,
  }) async {
    final id = ChatThread.idFor(studentId, counselorId);
    final ref = _chats.doc(id);
    final snap = await ref.get();
    if (snap.exists) return ChatThread.fromMap(id, snap.data()!);

    final thread = ChatThread(
      id: id,
      studentId: studentId,
      studentAlias: studentAlias,
      counselorId: counselorId,
      counselorName: counselorName,
      updatedAt: DateTime.now(),
    );
    await ref.set(thread.toMap());
    return thread;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    return _messages(threadId)
        .orderBy('sentAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatMessage.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<void> sendMessage(
    String threadId,
    String senderId,
    String text,
  ) async {
    final now = DateTime.now();
    final message = ChatMessage(
      id: '',
      senderId: senderId,
      text: text,
      sentAt: now,
    );
    final batch = _db.batch();
    batch.set(_messages(threadId).doc(), message.toMap());
    batch.update(_chats.doc(threadId), {'lastMessage': text, 'updatedAt': now});
    await batch.commit();
  }

  @override
  Future<void> editMessage(
    String threadId,
    String messageId,
    String text,
  ) async {
    await _messages(threadId)
        .doc(messageId)
        .update({'text': text, 'editedAt': DateTime.now()});
    await _refreshPreview(threadId);
  }

  @override
  Future<void> deleteMessage(String threadId, String messageId) async {
    await _messages(threadId).doc(messageId).delete();
    await _refreshPreview(threadId);
  }

  /// Keeps the thread's preview text in sync with its latest message.
  Future<void> _refreshPreview(String threadId) async {
    final latest = await _messages(threadId)
        .orderBy('sentAt', descending: true)
        .limit(1)
        .get();
    final text = latest.docs.isEmpty
        ? ''
        : latest.docs.first.data()['text'] as String;
    await _chats.doc(threadId).update({'lastMessage': text});
  }

  @override
  Future<void> deleteThread(String threadId) async {
    final messages = await _messages(threadId).get();
    // Firestore batches are limited to 500 writes.
    const chunk = 450;
    for (var i = 0; i < messages.docs.length; i += chunk) {
      final batch = _db.batch();
      for (final doc in messages.docs.skip(i).take(chunk)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _chats.doc(threadId).delete();
  }
}
