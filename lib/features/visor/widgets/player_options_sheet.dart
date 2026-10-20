import 'package:flutter/material.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';

class PlayerOptionsSheet extends StatefulWidget {
  final MidiState initialState;
  final bool voiceMix;
  final ValueChanged<double> onSpeed;
  final void Function(int, bool) onMute;
  final void Function(int, double) onVolume;
  final ValueChanged<int> onSolo;
  final VoidCallback onReset;
  const PlayerOptionsSheet(
      {super.key,
      required this.initialState,
      required this.voiceMix,
      required this.onSpeed,
      required this.onMute,
      required this.onVolume,
      required this.onSolo,
      required this.onReset});
  @override
  State<PlayerOptionsSheet> createState() => _PlayerOptionsSheetState();
}

class _PlayerOptionsSheetState extends State<PlayerOptionsSheet> {
  late double speed;
  late List<MidiVoz> voices;
  @override
  void initState() {
    super.initState();
    speed = widget.initialState.speed;
    voices = widget.initialState.voces
        .map((v) => MidiVoz(
            trackIndex: v.trackIndex,
            nombre: v.nombre,
            activa: v.activa,
            volumen: v.volumen))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SafeArea(
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .8),
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    widget.voiceMix
                                        ? strings.t(
                                            'Mezcla de voces', 'Voice mix')
                                        : strings.t('Velocidad', 'Speed'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: strings.t('Cerrar', 'Close'),
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded))
                          ]),
                          if (!widget.voiceMix) ...[
                            Text('${speed.toStringAsFixed(2)}×',
                                textAlign: TextAlign.center),
                            Slider(
                                value: speed.clamp(.5, 2),
                                min: .5,
                                max: 2,
                                divisions: 30,
                                label: '${speed.toStringAsFixed(2)}×',
                                onChanged: (value) {
                                  setState(() => speed = value);
                                  widget.onSpeed(value);
                                }),
                            const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(child: Text('0.50×')),
                                  Flexible(child: Text('2.00×'))
                                ]),
                            TextButton(
                                onPressed: speed == 1
                                    ? null
                                    : () {
                                        setState(() => speed = 1);
                                        widget.onSpeed(1);
                                      },
                                child: Text(strings.t('Restablecer', 'Reset'))),
                          ] else ...[
                            TextButton(
                                onPressed: () {
                                  setState(() {
                                    for (final v in voices) {
                                      v.activa = true;
                                      v.volumen = 1;
                                    }
                                  });
                                  widget.onReset();
                                },
                                child: Text(strings.t(
                                    'Restablecer mezcla', 'Reset mix'))),
                            if (voices.isEmpty)
                              Text(strings.t(
                                  'No hay voces separadas en este audio.',
                                  'This audio has no separate voices.')),
                            for (final voice in voices)
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        children: [
                                          IconButton(
                                              tooltip: voice.activa
                                                  ? strings.t(
                                                      'Silenciar ${strings.voiceLabel(voice.nombre)}',
                                                      'Mute ${strings.voiceLabel(voice.nombre)}')
                                                  : strings.t(
                                                      'Activar ${strings.voiceLabel(voice.nombre)}',
                                                      'Unmute ${strings.voiceLabel(voice.nombre)}'),
                                              onPressed: () {
                                                final muted = voice.activa;
                                                setState(() =>
                                                    voice.activa = !muted);
                                                widget.onMute(
                                                    voice.trackIndex, muted);
                                              },
                                              icon: Icon(voice.activa
                                                  ? Icons.volume_up_rounded
                                                  : Icons.volume_off_rounded)),
                                          Text(strings.voiceLabel(voice.nombre)),
                                          Text(
                                              '${(voice.volumen * 100).round()}%'),
                                          TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  for (final v in voices) {
                                                    v.activa = v.trackIndex ==
                                                        voice.trackIndex;
                                                  }
                                                });
                                                widget.onSolo(voice.trackIndex);
                                              },
                                              child: Text(
                                                  strings.t('Solo', 'Solo')))
                                        ]),
                                    Slider(
                                        value: voice.volumen.clamp(0, 1),
                                        label:
                                            '${(voice.volumen * 100).round()}%',
                                        onChanged: (value) {
                                          setState(() => voice.volumen = value);
                                          widget.onVolume(
                                              voice.trackIndex, value);
                                        }),
                                  ]),
                          ],
                        ])))));
  }
}
