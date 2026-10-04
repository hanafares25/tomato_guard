import 'dart:math' as math;

import '../config.dart';
import 'classifier.dart';

/// Numerically stable softmax.
List<double> softmax(List<double> logits) {
  final maxLogit = logits.reduce(math.max);
  final exps = [for (final l in logits) math.exp(l - maxLogit)];
  final sum = exps.reduce((a, b) => a + b);
  return [for (final e in exps) e / sum];
}

/// The [k] most probable classes, highest first.
List<Prediction> topK(List<double> probs, List<String> labels, {int k = 3}) {
  assert(probs.length == labels.length);
  final preds = [
    for (var i = 0; i < probs.length; i++) Prediction(labels[i], probs[i]),
  ]..sort((a, b) => b.confidence.compareTo(a.confidence));
  return preds.take(k).toList();
}

/// Decides which answer to give: the top-1 class id, or [kNotSureId] when the
/// model is not confident enough to guess.
String decideAnswerId(
  List<Prediction> predictions, {
  double threshold = kConfidenceThreshold,
  double minMargin = kMinMargin,
}) {
  if (predictions.isEmpty) return kNotSureId;
  final sorted = [...predictions]
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  final top1 = sorted[0].confidence;
  final top2 = sorted.length > 1 ? sorted[1].confidence : 0.0;

  // Written as !(x >= t) so NaN from a broken model counts as "not sure".
  if (!(top1 >= threshold)) return kNotSureId;
  // Small epsilon so that e.g. 0.95 - 0.80 counts as a 0.15 margin despite
  // floating-point rounding.
  if (!(top1 - top2 >= minMargin - 1e-9)) return kNotSureId;
  return sorted[0].label;
}

enum Confidence { high, medium }

/// How sure the model is about an answer that [decideAnswerId] accepted
/// (so [predictions] is not empty).
Confidence confidenceOf(
  List<Prediction> predictions, {
  double high = kHighConfidenceThreshold,
}) {
  final top1 = predictions.map((p) => p.confidence).reduce(math.max);
  return top1 >= high ? Confidence.high : Confidence.medium;
}
