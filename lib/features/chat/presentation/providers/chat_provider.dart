import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../booking/models/counselor.dart';
import '../../../booking/models/session_user.dart';
import '../../data/chat_repository.dart';
import '../../models/chat_message.dart';
import '../../models/chat_thread.dart';

/// State for the chat inbox and the conversation screen.
class ChatProvider extends ChangeNotifier {
  ChatProvider({required this.repository, required this.user}) {
    _slowTimer = Timer(const Duration(seconds: 12), () {
      if (!_loading) return;
      _loading = false;
      _error = 'Still connecting… Check your internet connection. If this keeps '
        'happening, the database may not be set up yet.';
      notifyListeners();
    });
    _subscription = repository
        .watchThreads(user.id)
        .listen(
          (threads) {
            _slowTimer?.cancel();
            _threads = threads;
            _loading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object e) {
            _loading = false;
            _error = 'Could not load conversations. $e';
            notifyListeners();
          },
        );
  }

  final ChatRepository repository;
  final SessionUser user;
  late final StreamSubscription<List<ChatThread>> _subscription;
  Timer? _slowTimer;

  List<ChatThread> _threads = const [];
  bool _loading = true;
  String? _error;

  List<ChatThread> get threads => _threads;
  bool get loading => _loading;
  String? get error => _error;

  /// Students start (or continue) a chat with a counselor.
  Future<ChatThread> openWithCounselor(Counselor counselor) {
    return repository.openThread(
      studentId: user.id,
      studentAlias: user.alias,
      counselorId: counselor.id,
      counselorName: counselor.name,
    );
  }

  /// Opens the chat linked to a booking, from either side.
  Future<ChatThread> openForBooking({
    required String studentId,
    required String studentAlias,
    required String counselorId,
    required String counselorName,
  }) {
    return repository.openThread(
      studentId: studentId,
      studentAlias: studentAlias,
      counselorId: counselorId,
      counselorName: counselorName,
    );
  }

  Stream<List<ChatMessage>> messages(String threadId) =>
      repository.watchMessages(threadId);

  /// Returns an error message, or null when the text can be sent.
  static String? validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Message cannot be empty.';
    if (trimmed.length > ChatMessage.maxLength) {
      return 'Messages are limited to ${ChatMessage.maxLength} characters.';
    }
    return null;
  }

  Future<void> send(String threadId, String text) {
    final error = validate(text);
    if (error != null) throw ArgumentError(error);
    return repository.sendMessage(threadId, user.id, text.trim());
  }

  Future<void> edit(String threadId, ChatMessage message, String text) {
    if (!message.isMine(user.id)) {
      throw StateError('You can only edit your own messages.');
    }
    final error = validate(text);
    if (error != null) throw ArgumentError(error);
    return repository.editMessage(threadId, message.id, text.trim());
  }

  Future<void> deleteMessage(String threadId, ChatMessage message) {
    if (!message.isMine(user.id)) {
      throw StateError('You can only delete your own messages.');
    }
    return repository.deleteMessage(threadId, message.id);
  }

  /// Removes the thread from the list straight away (a swiped-away row must
  /// leave the tree immediately), then deletes it from the backend.
  Future<void> deleteThread(String threadId) async {
    final before = _threads;
    _threads = _threads.where((t) => t.id != threadId).toList();
    notifyListeners();
    try {
      await repository.deleteThread(threadId);
    } catch (_) {
      _threads = before;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
