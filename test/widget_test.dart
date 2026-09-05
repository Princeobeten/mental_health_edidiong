import 'package:flutter_test/flutter_test.dart';

import 'package:mental_health_chatbot/services/crisis_detector.dart';

void main() {
  group('CrisisDetector', () {
    final detector = CrisisDetector();

    test('flags high-risk phrases', () {
      expect(detector.isCrisis('I want to die'), isTrue);
      expect(detector.isCrisis('Sometimes I think about suicide'), isTrue);
      expect(detector.isCrisis('I might HURT MYSELF tonight'), isTrue);
    });

    test('does not flag ordinary distress', () {
      expect(detector.isCrisis('I had a stressful day at work'), isFalse);
      expect(detector.isCrisis('I feel a bit anxious about exams'), isFalse);
    });
  });
}
