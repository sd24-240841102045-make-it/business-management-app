import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:business_managment_app/services/notification_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

// ─────────────────────────────────────────────
// Notification Bell Icon (AppBar Action)
// ─────────────────────────────────────────────
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  final _service = NotificationService();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int _lastCount = 0;
  OverlayEntry? _overlayEntry;
  StreamSubscription<List<AppNotification>>? _sub;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _sub = _service.notificationsStream.listen((_) {
      if (!mounted) return;
      final newCount = _service.unreadCount;
      if (newCount > _lastCount) {
        if (mounted && !_shakeController.isAnimating) {
          _shakeController.forward(from: 0).then((_) {
            if (mounted) _shakeController.reverse();
          });
        }
      }
      _lastCount = newCount;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _shakeController.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _openNotifications() {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      // Mobile phone: Show modal bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _MobileNotificationSheet(),
      );
    } else {
      // Desktop / Tablet: Show anchored overlay panel
      _toggleOverlayPanel();
    }
  }

  void _toggleOverlayPanel() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _NotificationPanel(
        anchorOffset: offset,
        anchorSize: size,
        onClose: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );

    final overlay = Overlay.maybeOf(context);
    if (overlay != null) {
      overlay.insert(_overlayEntry!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _service.unreadCount;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (ctx, child) => Transform.rotate(
        angle: _shakeAnimation.value,
        child: child,
      ),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: _openNotifications,
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.55),
                      blurRadius: 7,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    unread > 99 ? '99+' : unread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mobile Notification Sheet
// ─────────────────────────────────────────────
class _MobileNotificationSheet extends StatelessWidget {
  const _MobileNotificationSheet();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Container(
      height: height * 0.82,
      decoration: BoxDecoration(
        color: const Color(0xFF131325),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: kPremiumBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Drag handle bar
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: NotificationCenterView(
              onClose: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Desktop Notification Panel Overlay
// ─────────────────────────────────────────────
class _NotificationPanel extends StatefulWidget {
  final Offset anchorOffset;
  final Size anchorSize;
  final VoidCallback onClose;

  const _NotificationPanel({
    required this.anchorOffset,
    required this.anchorSize,
    required this.onClose,
  });

  @override
  State<_NotificationPanel> createState() => __NotificationPanelState();
}

class __NotificationPanelState extends State<_NotificationPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = 380.0;
    double left = widget.anchorOffset.dx + widget.anchorSize.width / 2 - panelWidth / 2;
    left = left.clamp(12.0, screenWidth - panelWidth - 12);

    return Stack(
      children: [
        // Transparent tap dismiss background
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: widget.anchorOffset.dy + widget.anchorSize.height + 6,
          left: left,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: panelWidth,
                  height: 560,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131325),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kPremiumBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: NotificationCenterView(onClose: widget.onClose),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Reusable Notification Center View
// ─────────────────────────────────────────────
class NotificationCenterView extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationCenterView({super.key, this.onClose});

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  final _service = NotificationService();
  String _selectedFilter = 'all'; // all, unread, invitations, tasks, messages

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _service.notificationsStream,
      initialData: _service.notifications,
      builder: (context, snapshot) {
        final allNotifs = snapshot.data ?? [];
        final showInvitations = allNotifs.any((n) => n.category == 'invitations');
        final showTasks = allNotifs.any((n) => n.category == 'tasks' || n.category == 'general');
        final showBilling = allNotifs.any((n) => n.category == 'billing');
        final showMessages = allNotifs.any((n) => n.category == 'messages');
        final showTeam = allNotifs.any((n) => n.category == 'team');

        final filtered = allNotifs.where((n) {
          if (_selectedFilter == 'unread') return !n.isRead;
          if (_selectedFilter == 'invitations') return n.category == 'invitations';
          if (_selectedFilter == 'tasks') return n.category == 'tasks' || n.category == 'general';
          if (_selectedFilter == 'billing') return n.category == 'billing';
          if (_selectedFilter == 'messages') return n.category == 'messages';
          if (_selectedFilter == 'team') return n.category == 'team';
          return true;
        }).toList();

        final unreadCount = _service.unreadCount;

        return Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: kPremiumGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton.icon(
                      icon: const Icon(Icons.done_all_rounded, size: 15, color: kPremiumGold),
                      label: const Text(
                        'Mark all read',
                        style: TextStyle(fontSize: 12, color: kPremiumGold, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _service.markAllRead(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (allNotifs.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      color: kPremiumMuted,
                      tooltip: 'Clear all',
                      onPressed: () {
                        _service.clearAll();
                      },
                    ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: kPremiumMuted,
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),

            // ── Filter Chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${allNotifs.length})'),
                  _buildFilterChip('unread', 'Unread ($unreadCount)'),
                  if (showTasks) _buildFilterChip('tasks', 'Work & Tasks 📋'),
                  if (showBilling) _buildFilterChip('billing', 'Billing 🧾'),
                  if (showMessages) _buildFilterChip('messages', 'Messages 💬'),
                  if (showInvitations) _buildFilterChip('invitations', 'Invitations 📩'),
                  if (showTeam) _buildFilterChip('team', 'Team 👥'),
                ],
              ),
            ),

            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFF22223B)),

            // ── Notifications List or Empty State ──
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final notif = filtered[i];
                        return _NotificationCard(
                          notification: notif,
                          onMarkRead: () => _service.markRead(notif.id),
                          onDelete: () => _service.deleteNotification(notif.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = key),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? kPremiumGold : const Color(0xFF1E1E34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? kPremiumGold : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedFilter == 'unread'
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_off_outlined,
                size: 40,
                color: kPremiumMuted.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFilter == 'unread'
                  ? 'All caught up! No unread notifications'
                  : 'No notifications in this filter',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Real-time alerts for project works, billing & messages will appear here.',
              style: TextStyle(
                color: kPremiumMuted.withOpacity(0.6),
                fontSize: 11.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Notification Card with Rich Details & Quick Copy
// ─────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final payload = n.payload ?? {};
    final inviteCode = payload['code']?.toString() ?? payload['token']?.toString() ?? '';

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: () {
          if (!n.isRead) onMarkRead();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: n.isRead ? const Color(0xFF18182E) : const Color(0xFF22223D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: n.isRead
                  ? Colors.white.withOpacity(0.06)
                  : n.color.withOpacity(0.35),
            ),
            boxShadow: n.isRead
                ? null
                : [
                    BoxShadow(
                      color: n.color.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: n.color.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: n.color.withOpacity(0.3)),
                    ),
                    child: Icon(n.icon, color: n.color, size: 19),
                  ),
                  const SizedBox(width: 10),

                  // Title & Meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: n.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                n.categoryLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: n.color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              n.timeAgo,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: kPremiumMuted.withOpacity(0.65),
                              ),
                            ),
                            if (!n.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: kPremiumGold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              // Body text
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  n.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: n.isRead ? kPremiumMuted : Colors.white.withOpacity(0.85),
                    height: 1.35,
                  ),
                ),
              ),

              // Interactive Action: Access Code Copy Banner if available
              if (inviteCode.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key_rounded, size: 14, color: kPremiumGold),
                        const SizedBox(width: 6),
                        Text(
                          'Code: $inviteCode',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kPremiumGold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: inviteCode));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Access code "$inviteCode" copied!'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF2ECC71),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kPremiumGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'COPY',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Toast Notification Widget
// ─────────────────────────────────────────────
class NotificationToast extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const NotificationToast({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<NotificationToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();

    _dismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (!mounted) return;
    try {
      await _ctrl.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final payload = n.payload ?? {};
    final inviteCode = payload['code']?.toString() ?? payload['token']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            onTap: _dismiss,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF151528),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: n.color.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: n.color.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: n.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: n.color.withOpacity(0.35)),
                  ),
                  child: Icon(n.icon, color: n.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (inviteCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Code: $inviteCode',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kPremiumGold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: inviteCode));
                                HapticFeedback.selectionClick();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Code $inviteCode copied!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: kPremiumGold,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'COPY',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: kPremiumMuted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _dismiss,
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

// ─────────────────────────────────────────────
// Toast Manager — add this to MaterialApp builder
// ─────────────────────────────────────────────
class ToastManager extends StatefulWidget {
  final Widget child;
  const ToastManager({super.key, required this.child});

  @override
  State<ToastManager> createState() => ToastManagerState();

  static ToastManagerState? of(BuildContext context) =>
      context.findAncestorStateOfType<ToastManagerState>();
}

class ToastManagerState extends State<ToastManager> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  final List<OverlayEntry> _toasts = [];

  void showToast(AppNotification notification) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final toastWidth = math.min(420.0, screenWidth - 32);
        final topPadding = MediaQuery.of(ctx).padding.top;
        final idx = _toasts.indexOf(entry);

        return Positioned(
          top: topPadding + 10 + (idx >= 0 ? idx * 75.0 : 0.0),
          left: (screenWidth - toastWidth) / 2,
          width: toastWidth,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: toastWidth,
              child: NotificationToast(
                notification: notification,
                onDismiss: () {
                  if (entry.mounted) {
                    entry.remove();
                  }
                  _toasts.remove(entry);
                },
              ),
            ),
          ),
        );
      },
    );

    final overlay = _overlayKey.currentState ?? Overlay.maybeOf(context);
    if (overlay != null) {
      _toasts.add(entry);
      overlay.insert(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: _overlayKey,
      initialEntries: [
        OverlayEntry(builder: (ctx) => widget.child),
      ],
    );
  }
}
