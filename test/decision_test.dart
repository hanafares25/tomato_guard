import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_guard/classifier/classifier.dart';
import 'package:tomato_guard/classifier/decision.dart';
import 'package:tomato_guard/config.dart';

List<Prediction> preds(List<double> confidences) => [
  for (var i = 0; i < confidences.length; i++)
    Prediction('class_$i', confidences[i]),
];

void main() {
  test('defaults are 0.80 threshold and 0.15 margin', () {
    expect(kConfidenceThreshold, 0.80);
    expect(kMinMargin, 0.15);
  });

  group('threshold', () {
    test('confident answer is returned', () {
      expect(decideAnswerId(preds([0.92, 0.05, 0.03])), 'class_0');
    });

    test('top-1 below threshold is not sure', () {
      expect(decideAnswerId(preds([0.79, 0.11, 0.10])), kNotSureId);
    });

    test('top-1 exactly at threshold is accepted', () {
      expect(decideAnswerId(preds([0.80, 0.15, 0.05])), 'class_0');
    });

    test('custom threshold is respected', () {
      expect(decideAnswerId(preds([0.92, 0.08]), threshold: 0.95), kNotSureId);
    });
  });

  // With probabilities summing to 1, top-1 >= 0.80 forces a margin >= 0.60,
  // so the margin rule only bites when the threshold is lowered.
  group('margin', () {
    test('margin below minimum is not sure', () {
      expect(
        decideAnswerId(preds([0.55, 0.41, 0.04]), threshold: 0.5),
        kNotSureId,
      );
    });

    test('margin exactly at minimum is accepted despite rounding', () {
      // 0.55 - 0.40 is not exactly 0.15 in floating point.
      expect(
        decideAnswerId(preds([0.55, 0.40, 0.05]), threshold: 0.5),
        'class_0',
      );
    });

    test('custom margin is respected', () {
      expect(decideAnswerId(preds([0.92, 0.08]), minMargin: 0.9), kNotSureId);
    });

    test('margin is top-1 minus top-2, not top-1 minus the rest', () {
      expect(
        decideAnswerId(preds([0.55, 0.20, 0.20, 0.05]), threshold: 0.5),
        'class_0',
      );
    });
  });

  group('edge cases', () {
    test('unsorted predictions use the most confident one', () {
      expect(decideAnswerId(preds([0.05, 0.90, 0.05])), 'class_1');
    });

    test('single prediction has no runner-up to compete with', () {
      expect(decideAnswerId(preds([0.85])), 'class_0');
    });

    test('no predictions is not sure', () {
      expect(decideAnswerId(const []), kNotSureId);
    });

    test('NaN confidence is not sure', () {
      expect(decideAnswerId(preds([double.nan, 0.1])), kNotSureId);
    });
  });

  group('softmax + topK feeding the decision', () {
    test('softmax sums to 1 and survives large logits', () {
      final p = softmax([1000, 1001, 1002]);
      expect(p.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(p.every((v) => v.isFinite), isTrue);
    });

    test('topK returns the 3 most probable, highest first', () {
      final top = topK([0.1, 0.5, 0.05, 0.3, 0.05], ['a', 'b', 'c', 'd', 'e']);
      expect(top.map((p) => p.label), ['b', 'd', 'a']);
    });

    test('close logits end up not sure', () {
      final top = topK(softmax([2.0, 1.9, 0.1]), ['a', 'b', 'c']);
      expect(decideAnswerId(top), kNotSureId);
    });
  });

  group('confidence level', () {
    test('default high-confidence threshold is 0.90', () {
      expect(kHighConfidenceThreshold, 0.90);
    });

    test('at or above the threshold is high', () {
      expect(confidenceOf(preds([0.90, 0.10])), Confidence.high);
      expect(confidenceOf(preds([0.99, 0.01])), Confidence.high);
    });

    test('accepted but below the threshold is medium', () {
      expect(confidenceOf(preds([0.85, 0.15])), Confidence.medium);
    });

    test('uses the most confident prediction even if unsorted', () {
      expect(confidenceOf(preds([0.05, 0.95])), Confidence.high);
    });
  });
}
