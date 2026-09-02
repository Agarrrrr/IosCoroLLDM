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
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/midi/midi_export_service.dart';
import 'package:coro_lldm/core/storage/android_file_saver.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/features/premium/premium_dialog.dart';

const List<double> _kSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
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
  bool _showTopBar = true;
  bool _showTools = false;
  bool _showMidi = false;
  bool _showDrawingPalette = false;

  final MidiEngine _midi = MidiEngine();
  bool _hasMidi = false;
  bool _midiIniciado = false;
  bool _idiomaVerificado = false;
  bool _pdfAdRegistered = false;

  final PdfViewerController _pdfController = PdfViewerController();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pdfEngineProvider.notifier).init(widget.cantoId);
    });
  }

  void _initMidi(Canto canto) async {
    debugPrint('🎵 [MidiEngine] Inicializando para el canto: ${canto.nombre}');
    debugPrint('🎵 [MidiEngine] midiArchivo del canto: "${canto.midiArchivo}"');

    if (canto.midiArchivo == null || canto.midiArchivo!.isEmpty) {
      debugPrint('🎵 [MidiEngine] Este canto no tiene archivo MIDI asignado.');
      return;
    }

    setState(() {
      _hasMidi = true;
    });

    try {
      // Descarga bajo demanda (si ya existe en disco, se usa al instante)
      final localMidi = await OfflineFiles.ensureMidi(canto);
      if (!mounted) return;
      debugPrint('🎵 [NativeMidiEngine] Cargando MIDI: ${localMidi.path}');
      _midi.loadMidi(localMidi.path, canto.nombre);
      ref.read(syncManagerProvider.notifier).refresh();
    } catch (e) {
      debugPrint('🎵 [MidiEngine] No se pudo obtener el archivo MIDI: $e');
    }
  }

  void _cambiarIdioma(Canto canto) {
    final vinculo = canto.vinculoIdioma;
    if (vinculo == null || vinculo.isEmpty) return;
    context.pushReplacement('/visor/$vinculo?manualLanguage=1');
  }

  @override
  void dispose() {
    _carouselSnapTimer?.cancel();
    _carouselHintTimer?.cancel();
    _carouselNavigationEpoch++;
    _midi.dispose();
    super.dispose();
  }

  void _toggleTopBar() {
    final state = ref.read(pdfEngineProvider);
    if (state.isDrawingMode || _showMidi) return;
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
      if (nextVisible) _showMidi = false;
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

  void _toggleMidi() {
    setState(() {
      _showMidi = !_showMidi;
      if (_showMidi) {
        _showTools = false;
        _showDrawingPalette = false;
        ref.read(pdfEngineProvider.notifier).setDrawingMode(false);
      }
    });
  }

  Future<void> _handlePlay(Canto canto, MidiState midiState) async {
    if (midiState.isPlaying) {
      _midi.pause();
      return;
    }
    final allowed = await ref
        .read(monetizationProvider.notifier)
        .consumeAudioAccess(canto.id);
    if (!mounted) return;
    if (allowed) {
      _midi.play();
      return;
    }
    await _showAudioLimitDialog(canto);
  }

  Future<void> _showAudioLimitDialog(Canto canto) async {
    final strings = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.t('Límite diario', 'Daily limit')),
        content: Text(
          strings.t(
            'La versión gratuita permite escuchar 5 cantos distintos al día. Puedes obtener un audio extra viendo un anuncio o activar Premium.',
            'The free version lets you listen to 5 different songs per day. Watch an ad for one extra audio or activate Premium.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.t('Ahora no', 'Not now')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              showPremiumDialog(context);
            },
            child: const Text('Premium'),
          ),
          if (AdUnitIds.rewarded != null)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final earned = await AdsService.instance.showRewarded();
                if (!mounted) return;
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
                  return;
                }
                final controller = ref.read(monetizationProvider.notifier);
                await controller.grantRewardedAudio();
                await controller.consumeAudioAccess(canto.id);
                if (mounted) _midi.play();
              },
              child: Text(strings.t('Ver anuncio', 'Watch ad')),
            ),
        ],
      ),
    );
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

  // Compatibilidad temporal con el menú anterior durante la migración.
  // ignore: unused_element
  Future<void> _mostrarMenuCompartir(Canto canto, String? localPdfPath) async {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Compartir "${canto.nombre}"',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded,
                        color: theme.colorScheme.primary),
                  ),
                  title: Text('Compartir Partitura (PDF)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text('Enviar archivo PDF de la partitura',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _guardarOCompartirPdf(canto, localPdfPath);
                  },
                ),
                if (canto.midiArchivo != null && canto.midiArchivo!.isNotEmpty)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note_rounded,
                          color: Colors.amber),
                    ),
                    title: Text('Compartir Audio (MIDI)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    subtitle: Text('Enviar archivo de audio MIDI',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey)),
                    onTap: () async {
                      Navigator.pop(context);
                      final midiFile = await OfflineFiles.midiFile(canto.id);
                      if (!mounted) return;
                      if (await midiFile.exists()) {
                        final midiName =
                            MidiExportService.displayMidiFileName(canto);
                        final shareMidi =
                            await _prepareShareFile(midiFile, midiName);
                        await Share.shareXFiles(
                          [
                            XFile(shareMidi.path,
                                name: midiName, mimeType: 'audio/midi')
                          ],
                          text: 'Audio MIDI: ${canto.nombre}',
                        );
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'El archivo de audio MIDI aún se está descargando.')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _mostrarMenuCompartirMp3(
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
        midiError = 'No se pudo preparar el MIDI: $e';
      }
    }
    if (!mounted) return;

    final selection = await showModalBottomSheet<_ShareSelection>(
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
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${strings.t(Platform.isAndroid ? 'Exportar' : 'Compartir', Platform.isAndroid ? 'Export' : 'Share')} '
                '"${canto.nombre}"',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(strings.t('Partitura (PDF)', 'Sheet Music (PDF)')),
                subtitle: Text(
                  strings.t(
                    Platform.isAndroid
                        ? 'Guardar o compartir la partitura'
                        : 'Compartir la partitura',
                    Platform.isAndroid
                        ? 'Save or share the score'
                        : 'Share the score',
                  ),
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  const _ShareSelection(_ShareKind.pdf),
                ),
              ),
              if (voices.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(
                    Icons.groups_rounded,
                    color: Colors.amber,
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
                  leading: const Icon(
                    Icons.library_music_rounded,
                    color: Colors.deepOrange,
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
                      color: Colors.grey,
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
      await _mostrarDialogoLimiteExport(canto, localPdfPath);
      return;
    }

    if (!Platform.isAndroid) {
      if (selection.kind == _ShareKind.allVoices ||
          selection.kind == _ShareKind.voicesOnly) {
        await _exportarTodasLasVocesIOS(
          canto,
          voices,
          includeEnsemble: selection.kind == _ShareKind.allVoices,
        );
      } else {
        await _exportarAudioIOS(canto, selection.voice);
      }
      return;
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
    if (renderBox == null) return Rect.zero;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  /// Diálogo de límite diario de exports alcanzado (solo usuarios free).
  Future<void> _mostrarDialogoLimiteExport(
    Canto canto,
    String? localPdfPath,
  ) async {
    final strings = AppStrings.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(strings.t('Límite diario alcanzado', 'Daily limit reached')),
        content: Text(strings.t(
          'Puedes exportar 3 audios gratis al día. ¿Quieres ver un anuncio breve '
              'para obtener 1 más, o apoyar el desarrollo con Premium?',
          'You can export 3 free audios per day. Watch a short ad to get 1 more, '
              'or support the app with Premium.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(strings.t('Cancelar', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'premium'),
            child: Text(strings.t('Ir a Premium', 'Go Premium')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'rewarded'),
            child: Text(strings.t('Ver anuncio', 'Watch ad')),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result == 'cancel') return;
    if (result == 'premium') {
      await showDialog<void>(
        context: context,
        builder: (_) => const PremiumDialog(),
      );
      return;
    }
    // 'rewarded'
    final earned = await AdsService.instance.showRewarded();
    if (!mounted) return;
    if (earned) {
      await ref.read(monetizationProvider.notifier).grantRewardedExport();
      await _mostrarMenuCompartirMp3(canto, localPdfPath);
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
  }

  Future<void> _exportarAudioIOS(
    Canto canto,
    MidiExportVoice? voice,
  ) async {
    final strings = AppStrings.of(context);
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
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
      final displayFileName = MidiExportService.displayFileName(
        canto,
        voice: voice,
      );
      final shareMp3 = await _prepareShareFile(mp3, displayFileName);
      if (!mounted) return;
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      await Share.shareXFiles(
        [XFile(shareMp3.path, name: displayFileName, mimeType: 'audio/mpeg')],
        subject: canto.nombre,
        sharePositionOrigin: _shareButtonRect(),
      );
      await ref.read(monetizationProvider.notifier).consumeAudioExport();
      unawaited(AdsService.instance.onExportCompleted());
    } catch (e) {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${strings.t('No se pudo exportar el audio', 'Could not export audio')}: $e')),
      );
    }
  }

  Future<void> _exportarTodasLasVocesIOS(
      Canto canto, List<MidiExportVoice> voices,
      {bool includeEnsemble = true}) async {
    final strings = AppStrings.of(context);
    final total = voices.length + (includeEnsemble ? 1 : 0);
    final progress = ValueNotifier<(int, int, String)>(
        (0, total, strings.t('Voces individuales', 'Individual voices')));
    var cancelled = false;
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
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
                      '${value.$3}\n$completed ${strings.t('de', 'of')} $total'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                progress.value = progress.value;
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
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      if (files.isEmpty || cancelled) return;
      final names = <String>[
        if (includeEnsemble) MidiExportService.displayFileName(canto),
        for (final voice in voices)
          MidiExportService.displayFileName(canto, voice: voice),
      ];
      final shareFiles = await Future.wait([
        for (var i = 0; i < files.length; i++)
          _prepareShareFile(files[i], names[i]),
      ]);
      await Share.shareXFiles(
        [
          for (var i = 0; i < shareFiles.length; i++)
            XFile(shareFiles[i].path, name: names[i], mimeType: 'audio/mpeg'),
        ],
        subject: canto.nombre,
        sharePositionOrigin: _shareButtonRect(),
      );
      await ref.read(monetizationProvider.notifier).consumeAudioExport();
      unawaited(AdsService.instance.onExportCompleted());
    } catch (e) {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${strings.t('No se pudieron exportar los MP3', 'Could not export MP3s')}: $e')),
      );
    } finally {
      progress.dispose();
    }
  }

  Future<_ExportDestination?> _elegirDestino() async {
    if (!Platform.isAndroid) return _ExportDestination.share;
    final strings = AppStrings.of(context);
    return showModalBottomSheet<_ExportDestination>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: Text(strings.t(
                'Guardar en dispositivo',
                'Save to device',
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
      await Share.shareXFiles(
        [XFile(sharePdf.path, name: pdfName, mimeType: 'application/pdf')],
        subject: canto.nombre,
        sharePositionOrigin: _shareButtonRect(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          '${strings.t('No se pudo guardar o compartir el PDF', 'Could not save or share the PDF')}: $error',
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
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
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
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
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
        final mp3Name = MidiExportService.displayFileName(canto, voice: voice);
        final shareMp3 = await _prepareShareFile(mp3, mp3Name);
        await Share.shareXFiles(
          [XFile(shareMp3.path, name: mp3Name, mimeType: 'audio/mpeg')],
          subject: canto.nombre,
          sharePositionOrigin: _shareButtonRect(),
        );
        await ref.read(monetizationProvider.notifier).consumeAudioExport();
        unawaited(AdsService.instance.onExportCompleted());
      }
    } catch (e) {
      if (!mounted) return;
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${strings.t('No se pudo', 'Could not')} $operation ${strings.t('el MP3', 'the MP3')}: $e')),
      );
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
    var dialogOpen = true;
    var operation = strings.t('crear', 'create');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
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
                progress.value = progress.value;
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
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
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
        final shareFiles = await Future.wait([
          for (var i = 0; i < files.length; i++)
            _prepareShareFile(files[i], names[i]),
        ]);
        await Share.shareXFiles(
          [
            for (var i = 0; i < shareFiles.length; i++)
              XFile(
                shareFiles[i].path,
                name: names[i],
                mimeType: 'audio/mpeg',
              ),
          ],
          subject: canto.nombre,
          sharePositionOrigin: _shareButtonRect(),
        );
        await ref.read(monetizationProvider.notifier).consumeAudioExport();
        unawaited(AdsService.instance.onExportCompleted());
      }
    } catch (e) {
      if (!mounted) return;
      if (dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${strings.t('No se pudieron', 'Could not')} $operation ${strings.t('los MP3', 'the MP3s')}: $e')),
      );
    } finally {
      progress.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfEngineProvider);
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final isCarousel = ref.watch(pdfNavModeProvider);
    final cantos = ref.watch(cantosBaseProvider).value ?? [];
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

    final preferredLanguage = ref.read(languageFilterProvider);
    final willRedirect = !widget.ignorePreferredLanguage &&
        preferredLanguage != canto.idioma &&
        canto.vinculoIdioma != null &&
        canto.vinculoIdioma!.isNotEmpty;
    if (!_pdfAdRegistered &&
        canto.id == widget.cantoId &&
        canto.id.isNotEmpty &&
        !willRedirect) {
      _pdfAdRegistered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AdsService.instance.onPdfOpened();
      });
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

    // Evaluamos el brillo del sistema directamente, ya que el modo "Sepia" ahora delega en el SO el cambio a oscuro (Quiet)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSepiaProfile =
        themeMode == AppThemeMode.sepia || themeMode == AppThemeMode.quiet;
    final isNormalDark = themeMode == AppThemeMode.oscuroNormal;

    // Filtro para modo oscuro (Quiet) que mapea el fondo blanco a gris oscuro y notas a claro
    const quietFilter = ColorFilter.matrix([
      -0.65098,
      0.0,
      0.0,
      0.0,
      226.0,
      0.0,
      -0.66275,
      0.0,
      0.0,
      232.0,
      0.0,
      0.0,
      -0.68235,
      0.0,
      240.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]);

    // Filtro original en negativo (para tema oscuro normal)
    const invertFilter = ColorFilter.matrix([
      -1.0,
      0.0,
      0.0,
      0.0,
      255.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      255.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      255.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]);

    // Oscuro normal: blanco del PDF -> #1B2430 y negro -> #F1F5F9.
    const normalDarkFilter = ColorFilter.matrix([
      -0.83922,
      0.0,
      0.0,
      0.0,
      241.0,
      0.0,
      -0.81961,
      0.0,
      0.0,
      245.0,
      0.0,
      0.0,
      -0.78824,
      0.0,
      249.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]);

    // Filtro sepia para la partitura en modo sepia (blanco -> #F4ECD8, negro -> #5b4636)
    const sepiaFilter = ColorFilter.matrix([
      0.60000,
      0.0,
      0.0,
      0.0,
      91.0,
      0.0,
      0.65098,
      0.0,
      0.0,
      70.0,
      0.0,
      0.0,
      0.63529,
      0.0,
      54.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
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
                      color: theme.appBarTheme.backgroundColor ??
                          theme.scaffoldBackgroundColor,
                      border: Border(
                          bottom:
                              BorderSide(color: Colors.grey.withOpacity(0.2))),
                    ),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 60,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20),
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/');
                                }
                              },
                            ),
                            Expanded(
                              child: Text(
                                canto.nombre,
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (canto.vinculoIdioma != null &&
                                canto.vinculoIdioma!.isNotEmpty)
                              Semantics(
                                button: true,
                                label: strings.t(
                                  'Cambiar idioma de la partitura',
                                  'Change score language',
                                ),
                                child: InkWell(
                                  onTap: () => _cambiarIdioma(canto),
                                  borderRadius: BorderRadius.circular(14),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: accentColor.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      canto.idioma == 'es'
                                          ? 'ESP  |  ENG'
                                          : 'ENG  |  ESP',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_hasMidi)
                              _TopBarBtn(
                                icon: Icons.piano_rounded,
                                isActive: _showMidi,
                                activeColor: accentColor,
                                onTap: _toggleMidi,
                                tooltip: strings.t(
                                  'Reproductor MIDI',
                                  'MIDI player',
                                ),
                              ),
                            SizedBox(
                              key: _shareButtonKey,
                              child: _TopBarBtn(
                                icon: Icons.ios_share_rounded,
                                onTap: () => _mostrarMenuCompartirMp3(
                                    canto, state.localPath),
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
                                : state.error != null
                                    ? Center(child: Text(state.error!))
                                    : ColorFiltered(
                                        colorFilter: isDark
                                            ? (isSepiaProfile
                                                ? quietFilter
                                                : isNormalDark
                                                    ? normalDarkFilter
                                                    : invertFilter)
                                            : (isSepiaProfile
                                                ? sepiaFilter
                                                : const ColorFilter.mode(
                                                    Colors.transparent,
                                                    BlendMode.multiply)),
                                        child: PdfViewer.file(
                                          state.localPath!,
                                          key: ValueKey(state.localPath!),
                                          controller: _pdfController,
                                          params: PdfViewerParams(
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
                                                maxRasterDimension /
                                                    longestSide,
                                              )
                                                  .clamp(0.15, estimatedScale)
                                                  .toDouble();
                                            },
                                            errorBannerBuilder: (context, error,
                                                    stackTrace, documentRef) =>
                                                Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(24.0),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .error_outline_rounded,
                                                      color: Colors.red,
                                                      size: 48,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    const Text(
                                                      'No se pudo abrir la partitura',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      '$error',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
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
                                                (document, controller) {
                                              if (isCarousel) {
                                                unawaited(
                                                  _irAPaginaCarrusel(
                                                    controller.pageNumber ?? 1,
                                                    duration: Duration.zero,
                                                  ),
                                                );
                                                _mostrarPistaDeNavegacionCarrusel(
                                                  pageCount:
                                                      document.pages.length,
                                                );
                                              } else {
                                                _calcularLimiteEscala(document);
                                                _ajustarZoomAlAncho();
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
                                            calculateCurrentPageNumber:
                                                isCarousel
                                                    ? (visibleRect, pageRects,
                                                            _) =>
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
                                                    final pageLayouts =
                                                        <Rect>[];
                                                    var x = params.margin;
                                                    for (final page in pages) {
                                                      pageLayouts.add(
                                                        Rect.fromLTWH(
                                                          x,
                                                          (height -
                                                                  page.height) /
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
                                                        final width = pages
                                                                .fold(
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
                                            backgroundColor: Colors.white,
                                            pageDropShadow: null,
                                            pageOverlaysBuilder:
                                                (context, pageRect, page) => [
                                              Positioned.fill(
                                                child: RepaintBoundary(
                                                  child: AnnotationLayer(
                                                    cantoId: widget.cantoId,
                                                    pageNumber: page.pageNumber,
                                                    pageSize: Size(
                                                        pageRect.width,
                                                        pageRect.height),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
                        // NOTA: Se mueve a -380 cuando está cerrado para asegurar que no se asome
                        // de manera poco profesional en pantallas cortas o con partituras de una página.
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
                                  : -380,
                              left: 12,
                              right: 12,
                              child: _MidiPanel(
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

                        // ── Panel Herramientas de Dibujo ─────────────────────
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          bottom: _showTools
                              ? 12 + MediaQuery.of(context).padding.bottom
                              : -120,
                          left: 8,
                          right: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10)
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ToolBtn(
                                        icon: Icons.pan_tool_rounded,
                                        isActive: !state.isDrawingMode,
                                        tooltip: 'Navegar por la partitura',
                                        onTap: () {
                                          ref
                                              .read(pdfEngineProvider.notifier)
                                              .setDrawingMode(false);
                                          setState(() =>
                                              _showDrawingPalette = false);
                                          _annotationFeedback();
                                        }),
                                    Container(
                                        width: 1,
                                        height: 20,
                                        color: Colors.grey.withOpacity(0.3),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 5)),
                                    _ToolBtn(
                                      icon: Icons.edit_rounded,
                                      isActive: state.isDrawingMode &&
                                          state.currentTool == ToolType.pencil,
                                      tooltip: 'Lápiz y opciones',
                                      onTap: () =>
                                          _selectDrawingTool(ToolType.pencil),
                                    ),
                                    _ToolBtn(
                                        icon: Icons.text_fields_rounded,
                                        isActive: state.isDrawingMode &&
                                            state.currentTool == ToolType.text,
                                        tooltip: 'Insertar texto',
                                        onTap: () {
                                          final e = ref
                                              .read(pdfEngineProvider.notifier);
                                          e.setDrawingMode(true);
                                          e.setTool(ToolType.text);
                                          setState(() =>
                                              _showDrawingPalette = false);
                                          _annotationFeedback();
                                        }),
                                    _ToolBtn(
                                      icon: Icons.cleaning_services_rounded,
                                      isActive: state.isDrawingMode &&
                                          state.currentTool == ToolType.eraser,
                                      tooltip: 'Borrador y opciones',
                                      onTap: () =>
                                          _selectDrawingTool(ToolType.eraser),
                                    ),
                                    if (state.isDrawingMode) ...[
                                      Container(
                                          width: 1,
                                          height: 20,
                                          color: Colors.grey.withOpacity(0.3),
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 5)),
                                      _ToolBtn(
                                        icon: Icons.undo_rounded,
                                        isActive: false,
                                        onTap: () => ref
                                            .read(pdfEngineProvider.notifier)
                                            .undo(),
                                      ),
                                      _ToolBtn(
                                        icon: Icons.redo_rounded,
                                        isActive: false,
                                        onTap: () => ref
                                            .read(pdfEngineProvider.notifier)
                                            .redo(),
                                      ),
                                      _ToolBtn(
                                        icon: Icons.delete_sweep_rounded,
                                        isActive: false,
                                        onTap: () => ref
                                            .read(pdfEngineProvider.notifier)
                                            .clearAllGlobal(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Paleta de Dibujo Flotante (Grosor y Color) ─────────
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          bottom: (_showTools && _showDrawingPalette)
                              ? 72 + MediaQuery.of(context).padding.bottom
                              : -120,
                          left: 8,
                          right: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 10),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10)
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Slider de grosor
                                    _StrokePreview(
                                      sizeValue:
                                          state.currentTool == ToolType.eraser
                                              ? state.eraserSize
                                              : state.currentSize,
                                      isEraser:
                                          state.currentTool == ToolType.eraser,
                                      color:
                                          state.currentTool == ToolType.eraser
                                              ? accentColor
                                              : state.currentColor,
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                  overlayRadius: 12),
                                          trackHeight: 2,
                                          activeTrackColor: accentColor,
                                          inactiveTrackColor:
                                              Colors.grey.withOpacity(0.3),
                                          thumbColor: accentColor,
                                        ),
                                        child: Slider(
                                          value: state.currentTool ==
                                                  ToolType.eraser
                                              ? state.eraserSize
                                              : state.currentSize,
                                          min: 1.0,
                                          max: state.currentTool ==
                                                  ToolType.eraser
                                              ? 40.0
                                              : 15.0,
                                          onChanged: (val) => ref
                                              .read(pdfEngineProvider.notifier)
                                              .setCurrentSize(val),
                                          onChangeEnd: (_) =>
                                              HapticFeedback.selectionClick(),
                                        ),
                                      ),
                                    ),

                                    // Selector de colores solo si no es borrador
                                    if (state.currentTool !=
                                        ToolType.eraser) ...[
                                      Container(
                                          width: 1,
                                          height: 20,
                                          color: Colors.grey.withOpacity(0.3),
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 10)),
                                      _ColorBtn(
                                          color: Colors.black,
                                          isActive: state.currentColor ==
                                              Colors.black,
                                          onTap: () {
                                            ref
                                                .read(
                                                    pdfEngineProvider.notifier)
                                                .setCurrentColor(Colors.black);
                                            _annotationFeedback();
                                          }),
                                      _ColorBtn(
                                          color: Colors.red,
                                          isActive:
                                              state.currentColor == Colors.red,
                                          onTap: () {
                                            ref
                                                .read(
                                                    pdfEngineProvider.notifier)
                                                .setCurrentColor(Colors.red);
                                            _annotationFeedback();
                                          }),
                                      _ColorBtn(
                                          color: Colors.blue,
                                          isActive:
                                              state.currentColor == Colors.blue,
                                          onTap: () {
                                            ref
                                                .read(
                                                    pdfEngineProvider.notifier)
                                                .setCurrentColor(Colors.blue);
                                            _annotationFeedback();
                                          }),
                                      _ColorBtn(
                                          color: Colors.white,
                                          isActive: state.currentColor ==
                                              Colors.white,
                                          onTap: () {
                                            ref
                                                .read(
                                                    pdfEngineProvider.notifier)
                                                .setCurrentColor(Colors.white);
                                            _annotationFeedback();
                                          }),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
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
  /// IDs, huellas de caché ni versiones y para que Android resuelva `.mp3`
  /// como audio MPEG al entregar el URI a WhatsApp.
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
}

// ══════════════════════════════════════════════════════════════════════════════
// MIDI Panel — Reproductor completo
// ══════════════════════════════════════════════════════════════════════════════
class _MidiPanel extends StatefulWidget {
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

  const _MidiPanel({
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
  State<_MidiPanel> createState() => _MidiPanelState();
}

class _MidiPanelState extends State<_MidiPanel> {
  bool _showSettings = false;
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(1, '0');
    final s = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _abrirMezcladorModal(BuildContext parentContext) {
    showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        final localVolumes = <int, double>{
          for (final voz in widget.midiState.voces)
            voz.trackIndex: voz.volumen.clamp(0.0, 1.0).toDouble(),
        };
        final localMuted = <int, bool>{
          for (final voz in widget.midiState.voces) voz.trackIndex: !voz.activa,
        };

        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.45,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          tooltip: 'Regresar',
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Mezclador de voces',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            widget.onResetVozVolumes();
                            setModalState(() {
                              for (final voz in widget.midiState.voces) {
                                localVolumes[voz.trackIndex] = 1.0;
                                localMuted[voz.trackIndex] = false;
                              }
                            });
                          },
                          icon: Icon(Icons.rotate_left_rounded,
                              size: 16, color: widget.accentColor),
                          label: Text(
                            'Restablecer',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: widget.midiState.voces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final voz = widget.midiState.voces[index];
                        final volume =
                            localVolumes[voz.trackIndex] ?? voz.volumen;
                        final muted = localMuted[voz.trackIndex] ?? !voz.activa;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !muted
                                  ? widget.accentColor.withOpacity(0.25)
                                  : Colors.grey.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  !muted && volume > 0
                                      ? (volume > 0.5
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_down_rounded)
                                      : Icons.volume_off_rounded,
                                  size: 20,
                                  color:
                                      !muted ? widget.accentColor : Colors.grey,
                                ),
                                onPressed: () {
                                  final nextMuted = !muted;
                                  setModalState(() {
                                    localMuted[voz.trackIndex] = nextMuted;
                                  });
                                  widget.onVozToggle(
                                    voz.trackIndex,
                                    nextMuted,
                                  );
                                },
                                tooltip: muted
                                    ? 'Activar ${voz.nombre}'
                                    : 'Silenciar ${voz.nombre}',
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onLongPress: () =>
                                              widget.onVozSolo(voz.trackIndex),
                                          child: Text(
                                            voz.nombre,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: !muted
                                                  ? theme.colorScheme.onSurface
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${(volume * 100).round()}%',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: !muted
                                                ? widget.accentColor
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Slider(
                                      value: volume.clamp(0.0, 1.0).toDouble(),
                                      activeColor: widget.accentColor,
                                      inactiveColor:
                                          widget.accentColor.withOpacity(0.2),
                                      onChanged: (value) {
                                        setModalState(() {
                                          localVolumes[voz.trackIndex] = value;
                                        });
                                        widget.onVozVolumeChange(
                                            voz.trackIndex, value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool loading = !widget.isReady || !widget.isLoaded;

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.accentColor.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador metrónomo (flash en cada beat)
            Row(
              children: [
                Icon(Icons.piano_rounded, color: widget.accentColor, size: 18),
                const SizedBox(width: 8),
                Text('Reproductor',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: widget.accentColor)),
                const Spacer(),
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
                      final grouping = groups.any((group) => group > 1)
                          ? ' · ${groups.join('+')}'
                          : '';
                      final groupStarts = <int>[];
                      var groupOffset = 0;
                      for (final group in groups) {
                        groupStarts.add(groupOffset);
                        groupOffset += group;
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$numerator/$denominator$grouping',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 7),
                          ...List.generate(beats, (index) {
                            final isCurrent =
                                index == widget.midiState.beatIndex;
                            final isFirst = index == 0;
                            final isGroupStart = groupStarts.contains(index);
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
                                        ? Colors.redAccent
                                        : widget.accentColor)
                                    : Colors.grey.withOpacity(0.3),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: isFirst
                                              ? Colors.redAccent
                                                  .withOpacity(0.5)
                                              : widget.accentColor
                                                  .withOpacity(0.5),
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
                // Botón Ajustes
                IconButton(
                  onPressed: () =>
                      setState(() => _showSettings = !_showSettings),
                  icon: Icon(
                    _showSettings
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.settings_rounded,
                    color: _showSettings
                        ? widget.accentColor
                        : Colors.grey.withOpacity(0.8),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
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
                    inactiveTrackColor: widget.accentColor.withOpacity(0.2),
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
                              fontSize: 11, color: Colors.grey)),
                      Text(_formatTime(widget.midiState.tiempoTotal),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Controles principales ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Metrónomo toggle
                _GoldIconBtn(
                  isActive: widget.midiState.metronomoActivo,
                  activeColor: widget.accentColor,
                  onTap: loading ? null : widget.onMetronomo,
                  tooltip: 'Metrónomo',
                  size: 22,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOutCubic,
                    tween: Tween<double>(
                      begin: 0.0,
                      end: widget.midiState.metronomoActivo &&
                              widget.midiState.isPlaying
                          ? (widget.midiState.beatSerial.isEven ? -0.42 : 0.42)
                          : 0.0,
                    ),
                    builder: (context, angle, child) {
                      return MetronomeIcon(
                        color: widget.midiState.metronomoActivo
                            ? widget.accentColor
                            : Colors.grey.withOpacity(0.6),
                        size: 20,
                        rotationAngle: angle,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Play / Pause
                GestureDetector(
                  onTap: loading ? null : widget.onPlay,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: loading
                          ? Colors.grey.withOpacity(0.2)
                          : widget.accentColor,
                      boxShadow: loading
                          ? []
                          : [
                              BoxShadow(
                                  color: widget.accentColor.withOpacity(0.4),
                                  blurRadius: 12)
                            ],
                    ),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Icon(
                            widget.midiState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Stop
                _GoldIconBtn(
                  icon: Icons.stop_rounded,
                  isActive: false,
                  activeColor: widget.accentColor,
                  onTap: loading ? null : widget.onStop,
                  tooltip: 'Detener',
                  size: 22,
                ),
                const SizedBox(width: 8),
                _GoldIconBtn(
                  icon: Icons.tune_rounded,
                  isActive: false,
                  activeColor: widget.accentColor,
                  onTap: loading ? null : () => _abrirMezcladorModal(context),
                  tooltip: 'Mezclador de voces',
                  size: 22,
                ),
              ],
            ),

            // Sección Expandible de Ajustes
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: _showSettings
                  ? Column(
                      children: [
                        const SizedBox(height: 16),
                        // ── Selector de velocidad ──────────────────────────────────────
                        Row(
                          children: [
                            Icon(Icons.speed_rounded,
                                size: 16, color: Colors.grey.withOpacity(0.8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _kSpeeds.map((s) {
                                    final active =
                                        (widget.midiState.speed - s).abs() <
                                            0.05;
                                    return GestureDetector(
                                      onTap: loading
                                          ? null
                                          : () => widget.onSpeedChange(s),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: active
                                              ? widget.accentColor
                                              : widget.accentColor
                                                  .withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: active
                                                  ? widget.accentColor
                                                  : widget.accentColor
                                                      .withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '${s}x',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: active
                                                ? Colors.white
                                                : widget.accentColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  color: theme.colorScheme.primary.withOpacity(0.5))
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
                      color: Colors.grey,
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
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;
  final String tooltip;

  const _TopBarBtn(
      {required this.icon,
      this.isActive = false,
      this.activeColor,
      required this.onTap,
      required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = activeColor ?? theme.colorScheme.primary;
    return IconButton(
      icon: Icon(icon, color: isActive ? color : Colors.grey),
      onPressed: onTap,
      tooltip: tooltip,
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
    final inactiveColor = Colors.grey.withOpacity(0.6);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
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
      Offset(0, -size.height * 0.5),
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

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String? tooltip;

  const _ToolBtn(
      {required this.icon,
      required this.isActive,
      required this.onTap,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = InkWell(
      onTap: onTap,
      enableFeedback: true,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.14)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.45)
                : Colors.transparent,
          ),
        ),
        child: Icon(icon,
            size: 20,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.58)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _StrokePreview extends StatelessWidget {
  final double sizeValue;
  final bool isEraser;
  final Color color;

  const _StrokePreview({
    required this.sizeValue,
    required this.isEraser,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diameter = (sizeValue * 1.7).clamp(4.0, 30.0).toDouble();
    return Tooltip(
      message: isEraser ? 'Tamaño del borrador' : 'Tamaño del pincel',
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _StrokePreviewPainter(
            diameter: diameter,
            color: color,
            isEraser: isEraser,
            background: theme.colorScheme.surface,
          ),
        ),
      ),
    );
  }
}

class _StrokePreviewPainter extends CustomPainter {
  final double diameter;
  final Color color;
  final bool isEraser;
  final Color background;

  const _StrokePreviewPainter({
    required this.diameter,
    required this.color,
    required this.isEraser,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = diameter / 2;
    final outline = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (isEraser) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
              .withOpacity(background.computeLuminance() > 0.5 ? 0.08 : 0.18),
      );
      canvas.drawCircle(center, radius, outline);
    } else {
      canvas.drawCircle(center, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePreviewPainter oldDelegate) =>
      oldDelegate.diameter != diameter ||
      oldDelegate.color != color ||
      oldDelegate.isEraser != isEraser ||
      oldDelegate.background != background;
}

class _ColorBtn extends StatelessWidget {
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _ColorBtn(
      {required this.color, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = color == Colors.white ? Colors.grey : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              if (isActive)
                BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
