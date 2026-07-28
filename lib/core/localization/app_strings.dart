import 'package:flutter/widgets.dart';

class AppStrings {
  final bool isEnglish;

  const AppStrings._(this.isEnglish);

  factory AppStrings.of(BuildContext context) =>
      AppStrings._(Localizations.localeOf(context).languageCode == 'en');

  String t(String es, String en) => isEnglish ? en : es;
}
