import 'package:flutter_test/flutter_test.dart';
import 'package:mindcheck/features/chat/data/in_memory_chat_repository.dart';
import 'package:mindcheck/features/chat/models/chat_thread.dart';
import 'package:mindcheck/features/chat/presentation/providers/chat_provider.dart';

import '../booking/test_helpers.dart';

/// Functional tests for the anonymous chat feature.
void main() {
  late InMemoryChatRepository repo;
  late ChatProvider studentChat;
  late ChatProvider counselorChat;
  late ChatThread thread;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    repo = InMemoryChatRepository();
    studentChat = ChatProvider(repository: repo, user: student);
    counselorChat = ChatProvider(repository: repo, user: counselorUser);
    thread = await studentChat.openWithCounselor(counselor);
    await settle();
  });

  tearDown(() {
    studentChat.dispose();
    counselorChat.dispose();
  });

  test('TC-C01 a sent message reaches the counselor (Create + Read)',
      () async {
    await studentChat.send(thread.id, '  Hello there  ');
    await settle();

    final messages = await counselorChat.messages(thread.id).first;
    expect(messages.single.text, 'Hello there');
    expect(messages.single.senderId, student.id);
    expect(counselorChat.threads.single.lastMessage, 'Hello there');
  });

  test('TC-C02 empty or whitespace messages are rejected', () {
    expect(ChatProvider.validate('   '), isNotNull);
    expect(() => studentChat.send(thread.id, ''), throwsArgumentError);
  });

  test('TC-C03 messages over 1000 characters are rejected', () {
    expect(ChatProvider.validate('x' * 1001), isNotNull);
    expect(ChatProvider.validate('x' * 1000), isNull);
  });

  test('TC-C04 editing my message updates it and marks it edited (Update)',
      () async {
    await studentChat.send(thread.id, 'Helo');
    final sent = (await studentChat.messages(thread.id).first).single;
    await studentChat.edit(thread.id, sent, 'Hello');

    final updated = (await studentChat.messages(thread.id).first).single;
    expect(updated.text, 'Hello');
    expect(updated.isEdited, isTrue);
  });

  test('TC-C05 deleting my message removes it and updates the preview (Delete)',
      () async {
    await studentChat.send(thread.id, 'First');
    await studentChat.send(thread.id, 'Oops');
    final oops = (await studentChat.messages(thread.id).first).last;
    await studentChat.deleteMessage(thread.id, oops);
    await settle();

    final messages = await studentChat.messages(thread.id).first;
    expect(messages.map((m) => m.text), ['First']);
    expect(studentChat.threads.single.lastMessage, 'First');
  });

  test('TC-C06 nobody can edit or delete someone else\'s message', () async {
    await studentChat.send(thread.id, 'Mine');
    final msg = (await counselorChat.messages(thread.id).first).single;
    expect(() => counselorChat.edit(thread.id, msg, 'x'), throwsStateError);
    expect(() => counselorChat.deleteMessage(thread.id, msg), throwsStateError);
  });

  test('TC-C07 deleting a conversation removes it for both sides', () async {
    await studentChat.send(thread.id, 'Hi');
    await settle();
    await studentChat.deleteThread(thread.id);
    await settle();

    expect(studentChat.threads, isEmpty);
    expect(counselorChat.threads, isEmpty);
    expect(await repo.watchMessages(thread.id).first, isEmpty);
  });

  test('TC-C08 the counselor sees the alias, the student sees the name',
      () async {
    expect(thread.titleFor(counselorUser.id), student.alias);
    expect(thread.titleFor(student.id), counselor.name);
  });

  test('TC-C09 reopening a chat continues the same conversation', () async {
    final again = await studentChat.openWithCounselor(counselor);
    expect(again.id, thread.id);
  });
}
