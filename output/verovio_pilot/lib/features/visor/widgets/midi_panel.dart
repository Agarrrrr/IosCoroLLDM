import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/features/shared/content_notice.dart';
import 'player_options_sheet.dart';
import 'player_dismiss_handle.dart';
import 'metronome_motion.dart';

class MidiPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final String? errorMessage;
  final String cantoId;
  final MidiState midiState;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final void Function(double) onSeek;
  final void Function(double) onSpeedChange;
  final VoidCallback onMetronomo;
  final void Function(int, bool) onVozToggle;
  final void Function(int, double) onVozVolumeChange;
  final VoidCallback onResetVozVolumes;
  final void Function(int) onVozSolo;
  final bool isLoaded;
  final bool isReady;
  final Color accentColor;

  const MidiPanel({
    super.key,
    this.onClose,
    this.errorMessage,
    required this.cantoId,
    required this.midiState,
    required this.onPlay,
    required this.onStop,
    required this.onSeek,
    required this.onSpeedChange,
    required this.onMetronomo,
    required this.onVozToggle,
    required this.onVozVolumeChange,
    required this.onResetVozVolumes,
    required this.onVozSolo,
    required this.isLoaded,
    required this.isReady,
    required this.accentColor,
  });

  @override
  State<MidiPanel> createState() => _MidiPanelState();
}

class _MidiPanelState extends State<MidiPanel> {
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(1, '0');
    final s = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showOptions(bool voiceMix) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => PlayerOptionsSheet(
            initialState: widget.midiState,
            voiceMix: voiceMix,
            onSpeed: widget.onSpeedChange,
            onMute: widget.onVozToggle,
            onVolume: widget.onVozVolumeChange,
            onSolo: widget.onVozSolo,
            onReset: widget.onResetVozVolumes));
  }

  Duration get _beatDuration => MetronomeMotion.pulseDuration(widget.midiState);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool loading = !widget.isReady || !widget.isLoaded;

    if (widget.errorMessage != null) {
      return Material(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.outline, width: 0.75)),
        elevation: 12,
        color: theme.colorScheme.surface,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.onClose != null)
              PlayerDismissHandle(onClose: widget.onClose!),
            Flexible(
                child: ContentNotice(
              icon: Icons.music_off_rounded,
              title: AppStrings.of(context)
                  .t('Audio no disponible', 'Audio unavailable'),
              message: widget.errorMessage!,
            )),
          ]),
        ),
      );
    }

    return Material(
      elevation: 12,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outline, width: 0.75)),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      shadowColor: Colors.black.withValues(alpha: .35),
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.70),
          child: SingleChildScrollView(
              child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onClose != null)
                  PlayerDismissHandle(onClose: widget.onClose!),
                // Indicador metrónomo (flash en cada beat)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.piano_rounded,
                        color: widget.accentColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '♩ = ${widget.midiState.tempoBpm}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Metrónomo Visual (Row de bolitas)
                    if (widget.midiState.metronomoActivo &&
                        widget.midiState.beatIndex != null &&
                        widget.midiState.beatNumerator != null) ...[
                      Builder(
                        builder: (context) {
                          final beats = widget.midiState.beatNumerator!;
                          final dotSize = beats > 8 ? 6.0 : 8.0;
                          final numerator =
                              widget.midiState.timeSignatureNumerator ?? beats;
                          final denominator =
                              widget.midiState.timeSignatureDenominator ?? 4;
                          final groups = widget.midiState.beatGroups;
                          final groupStarts = <int>[];
                          var groupOffset = 0;
                          for (final group in groups) {
                            groupStarts.add(groupOffset);
                            groupOffset += group;
                          }
                          return Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '$numerator/$denominator',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 7),
                              ...List.generate(beats, (index) {
                                final isCurrent =
                                    index == widget.midiState.beatIndex;
                                final isFirst = index == 0;
                                final isGroupStart =
                                    groupStarts.contains(index);
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 90),
                                  margin: EdgeInsets.only(
                                    left: isGroupStart && index > 0 ? 5 : 2,
                                    right: 2,
                                  ),
                                  width: isCurrent ? dotSize + 2 : dotSize,
                                  height: isCurrent ? dotSize + 2 : dotSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCurrent
                                        ? (isFirst
                                            ? AccessibleColors.against(
                                                Colors.redAccent,
                                                [theme.colorScheme.surface],
                                                minimum: 3.1)
                                            : widget.accentColor)
                                        : Colors.grey.withValues(alpha: 0.3),
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: isFirst
                                                  ? Colors.redAccent
                                                      .withValues(alpha: 0.5)
                                                  : widget.accentColor
                                                      .withValues(alpha: 0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : [],
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (!widget.isReady)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: widget.accentColor),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Barra de progreso ──────────────────────────────────────────
                Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: widget.accentColor,
                        inactiveTrackColor:
                            widget.accentColor.withValues(alpha: 0.2),
                        thumbColor: widget.accentColor,
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _isDraggingSlider
                            ? _dragValue
                            : widget.midiState.progress.clamp(0.0, 1.0),
                        onChangeStart: loading
                            ? null
                            : (_) {
                                setState(() {
                                  _isDraggingSlider = true;
                                  _dragValue = widget.midiState.progress;
                                });
                              },
                        onChanged: loading
                            ? null
                            : (v) {
                                setState(() {
                                  _dragValue = v;
                                });
                              },
                        onChangeEnd: loading
                            ? null
                            : (v) {
                                setState(() {
                                  _isDraggingSlider = false;
                                });
                                widget.onSeek(v);
                              },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatTime(widget.midiState.tiempoActual),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant)),
                          Text(_formatTime(widget.midiState.tiempoTotal),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Controles principales ──────────────────────────────────────
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Metrónomo toggle
                        _GoldIconBtn(
                          isActive: widget.midiState.metronomoActivo,
                          activeColor: widget.accentColor,
                          onTap: loading ? null : widget.onMetronomo,
                          tooltip: 'Metrónomo',
                          size: 22,
                          child: TweenAnimationBuilder<double>(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : _beatDuration,
                            curve: Curves.easeInOutSine,
                            tween: Tween<double>(
                              begin: 0.0,
                              end: widget.midiState.metronomoActivo &&
                                      widget.midiState.isPlaying
                                  ? (widget.midiState.beatSerial.isEven
                                      ? -MetronomeMotion.amplitude(
                                          widget.midiState)
                                      : MetronomeMotion.amplitude(
                                          widget.midiState))
                                  : 0.0,
                            ),
                            builder: (context, angle, child) {
                              return MetronomeIcon(
                                color: widget.midiState.metronomoActivo
                                    ? widget.accentColor
                                    : theme.colorScheme.onSurfaceVariant,
                                size: 22,
                                rotationAngle: angle,
                              );
                            },
                          ),
                        ),
                        // Play / Pause (Foco central del reproductor)
                        IconButton(
                            tooltip: AppStrings.of(context)
                                .t('Mezcla de voces', 'Voice mix'),
                            icon: const Icon(Icons.tune_rounded),
                            onPressed:
                                loading ? null : () => _showOptions(true)),
                        GestureDetector(
                          onTap: loading ? null : widget.onPlay,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: loading
                                  ? Colors.grey.withValues(alpha: 0.2)
                                  : theme.colorScheme.primaryContainer,
                            ),
                            child: loading
                                ? Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                        color: theme.colorScheme.primary,
                                        strokeWidth: 2.5))
                                : Padding(
                                    padding: EdgeInsets.only(
                                      left:
                                          widget.midiState.isPlaying ? 0 : 2.5,
                                    ),
                                    child: Icon(
                                      widget.midiState.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                        // Stop
                        IconButton(
                            tooltip:
                                AppStrings.of(context).t('Velocidad', 'Speed'),
                            icon: const Icon(Icons.speed_rounded),
                            onPressed:
                                loading ? null : () => _showOptions(false)),
                        _GoldIconBtn(
                          icon: Icons.stop_rounded,
                          isActive: false,
                          activeColor: widget.accentColor,
                          onTap: loading ? null : widget.onStop,
                          tooltip: 'Detener',
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ))),
    );
  }
}

