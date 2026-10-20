const fs = require('fs');
const p = 'lib/features/visor/visor_screen.dart';
let s = fs.readFileSync(p, 'utf8').replaceAll('\r\n', '\n');
s = s.replace('  bool _showSettings = false;\n', '');
let a = s.indexOf('  void _abrirMezcladorModal('), b = s.indexOf('  @override\n  Widget build', a);
s = s.slice(0,a) + `  Widget _buildVoiceMix(BuildContext context, bool loading) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(strings.t('Mezcla de voces', 'Voice mix')),
      leading: const Icon(Icons.tune_rounded),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: loading ? null : widget.onResetVozVolumes,
            icon: const Icon(Icons.restore_rounded),
            label: Text(strings.t('Restablecer mezcla', 'Reset mix')),
          ),
        ),
        for (final voice in widget.midiState.voces)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: voice.activa
                          ? strings.t('Silenciar \${voice.nombre}', 'Mute \${voice.nombre}')
                          : strings.t('Activar \${voice.nombre}', 'Unmute \${voice.nombre}'),
                      onPressed: loading ? null : () => widget.onVozToggle(voice.trackIndex, voice.activa),
                      icon: Icon(voice.activa ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                    ),
                    Text(voice.nombre, style: TextStyle(color: scheme.onSurface)),
                    Text('\${(voice.volumen * 100).round()}%'),
                    TextButton(
                      onPressed: loading ? null : () => widget.onVozSolo(voice.trackIndex),
                      child: Text(strings.t('Solo', 'Solo')),
                    ),
                  ],
                ),
                Slider(
                  value: voice.volumen.clamp(0.0, 1.0),
                  label: '\${(voice.volumen * 100).round()}%',
                  onChanged: loading ? null : (value) => widget.onVozVolumeChange(voice.trackIndex, value),
                ),
              ],
            ),
          ),
      ],
    );
  }

`.replaceAll('\${','${') + s.slice(b);
a = s.indexOf('                    // Botón Ajustes'); b = s.indexOf('\n                  ],',a); s=s.slice(0,a)+s.slice(b);
a = s.indexOf('                        // Mezclador de voces', s.indexOf('class _MidiPanelState')); b=s.indexOf('                        // Metrónomo toggle',a); s=s.slice(0,a)+s.slice(b);
a=s.indexOf('                        // Selector de velocidad',s.indexOf('class _MidiPanelState')); b=s.indexOf('\n                      ],',a); s=s.slice(0,a)+s.slice(b);
a=s.indexOf('                // Sección Expandible de Ajustes'); b=s.indexOf('\n              ],\n            ),',a);
s=s.slice(0,a)+`                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(AppStrings.of(context).t('Velocidad', 'Speed')),
                    Text('\${widget.midiState.speed.toStringAsFixed(2)}×'),
                    TextButton(
                      onPressed: loading || widget.midiState.speed == 1.0
                          ? null : () => widget.onSpeedChange(1.0),
                      child: Text(AppStrings.of(context).t('Restablecer', 'Reset')),
                    ),
                  ],
                ),
                Slider(
                  value: widget.midiState.speed.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  label: '\${widget.midiState.speed.toStringAsFixed(2)}×',
                  onChanged: loading ? null : widget.onSpeedChange,
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('0.50×'), Text('2.00×')],
                ),
                _buildVoiceMix(context, loading),`+s.slice(b);
fs.writeFileSync(p,s);

