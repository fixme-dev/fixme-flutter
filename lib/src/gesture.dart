// Three fingers down within 400 ms. Pure, so it is unit tested; the Dart overlay opens on it, and in native mode the
// controller uses it to take its widget snapshot at the moment the screen freezes.

/// Counts fingers: three down within 400 ms is a three-finger tap.
class ThreeFingerDetector {
  final Map<int, int> _down = {};
  bool _fired = false;

  /// Returns true when this pointer-down completes a three-finger tap.
  bool down(int pointer, int atMs) {
    _down[pointer] = atMs;
    _down.removeWhere((_, t) => atMs - t > 400);
    if (!_fired && _down.length >= 3) {
      _fired = true;
      return true;
    }
    return false;
  }

  void up(int pointer) {
    _down.remove(pointer);
    if (_down.isEmpty) _fired = false;
  }
}
