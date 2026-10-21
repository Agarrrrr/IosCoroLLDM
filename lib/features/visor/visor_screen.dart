import 'widgets/midi_panel.dart';

export 'widgets/midi_panel.dart' show MidiPanel;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:pdfrx/pdfrx.dart';

import 'package:google_fonts/google_fonts.dart';

import 'dart:async';

import 'dart:io';

import 'dart:math';

import 'package:flutter_animate/flutter_animate.dart';

import 'package:share_plus/share_plus.dart';

import 'package:path_provider/path_provider.dart';

import 'package:coro_lldm/core/offline/offline_files.dart';

import 'package:coro_lldm/core/offline/sync_manager.dart';

import 'package:coro_lldm/core/pdf/pdf_engine.dart';

import 'package:coro_lldm/models/trazo.dart';

import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';

import 'package:coro_lldm/features/visor/widgets/pdf_theme_palette.dart';

import 'package:coro_lldm/core/providers/cantos_provider.dart';

import 'package:coro_lldm/core/providers/theme_provider.dart';

import 'package:coro_lldm/models/canto.dart';

import 'package:coro_lldm/core/midi/midi_engine.dart';

import 'package:coro_lldm/core/midi/midi_export_service.dart';

import 'package:coro_lldm/core/audio/system_media_session.dart';

import 'package:coro_lldm/core/audio/vocal_audio_service.dart';

import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';

import 'package:coro_lldm/core/providers/jukebox_provider.dart';

import 'package:coro_lldm/features/jukebox/widgets/jukebox_mini_player.dart';

import 'widgets/vocal_panel.dart';

import 'widgets/singing_icon.dart';

import 'package:coro_lldm/core/storage/android_file_saver.dart';

import 'package:coro_lldm/core/storage/whatsapp_audio_share.dart';

import 'package:coro_lldm/core/localization/app_strings.dart';

import 'package:coro_lldm/core/monetization/ads_service.dart';

import 'package:coro_lldm/core/monetization/monetization_controller.dart';

import 'package:coro_lldm/features/premium/premium_dialog.dart';

import 'package:coro_lldm/features/premium/reward_or_premium_dialog.dart';

import 'package:coro_lldm/core/monetization/usage_quota.dart';

import 'package:coro_lldm/features/premium/usage_quota_notice.dart';

import 'package:coro_lldm/features/visor/widgets/score_title_button.dart';

import 'package:coro_lldm/features/visor/widgets/async_action_icon_button.dart';

import 'package:coro_lldm/features/shared/content_notice.dart';

import 'package:coro_lldm/features/shared/app_notification_banner.dart';

import 'package:coro_lldm/features/visor/widgets/annotation_tools.dart';

import 'score_wakelock.dart';

import 'widgets/export_navigation.dart';

import 'package:coro_lldm/core/storage/export_share.dart';

const double _kScaleEpsilon = 0.001;

enum _ShareKind { pdf, voicesOnly, allVoices, voice }

enum _ExportDestination { share, save }

class _ShareSelection {
  final _ShareKind kind;

  final MidiExportVoice? voice;

  const _ShareSelection(this.kind, [this.voice]);
}

class VisorScreen extends ConsumerStatefulWidget {
  final String cantoId;

  final bool ignorePreferredLanguage;

  const VisorScreen({
    super.key,
    required this.cantoId,
    this.ignorePreferredLanguage = false,
  });

  @override
  ConsumerState<VisorScreen> createState() => _VisorScreenState();
}

class _VisorScreenState extends ConsumerState<VisorScreen> {
  late final ScoreWakelock _screenLock;

  bool _showTopBar = true;

  bool _showTools = false;

  bool _showMidi = false;

  bool _showVocal = false;

  String _lastAudioMode = ''; // 'midi' o 'vocal'

  VocalSong? _vocalSong;

  bool _quotaToastShown = false;

  bool _audioAccessPending = false;

  bool _showDrawingPalette = false;

  final MidiEngine _midi = MidiEngine();

  bool _hasMidi = false;

  String? _midiError;

  bool _midiIniciado = false;

  Future<bool>? _midiLoadFuture;

  bool _idiomaVerificado = false;

  bool _pdfAdRegistered = false;

  final PdfViewerController _pdfController = PdfViewerController();

  bool _pdfViewReady = false;

  bool _pdfReadFailed = false;

  Orientation? _lastOrientation;

  double _minScaleLimit = 0.1;

  Timer? _carouselSnapTimer;

  Timer? _carouselHintTimer;

  bool _showCarouselNavigationHint = false;

  int _carouselNavigationEpoch = 0;

