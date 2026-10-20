import 'package:flutter/widgets.dart';

class AppStrings {
  final bool isEnglish;

  const AppStrings._(this.isEnglish);

  factory AppStrings.of(BuildContext context) =>
      AppStrings._(Localizations.localeOf(context).languageCode == 'en');

  String t(String es, String en) => isEnglish ? en : es;

  String get appTitle => isEnglish ? 'TLOTW Choir' : 'Coro LLDM';

  String voiceLabel(String voiceKey) {
    final lower = voiceKey.trim().toLowerCase();
    if (lower == 'ensamble' || lower == 'ensemble') {
      return isEnglish ? 'Ensemble' : 'Ensamble';
    }
    if (lower == 'soprano') {
      return 'Soprano';
    }
    if (lower == 'contralto' || lower == 'alto') {
      return isEnglish ? 'Alto' : 'Contralto';
    }
    if (lower == 'tenor') {
      return 'Tenor';
    }
    if (lower == 'bajo' || lower == 'bass') {
      return isEnglish ? 'Bass' : 'Bajo';
    }
    if (lower == 'solista' || lower == 'soloist' || lower == 'solo') {
      return isEnglish ? 'Soloist' : 'Solista';
    }
    if (lower == 'barítono' || lower == 'baritono' || lower == 'baritone') {
      return isEnglish ? 'Baritone' : 'Barítono';
    }
    if (lower.startsWith('soprano ')) {
      return voiceKey;
    }
    if (lower.startsWith('alto ') || lower.startsWith('contralto ')) {
      final numPart = voiceKey.split(' ').last;
      return isEnglish ? 'Alto $numPart' : 'Contralto $numPart';
    }
    if (lower.startsWith('tenor ')) {
      return voiceKey;
    }
    if (lower.startsWith('bajo ') || lower.startsWith('bass ')) {
      final numPart = voiceKey.split(' ').last;
      return isEnglish ? 'Bass $numPart' : 'Bajo $numPart';
    }
    if (lower.startsWith('voz ') || lower.startsWith('voice ')) {
      final numPart = voiceKey.split(' ').last;
      return isEnglish ? 'Voice $numPart' : 'Voz $numPart';
    }
    return voiceKey;
  }
}
