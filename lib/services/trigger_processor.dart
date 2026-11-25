/// Processes incoming 0/1 values from the ESP32 and decides whether
/// a camera shot should be triggered.
class TriggerProcessor {
  bool risingEdgeOnly;
  Duration cooldown;

  int? _lastValue;
  DateTime? _lastTriggerTime;

  TriggerProcessor({
    this.risingEdgeOnly = true,
    this.cooldown = const Duration(milliseconds: 500),
  });

  int? get lastValue => _lastValue;
  DateTime? get lastTriggerTime => _lastTriggerTime;

  /// Parses raw string or numeric payloads like "0", "1", "1\n", or byte [1]/[0].
  /// Returns 0, 1, or null if the payload cannot be interpreted.
  static int? parseValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed == '0') return 0;
    if (trimmed == '1') return 1;
    // Also support simple JSON like {"value":1} or {"trigger":1}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final match = RegExp(r':\s*([01])\b').firstMatch(trimmed);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  /// Evaluates a received [value] (0 or 1) at [now].
  /// Returns true if the camera should capture a shot.
  bool process(int value, {DateTime? now}) {
    if (value != 0 && value != 1) {
      return false;
    }

    final timestamp = now ?? DateTime.now();
    final previous = _lastValue;
    _lastValue = value;

    if (value != 1) {
      return false;
    }

    if (risingEdgeOnly && previous == 1) {
      return false;
    }

    if (_lastTriggerTime != null &&
        timestamp.difference(_lastTriggerTime!) < cooldown) {
      return false;
    }

    _lastTriggerTime = timestamp;
    return true;
  }

  void reset() {
    _lastValue = null;
    _lastTriggerTime = null;
  }
}
