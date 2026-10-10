import 'package:flutter/material.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';

/// The drag region is separate from sliders and the scrolling voice list.
class PlayerDismissHandle extends StatefulWidget {
  final VoidCallback onClose;
  const PlayerDismissHandle({super.key, required this.onClose});

  @override
  State<PlayerDismissHandle> createState() => _PlayerDismissHandleState();
}

class _PlayerDismissHandleState extends State<PlayerDismissHandle> {
  double _distance = 0;

  @override
  Widget build(BuildContext context) {
    final label =
        AppStrings.of(context).t('Cerrar reproductor', 'Close player');
    return Row(children: [
      Expanded(
        child: Semantics(
          label: label,
          hint: AppStrings.of(context).t('Desliza hacia abajo', 'Swipe down'),
          button: true,
          onTap: widget.onClose,
          child: GestureDetector(
            key: const ValueKey('player-dismiss-drag'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => _distance = 0,
            onVerticalDragUpdate: (details) =>
                _distance = (_distance + details.delta.dy).clamp(0, 1000),
            onVerticalDragCancel: () => _distance = 0,
            onVerticalDragEnd: (details) {
              final close = _distance >= 48 ||
                  (_distance >= 12 && (details.primaryVelocity ?? 0) >= 700);
              _distance = 0;
              if (close) widget.onClose();
            },
            child: Listener(
                onPointerCancel: (_) => _distance = 0,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                )),
          ),
        ),
      ),
      IconButton(
        tooltip: label,
        onPressed: widget.onClose,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    ]);
  }
}
