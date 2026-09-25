import 'package:flutter/material.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/models/chat_models.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel? conversation;
  final String title;
  final String subtitle;
  final String? timeText;
  final int unreadCount;
  final bool isSelected;
  final bool isOnline;
  final VoidCallback onTap;
  final String? badgeLabel;
  final Color? badgeColor;

  const ConversationTile({
    super.key,
    this.conversation,
    required this.title,
    required this.subtitle,
    this.timeText,
    this.unreadCount = 0,
    this.isSelected = false,
    this.isOnline = true,
    required this.onTap,
    this.badgeLabel,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      glow: isSelected ? kPremiumGold : null,
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            children: [
              PremiumAvatar(
                label: title,
                size: 44,
                radius: 14,
                style: AvatarStyle.gradient,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: kPremiumSuccess,
                      shape: BoxShape.circle,
                      border: Border.all(color: kPremiumBg, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: kPremiumSuccess.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                          fontSize: 14.5,
                          color: isSelected ? kPremiumGold : kPremiumText,
                        ),
                      ),
                    ),
                    if (timeText != null && timeText!.isNotEmpty)
                      Text(
                        timeText!,
                        style: TextStyle(
                          fontSize: 11,
                          color: unreadCount > 0 ? kPremiumGold : kPremiumMuted,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0 ? kPremiumText : kPremiumMuted,
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPremiumGold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: kPremiumBg,
                          ),
                        ),
                      )
                    else if (badgeLabel != null)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? kPremiumBlue).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (badgeColor ?? kPremiumBlue).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: badgeColor ?? kPremiumBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
