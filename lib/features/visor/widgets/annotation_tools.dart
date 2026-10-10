import 'package:flutter/material.dart';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'annotation_theme_palette.dart';
import 'package:coro_lldm/app/accessible_colors.dart';

class AnnotationTools extends StatelessWidget {
  final PdfEngineState state;
  final ValueChanged<ToolType> onTool;
  final VoidCallback onNavigate, onUndo, onClear;
  final VoidCallback? onRedo;
  const AnnotationTools(
      {super.key,
      required this.state,
      required this.onTool,
      required this.onNavigate,
      required this.onUndo,
      this.onRedo,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget button(
            String label, Widget icon, bool selected, VoidCallback? action) =>
        IconButton(
            tooltip: label,
            onPressed: action,
            style: IconButton.styleFrom(
                foregroundColor: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                backgroundColor:
                    selected ? scheme.primaryContainer : Colors.transparent),
            icon: icon);
    return Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        elevation: 4,
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              button(
                  'Navegar por la partitura',
                  const Icon(Icons.pan_tool_rounded),
                  !state.isDrawingMode,
                  onNavigate),
              for (final tool in [
                ToolType.pencil,
                ToolType.highlighter,
                ToolType.text,
                ToolType.eraser
              ])
                button(
                    switch (tool) {
                      ToolType.pencil => 'Lápiz y opciones',
                      ToolType.highlighter => 'Subrayador y opciones',
                      ToolType.text => 'Insertar texto',
                      ToolType.eraser => 'Borrador y opciones'
                    },
                    tool == ToolType.eraser || tool == ToolType.highlighter
                        ? AnnotationToolIcon(tool: tool)
                        : Icon(tool == ToolType.pencil
                            ? Icons.edit_rounded
                            : Icons.text_fields_rounded),
                    state.isDrawingMode && state.currentTool == tool,
                    () => onTool(tool)),
              if (state.isDrawingMode) ...[
                button('Deshacer', const Icon(Icons.undo_rounded), false,
                    state.canUndo ? onUndo : null),
                button(
                    AppStrings.of(context).t('Rehacer', 'Redo'),
                    const Icon(Icons.redo_rounded),
                    false,
                    state.canRedo ? onRedo : null),
                button(
                    'Borrar anotaciones',
                    const Icon(Icons.delete_outline_rounded),
                    false,
                    state.trazos.values.any((strokes) => strokes.isNotEmpty)
                        ? () => _confirmClear(context)
                        : null),
              ],
            ])));
  }

  Future<void> _confirmClear(BuildContext context) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: Text(strings.t('¿Borrar todas las anotaciones?',
                    'Delete all annotations?')),
                content: Text(strings.t(
                    'Se borrarán las anotaciones de todas las páginas de este canto.',
                    'Annotations on every page of this song will be deleted.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(strings.t('Cancelar', 'Cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(strings.t('Borrar todo', 'Delete all'))),
                ]));
    if (context.mounted && confirmed == true) onClear();
  }
}

class AnnotationPalette extends StatelessWidget {
  final AppThemeMode themeMode;
  final PdfEngineState state;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onSize;
  const AnnotationPalette(
      {super.key,
      required this.themeMode,
      required this.state,
      required this.onColor,
      required this.onSize});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marker = state.currentTool == ToolType.highlighter;
    return Material(
        color: scheme.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Slider(
                  value: state.drawingSize,
                  min: 1,
                  max: marker || state.currentTool == ToolType.eraser ? 40 : 15,
                  label: state.drawingSize.round().toString(),
                  onChanged: onSize),
              if (state.currentTool != ToolType.eraser)
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final color in [
                        if (marker) ...[
                          const Color(0xFFEEFF00),
                          const Color(0xFF00BFFF),
                          const Color(0xFFFF40A0)
                        ],
                        Colors.black,
                        Colors.red,
                        Colors.blue,
                        Colors.white
                      ])
                        IconButton(
                            tooltip: _name(context, color),
                            isSelected: state.drawingColor.toARGB32() ==
                                color.toARGB32(),
                            onPressed: () => onColor(color),
                            icon: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                    color: AnnotationThemePalette.color(
                                        color, state.currentTool, themeMode),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: scheme.onSurfaceVariant)),
                                child: state.drawingColor.toARGB32() ==
                                        color.toARGB32()
                                    ? Icon(Icons.check,
                                        size: 18,
                                        color: AccessibleColors.onFill(
                                            AnnotationThemePalette.color(color,
                                                state.currentTool, themeMode)))
                                    : null)),
                    ])),
            ])));
  }

  String _name(BuildContext context, Color color) {
    final strings = AppStrings.of(context);
    return switch (color.toARGB32()) {
      0xFFEEFF00 => strings.t('Amarillo neón', 'Neon yellow'),
      0xFF00BFFF => strings.t('Azul brillante', 'Bright blue'),
      0xFFFF40A0 => strings.t('Rosa', 'Pink'),
      0xFF000000 => strings.t('Negro', 'Black'),
      0xFFFFFFFF => strings.t('Blanco', 'White'),
      0xFFF44336 => strings.t('Rojo', 'Red'),
      _ => strings.t('Azul', 'Blue'),
    };
  }
}

class AnnotationToolIcon extends StatelessWidget {
  final ToolType tool;
  const AnnotationToolIcon({super.key, required this.tool});
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(24, 24),
      painter: _ToolPainter(tool, IconTheme.of(context).color ?? Colors.black));
}

class _ToolPainter extends CustomPainter {
  final ToolType tool;
  final Color color;
  _ToolPainter(this.tool, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    if (tool == ToolType.eraser) {
      canvas.drawPath(
          Path()
            ..moveTo(3, 15)
            ..lineTo(13, 4)
            ..lineTo(22, 12)
            ..lineTo(13, 21)
            ..lineTo(9, 21)
            ..close(),
          paint);
      canvas.drawLine(const Offset(7, 11), const Offset(16, 19), paint);
      canvas.drawLine(const Offset(13, 21), const Offset(23, 21), paint);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(6, 14)
            ..lineTo(14, 3)
            ..lineTo(22, 9)
            ..lineTo(14, 19)
            ..close(),
          paint);
      canvas.drawPath(
          Path()
            ..moveTo(6, 14)
            ..lineTo(3, 20)
            ..lineTo(10, 20)
            ..lineTo(14, 19),
          paint);
      canvas.drawLine(
          const Offset(2, 23), const Offset(17, 23), paint..strokeWidth = 2.8);
    }
  }

  @override
  bool shouldRepaint(_ToolPainter old) =>
      old.tool != tool || old.color != color;
}
