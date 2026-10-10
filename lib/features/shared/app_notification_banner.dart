import 'dart:async';
import 'package:flutter/material.dart';

/// A single transient notification above the page, outside player controls.
abstract final class AppNotificationBanner {
  static VoidCallback? _hideCurrent;

  static void show(BuildContext context, String message,
      {IconData icon = Icons.headphones_rounded}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _hideCurrent?.call();
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    late OverlayEntry entry;
    var removed = false;
    void hide() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
      if (identical(_hideCurrent, hide)) _hideCurrent = null;
    }

    entry = OverlayEntry(
        builder: (context) => Positioned(
              top: media.padding.top + 12,
              left: 16,
              right: 16,
              child: Theme(
                  data: theme,
                  child: _Notification(
                      message: message,
                      icon: icon,
                      reduceMotion: media.disableAnimations,
                      onDismiss: hide)),
            ));
    _hideCurrent = hide;
    overlay.insert(entry);
  }
}

class _Notification extends StatefulWidget {
  final String message;
  final IconData icon;
  final bool reduceMotion;
  final VoidCallback onDismiss;
  const _Notification(
      {required this.message,
      required this.icon,
      required this.reduceMotion,
      required this.onDismiss});
  @override
  State<_Notification> createState() => _NotificationState();
}

class _NotificationState extends State<_Notification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
        vsync: this,
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220))
      ..forward();
    _timer = Timer(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _animation.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
        opacity: _animation,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, -.25), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: _animation, curve: Curves.easeOutCubic)),
          child: Semantics(
              liveRegion: true,
              child: Material(
                key: const ValueKey('app-notification-banner'),
                color: scheme.surface,
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Icon(widget.icon, color: scheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(widget.message,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w500))),
                        ]))),
              )),
        ));
  }
}
