import 'package:flutter/material.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';

class ScoreTitleButton extends StatelessWidget {
  final String title;
  const ScoreTitleButton({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Tooltip(
        message: title,
        child: InkWell(
          onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                    scrollable: true,
                    title: Text(strings.t('Nombre del canto', 'Song title')),
                    content: SelectableText(title),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(strings.t('Cerrar', 'Close')))
                    ],
                  )),
          child: ConstrainedBox(
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
          ),
        ));
  }
}
