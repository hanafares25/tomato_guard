import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../classifier/decision.dart';
import '../config.dart';

enum AnswerColor { green, amber, red }

class Answer {
  const Answer({
    required this.id,
    required this.color,
    required this.name,
    required this.audioPath,
  });

  final String id;
  final AnswerColor color;

  /// Short Arabic caption. The audio is the primary channel; this is backup.
  final String name;

  /// Asset path of the spoken answer, or null if the clip is missing
  /// (release builds only; debug builds refuse to start instead).
  final String? audioPath;
}

class AnswerBook {
  AnswerBook(this._answers, this._confidenceAudio);

  final Map<String, Answer> _answers;

  /// Only clips that are actually bundled.
  final Map<Confidence, String> _confidenceAudio;

  /// Loads [kAnswersAsset] and checks that every class in [labels] (plus
  /// [kNotSureId]) has an answer whose audio clip is bundled, and that the
  /// confidence clips are bundled.
  ///
  /// Debug builds throw on any gap so it is fixed before shipping. Release
  /// builds log it: a class without an answer falls back to "not sure", and
  /// an answer without audio is shown silently.
  static Future<AnswerBook> load(List<String> labels) async {
    final decoded = jsonDecode(await rootBundle.loadString(kAnswersAsset));
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$kAnswersAsset must be a JSON object');
    }
    final bundled = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .toSet();

    final problems = <String>[];
    final answers = <String, Answer>{};
    for (final MapEntry(key: id, value: entry) in decoded.entries) {
      var answer = _parse(id, entry);
      final path = answer.audioPath;
      if (path == null) {
        problems.add('"$id": no audio.path');
      } else if (!bundled.contains(path)) {
        problems.add('"$id": audio file not bundled: $path');
        answer = Answer(
          id: id,
          color: answer.color,
          name: answer.name,
          audioPath: null,
        );
      }
      answers[id] = answer;
    }
    for (final id in [kNotSureId, ...labels]) {
      if (!answers.containsKey(id)) problems.add('"$id": no answer');
    }
    final confidenceAudio = {
      Confidence.high: kHighConfidenceAudio,
      Confidence.medium: kMediumConfidenceAudio,
    };
    confidenceAudio.removeWhere((c, path) {
      final missing = !bundled.contains(path);
      if (missing) problems.add('confidence clip not bundled: $path');
      return missing;
    });

    if (problems.isNotEmpty) {
      final message = '$kAnswersAsset is incomplete:\n${problems.join('\n')}';
      if (kDebugMode) throw StateError(message);
      debugPrint(message);
    }
    // Every class falls back to this, so even release builds need it.
    if (!answers.containsKey(kNotSureId)) {
      throw StateError('$kAnswersAsset: missing "$kNotSureId" answer');
    }
    return AnswerBook(answers, confidenceAudio);
  }

  static Answer _parse(String id, Object? entry) {
    if (entry is! Map<String, dynamic> ||
        entry['name'] is! String ||
        entry['color'] is! String) {
      throw FormatException('$kAnswersAsset: "$id" needs "name" and "color"');
    }
    final color =
        AnswerColor.values.asNameMap()[entry['color']] ??
        (throw FormatException(
          '$kAnswersAsset: "$id" has unknown color '
          '"${entry['color']}" (use green, amber or red)',
        ));
    final audio = entry['audio'];
    return Answer(
      id: id,
      color: color,
      name: entry['name'] as String,
      audioPath: audio is Map<String, dynamic> && audio['path'] is String
          ? audio['path'] as String
          : null,
    );
  }

  Answer forId(String id) => _answers[id] ?? _answers[kNotSureId]!;

  /// Clips to play in order: the answer, then how confident the model is
  /// ([confidence] is null for "not sure"). Missing clips are skipped.
  List<String> audioFor(Answer answer, Confidence? confidence) => [
    ?answer.audioPath,
    if (confidence != null) ?_confidenceAudio[confidence],
  ];
}
