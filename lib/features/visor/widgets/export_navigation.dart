import 'package:flutter/material.dart';

/// Wait for removal from the overlay, not just Navigator.pop's result.
Future<T?> showSettledExportSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isScrollControlled = false,
}) async {
  TransitionRoute<dynamic>? route;
  final result = await showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    shape: shape,
    isScrollControlled: isScrollControlled,
    builder: (context) {
      route = ModalRoute.of(context);
      return builder(context);
    },
  );
  await route?.completed;
  return result;
}

/// Owns exactly one route; failure must never pop the score or another modal.
class ExportProgressDialog {
  ExportProgressDialog(BuildContext context, WidgetBuilder builder)
      : _navigator = Navigator.of(context, rootNavigator: true),
        _route = DialogRoute<void>(
          context: context,
          barrierDismissible: false,
          builder: builder,
        ) {
    _navigator.push(_route);
  }

  final NavigatorState _navigator;
  final DialogRoute<void> _route;

  Future<void> close() async {
    if (_route.isActive) {
      if (_route.isCurrent) {
        _navigator.pop();
      } else {
        _navigator.removeRoute(_route);
      }
    }
    await _route.completed;
  }
}
