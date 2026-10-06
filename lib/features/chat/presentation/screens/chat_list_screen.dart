import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../booking/models/counselor.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../booking/presentation/widgets/booking_ui.dart';
import '../../../booking/presentation/widgets/counselor_card.dart';
import '../../models/chat_thread.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

/// Interface: Chat inbox.
///
/// CRUD: Read conversations (live), Create (start a chat with a counselor),
/// Delete (swipe to delete a conversation).
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  static const routeName = '/chat';

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final isCounselor = chat.user.isCounselor;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: isCounselor
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _startNewChat(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New chat'),
            ),
      body: Column(
        children: [
          if (!isCounselor)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chats are anonymous. Counselors see you as '
                      '"${chat.user.alias}".',
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildList(context, chat)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, ChatProvider chat) {
    if (chat.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chat.error != null) {
      return EmptyMessage(
        icon: Icons.cloud_off,
        title: 'Could not load messages',
        message: chat.error!,
      );
    }
    if (chat.threads.isEmpty) {
      return EmptyMessage(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        message: chat.user.isCounselor
            ? 'Messages from students will appear here.'
            : 'Start an anonymous chat with a counselor whenever you need '
                  'to talk.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: chat.threads.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final thread = chat.threads[i];
        return Dismissible(
          key: ValueKey(thread.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          confirmDismiss: (_) => confirmAction(
            context,
            title: 'Delete conversation?',
            message:
                'All messages in this chat will be permanently deleted '
                'for both of you.',
            confirmLabel: 'Delete',
            destructive: true,
          ),
          onDismissed: (_) => _delete(context, thread),
          child: _ThreadTile(thread: thread, userId: chat.user.id),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, ChatThread thread) async {
    try {
      await context.read<ChatProvider>().deleteThread(thread.id);
      if (context.mounted) showMessage(context, 'Conversation deleted.');
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _startNewChat(BuildContext context) async {
    final booking = context.read<BookingProvider>();
    final chat = context.read<ChatProvider>();
    booking.loadCounselors();

    final counselor = await showModalBottomSheet<Counselor>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CounselorPicker(),
    );
    if (counselor == null || !context.mounted) return;

    try {
      final thread = await chat.openWithCounselor(counselor);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(thread: thread)),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.userId});

  final ChatThread thread;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iAmCounselor = userId == thread.counselorId;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        child: Icon(
          iAmCounselor ? Icons.visibility_off_outlined : Icons.person,
        ),
      ),
      title: Text(thread.titleFor(userId)),
      subtitle: Text(
        thread.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        BookingFormat.relative(thread.updatedAt),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(thread: thread)),
      ),
    );
  }
}

class _CounselorPicker extends StatelessWidget {
  const _CounselorPicker();

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Column(
          children: [
            Text(
              'Chat with a counselor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: booking.loadingCounselors && booking.counselors.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: booking.counselors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = booking.counselors[i];
                        return CounselorCard(
                          counselor: c,
                          onTap: () => Navigator.pop(context, c),
                          trailing: const Icon(Icons.chevron_right),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
