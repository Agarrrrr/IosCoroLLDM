import 'package:flutter/material.dart';

class ScoreTitleButton extends StatelessWidget {
  final String title;
  const ScoreTitleButton({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold))),
    );
  }
}
