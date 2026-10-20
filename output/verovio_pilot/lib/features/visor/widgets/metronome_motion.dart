import 'dart:math';
import 'package:coro_lldm/core/midi/midi_engine.dart';

/// A click marks an extreme; the rod takes the whole pulse to reach the other.
class MetronomeMotion {
  static Duration pulseDuration(MidiState midi) {
    final groups = midi.beatGroups;
    final units =
        groups.isEmpty ? 1 : groups[(midi.beatIndex ?? 0) % groups.length];
    final milliseconds = 60000 /
        (max(1, midi.tempoBpm) * midi.speed.clamp(.5, 2)) *
        4 /
        (midi.timeSignatureDenominator ?? 4) *
        units;
    return Duration(microseconds: (milliseconds * 1000).round());
  }

  /// Wider, slower arcs at slow tempos, without clipping the small icon.
  static double amplitude(MidiState midi) {
    final seconds = pulseDuration(midi).inMicroseconds / 1000000;
    return (.48 + (seconds - .25) * .5).clamp(.48, .86);
  }
}
