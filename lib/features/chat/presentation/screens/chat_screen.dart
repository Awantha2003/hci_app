import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../booking/presentation/widgets/booking_ui.dart';
import '../../models/chat_message.dart';
import '../../models/chat_thread.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

/// Interface: Anonymous Chat.
///
/// CRUD: Create (send), Read (live messages), Update (edit own message),
/// Delete (own message).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.thread});

  static const routeName = '/chat/thread';

  final ChatThread thread;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final Stream<List<ChatMessage>> _messages;
  ChatMessage? _editing;
  bool _sending = false;
  bool _showHelpline = true;

  @override
  void initState() {
    super.initState();
    _messages = context.read<ChatProvider>().messages(widget.thread.id);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending && ChatProvider.validate(_controller.text) == null;

  Future<void> _send() async {
    if (!_canSend) return;
    final chat = context.read<ChatProvider>();
    final text = _controller.text;
    final editing = _editing;
    setState(() => _sending = true);
    try {
      if (editing != null) {
        await chat.edit(widget.thread.id, editing, text);
      } else {
        await chat.send(widget.thread.id, text);
      }
      if (!mounted) return;
      _controller.clear();
      setState(() => _editing = null);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEdit(ChatMessage message) {
    setState(() => _editing = message);
    _controller
      ..text = message.text
      ..selection = TextSelection.collapsed(offset: message.text.length);
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _controller.clear();
  }

  Future<void> _showOptions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit message'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy text'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete message',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    switch (action) {
      case 'edit':
        _startEdit(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) showMessage(context, 'Copied to clipboard.');
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'Delete message?',
          message: 'It will be removed for both of you.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !mounted) return;
        try {
          await context.read<ChatProvider>().deleteMessage(
            widget.thread.id,
            message,
          );
          if (_editing?.id == message.id) _cancelEdit();
        } catch (e) {
          if (mounted) showMessage(context, friendlyError(e), error: true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatProvider>();
    final userId = chat.user.id;
    final isCounselor = chat.user.isCounselor;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.secondary,
              child: Icon(
                isCounselor ? Icons.visibility_off_outlined : Icons.person,
                size: 20,
                color: scheme.onSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.thread.titleFor(userId),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Anonymous & confidential',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!isCounselor && _showHelpline)
            MaterialBanner(
              backgroundColor: scheme.tertiaryContainer,
              leading: Icon(
                Icons.support_agent,
                color: scheme.onTertiaryContainer,
              ),
              content: Text(
                'In crisis or need help right now? Call the National Mental '
                'Health Helpline 1926 (24/7, free).',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _showHelpline = false),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyMessage(
                    icon: Icons.cloud_off,
                    title: 'Could not load messages',
                    message: 'Check your connection and try again.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return EmptyMessage(
                    icon: Icons.forum_outlined,
                    title: 'Start the conversation',
                    message: isCounselor
                        ? 'Say hello to ${widget.thread.studentAlias}.'
                        : 'Your counselor will see you as '
                              '"${widget.thread.studentAlias}". Share as much '
                              'or as little as you like.',
                  );
                }
                return _MessageList(
                  messages: messages,
                  userId: userId,
                  onLongPress: _showOptions,
                );
              },
            ),
          ),
          if (_editing != null)
            Container(
              color: scheme.surfaceContainerHighest,
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Editing message')),
                  IconButton(
                    tooltip: 'Cancel editing',
                    onPressed: _cancelEdit,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: ChatMessage.maxLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        counterText: '',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: _editing != null ? 'Save edit' : 'Send',
                    onPressed: _canSend ? _send : null,
                    icon: Icon(_editing != null ? Icons.check : Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.userId,
    required this.onLongPress,
  });

  final List<ChatMessage> messages;
  final String userId;
  final ValueChanged<ChatMessage> onLongPress;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    // Reversed so the newest message sits at the bottom and the list starts
    // scrolled to it.
    final reversed = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final m = reversed[i];
        final older = i + 1 < reversed.length ? reversed[i + 1] : null;
        final showDate = older == null || !_sameDay(older.sentAt, m.sentAt);
        final mine = m.isMine(userId);
        return Column(
          children: [
            if (showDate) _DateDivider(date: m.sentAt),
            MessageBubble(
              key: ValueKey(m.id),
              message: m,
              isMine: mine,
              onLongPress: mine ? () => onLongPress(m) : null,
            ),
          ],
        );
      },
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isToday ? 'Today' : BookingFormat.day(date),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}
