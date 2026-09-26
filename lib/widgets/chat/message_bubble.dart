import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/models/chat_models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool isDesktop;
  final bool showSenderHeader;
  final String? searchQuery;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isDesktop = false,
    this.showSenderHeader = false,
    this.searchQuery,
    this.onRetry,
    this.onEdit,
    this.onDelete,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPremiumSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: kPremiumGold),
                title: const Text('Copy Message Text', style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (message.deliveryStatus == MessageDeliveryStatus.error && onRetry != null) ...[
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded, color: kPremiumGold),
                  title: const Text('Retry Sending', style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Attempt to re-send this failed message', style: TextStyle(color: kPremiumMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRetry?.call();
                  },
                ),
              ],
              if (isMe && !message.isDeleted && onEdit != null) ...[
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded, color: kPremiumBlue),
                  title: const Text('Edit Message', style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit?.call();
                  },
                ),
              ],
              if ((isMe || onDelete != null) && !message.isDeleted) ...[
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: kPremiumDanger),
                  title: const Text('Delete Message', style: TextStyle(color: kPremiumDanger, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryIcon() {
    switch (message.deliveryStatus) {
      case MessageDeliveryStatus.sending:
        return const SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.check_rounded, size: 13, color: Colors.white70);
      case MessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF64D2FF));
      case MessageDeliveryStatus.error:
        return GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kPremiumDanger.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kPremiumDanger.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 12, color: kPremiumDanger),
                SizedBox(width: 4),
                Text(
                  'Failed • Tap to Retry',
                  style: TextStyle(fontSize: 10, color: kPremiumDanger, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildMessageText() {
    if (message.isDeleted) {
      return const Text(
        'This message was deleted',
        style: TextStyle(
          fontSize: 14,
          height: 1.35,
          fontStyle: FontStyle.italic,
          color: Colors.white60,
        ),
      );
    }

    final query = searchQuery?.trim();
    if (query == null || query.isEmpty) {
      return Text(
        message.message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.35,
          color: Colors.white,
        ),
      );
    }

    final text = message.message;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.35,
          color: Colors.white,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: kPremiumGold.withOpacity(0.35),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kPremiumGold.withOpacity(0.8), width: 1),
            ),
            child: Text(
              text.substring(index, index + query.length),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          height: 1.35,
          color: Colors.white,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * (isDesktop ? 0.6 : 0.78);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(context),
        onSecondaryTap: () => _showMessageActions(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          decoration: BoxDecoration(
            gradient: isMe ? kGradBlue : null,
            color: isMe ? null : kPremiumCard,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
            ),
            border: isMe
                ? (message.deliveryStatus == MessageDeliveryStatus.error
                    ? Border.all(color: kPremiumDanger.withOpacity(0.85), width: 1.2)
                    : Border.all(color: kPremiumBlue.withOpacity(0.35)))
                : Border.all(color: kPremiumBorder),
            boxShadow: [
              BoxShadow(
                color: (isMe ? kPremiumBlue : Colors.black).withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && showSenderHeader) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kPremiumGold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        message.senderRole.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: kPremiumMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],
              _buildMessageText(),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : kPremiumMuted,
                    ),
                  ),
                  if (message.updatedAt != null && !message.isDeleted) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(edited)',
                      style: TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: isMe ? Colors.white60 : kPremiumMuted,
                      ),
                    ),
                  ],
                  if (isMe) ...[
                    const SizedBox(width: 5),
                    _buildDeliveryIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
