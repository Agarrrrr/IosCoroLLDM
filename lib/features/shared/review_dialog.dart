import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key});

  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.lldm.coro';
  static const String androidMarketUri =
      'market://details?id=com.lldm.coro';
  static const String iOSAppStoreUrl =
      'https://apps.apple.com/app/id6792588543?action=write-review';
  static const String iOSItmsUri =
      'itms-apps://itunes.apple.com/app/id6792588543?action=write-review';
  static const String webUrl = 'https://www.lldmcoro.com';

  static Future<void> launchReviewStore() async {
    AdsService.instance.suspendForExternalAction();

    if (!kIsWeb && Platform.isIOS) {
      final itmsUri = Uri.parse(iOSItmsUri);
      try {
        if (await canLaunchUrl(itmsUri)) {
          await launchUrl(itmsUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      final webReviewUri = Uri.parse(iOSAppStoreUrl);
      if (await canLaunchUrl(webReviewUri)) {
        await launchUrl(webReviewUri, mode: LaunchMode.externalApplication);
        return;
      }
    } else if (!kIsWeb && Platform.isAndroid) {
      final marketUri = Uri.parse(androidMarketUri);
      try {
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      final storeUri = Uri.parse(androidStoreUrl);
      if (await canLaunchUrl(storeUri)) {
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
        return;
      }
    } else {
      final webUri = Uri.parse(webUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  static void markRated() {
    try {
      final box = Hive.box('cache');
      box.put('review_has_rated', true);
    } catch (_) {}
  }

  static void markDismissed() {
    try {
      final box = Hive.box('cache');
      box.put('review_dismissed_at', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static bool shouldShowAutoPrompt() {
    try {
      final box = Hive.box('cache');
      final hasRated = box.get('review_has_rated', defaultValue: false) as bool;
      if (hasRated) return false;

      final dismissedAt = box.get('review_dismissed_at') as int?;
      if (dismissedAt != null) {
        final lastDismissed =
            DateTime.fromMillisecondsSinceEpoch(dismissedAt);
        if (DateTime.now().difference(lastDismissed).inDays < 7) {
          return false;
        }
      }

      final launchCount =
          (box.get('review_launch_count', defaultValue: 0) as int) + 1;
      box.put('review_launch_count', launchCount);

      // Prompt on 3rd session, then wait at least 7 days between prompts
      return launchCount >= 3;
    } catch (_) {
      return false;
    }
  }

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _selectedStars = 5;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const goldAccent = Color(0xFFC59B27);

    String ctaText;
    IconData ctaIcon;

    if (!kIsWeb && Platform.isIOS) {
      ctaText = strings.t('Calificar en App Store', 'Rate on App Store');
      ctaIcon = Icons.star_rounded;
    } else if (!kIsWeb && Platform.isAndroid) {
      ctaText = strings.t('Calificar en Google Play', 'Rate on Google Play');
      ctaIcon = Icons.star_rounded;
    } else {
      ctaText = strings.t('Dejar una reseña', 'Leave a review');
      ctaIcon = Icons.rate_review_rounded;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
          width: 1,
        ),
      ),
      backgroundColor: scheme.surface,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Golden Emblem Circle
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goldAccent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: goldAccent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.grade_rounded,
                    color: goldAccent,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title (Dignified Cinzel)
              Text(
                strings.t('¿Te gusta Coro LLDM?', 'Enjoying TLOTW Choir?'),
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 12),

              // Interactive 5 Golden Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isFilled = starIndex <= _selectedStars;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStars = starIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFilled
                            ? goldAccent
                            : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Reverent, clear description
              Text(
                strings.t(
                  'Tu calificación y comentario en la tienda nos ayuda enormemente a que más hermanos del coro conozcan esta herramienta de estudio coral.',
                  'Your rating and review on the store greatly helps more choir members discover this choral study tool.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Primary CTA
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: goldAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                  ),
                  icon: Icon(ctaIcon, size: 20),
                  label: Text(
                    ctaText,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  onPressed: () {
                    ReviewDialog.markRated();
                    Navigator.pop(context);
                    ReviewDialog.launchReviewStore();
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Secondary actions: Más tarde / Ya califiqué
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () {
                      ReviewDialog.markDismissed();
                      Navigator.pop(context);
                    },
                    child: Text(
                      strings.t('Más tarde', 'Maybe later'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () {
                      ReviewDialog.markRated();
                      Navigator.pop(context);
                    },
                    child: Text(
                      strings.t('Ya la califiqué', 'Already reviewed'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper to show the review dialog
Future<void> showReviewDialog(BuildContext context, {bool force = false}) async {
  if (!force && !ReviewDialog.shouldShowAutoPrompt()) {
    return;
  }
  return showDialog<void>(
    context: context,
    builder: (context) => const ReviewDialog(),
  );
}
