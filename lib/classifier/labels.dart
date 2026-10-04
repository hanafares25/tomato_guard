import 'dart:convert';

import 'package:flutter/services.dart';

import '../config.dart';

/// Loads class ids in model-output order from the training export
/// `{"classes": [{"index": 0, "id": "bacterial_spot", ...}, ...]}`.
///
/// The order comes from the explicit "index" fields, never from the order
/// or names in the file, because the model output is only identified by
/// position.
Future<List<String>> loadLabels() async {
  final decoded = jsonDecode(await rootBundle.loadString(kLabelsAsset));
  final classes = decoded is Map ? decoded['classes'] : null;
  if (classes is! List) {
    throw FormatException('$kLabelsAsset: expected {"classes": [...]}');
  }
  final ids = List<String?>.filled(classes.length, null);
  for (final c in classes) {
    final index = c is Map ? c['index'] : null;
    final id = c is Map ? c['id'] : null;
    if (index is! int || id is! String) {
      throw FormatException(
        '$kLabelsAsset: every class needs "index" and '
        '"id", got $c',
      );
    }
    if (index < 0 || index >= ids.length || ids[index] != null) {
      throw FormatException(
        '$kLabelsAsset: index $index is out of range or '
        'repeated',
      );
    }
    ids[index] = id;
  }
  return ids.cast<String>();
}
