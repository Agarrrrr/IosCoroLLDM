import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/providers/jukebox_provider.dart';
import 'package:coro_lldm/features/jukebox/jukebox_screen.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

class JukeboxMiniPlayer extends ConsumerWidget {
  const JukeboxMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jukebox = ref.watch(jukeboxProvider);
    final currentSong = jukebox.currentSong;

    if (currentSong == null && jukebox.playlist.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = scheme.primary;
    final onAccent = scheme.onPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, anim, secAnim) =>
                      const JukeboxScreen(),
                  transitionsBuilder: (context, anim, secAnim, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    );
                  },
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (jukebox.duration.inMilliseconds > 0)
                  LinearProgressIndicator(
                    value: (jukebox.position.inMilliseconds /
                            jukebox.duration.inMilliseconds)
                        .clamp(0.0, 1.0),
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      // Icono / Carátula
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: jukebox.isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: onAccent,
                                  ),
                                )
                              : SingingIcon(
                                  size: 22,
                                  color: onAccent,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Título y Voz
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentSong?.canto ?? 'Selecciona un canto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    jukebox.currentVoice,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                                if (jukebox.isOffline) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.offline_pin_rounded,
                                    size: 13,
                                    color: Colors.green.shade600,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Controles
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, size: 22),
                        color: scheme.onSurfaceVariant,
                        onPressed: jukebox.playlist.isEmpty
                            ? null
                            : () => ref.read(jukeboxProvider.notifier).previous(),
                      ),
                      GestureDetector(
                        onTap: () =>
                            ref.read(jukeboxProvider.notifier).togglePlay(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            jukebox.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: onAccent,
                            size: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 22),
                        color: scheme.onSurfaceVariant,
                        onPressed: jukebox.playlist.isEmpty
                            ? null
                            : () => ref.read(jukeboxProvider.notifier).next(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
