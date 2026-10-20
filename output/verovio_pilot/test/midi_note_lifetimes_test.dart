import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/midi/midi_note_lifetimes.dart';

void main() {
  test('una nota larga termina por posición musical aunque cambie la velocidad', () {
    final queue=MidiNoteLifetimes()..start(60,8);
    // Four wall seconds at 1x, followed by four wall seconds at .5x.
    expect(queue.advance(4),isEmpty);
    expect(queue.advance(6),isEmpty);
    // Two more wall seconds at 1x complete the eight musical seconds.
    expect(queue.advance(8),[60]);
    expect(queue.advance(9),isEmpty);
  });
  test('una coincidencia de altura no corta otra nota activa y las voces son independientes', () {
    final queue=MidiNoteLifetimes()..start(60,1)..start(60,3)..start(316,2);
    expect(queue.advance(1),isEmpty);
    expect(queue.activeCounts,{60:1,316:1});
    expect(queue.advance(2),[316]);
    expect(queue.advance(3),[60]);
  });
  test('pausar o buscar invalida todos los apagados anteriores', () {
    final queue=MidiNoteLifetimes()..start(60,8)..clear()..start(60,20);
    expect(queue.advance(8),isEmpty);
    expect(queue.advance(20),[60]);
  });
}
