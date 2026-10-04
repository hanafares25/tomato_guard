import 'dart:io';
import 'dart:math';

import 'classifier.dart';
import 'decision.dart';

/// Random predictions so the UI can be built before the model lands.
/// Produces a mix of confident and unsure results.
class FakeClassifier implements Classifier {
  FakeClassifier(this.labels, {Random? random}) : _random = random ?? Random();

  final List<String> labels;
  final Random _random;

  @override
  Future<List<Prediction>> classify(File img) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final winner = _random.nextInt(labels.length);
    final logits = [
      for (var i = 0; i < labels.length; i++)
        _random.nextDouble() * 2 + (i == winner ? _random.nextDouble() * 7 : 0),
    ];
    return topK(softmax(logits), labels);
  }
}