class _GoldIconBtn extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final bool isActive;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final Color activeColor;

  const _GoldIconBtn({
    this.icon,
    this.child,
    required this.isActive,
    this.onTap,
    required this.tooltip,
    this.size = 20,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: child ??
              Icon(
                icon,
                size: size,
                color: isActive ? activeColor : inactiveColor,
              ),
        ),
      ),
    );
  }
}

// ─── ICONO PERSONALIZADO DE METRÓNOMO (CustomPainter) ────────────────────────
class MetronomePainter extends CustomPainter {
  final Color color;
  final double rotationAngle;
  const MetronomePainter({required this.color, this.rotationAngle = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Dibujar el cuerpo (trapezoide del metrónomo)
    final path = Path()
      ..moveTo(size.width * 0.35, size.height * 0.15)
      ..lineTo(size.width * 0.65, size.height * 0.15)
      ..lineTo(size.width * 0.85, size.height * 0.85)
      ..lineTo(size.width * 0.15, size.height * 0.85)
      ..close();
    canvas.drawPath(path, paint);

    // 2. Dibujar el péndulo / varilla inclinada
    canvas.save();
    // Move pivot point to the bottom center of the metronome
    canvas.translate(size.width * 0.5, size.height * 0.8);
    canvas.rotate(rotationAngle);

    // Draw needle straight up
    canvas.drawLine(
      Offset.zero,
      Offset(0, -size.height * 0.62),
      paint,
    );

    // 3. Dibujar la pesa del péndulo
    canvas.drawCircle(Offset(0, -size.height * 0.35), 3, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MetronomePainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle || oldDelegate.color != color;
}

class MetronomeIcon extends StatelessWidget {
  final Color color;
  final double size;
  final double rotationAngle;
  const MetronomeIcon({
    super.key,
    required this.color,
    this.size = 22,
    this.rotationAngle = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: MetronomePainter(color: color, rotationAngle: rotationAngle),
    );
  }
}