  // Clave global para obtener la posición del botón de compartir (requerida en iOS)

  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _screenLock = ScoreWakelock();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pdfEngineProvider.notifier).init(widget.cantoId);
    });
  }

  void _initMidi(Canto canto) {
    debugPrint('🎵 [MidiEngine] Inicializando para el canto: ${canto.nombre}');

    debugPrint('🎵 [MidiEngine] midiArchivo del canto: "${canto.midiArchivo}"');

    if (canto.midiArchivo == null || canto.midiArchivo!.isEmpty) {
      debugPrint('🎵 [MidiEngine] Este canto no tiene archivo MIDI asignado.');

      return;
    }

    setState(() {
      _hasMidi = true;

      _midiError = null;
    });

    _midiLoadFuture = _loadMidiFile(canto);
  }

  Future<bool> _loadMidiFile(Canto canto) async {
    try {
      final localMidi = await OfflineFiles.ensureMidi(canto);

      if (!mounted) return false;

      debugPrint('🎵 [NativeMidiEngine] Cargando MIDI: ${localMidi.path}');

      final loaded = await _midi.loadMidi(localMidi.path, canto.nombre);

      if (!loaded) throw const FormatException('No se pudo preparar el audio');

      if (!mounted) return false;

      ref.read(syncManagerProvider.notifier).refresh();

      if (_midiError != null) {
        setState(() => _midiError = null);
      }

      return true;
    } catch (e) {
      debugPrint('🎵 [MidiEngine] No se pudo obtener el archivo MIDI: $e');

      if (!mounted) return false;

      final strings = AppStrings.of(context);

      final message = strings.t(
        'No se pudo abrir el audio de este canto. Puedes seguir consultando la partitura.',
        'Could not open this song’s audio. You can still view the score.',
      );

      setState(() => _midiError = message);

      return false;
    }
  }

  Future<bool> _ensureMidiReadyForPlay(Canto canto) async {
    if (_midi.state.isLoaded && _midi.state.isReady) return true;

    if (_midiLoadFuture != null) {
      final ok = await _midiLoadFuture!;

      if (ok && _midi.state.isLoaded) return true;
    }

    _midiLoadFuture = _loadMidiFile(canto);

    return _midiLoadFuture!;
  }

  void _initVocalSong(Canto canto) async {
    try {
      final vocalService = ref.read(vocalAudioServiceProvider);

      await vocalService.ensureManifestLoaded();

      if (!mounted) return;

      final song = vocalService.findSong(
        cantoId: canto.id,
        cantoNombre: canto.nombre,
        lang: canto.idioma,
      );

      if (!mounted) return;

      setState(() {
        _vocalSong = song;
      });
    } catch (e) {
      debugPrint('⚠️ [VisorScreen] Error al buscar audios de estudio: $e');
    }
  }

  void _cambiarIdioma(Canto canto) {
    final vinculo = canto.vinculoIdioma;

    if (vinculo == null || vinculo.isEmpty) return;

    context.pushReplacement('/visor/$vinculo?manualLanguage=1');
  }

  @override
  void dispose() {
    _screenLock.dispose();

    _carouselSnapTimer?.cancel();

    _carouselHintTimer?.cancel();

    _carouselNavigationEpoch++;

    _midi.stop();

    _midi.dispose();

    SystemMediaSession.instance.stopSession();

    super.dispose();
  }

  void _toggleTopBar() {
    final state = ref.read(pdfEngineProvider);

    if (state.isDrawingMode || _showMidi || _showVocal) return;

    setState(() {
      _showTopBar = !_showTopBar;
    });
  }

  void _toggleTools() {
    final nextVisible = !_showTools;

    final currentState = ref.read(pdfEngineProvider);

    final pdf = ref.read(pdfEngineProvider.notifier);

    setState(() {
      _showTools = nextVisible;

      _showDrawingPalette =
          nextVisible && currentState.currentTool != ToolType.text;

      if (nextVisible) {
        _showMidi = false;

        _showVocal = false;
      }
    });

    pdf.setDrawingMode(nextVisible);

    _annotationFeedback();
  }

  void _annotationFeedback() {
    HapticFeedback.selectionClick();

    SystemSound.play(SystemSoundType.click);
  }

  void _selectDrawingTool(ToolType tool) {
    final state = ref.read(pdfEngineProvider);

    final sameTool = state.currentTool == tool && state.isDrawingMode;

    final pdf = ref.read(pdfEngineProvider.notifier);

    pdf.setDrawingMode(true);

    pdf.setTool(tool);

    setState(() {
      _showDrawingPalette = !sameTool || !_showDrawingPalette;
    });

    _annotationFeedback();
  }

  void _switchToMidiFromVocal(Canto canto, {bool autoPlay = false}) {
    setState(() {
      _showVocal = false;

      _showMidi = true;

      _lastAudioMode = 'midi';

      _showTools = false;

      _showDrawingPalette = false;
    });

    ref.read(pdfEngineProvider.notifier).setDrawingMode(false);

    if (autoPlay && _hasMidi) {
      final currentMidiState = _midi.state;

      if (!currentMidiState.isPlaying) {
        _handlePlay(canto, currentMidiState);
      }
    }
  }

  Future<void> _onAudioButtonTap(Canto canto) async {
    if (_showMidi || _showVocal) {
      // Ocultar el panel sin detener la reproducción para permitir estudiar la partitura

      setState(() {
        _showMidi = false;

        _showVocal = false;
      });

      return;
    }

    if (_vocalSong == null) {
      try {
        final vocalService = ref.read(vocalAudioServiceProvider);

        await vocalService.ensureManifestLoaded();

        if (!mounted) return;

        _vocalSong = vocalService.findSong(
          cantoId: canto.id,
          cantoNombre: canto.nombre,
          lang: canto.idioma,
        );
      } catch (_) {}
    }

    if (!mounted) return;

    final hasVocal = _vocalSong != null;

    final hasMidi = _hasMidi;

    // Si el piano está reproduciendo o fue el último panel activo, reabrir Piano directamente sin cortar el audio

    final midiActive = _midi.state.isPlaying || _lastAudioMode == 'midi';

    if (midiActive && hasMidi) {
      setState(() {
        _showMidi = true;

        _showVocal = false;

        _showTools = false;

        _showDrawingPalette = false;

        _lastAudioMode = 'midi';
      });

      ref.read(pdfEngineProvider.notifier).setDrawingMode(false);

      return;
    }

    // Si fue el último panel activo o si hay voces y no se estaba usando piano, abrir Voces

    if (hasVocal && _lastAudioMode != 'midi') {
      setState(() {
        _showVocal = true;

        _showMidi = false;

        _showTools = false;

        _showDrawingPalette = false;

        _lastAudioMode = 'vocal';
      });

      ref.read(pdfEngineProvider.notifier).setDrawingMode(false);
    } else if (hasMidi) {
      setState(() {
        _showMidi = true;

        _showVocal = false;

        _showTools = false;

        _showDrawingPalette = false;

        _lastAudioMode = 'midi';
      });

      ref.read(pdfEngineProvider.notifier).setDrawingMode(false);
    }
  }

  Future<void> _handlePlay(Canto canto, MidiState midiState) async {
    if (_audioAccessPending) return;

    _audioAccessPending = true;

    try {
      if (midiState.isPlaying) {
        _midi.pause();

        return;
      }

      final ready = await _ensureMidiReadyForPlay(canto);

      if (!mounted || !ready) return;

      final allowed = await ref
          .read(monetizationProvider.notifier)
          .consumeAudioAccess(canto.id);

      if (!mounted) return;

      if (allowed) {
        unawaited(ref.read(jukeboxProvider.notifier).stop());

        _midi.play();

        if (!_quotaToastShown && !ref.read(monetizationProvider).isPremium) {
          _quotaToastShown = true;

          final remaining = currentUsageQuota().newSongsRemaining;

          AppNotificationBanner.show(
              context,
              AppStrings.of(context).t('$remaining cantos disponibles hoy',
                  '$remaining songs available today'));
        }

        return;
      }

      final unlocked = await _showAudioLimitDialog(canto);

      if (unlocked && mounted) {
        unawaited(ref.read(jukeboxProvider.notifier).stop());

        _midi.play();
      }
    } finally {
      _audioAccessPending = false;
    }
  }

  Future<bool> _requestVocalPlayAccess(Canto canto) async {
    final allowed = await ref
        .read(monetizationProvider.notifier)
        .consumeAudioAccess(canto.id);

    if (!mounted) return false;

    if (allowed) {
      if (!_quotaToastShown && !ref.read(monetizationProvider).isPremium) {
        _quotaToastShown = true;

        final remaining = currentUsageQuota().newSongsRemaining;

        AppNotificationBanner.show(
            context,
            AppStrings.of(context).t('$remaining cantos disponibles hoy',
                '$remaining songs available today'));
      }

      return true;
    }

    return _showAudioLimitDialog(canto);
  }

  Future<bool> _showAudioLimitDialog(Canto canto) async {
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
      final allowed = await confirmAccessAfterPrompt(
        prompt: () => showPremiumDialog(context),
        isCurrent: () => mounted && widget.cantoId == canto.id,
        checkAccess: () async => ref.read(monetizationProvider).isPremium,
      );

      return allowed;
    }

    // RewardPromptResult.rewarded

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

    final allowed = await controller.consumeAudioAccess(canto.id);

    return mounted && allowed && widget.cantoId == canto.id;
  }

  void _closeScore() {
    _midi.stop();

    SystemMediaSession.instance.stopSession();

    if (!_pdfAdRegistered) {
      _pdfAdRegistered = true;

      unawaited(AdsService.instance.onPdfOpened());
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _ajustarZoomAlAncho() {
    if (_pdfController.isReady) {
      final matrix = _pdfController.calcMatrixFitWidthForPage(
          pageNumber: _pdfController.pageNumber ?? 1);

      if (matrix != null) {
        _pdfController.value = matrix;
      }
    }
  }

  Future<void> _irAPaginaCarrusel(
    int pageNumber, {
    Duration duration = const Duration(milliseconds: 220),
  }) async {
    if (!_pdfController.isReady || _pdfController.pageCount == 0) return;

    final requestEpoch = ++_carouselNavigationEpoch;

    final targetPage = pageNumber.clamp(1, _pdfController.pageCount);

    var matrix = _pdfController.calcMatrixForPage(
      pageNumber: targetPage,
      anchor: PdfPageAnchor.all,
    );

    final targetScale = matrix.getMaxScaleOnAxis();

    if ((_minScaleLimit - targetScale).abs() > _kScaleEpsilon && mounted) {
      setState(() => _minScaleLimit = targetScale);

      await WidgetsBinding.instance.endOfFrame;

      if (!mounted ||
          requestEpoch != _carouselNavigationEpoch ||
          !_pdfController.isReady) {
        return;
      }

      matrix = _pdfController.calcMatrixForPage(
        pageNumber: targetPage,
        anchor: PdfPageAnchor.all,
      );
    }

    _carouselSnapTimer?.cancel();

    await _pdfController.goTo(matrix, duration: duration);
  }

  void _manejarToqueEnVisor(
    TapUpDetails details, {
    required double viewerWidth,
    required bool isCarousel,
    required bool isDrawingMode,
  }) {
    if (isDrawingMode) return;

    if (!isCarousel || !_pdfController.isReady || viewerWidth <= 0) {
      _toggleTopBar();

      return;
    }

    final x = details.localPosition.dx;

    final currentPage = _pdfController.pageNumber ?? 1;

    if (x <= viewerWidth * 0.30) {
      unawaited(_irAPaginaCarrusel(currentPage - 1));
    } else if (x >= viewerWidth * 0.70) {
      unawaited(_irAPaginaCarrusel(currentPage + 1));
    } else {
      _toggleTopBar();
    }
  }

  void _mostrarPistaDeNavegacionCarrusel({required int pageCount}) {
    _carouselHintTimer?.cancel();

    if (pageCount < 2 || !mounted) return;

    setState(() => _showCarouselNavigationHint = true);

    _carouselHintTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showCarouselNavigationHint = false);
      }
    });
  }

  /// En carrusel la página que contiene el centro del visor es la activa.

  /// Esto da un umbral natural de media página para avanzar o regresar y evita

  /// que una anotación se perciba como parte de la página vecina.

  int? _paginaActualEnCarrusel(
    Rect visibleRect,
    List<Rect> pageRects,
  ) {
    if (pageRects.isEmpty) return null;

    final center = visibleRect.center;

    var nearestIndex = 0;

    var nearestDistance = double.infinity;

    for (var index = 0; index < pageRects.length; index++) {
      final rect = pageRects[index];

      if (rect.contains(center)) return index + 1;

      final dx = center.dx < rect.left
          ? rect.left - center.dx
          : center.dx > rect.right
              ? center.dx - rect.right
              : 0.0;

      final dy = center.dy < rect.top
          ? rect.top - center.dy
          : center.dy > rect.bottom
              ? center.dy - rect.bottom
              : 0.0;

      final distance = dx * dx + dy * dy;

      if (distance < nearestDistance) {
        nearestDistance = distance;

        nearestIndex = index;
      }
    }

    return nearestIndex + 1;
  }

  void _programarAjusteDeCarrusel() {
    _carouselSnapTimer?.cancel();

    _carouselSnapTimer = Timer(const Duration(milliseconds: 380), () {
      if (!mounted || !_pdfController.isReady) return;

      // Con zoom ampliado el usuario necesita poder desplazarse libremente

      // dentro de la página; el ajuste solo aplica al nivel de lectura.

      final currentScale = _pdfController.value.getMaxScaleOnAxis();

      if (currentScale > _minScaleLimit + 0.02) return;

      final pageNumber = _pdfController.pageNumber;

      if (pageNumber == null) return;

      unawaited(
        _irAPaginaCarrusel(
          pageNumber,
          duration: const Duration(milliseconds: 180),
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint('No se pudo ajustar el carrusel: $error');
        }),
      );
    });
  }

  void _calcularLimiteEscala(PdfDocument document) {
    if (document.pages.isEmpty) return;

    final firstPageWidth = document.pages.first.width;

    final viewWidth = MediaQuery.sizeOf(context).width;

    if (!firstPageWidth.isFinite ||
        firstPageWidth <= 0 ||
        !viewWidth.isFinite ||
        viewWidth <= 0) {
      return;
    }

    final scale = viewWidth / firstPageWidth;

    if (!mounted || (_minScaleLimit - scale).abs() <= _kScaleEpsilon) {
      return;
    }

    setState(() {
      _minScaleLimit = scale;
    });

    // Forzar al controlador a respetar el minScale bloqueando la matriz.

    if (_pdfController.isReady) {
      final currentMatrix = _pdfController.value;

      final currentScale = currentMatrix.getMaxScaleOnAxis();

      if (currentScale + _kScaleEpsilon < scale) {
        _ajustarZoomAlAncho();
      }
    }
  }

  Future<void> _mostrarMenuCompartirMp3(
    Canto canto,
    String? localPdfPath,
  ) async {
    try {
      await _runExportFlow(canto, localPdfPath);
    } catch (error, stack) {
      debugPrint('No se pudo preparar la exportación: $error\n$stack');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        AppStrings.of(context).t(
            'No se pudo preparar la exportación de este canto.',
            'Could not prepare this song for export.'),
      )));
    }
  }

  Future<void> _runExportFlow(
    Canto canto,
    String? localPdfPath,
  ) async {
    final theme = Theme.of(context);

    final strings = AppStrings.of(context);

    List<MidiExportVoice> voices = const [];

    String? midiError;

    if (canto.midiArchivo != null && canto.midiArchivo!.isNotEmpty) {
      try {
        voices = await MidiExportService.voices(canto);
      } catch (e) {
        debugPrint('No se pudo preparar el MIDI para exportar: $e');

        midiError = strings.t(
            'No se pudo leer el audio de este canto. Puedes compartir el PDF si está disponible.',
            'Could not read this song’s audio. You can share the PDF if it is available.');
      }
    }

    if (!mounted) return;

    final selection = await showSettledExportSheet<_ShareSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${strings.t('Exportar', 'Export')} '
                '"${canto.nombre}"',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const UsageQuotaNotice(exports: true),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(strings.t('Partitura (PDF)', 'Sheet Music (PDF)')),
                subtitle: Text(
                  strings.t(
                    'Guardar o compartir la partitura',
                    'Save or share the score',
                  ),
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  const _ShareSelection(_ShareKind.pdf),
                ),
              ),
              if (voices.isNotEmpty) ...[
                ListTile(
                  leading: Icon(
                    Icons.groups_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(strings.t(
                    'Voces individuales (MP3)',
                    'Individual Voices (MP3)',
                  )),
                  subtitle: Text(strings.t(
                    'Convertir cada voz por separado, sin ensamble',
                    'Convert each voice separately, without ensemble',
                  )),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    const _ShareSelection(_ShareKind.voicesOnly),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.library_music_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(strings.t(
                    'Ensamble y todas las voces (MP3)',
                    'Ensemble and all voices (MP3)',
                  )),
                  subtitle: Text(strings.t(
                    'Convertir todo en una sola operación',
                    'Convert all in a single operation',
                  )),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    const _ShareSelection(_ShareKind.allVoices),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    strings.t('VOCES INDIVIDUALES', 'INDIVIDUAL VOICES'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final voice in voices)
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: Text(voice.name),
                    subtitle: Text(strings.t(
                      'Convertir esta voz a MP3',
                      'Convert this voice to MP3',
                    )),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _ShareSelection(_ShareKind.voice, voice),
                    ),
                  ),
              ] else if (midiError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    midiError,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (selection == null || !mounted) return;

    if (selection.kind == _ShareKind.pdf) {
      await _guardarOCompartirPdf(canto, localPdfPath);

      return;
    }

    // Para exportar audio, verificar límite de créditos diarios

    final canExport =
        await ref.read(monetizationProvider.notifier).canExportAudio();

    if (!mounted) return;

    if (!canExport) {
      final allowed = await _mostrarDialogoLimiteExport(canto);

      if (!allowed || !mounted) return;
    }

    final destination = await _elegirDestino();

    if (destination == null || !mounted) return;

    if (selection.kind == _ShareKind.allVoices ||
        selection.kind == _ShareKind.voicesOnly) {
      await _exportarTodasLasVoces(
        canto,
        voices,
        destination,
        includeEnsemble: selection.kind == _ShareKind.allVoices,
      );
    } else {
      await _exportarMp3(canto, selection.voice, destination);
    }
  }

  /// Devuelve el Rect del botón de compartir para iOS share sheet.

  Rect _shareButtonRect() {
    final renderBox =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;

    final viewport = Offset.zero & MediaQuery.sizeOf(context);

    if (renderBox != null && renderBox.attached && renderBox.hasSize) {
      final rect = (renderBox.localToGlobal(Offset.zero) & renderBox.size)
          .intersect(viewport);

      if (!rect.isEmpty) return rect;
    }

    return Rect.fromCenter(center: viewport.center, width: 1, height: 1);
  }

  /// Diálogo de límite diario de exports alcanzado (solo usuarios free).

  Future<bool> _mostrarDialogoLimiteExport(
    Canto canto,
  ) async {
    final strings = AppStrings.of(context);

    final accentColor = Theme.of(context).colorScheme.primary;

    final result = await showRewardOrPremiumDialog(
      context: context,
      type: RewardPromptType.audioExport,
      accentColor: accentColor,
    );

    if (!mounted || result == null || result == RewardPromptResult.dismiss) {
      return false;
    }

    if (result == RewardPromptResult.premium) {
      return confirmAccessAfterPrompt(
        prompt: () => showPremiumDialog(context),
        isCurrent: () => mounted && widget.cantoId == canto.id,
        checkAccess: () =>
            ref.read(monetizationProvider.notifier).canExportAudio(),
      );
    }

    // RewardPromptResult.rewarded

    final earned = await AdsService.instance.showRewarded();

    if (!mounted) return false;

    if (earned) {
      await ref.read(monetizationProvider.notifier).grantRewardedExport();

      return confirmAccessAfterPrompt(
        prompt: () async {},
        isCurrent: () => mounted && widget.cantoId == canto.id,
        checkAccess: () =>
            ref.read(monetizationProvider.notifier).canExportAudio(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.t(
            'El anuncio no está disponible aún. Inténtalo de nuevo.',
            'Ad not available yet. Please try again.',
          )),
        ),
      );
    }

    return false;
  }

  Future<_ExportDestination?> _elegirDestino() async {
    final strings = AppStrings.of(context);

    return showSettledExportSheet<_ExportDestination>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: Text(strings.t(
                Platform.isIOS
                    ? 'Guardar en Archivos'
                    : 'Guardar en dispositivo',
                Platform.isIOS ? 'Save to Files' : 'Save to device',
              )),
              subtitle: Text(strings.t(
                'Elegir nombre y ubicación',
                'Choose name and location',
              )),
              onTap: () => Navigator.pop(
                sheetContext,
                _ExportDestination.save,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(strings.t('Compartir', 'Share')),
              subtitle: Text(strings.t(
                'Enviar mediante otra aplicación',
                'Send via another app',
              )),
              onTap: () => Navigator.pop(
                sheetContext,
                _ExportDestination.share,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarOCompartirPdf(
    Canto canto,
    String? localPdfPath,
  ) async {
    final strings = AppStrings.of(context);

    if (localPdfPath == null || !await File(localPdfPath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(strings.t(
            'La partitura PDF todavía no está disponible.',
            'The PDF score is not available yet.',
          ))),
        );
      }

      return;
    }

    final destination = await _elegirDestino();

    if (destination == null || !mounted) return;

    final sourcePdf = File(localPdfPath);

    final pdfName = MidiExportService.displayPdfFileName(canto);

    try {
      if (destination == _ExportDestination.save) {
        final saved = await AndroidFileSaver.save([
          AndroidSaveFile(
            file: sourcePdf,
            name: pdfName,
            mimeType: 'application/pdf',
          ),
        ]);

        if (mounted && saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(strings.t(
              'PDF guardado correctamente.',
              'PDF saved successfully.',
            ))),
          );
        }

        return;
      }

      final sharePdf = await _prepareShareFile(sourcePdf, pdfName);

      if (!mounted) return;

      await ExportShare.share(
        [XFile(sharePdf.path, name: pdfName, mimeType: 'application/pdf')],
        subject: canto.nombre,
        origin: _shareButtonRect(),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          strings.t(
              'No se pudo guardar o compartir la partitura. Comprueba que la ubicación o la aplicación de destino estén disponibles.',
              'Could not save or share the score. Check that the destination folder or app is available.'),
        )),
      );
    }
  }

  Future<void> _exportarMp3(
    Canto canto,
    MidiExportVoice? voice,
    _ExportDestination destination,
  ) async {
    final strings = AppStrings.of(context);

    var operation = strings.t('crear', 'create');

    final dialog = ExportProgressDialog(
      context,
      (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  voice == null
                      ? strings.t('Convirtiendo ensamble a MP3…',
                          'Converting ensemble to MP3…')
                      : strings.t('Convirtiendo ${voice.name} a MP3…',
                          'Converting ${voice.name} to MP3…'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final mp3 = await MidiExportService.exportMp3(
        canto,
        trackIndex: voice?.trackIndex,
        voiceName: voice?.name,
      );

      if (!mounted) return;

      await dialog.close();

      if (!mounted) return;

      if (destination == _ExportDestination.save) {
        operation = strings.t('guardar', 'save');

        final saved = await AndroidFileSaver.save([
          AndroidSaveFile(
            file: mp3,
            name: MidiExportService.displayFileName(canto, voice: voice),
            mimeType: 'audio/mpeg',
          ),
        ]);

        if (mounted && saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(strings.t(
                    'MP3 guardado correctamente.', 'MP3 saved successfully.'))),
          );

          await ref.read(monetizationProvider.notifier).consumeAudioExport();

          unawaited(AdsService.instance.onExportCompleted());
        }
      } else {
        operation = strings.t('compartir', 'share');

        final mp3Name = MidiExportService.displayFileName(canto, voice: voice);

        final shareMp3 = await _prepareShareFile(mp3, mp3Name);

        if (!mounted) return;

        final sentToWhatsApp = await WhatsAppAudioShare.share([shareMp3]);

        final shared =
            sentToWhatsApp || await _shareMp3Files([shareMp3], [mp3Name]);

        if (!shared || !mounted) return;

        await ref.read(monetizationProvider.notifier).consumeAudioExport();

        unawaited(AdsService.instance.onExportCompleted());
      }
    } catch (e) {
      debugPrint('Exportación fallida: $e');

      if (!mounted) return;

      await dialog.close();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(strings.t(
                'No se pudo $operation el archivo de audio. Comprueba que el canto y el destino estén disponibles.',
                'Could not $operation the audio file. Check that the song and destination are available.'))),
      );
    } finally {
      await dialog.close();
    }
  }

  Future<void> _exportarTodasLasVoces(
      Canto canto, List<MidiExportVoice> voices, _ExportDestination destination,
      {bool includeEnsemble = true}) async {
    final strings = AppStrings.of(context);

    final total = voices.length + (includeEnsemble ? 1 : 0);

    final progress = ValueNotifier<(int, int, String)>(
        (0, total, strings.t('Voces individuales', 'Individual voices')));

    var cancelled = false;

    var operation = strings.t('crear', 'create');

    final dialog = ExportProgressDialog(
      context,
      (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title:
              Text(strings.t('Preparando archivos MP3', 'Preparing MP3 files')),
          content: ValueListenableBuilder<(int, int, String)>(
            valueListenable: progress,
            builder: (context, value, child) {
              final completed = value.$1;

              final total = value.$2;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: total == 0 ? null : completed / total,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    cancelled
                        ? strings.t('Cancelando al terminar el archivo actual…',
                            'Cancelling after current file…')
                        : '${value.$3}\n$completed ${strings.t('de', 'of')} $total',
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;

                progress.value = (
                  progress.value.$1,
                  progress.value.$2,
                  strings.t('Cancelando al terminar el archivo actual…',
                      'Cancelling after current file…')
                );
              },
              child: Text(strings.t('Cancelar', 'Cancel')),
            ),
          ],
        ),
      ),
    );

    try {
      final files = await MidiExportService.exportAllMp3(
        canto,
        onProgress: (completed, total, label) {
          progress.value = (completed, total, label);
        },
        isCancelled: () => cancelled,
        includeEnsemble: includeEnsemble,
      );

      if (!mounted) return;

      await dialog.close();

      if (!mounted) return;

      if (files.isEmpty || cancelled) return;

      final names = <String>[
        if (includeEnsemble) MidiExportService.displayFileName(canto),
        for (final voice in voices)
          MidiExportService.displayFileName(canto, voice: voice),
      ];

      if (destination == _ExportDestination.save) {
        operation = strings.t('guardar', 'save');

        final saved = await AndroidFileSaver.save([
          for (var i = 0; i < files.length; i++)
            AndroidSaveFile(
              file: files[i],
              name: names[i],
              mimeType: 'audio/mpeg',
            ),
        ]);

        if (mounted && saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${files.length} ${strings.t('archivos MP3 guardados.', 'MP3 files saved.')}')),
          );

          await ref.read(monetizationProvider.notifier).consumeAudioExport();

          unawaited(AdsService.instance.onExportCompleted());
        }
      } else {
        operation = strings.t('compartir', 'share');

        final shareFiles = await Future.wait([
          for (var i = 0; i < files.length; i++)
            _prepareShareFile(files[i], names[i]),
        ]);

        if (!mounted) return;

        final sentToWhatsApp = await WhatsAppAudioShare.share(shareFiles);

        final shared =
            sentToWhatsApp || await _shareMp3Files(shareFiles, names);

        if (!shared || !mounted) return;

        await ref.read(monetizationProvider.notifier).consumeAudioExport();

        unawaited(AdsService.instance.onExportCompleted());
      }
    } catch (e) {
      debugPrint('Exportación fallida: $e');

      if (!mounted) return;

      await dialog.close();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(strings.t(
                'No se pudieron $operation los archivos de audio. Comprueba que el canto y el destino estén disponibles.',
                'Could not $operation the audio files. Check that the song and destination are available.'))),
      );
    } finally {
      await dialog.close();

      progress.dispose();
    }
  }

  Widget _pdfErrorNotice(BuildContext context) {
    final strings = AppStrings.of(context);

    return ContentNotice(
      icon: Icons.picture_as_pdf_outlined,
      title: strings.t(
          'No se pudo abrir esta partitura', 'Could not open this score'),
      message: strings.t(
        'El archivo no está disponible o no se pudo leer en este dispositivo. Puedes volver al catálogo y consultar otro canto. Si el problema continúa, comunícalo al soporte de la app.',
        'The file is unavailable or could not be read on this device. You can return to the catalog and view another song. If the problem persists, report it to app support.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfEngineProvider);

    final theme = Theme.of(context);

    final themeMode = ref.watch(themeProvider);

    final accentColor = theme.colorScheme.primary;

    final isCarousel = ref.watch(pdfNavModeProvider);

    final cantos = ref.watch(cantosBaseProvider).valueOrNull ?? [];

    final canto = cantos.firstWhere(
      (c) => c.id == widget.cantoId,
      orElse: () => Canto(id: '', nombre: 'Partitura', archivo: '', temas: []),
    );

    final strings = AppStrings.of(context);

    final isMobile = Platform.isIOS || Platform.isAndroid;

    // Iniciar MIDI cuando el canto ya está resuelto del catálogo

    if (!_midiIniciado && canto.id == widget.cantoId && canto.id.isNotEmpty) {
      _midiIniciado = true;

      _initMidi(canto);

      _initVocalSong(canto);
    }

    // Preferencia de idioma de partitura (ESP/ENG): redirigir a la versión vinculada

    if (!_idiomaVerificado &&
        canto.id == widget.cantoId &&
        canto.id.isNotEmpty) {
      _idiomaVerificado = true;

      final pref = ref.read(languageFilterProvider);

      if (!widget.ignorePreferredLanguage &&
          pref != canto.idioma &&
          canto.vinculoIdioma != null &&
          canto.vinculoIdioma!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pushReplacement('/visor/${canto.vinculoIdioma}');
        });
      }
    }

    final orientation = MediaQuery.of(context).orientation;

    if (_lastOrientation != null && _lastOrientation != orientation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_pdfController.isReady ||
            _pdfController.pageCount == 0) {
          return;
        }

        if (isCarousel) {
          unawaited(
            _irAPaginaCarrusel(
              _pdfController.pageNumber ?? 1,
              duration: Duration.zero,
            ),
          );

          return;
        }

        final matrix = _pdfController.calcMatrixFitWidthForPage(
          pageNumber: _pdfController.pageNumber ?? 1,
        );

        if (matrix == null) return;

        setState(() => _minScaleLimit = matrix.getMaxScaleOnAxis());

        _pdfController.value = matrix;
      });
    }

    _lastOrientation = orientation;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        _closeScore();
      },
      child: Scaffold(
        backgroundColor: PdfThemePalette.background(themeMode),
        body: SafeArea(
          bottom: isMobile,
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Top Bar ─────────────────────────────────────────────────

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _showTopBar ? 60 : 0,
                    decoration: BoxDecoration(
                      color: PdfThemePalette.background(themeMode),
                      border: Border(
                          bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2))),
                    ),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 60,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant),
                              onPressed: _closeScore,
                            ),
                            Expanded(
                                child: ScoreTitleButton(title: canto.nombre)),
                            if (canto.vinculoIdioma != null &&
                                canto.vinculoIdioma!.isNotEmpty)
                              IconButton(
                                tooltip: strings.t(
                                    'Cambiar idioma de la partitura',
                                    'Change score language'),
                                icon: Text('ENG–ESP',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: accentColor)),
                                onPressed: () => _cambiarIdioma(canto),
                              ),
                            if (_hasMidi || _vocalSong != null)
                              _TopBarBtn(
                                isActive: _showMidi || _showVocal,
                                activeColor: accentColor,
                                onTap: () => _onAudioButtonTap(canto),
                                tooltip: strings.t(
                                  'Reproductor de estudio',
                                  'Study player',
                                ),
                                child: _showVocal ||
                                        (!_hasMidi && _vocalSong != null)
                                    ? SingingIcon(
                                        size: 22,
                                        color: (_showMidi || _showVocal)
                                            ? accentColor
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      )
                                    : Icon(
                                        Icons.piano_rounded,
                                        color: (_showMidi || _showVocal)
                                            ? accentColor
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                              ),
                            SizedBox(
                              key: _shareButtonKey,
                              child: AsyncActionIconButton(
                                onPressed: () => _mostrarMenuCompartirMp3(
                                    canto, state.localPath),
                                busyLabel: strings.t('Preparando exportación…',
                                    'Preparing export…'),
                                tooltip: strings.t(
                                  'Compartir o guardar',
                                  'Share or save',
                                ),
                              ),
                            ),
                            _TopBarBtn(
                              icon: _showTools
                                  ? Icons.close_rounded
                                  : Icons.draw_rounded,
                              isActive: _showTools,
                              onTap: _toggleTools,
                              tooltip: strings.t('Anotaciones', 'Annotations'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── PDF Viewer ───────────────────────────────────────────────

                  Expanded(
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, viewerConstraints) =>
                              GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) => _manejarToqueEnVisor(
                              details,
                              viewerWidth: viewerConstraints.maxWidth,
                              isCarousel: isCarousel,
                              isDrawingMode: state.isDrawingMode,
                            ),
                            child: state.isLoading
                                ? _LoadingPlaceholder()
                                : state.error != null || _pdfReadFailed
                                    ? _pdfErrorNotice(context)
                                    : PdfViewer.file(
                                        state.localPath!,
                                        key: ValueKey(state.localPath!),
                                        controller: _pdfController,
                                        params: PdfViewerParams(
                                          errorBannerBuilder: (context, error,
                                              stack, document) {
                                            debugPrint(
                                                'No se pudo leer el PDF: $error');

                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              if (mounted && !_pdfReadFailed) {
                                                setState(() =>
                                                    _pdfReadFailed = true);
                                              }
                                            });

                                            return const SizedBox.shrink();
                                          },

                                          enableTextSelection: false,

                                          margin: isCarousel ? 0 : 8,

                                          minScale: _minScaleLimit,

                                          maxScale: 6,

                                          pageAnchor: isCarousel
                                              ? PdfPageAnchor.all
                                              : PdfPageAnchor.top,

                                          pageAnchorEnd: isCarousel
                                              ? PdfPageAnchor.all
                                              : PdfPageAnchor.bottom,

                                          limitRenderingCache: true,

                                          maxImageBytesCachedOnMemory:
                                              32 * 1024 * 1024,

                                          horizontalCacheExtent: 0.35,

                                          verticalCacheExtent: 0.75,

                                          getPageRenderingScale: (
                                            context,
                                            page,
                                            controller,
                                            estimatedScale,
                                          ) {
                                            const maxRasterDimension = 1800.0;

                                            final longestSide =
                                                max(page.width, page.height);

                                            if (!longestSide.isFinite ||
                                                longestSide <= 0) {
                                              return estimatedScale;
                                            }

                                            return min(
                                              estimatedScale,
                                              maxRasterDimension / longestSide,
                                            )
                                                .clamp(0.15, estimatedScale)
                                                .toDouble();
                                          },

                                          boundaryMargin: isCarousel
                                              ? EdgeInsets.zero
                                              : isMobile
                                                  ? const EdgeInsets.only(
                                                      bottom: 96,
                                                    )
                                                  : EdgeInsets.zero,

                                          // Usar la fricción estándar evita que

                                          // el desplazamiento se detenga demasiado

                                          // pronto en iPad/iPhone.

                                          interactionEndFrictionCoefficient:
                                              0.0000135,

                                          onViewerReady:
                                              (document, controller) async {
                                            if (isCarousel) {
                                              await _irAPaginaCarrusel(
                                                controller.pageNumber ?? 1,
                                                duration: Duration.zero,
                                              );

                                              if (!mounted) return;

                                              _mostrarPistaDeNavegacionCarrusel(
                                                pageCount:
                                                    document.pages.length,
                                              );
                                            } else {
                                              _calcularLimiteEscala(document);

                                              _ajustarZoomAlAncho();
                                            }

                                            if (mounted) {
                                              setState(
                                                  () => _pdfViewReady = true);
                                            }
                                          },

                                          onInteractionStart: (_) {
                                            _carouselSnapTimer?.cancel();
                                          },

                                          onInteractionEnd: (_) {
                                            if (isCarousel &&
                                                !state.isDrawingMode) {
                                              _programarAjusteDeCarrusel();
                                            }
                                          },

                                          panEnabled: !state.isDrawingMode,

                                          scaleEnabled: true,

                                          calculateCurrentPageNumber: isCarousel
                                              ? (visibleRect, pageRects, _) =>
                                                  _paginaActualEnCarrusel(
                                                    visibleRect,
                                                    pageRects,
                                                  )
                                              : null,

                                          layoutPages: isCarousel
                                              ? (pages, params) {
                                                  final height = pages.fold(
                                                        0.0,
                                                        (previous, page) =>
                                                            max<double>(
                                                          previous,
                                                          page.height,
                                                        ),
                                                      ) +
                                                      params.margin * 2;

                                                  final pageLayouts = <Rect>[];

                                                  var x = params.margin;

                                                  for (final page in pages) {
                                                    pageLayouts.add(
                                                      Rect.fromLTWH(
                                                        x,
                                                        (height - page.height) /
                                                            2,
                                                        page.width,
                                                        page.height,
                                                      ),
                                                    );

                                                    x += page.width +
                                                        params.margin;
                                                  }

                                                  return PdfPageLayout(
                                                    pageLayouts: pageLayouts,
                                                    documentSize:
                                                        Size(x, height),
                                                  );
                                                }
                                              : isMobile
                                                  ? (pages, params) {
                                                      final width = pages.fold(
                                                            0.0,
                                                            (value, page) =>
                                                                max(
                                                              value,
                                                              page.width,
                                                            ),
                                                          ) +
                                                          params.margin * 2;

                                                      final pageLayouts =
                                                          <Rect>[];

                                                      var y = params.margin;

                                                      for (final page
                                                          in pages) {
                                                        pageLayouts.add(
                                                          Rect.fromLTWH(
                                                            (width -
                                                                    page.width) /
                                                                2,
                                                            y,
                                                            page.width,
                                                            page.height,
                                                          ),
                                                        );

                                                        y += page.height +
                                                            params.margin;
                                                      }

                                                      final endSpace =
                                                          pages.isEmpty
                                                              ? 96.0
                                                              : max(
                                                                  96.0,
                                                                  pages.last
                                                                          .height *
                                                                      0.12,
                                                                );

                                                      return PdfPageLayout(
                                                        pageLayouts:
                                                            pageLayouts,
                                                        documentSize: Size(
                                                          width,
                                                          y + endSpace,
                                                        ),
                                                      );
                                                    }
                                                  : null,

                                          backgroundColor:
                                              PdfThemePalette.background(
                                                  themeMode),

                                          pageColorFilter:
                                              PdfThemePalette.filter(themeMode),

                                          pageDropShadow: null,

                                          pageOverlaysBuilder:
                                              (context, pageRect, page) {
                                            // The viewer first lays out at its

                                            // default matrix, then fits the

                                            // page. Avoid preparing dense

                                            // notes at those transient sizes.

                                            if (!_pdfViewReady) {
                                              return const <Widget>[];
                                            }

                                            final visiblePage =
                                                pageRect.intersect(
                                              Rect.fromLTWH(
                                                0,
                                                0,
                                                viewerConstraints.maxWidth,
                                                viewerConstraints.maxHeight,
                                              ),
                                            );

                                            return [
                                              Positioned.fill(
                                                child: AnnotationLayer(
                                                  themeMode: themeMode,
                                                  cantoId: widget.cantoId,
                                                  pageNumber: page.pageNumber,
                                                  pageSize: Size(pageRect.width,
                                                      pageRect.height),
                                                  visibleRect: visiblePage
                                                          .isEmpty
                                                      ? Rect.zero
                                                      : visiblePage.shift(
                                                          -pageRect.topLeft),
                                                ),
                                              ),
                                            ];
                                          },
                                        ),
                                      ),
                          ),
                        ),

                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity:
                                    isCarousel && _showCarouselNavigationHint
                                        ? 1
                                        : 0,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOut,
                                child: Semantics(
                                  label: strings.t(
                                    'Toca el lado derecho para avanzar',
                                    'Tap the right side to advance',
                                  ),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.surface
                                          .withValues(alpha: 0.90),
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.42),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.22),
                                          blurRadius: 12,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 24,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── Panel MIDI Flotante ──────────────────────────────

                        // Hide the whole panel even when quota text adds height.

                        StreamBuilder<MidiState>(
                          stream: _midi.stateStream,
                          initialData: _midi.state,
                          builder: (context, snapshot) {
                            final currentMidiState =
                                snapshot.data ?? _midi.state;

                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOutCubic,
                              bottom: _showMidi
                                  ? (16 + MediaQuery.of(context).padding.bottom)
                                  : -MediaQuery.of(context).size.height * 2,
                              left: 12,
                              right: 12,
                              child: MidiPanel(
                                onClose: () =>
                                    setState(() => _showMidi = false),
                                onSwitchToVocal: _vocalSong != null
                                    ? () => setState(() {
                                          _showMidi = false;

                                          _showVocal = true;

                                          _lastAudioMode = 'vocal';
                                        })
                                    : null,
                                cantoId: canto.id,
                                errorMessage: _midiError,
                                midiState: currentMidiState,
                                onPlay: () =>
                                    _handlePlay(canto, currentMidiState),
                                onStop: _midi.stop,
                                onSeek: _midi.seek,
                                onSpeedChange: _midi.setSpeed,
                                onMetronomo: _midi.toggleMetronomo,
                                onVozToggle: (trackIndex, muted) =>
                                    _midi.setTrackMute(trackIndex, muted),
                                onVozVolumeChange: (trackIndex, volume) =>
                                    _midi.setTrackVolume(trackIndex, volume),
                                onResetVozVolumes: _midi.resetTrackVolumes,
                                onVozSolo: (soloTrackIndex) {
                                  // Activar solo la voz seleccionada y mutear las demás

                                  for (var v in currentMidiState.voces) {
                                    final shouldMute =
                                        v.trackIndex != soloTrackIndex;

                                    _midi.setTrackMute(
                                        v.trackIndex, shouldMute);
                                  }
                                },
                                isLoaded: currentMidiState.isLoaded,
                                isReady: currentMidiState.isReady,
                                accentColor: accentColor,
                              ),
                            );
                          },
                        ),

                        // ── Panel de Voces Cantadas (Estudio Coral) ──────────

                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                          bottom: _showVocal && _vocalSong != null
                              ? (16 + MediaQuery.of(context).padding.bottom)
                              : -500,
                          left: 12,
                          right: 12,
                          child: _vocalSong != null
                              ? VocalPanel(
                                  onClose: () =>
                                      setState(() => _showVocal = false),
                                  onSwitchToMidi: _hasMidi
                                      ? () => _switchToMidiFromVocal(canto,
                                          autoPlay: true)
                                      : null,
                                  onRequestPlayAccess: () =>
                                      _requestVocalPlayAccess(canto),
                                  onPlaybackStarted: () {
                                    _midi.stop();

                                    unawaited(ref
                                        .read(jukeboxProvider.notifier)
                                        .stop());
                                  },
                                  song: _vocalSong!,
                                  initialVoice: ref.watch(userVoiceProvider),
                                  accentColor: accentColor,
                                )
                              : const SizedBox.shrink(),
                        ),

                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          bottom: _showTools
                              ? 12 + MediaQuery.paddingOf(context).bottom
                              : -160,
                          left: 8,
                          right: 8,
                          child: AnnotationTools(
                            state: state,
                            onTool: (tool) {
                              if (tool == ToolType.text) {
                                ref
                                    .read(pdfEngineProvider.notifier)
                                    .setDrawingMode(true);

                                ref
                                    .read(pdfEngineProvider.notifier)
                                    .setTool(tool);

                                setState(() => _showDrawingPalette = false);
                              } else {
                                _selectDrawingTool(tool);
                              }
                            },
                            onNavigate: () {
                              ref
                                  .read(pdfEngineProvider.notifier)
                                  .setDrawingMode(false);

                              setState(() => _showDrawingPalette = false);
                            },
                            onUndo: () =>
                                ref.read(pdfEngineProvider.notifier).undo(),
                            onRedo: () =>
                                ref.read(pdfEngineProvider.notifier).redo(),
                            onClear: () => ref
                                .read(pdfEngineProvider.notifier)
                                .clearAllGlobal(),
                          ),
                        ),

                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          bottom: _showTools && _showDrawingPalette
                              ? 72 + MediaQuery.paddingOf(context).bottom
                              : -180,
                          left: 8,
                          right: 8,
                          child: AnnotationPalette(
                              themeMode: themeMode,
                              state: state,
                              onSize: (size) => ref
                                  .read(pdfEngineProvider.notifier)
                                  .setCurrentSize(size),
                              onColor: (color) {
                                ref
                                    .read(pdfEngineProvider.notifier)
                                    .setCurrentColor(color);

                                _annotationFeedback();
                              }),
                        ),

                        // ── Mini-Reproductor Jukebox Flotante para Estudio ──

                        Consumer(
                          builder: (context, ref, _) {
                            final jukebox = ref.watch(jukeboxProvider);

                            final isJukeboxActive = !jukebox.isDismissed &&
                                jukebox.currentSong != null;

                            final isPanelOpen =
                                _showMidi || _showVocal || _showTools;

                            if (!isJukeboxActive || isPanelOpen) {
                              return const SizedBox.shrink();
                            }

                            return Positioned(
                              bottom: MediaQuery.paddingOf(context).bottom + 8,
                              left: 12,
                              right: 12,
                              child: const JukeboxMiniPlayer(),
                            );
                          },
                        ),
                      ],
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

  /// Algunas apps receptoras ignoran `XFile.name` y muestran el nombre físico

  /// del archivo. Compartimos una copia con el nombre público para no filtrar

  /// IDs, huellas de caché ni versiones y para que las apps de mensajería

  /// reciban un MP3 real identificado como `audio/mpeg`, sin adjuntar asunto

  /// ni texto que pueda hacer que lo traten como un documento genérico.

  Future<File> _prepareShareFile(File source, String displayName) async {
    final tempDir = await getTemporaryDirectory();

    final shareDir = Directory(
      '${tempDir.path}/share_exports/'
      '${DateTime.now().microsecondsSinceEpoch}',
    );

    await shareDir.create(recursive: true);

    final target = File('${shareDir.path}/$displayName');

    return source.copy(target.path);
  }

  Future<bool> _shareMp3Files(List<File> files, List<String> names) async {
    return ExportShare.share(
      [
        for (var index = 0; index < files.length; index++)
          XFile(files[index].path, name: names[index], mimeType: 'audio/mpeg'),
      ],
      origin: _shareButtonRect(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

// MIDI Panel — Reproductor completo

// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════

// Widgets auxiliares

// ══════════════════════════════════════════════════════════════════════════════

class _LoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 60, color: Colors.grey)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                  duration: 1500.ms,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5))
              .scaleXY(
                  begin: 0.95,
                  end: 1.05,
                  duration: 1500.ms,
                  curve: Curves.easeInOutSine)
              .then()
              .scaleXY(
                  begin: 1.05,
                  end: 0.95,
                  duration: 1500.ms,
                  curve: Curves.easeInOutSine),
          const SizedBox(height: 20),
          Text('Preparando partitura...',
                  style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w500))
              .animate(onPlay: (c) => c.repeat())
              .fade(duration: 1500.ms, begin: 0.4, end: 1.0)
              .then()
              .fade(duration: 1500.ms, begin: 1.0, end: 0.4),
        ],
      ),
    );
  }
}

class _TopBarBtn extends StatelessWidget {
  final IconData? icon;

  final Widget? child;

  final bool isActive;

  final Color? activeColor;

  final VoidCallback onTap;

  final String tooltip;

  const _TopBarBtn(
      {this.icon,
      this.child,
      this.isActive = false,
      this.activeColor,
      required this.onTap,
      required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = activeColor ?? theme.colorScheme.primary;

    return IconButton(
      icon: child ??
          Icon(icon!,
              color: isActive ? color : theme.colorScheme.onSurfaceVariant),
      onPressed: onTap,
      tooltip: tooltip,
    );
  }
}
