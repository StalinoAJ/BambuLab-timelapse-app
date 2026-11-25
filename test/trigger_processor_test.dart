import 'package:flutter_test/flutter_test.dart';
import 'package:bambulab_timelapse/services/trigger_processor.dart';

void main() {
  group('TriggerProcessor', () {
    test('parses 0, 1, whitespace, and JSON payloads', () {
      expect(TriggerProcessor.parseValue('0'), 0);
      expect(TriggerProcessor.parseValue('1'), 1);
      expect(TriggerProcessor.parseValue(' 1\r\n'), 1);
      expect(TriggerProcessor.parseValue('{"value": 1}'), 1);
      expect(TriggerProcessor.parseValue('{"value": 0}'), 0);
      expect(TriggerProcessor.parseValue('invalid'), isNull);
    });

    test('triggers on 1 and ignores 0', () {
      final processor = TriggerProcessor(
        risingEdgeOnly: true,
        cooldown: const Duration(milliseconds: 500),
      );
      final t0 = DateTime(2026, 11, 25, 12, 0, 0);

      expect(processor.process(0, now: t0), isFalse);
      expect(processor.process(1, now: t0.add(const Duration(seconds: 1))),
          isTrue);
    });

    test('risingEdgeOnly ignores repeated 1s until 0 is received', () {
      final processor = TriggerProcessor(
        risingEdgeOnly: true,
        cooldown: Duration.zero,
      );
      final t0 = DateTime(2026, 11, 25, 12, 0, 0);

      expect(processor.process(1, now: t0), isTrue);
      expect(processor.process(1, now: t0.add(const Duration(seconds: 1))),
          isFalse);
      expect(processor.process(0, now: t0.add(const Duration(seconds: 2))),
          isFalse);
      expect(processor.process(1, now: t0.add(const Duration(seconds: 3))),
          isTrue);
    });

    test('enforces cooldown between triggers', () {
      final processor = TriggerProcessor(
        risingEdgeOnly: false,
        cooldown: const Duration(milliseconds: 500),
      );
      final t0 = DateTime(2026, 11, 25, 12, 0, 0);

      expect(processor.process(1, now: t0), isTrue);
      expect(processor.process(1, now: t0.add(const Duration(milliseconds: 200))),
          isFalse);
      expect(processor.process(1, now: t0.add(const Duration(milliseconds: 600))),
          isTrue);
    });
  });
}
