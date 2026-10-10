import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/features/visor/widgets/metronome_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El balanceo lento es más amplio y tarda todo el pulso', () {
    const slow = MidiState(tempoBpm: 60);
    const fast = MidiState(tempoBpm: 180);
    expect(MetronomeMotion.pulseDuration(slow), const Duration(seconds: 1));
    expect(
        MetronomeMotion.pulseDuration(fast).inMicroseconds, closeTo(333333, 1));
    expect(MetronomeMotion.amplitude(slow),
        greaterThan(MetronomeMotion.amplitude(fast)));
    expect(MetronomeMotion.pulseDuration(slow.copyWith(speed: .5)),
        const Duration(seconds: 2));
  });
  test('Los compases compuestos y grupos desiguales conservan el pulso musical',
      () {
    const compound = MidiState(
        tempoBpm: 120,
        timeSignatureDenominator: 8,
        beatGroups: [3, 3],
        beatIndex: 0);
    expect(MetronomeMotion.pulseDuration(compound),
        const Duration(milliseconds: 750));
    final irregular = compound.copyWith(beatGroups: [2, 3], beatIndex: 0);
    expect(MetronomeMotion.pulseDuration(irregular),
        const Duration(milliseconds: 500));
    expect(MetronomeMotion.pulseDuration(irregular.copyWith(beatIndex: 1)),
        const Duration(milliseconds: 750));
  });
}
