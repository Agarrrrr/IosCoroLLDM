import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum RewardPromptType {
  audioPlayback,
  audioExport,
}

enum RewardPromptResult {
  premium,
  rewarded,
  dismiss,
}

/// Muestra un diálogo visualmente atractivo y contrastado para invitar
/// al usuario a adquirir Premium o ver un anuncio recompensado (+1 crédito).
Future<RewardPromptResult?> showRewardOrPremiumDialog({
  required BuildContext context,
  required RewardPromptType type,
  Color? accentColor,
}) {
  return showDialog<RewardPromptResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => RewardOrPremiumDialog(
      type: type,
      accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
    ),
  );
}

class RewardOrPremiumDialog extends StatelessWidget {
  final RewardPromptType type;
  final Color accentColor;

  const RewardOrPremiumDialog({
    super.key,
    required this.type,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final isPlayback = type == RewardPromptType.audioPlayback;
    const goldColor = Color(0xFFD4AF37);

    final title = isPlayback
        ? strings.t('¿Quieres seguir escuchando?', 'Want to keep listening?')
        : strings.t('¿Quieres seguir exportando?', 'Want to keep exporting?');

    final subtitle = isPlayback
        ? strings.t(
            'Has alcanzado tu límite diario de 5 audios gratuitos. Elige cómo deseas continuar:',
            'You reached your daily limit of 5 free audios. Choose how to continue:',
          )
        : strings.t(
            'Has alcanzado tu límite diario de 3 exportaciones gratuitas. Elige cómo deseas continuar:',
            'You reached your daily limit of 3 free exports. Choose how to continue:',
          );

    final pillLabel = isPlayback
        ? strings.t('5 DE 5 AUDIOS USADOS HOY', '5 OF 5 AUDIOS USED TODAY')
        : strings.t('3 DE 3 EXPORTS USADOS HOY', '3 OF 3 EXPORTS USED TODAY');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // ── Avatar / Icono principal con halo de resalte ───────────────
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    goldColor.withValues(alpha: 0.28),
                    accentColor.withValues(alpha: 0.14),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: goldColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: goldColor.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isPlayback
                      ? Icons.headphones_rounded
                      : Icons.file_download_rounded,
                  color: goldColor,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Pill de estado / cuota ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: goldColor.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                pillLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: goldColor,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Título y subtítulo ─────────────────────────────────────────
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // ── Opción 1: TARJETA PREMIUM (Opción recomendada y destacada) ─
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, RewardPromptResult.premium),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        goldColor.withValues(alpha: 0.18),
                        const Color(0xFFF59E0B).withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.75),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: goldColor.withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEAB308), Color(0xFFCA8A04)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: goldColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  strings.t('Hacerte Premium', 'Go Premium'),
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF08A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    strings.t('MEJOR', 'BEST'),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF854D0E),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPlayback
                                  ? strings.t(
                                      'Audios ilimitados, sin anuncios y apoya el coro.',
                                      'Unlimited audio, no ads & support the choir.',
                                    )
                                  : strings.t(
                                      'Exportaciones ilimitadas, sin anuncios.',
                                      'Unlimited exports & no ads.',
                                    ),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: goldColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Opción 2: TARJETA VER ANUNCIO (+1 Recompensa) ──────────────
            if (AdUnitIds.rewarded != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      Navigator.pop(context, RewardPromptResult.rewarded),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.65),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.15),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: accentColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.t('Ver anuncio breve', 'Watch short ad'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPlayback
                                    ? strings.t(
                                        'Obtén +1 audio viendo un video corto.',
                                        'Get +1 audio by watching a short video.',
                                      )
                                    : strings.t(
                                        'Obtén +1 exportación viendo un video corto.',
                                        'Get +1 export by watching a short video.',
                                      ),
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+1',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ── Opción 3: DESCARTAR (Quizás más tarde) ─────────────────────
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, RewardPromptResult.dismiss),
              child: Text(
                strings.t('Quizás más tarde', 'Maybe later'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
