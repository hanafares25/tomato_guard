import 'dart:io';

class Prediction {
  const Prediction(this.label, this.confidence);

  /// Class id, exactly as written in labels.json (and keyed in answers.json).
  final String label;

  /// Probability in [0, 1].
  final double confidence;

  @override
  String toString() => '$label: ${confidence.toStringAsFixed(3)}';
}

abstract class Classifier {
  /// Returns the top predictions, sorted by confidence (highest first).
  Future<List<Prediction>> classify(File img);
}
