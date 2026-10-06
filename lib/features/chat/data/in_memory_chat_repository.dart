import 'dart:async';

import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import 'chat_repository.dart';

/// A [ChatRepository] that keeps everything in memory, for tests and for
/// running the app before Firebase is configured.
class InMemoryChatRepository implements ChatRepository {
  InMemoryChatRepository({
    List<ChatThread> threads = const [],
    Map<String, List<ChatMessage>> messages = const {},
  }) : _threads = {for (final t in threads) t.id: t},
       _messages = {
         for (final e in messages.entries) e.key: [...e.value],
       };

  final Map<String, ChatThread> _threads;
  final Map<String, List<ChatMessage>> _messages;
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  void _notify() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) {
    return Stream<T>.multi((controller) {
      controller.add(read());
      final sub = _changes.stream.listen((_) => controller.add(read()));
      // Not returning the cancel future lets `.first` complete at once.
      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  List<ChatMessage> _list(String threadId) =>
      _messages.putIfAbsent(threadId, () => []);

  void _refreshPreview(String threadId) {
    final thread = _threads[threadId];
    if (thread == null) return;
    final list = _list(threadId);
    _threads[threadId] = thread.copyWith(
      lastMessage: list.isEmpty ? '' : list.last.text,
    );
  }

  @override
  Stream<List<ChatThread>> watchThreads(String userId) => _watch(
    () =>
        _threads.values
            .where(
              (t) =>
                  t.participants.contains(userId) && t.lastMessage.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<ChatThread> openThread({
    required String studentId,
    required String studentAlias,
    required String counselorId,
    required String counselorName,
  }) async {
    final id = ChatThread.idFor(studentId, counselorId);
    return _threads.putIfAbsent(
      id,
      () => ChatThread(
        id: id,
        studentId: studentId,
        studentAlias: studentAlias,
        counselorId: counselorId,
        counselorName: counselorName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) =>
      _watch(() => List.unmodifiable(_list(threadId)));

  @override
  Future<void> sendMessage(
    String threadId,
    String senderId,
    String text,
  ) async {
    final thread = _threads[threadId];
    if (thread == null) throw StateError('Chat $threadId does not exist.');
    final now = DateTime.now();
    _list(threadId).add(
      ChatMessage(
        id: 'msg_${_nextId++}',
        senderId: senderId,
        text: text,
        sentAt: now,
      ),
    );
    _threads[threadId] = thread.copyWith(lastMessage: text, updatedAt: now);
    _notify();
  }

  @override
  Future<void> editMessage(
    String threadId,
    String messageId,
    String text,
  ) async {
    final list = _list(threadId);
    final i = list.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    list[i] = list[i].copyWith(text: text, editedAt: DateTime.now());
    _refreshPreview(threadId);
    _notify();
  }

  @override
  Future<void> deleteMessage(String threadId, String messageId) async {
    _list(threadId).removeWhere((m) => m.id == messageId);
    _refreshPreview(threadId);
    _notify();
  }

  @override
  Future<void> deleteThread(String threadId) async {
    _threads.remove(threadId);
    _messages.remove(threadId);
    _notify();
  }
}
