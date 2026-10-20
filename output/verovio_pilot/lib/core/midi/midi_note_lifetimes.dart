/// Releases are scheduled in song seconds, not wall-clock milliseconds.
/// Thus changing playback speed cannot truncate or overextend a held note.
class MidiNoteLifetimes {
  final Map<int, List<double>> _ends = {};
  void start(int key, double endSeconds) {
    (_ends[key] ??= []).add(endSeconds);
  }
  Map<int, int> get activeCounts => {for(final entry in _ends.entries) entry.key: entry.value.length};
  List<int> advance(double songSeconds) {
    final released = <int>[];
    for(final entry in _ends.entries) {
      entry.value.removeWhere((end) => end <= songSeconds);
      if(entry.value.isEmpty) released.add(entry.key);
    }
    for(final key in released) {_ends.remove(key);}
    return released;
  }
  void clear() => _ends.clear();
}
