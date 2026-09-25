import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/models/chat_models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool isDesktop;
  final bool showSenderHeader;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isDesktop = false,
    this.showSenderHeader = false,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline_rounded, size: 13, color: kPremiumDanger),
              SizedBox(width: 3),
              Text(
                'Retry',
                style: TextStyle(fontSize: 10, color: kPremiumDanger, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
    }
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
                ? Border.all(color: kPremiumBlue.withOpacity(0.35))
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
              Text(
                message.isDeleted ? 'This message was deleted' : message.message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                  color: message.isDeleted ? Colors.white60 : Colors.white,
                ),
              ),
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
