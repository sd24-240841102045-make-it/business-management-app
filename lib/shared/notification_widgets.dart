import 'package:flutter/material.dart';
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

    _service.notificationsStream.listen((_) {
      final newCount = _service.unreadCount;
      if (newCount > _lastCount) {
        _shakeController.forward(from: 0).then((_) => _shakeController.reverse());
      }
      _lastCount = newCount;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _togglePanel() {
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

    Overlay.of(context).insert(_overlayEntry!);
    _service.markAllRead();
    setState(() {});
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
            onPressed: _togglePanel,
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEE0979)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  unread > 99 ? '99+' : unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Notification Panel Overlay
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
  final _service = NotificationService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    _service.notificationsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = 360.0;
    double left = widget.anchorOffset.dx + widget.anchorSize.width / 2 - panelWidth / 2;
    left = left.clamp(8.0, screenWidth - panelWidth - 8);

    final notifications = _service.notifications;

    return Stack(
      children: [
        // Dimmed background tap to close
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: widget.anchorOffset.dy + widget.anchorSize.height + 4,
          left: left,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: panelWidth,
                  constraints: const BoxConstraints(maxHeight: 520),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kPremiumBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_rounded,
                              color: kPremiumGold,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (notifications.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  _service.clearAll();
                                  setState(() {});
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: Text(
                                  'Clear all',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: kPremiumMuted,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: kPremiumMuted,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF2A2A4A)),
                      // Body
                      if (notifications.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 42,
                                color: kPremiumMuted.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No notifications yet',
                                style: TextStyle(
                                  color: kPremiumMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Color(0xFF2A2A4A),
                            ),
                            itemBuilder: (ctx, i) {
                              final n = notifications[i];
                              return _NotificationTile(
                                notification: n,
                                onDismiss: () {
                                  _service.notifications; // refresh
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        ),
                    ],
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
// Single Notification Tile
// ─────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: n.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: n.color.withValues(alpha: 0.3)),
            ),
            child: Icon(n.icon, color: n.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  n.body,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: kPremiumMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _timeAgo(n.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: kPremiumMuted.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (!n.isRead)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 4, left: 4),
              decoration: BoxDecoration(
                color: kPremiumGold,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();

    Future.delayed(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: n.color.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: n.color.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: n.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: n.color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(n.icon, color: n.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        style: TextStyle(fontSize: 11.5, color: kPremiumMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
  final List<OverlayEntry> _toasts = [];

  void showToast(AppNotification notification) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        right: 16,
        bottom: 80 + _toasts.indexOf(entry) * 80.0,
        child: NotificationToast(
          notification: notification,
          onDismiss: () {
            entry.remove();
            _toasts.remove(entry);
          },
        ),
      ),
    );
    _toasts.add(entry);
    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
