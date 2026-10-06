import 'package:flutter/material.dart';

import '../../../booking/presentation/widgets/booking_ui.dart';
import '../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isMine ? scheme.primary : scheme.surfaceContainerLowest;
    final foreground = isMine ? scheme.onPrimary : scheme.onSurface;
    final time = BookingFormat.time(message.sentAt);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Semantics(
          label:
              '${isMine ? 'You' : 'They'} said: ${message.text}. '
              'Sent $time${message.isEdited ? ', edited' : ''}',
          hint: isMine && onLongPress != null
              ? 'Long press to edit or delete'
              : null,
          excludeSemantics: true,
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(
                      message.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.isEdited ? 'edited · $time' : time,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
