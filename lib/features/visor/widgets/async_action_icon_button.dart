import 'package:flutter/material.dart';

/// Keeps the complete async flow single-flight, including its preparation.
class AsyncActionIconButton extends StatefulWidget {
  const AsyncActionIconButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.busyLabel,
    this.icon = Icons.ios_share_rounded,
  });

  final Future<void> Function() onPressed;
  final String tooltip;
  final String busyLabel;
  final IconData icon;

  @override
  State<AsyncActionIconButton> createState() => _AsyncActionIconButtonState();
}

class _AsyncActionIconButtonState extends State<AsyncActionIconButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: _busy ? widget.busyLabel : widget.tooltip,
        onPressed: _busy ? null : _run,
        icon: _busy
            ? Semantics(
                label: widget.busyLabel,
                liveRegion: true,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(widget.icon),
      );
}
