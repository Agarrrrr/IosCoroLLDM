import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/core/monetization/usage_quota.dart';
import 'package:coro_lldm/core/providers/jukebox_provider.dart';
import 'package:coro_lldm/features/jukebox/jukebox_screen.dart';
import 'package:coro_lldm/features/premium/premium_dialog.dart';
import 'package:coro_lldm/features/premium/reward_or_premium_dialog.dart';
import 'package:coro_lldm/features/shared/app_notification_banner.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

class JukeboxMiniPlayer extends ConsumerStatefulWidget {
  const JukeboxMiniPlayer({super.key});

  @override
  ConsumerState<JukeboxMiniPlayer> createState() => _JukeboxMiniPlayerState();
}

class _JukeboxMiniPlayerState extends ConsumerState<JukeboxMiniPlayer> {
  bool _accessPending = false;
  bool _quotaToastShown = false;

  Future<bool> _ensurePlayAccess(String songId) async {
    final allowed = await ref
        .read(monetizationProvider.notifier)
        .consumeAudioAccess(songId);
    if (!mounted) return false;
    if (allowed) {
      if (!_quotaToastShown && !ref.read(monetizationProvider).isPremium) {
        _quotaToastShown = true;
        final remaining = currentUsageQuota().newSongsRemaining;
        AppNotificationBanner.show(
          context,
          AppStrings.of(context).t(
            '$remaining cantos disponibles hoy',
            '$remaining songs available today',
          ),
        );
      }
      return true;
    }

    final strings = AppStrings.of(context);
    final accentColor = Theme.of(context).colorScheme.primary;
    final result = await showRewardOrPremiumDialog(
      context: context,
      type: RewardPromptType.audioPlayback,
      accentColor: accentColor,
    );
    if (!mounted || result == null || result == RewardPromptResult.dismiss) {
      return false;
    }
    if (result == RewardPromptResult.premium) {
      await showPremiumDialog(context);
      return mounted && ref.read(monetizationProvider).isPremium;
    }
    final earned = await AdsService.instance.showRewarded();
    if (!mounted) return false;
    if (!earned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.t(
              'El anuncio todavía no está disponible. Intenta de nuevo en unos segundos.',
              'The ad is not available yet. Try again in a few seconds.',
            ),
          ),
        ),
      );
      return false;
    }
    final controller = ref.read(monetizationProvider.notifier);
    await controller.grantRewardedAudio();
    final granted = await controller.consumeAudioAccess(songId);
    return mounted && granted;
  }

  Future<void> _handleTogglePlay() async {
    if (_accessPending) return;
    final jukebox = ref.read(jukeboxProvider);
    if (jukebox.isPlaying) {
      await ref.read(jukeboxProvider.notifier).togglePlay();
      return;
    }
    final song = jukebox.currentSong ??
        (jukebox.playlist.isNotEmpty ? jukebox.playlist.first : null);
    if (song == null) return;

    _accessPending = true;
    try {
      final allowed = await _ensurePlayAccess(song.id ?? song.canto);
      if (!mounted || !allowed) return;
      await ref.read(jukeboxProvider.notifier).togglePlay();
    } finally {
      _accessPending = false;
    }
  }

  Future<void> _handleNext() async {
    if (_accessPending) return;
    final jukebox = ref.read(jukeboxProvider);
    if (jukebox.playlist.isEmpty) return;
    int nextIndex = jukebox.currentIndex + 1;
    if (nextIndex >= jukebox.playlist.length) {
      if (jukebox.repeatMode == JukeboxRepeatMode.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    final nextSong = jukebox.playlist[nextIndex];
    _accessPending = true;
    try {
      final allowed = await _ensurePlayAccess(nextSong.id ?? nextSong.canto);
      if (!mounted || !allowed) return;
      await ref.read(jukeboxProvider.notifier).next();
    } finally {
      _accessPending = false;
    }
  }

  Future<void> _handlePrevious() async {
    if (_accessPending) return;
    final jukebox = ref.read(jukeboxProvider);
    if (jukebox.playlist.isEmpty) return;
    if (jukebox.position.inSeconds > 3) {
      await ref.read(jukeboxProvider.notifier).previous();
      return;
    }
    int prevIndex = jukebox.currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = jukebox.repeatMode == JukeboxRepeatMode.all
          ? jukebox.playlist.length - 1
          : 0;
    }
    final prevSong = jukebox.playlist[prevIndex];
    _accessPending = true;
    try {
      final allowed = await _ensurePlayAccess(prevSong.id ?? prevSong.canto);
      if (!mounted || !allowed) return;
      await ref.read(jukeboxProvider.notifier).previous();
    } finally {
      _accessPending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final strings = AppStrings.of(context);
    final isPiano = jukebox.audioMode == JukeboxAudioMode.piano;
    final voiceDisplay = strings.voiceLabel(jukebox.currentVoice);
    final badgeText = isPiano
        ? '${strings.t('Piano', 'Piano')} · $voiceDisplay'
        : voiceDisplay;

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
                              : isPiano
                                  ? Icon(
                                      Icons.piano_rounded,
                                      size: 22,
                                      color: onAccent,
                                    )
                                  : SingingIcon(
                                      size: 22,
                                      color: onAccent,
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Título y Modo/Voz
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentSong?.canto ??
                                  strings.t(
                                      'Selecciona un canto', 'Select a song'),
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
                                    badgeText,
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
                            : _handlePrevious,
                      ),
                      GestureDetector(
                        onTap: _handleTogglePlay,
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
                        onPressed:
                            jukebox.playlist.isEmpty ? null : _handleNext,
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
