import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

class ScoreCard extends ConsumerWidget {
  final Canto canto;
  final VoidCallback onTap;

  const ScoreCard({
    super.key,
    required this.canto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(vocalManifestProvider);
    final hasAudio = canto.midiArchivo != null && canto.midiArchivo!.isNotEmpty;
    final vocalService = ref.watch(vocalAudioServiceProvider);
    final hasVocal = vocalService.findSong(
          cantoId: canto.id,
          cantoNombre: canto.nombre,
          lang: canto.idioma,
        ) !=
        null;
    final hasAnyAudio = hasAudio || hasVocal;
    final isFavorite = ref.watch(favoritosProvider).contains(canto.id);
    final strings = AppStrings.of(context);

    final cardBg = Theme.of(context).colorScheme.surface;
    final audioColor = Theme.of(context).colorScheme.primary;
    final hasSubtitleRow = hasAudio || hasVocal || canto.temas.isNotEmpty;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Ink(
                  decoration: BoxDecoration(
                    color: hasAnyAudio
                        ? audioColor
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          topRight: Radius.circular(17),
                          bottomRight: Radius.circular(17),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Texto
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: canto.nombre,
                                    child: Text(
                                      canto.nombre,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                  if (hasSubtitleRow) ...[
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        if (hasAudio) ...[
                                          Icon(Icons.piano_rounded,
                                              size: 18, color: audioColor),
                                          const SizedBox(width: 6),
                                        ],
                                        if (hasVocal) ...[
                                          SingingIcon(
                                            size: 17,
                                            color: audioColor,
                                          ),
                                          if (canto.temas.isNotEmpty)
                                            const SizedBox(width: 6),
                                        ],
                                        if (canto.temas.isNotEmpty)
                                          Flexible(
                                            child: Text(
                                              canto.temas.join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: isFavorite
                                  ? strings.t('Quitar de favoritos',
                                      'Remove from favorites')
                                  : strings.t('Agregar a favoritos',
                                      'Add to favorites'),
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 48),
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                reverseDuration:
                                    const Duration(milliseconds: 180),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                  scale: CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.elasticOut,
                                  ),
                                  child: FadeTransition(
                                      opacity: animation, child: child),
                                ),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey(isFavorite),
                                  size: 22,
                                  color: isFavorite
                                      ? AccessibleColors.against(
                                          const Color(0xFFE25563), [cardBg],
                                          minimum: 3.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                              onPressed: () {
                                ref
                                    .read(favoritosProvider.notifier)
                                    .toggle(canto.id);
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      duration:
                                          const Duration(milliseconds: 1400),
                                      behavior: SnackBarBehavior.floating,
                                      content: Row(
                                        children: [
                                          Icon(
                                            isFavorite
                                                ? Icons.heart_broken_rounded
                                                : Icons.favorite_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              isFavorite
                                                  ? strings.t(
                                                      'Se quitó de favoritos',
                                                      'Removed from favorites',
                                                    )
                                                  : strings.t(
                                                      'Agregado a favoritos',
                                                      'Added to favorites',
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                              },
                            ),
                            const SizedBox(width: 10),

                            // Flecha
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
