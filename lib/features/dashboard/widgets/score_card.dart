import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ScoreCard extends ConsumerWidget {
  final Canto canto;
  final int index;
  final VoidCallback onTap;

  const ScoreCard({
    super.key,
    required this.canto,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAudio = canto.midiArchivo != null && canto.midiArchivo!.isNotEmpty;
    final isFavorite = ref.watch(favoritosProvider).contains(canto.id);
    final strings = AppStrings.of(context);

    final cardBg = Theme.of(context).colorScheme.surface;

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
                    color: Theme.of(context).colorScheme.primary,
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
                                  Text(
                                    canto.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      if (hasAudio) ...[
                                        Icon(Icons.piano_rounded,
                                            size: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Text(
                                          canto.temas.isEmpty
                                              ? 'Sin categoría'
                                              : canto.temas.join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Botón Favorito (corazón) — marcar/desmarcar instantáneo
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
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
                                      ? const Color(0xFFE25563)
                                      : (isDark
                                          ? Colors.white24
                                          : Colors.grey.shade400),
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
                              color: isDark
                                  ? Colors.white30
                                  : const Color(0xFFCBD5E1),
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
    )
        .animate(
          delay: Duration(milliseconds: index < 10 ? index * 22 : 220),
        )
        .fadeIn(duration: 280.ms)
        .slideX(
          begin: 0.035,
          end: 0,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
