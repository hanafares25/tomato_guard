import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../config.dart';
import 'classifier.dart';
import 'decision.dart';

/// On-device classifier for the bundled [kModelAsset].
///
/// Input size and type (float32, int8 or uint8) are read from the model, so
/// only [preprocess] in config.dart has to be kept in sync with training.
class TfliteClassifier implements Classifier {
  TfliteClassifier._(
    this._interpreter,
    this.labels,
    this._input,
    this._output,
    this._layout,
  );

  final Interpreter _interpreter;
  final List<String> labels;
  final Tensor _input;
  final Tensor _output;
  final _Layout _layout;

  static Future<TfliteClassifier> create(List<String> labels) async {
    final interpreter = await Interpreter.fromAsset(kModelAsset);
    interpreter.allocateTensors();
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    debugPrint('model input: ${input.shape} ${input.type} ${input.params}');
    debugPrint('model output: ${output.shape} ${output.type} ${output.params}');

    final layout = _Layout.of(input.shape);
    _checkSupported(input);
    _checkSupported(output);
    if (output.numElements() != labels.length) {
      throw StateError(
        '$kModelAsset outputs ${output.numElements()} classes '
        'but $kLabelsAsset has ${labels.length}',
      );
    }
    if (kDebugMode) _checkPreprocessRange(input, layout);
    return TfliteClassifier._(interpreter, labels, input, output, layout);
  }

  @override
  Future<List<Prediction>> classify(File imgFile) async {
    // Decoding and resizing a camera photo takes a while on cheap phones;
    // keep it off the UI thread so the spinner keeps turning.
    _input.data = await compute(_prepareInput, (
      bytes: await imgFile.readAsBytes(),
      layout: _layout,
      type: _input.type,
      params: _input.params,
    ));
    _interpreter.invoke();

    final raw = _dequantize(_output);
    // A softmax output is non-negative and sums to 1; logits almost never do.
    final looksLikeProbs =
        raw.every((v) => v >= -1e-3) &&
        (raw.reduce((a, b) => a + b) - 1).abs() < 0.05;
    if (kDebugMode && looksLikeProbs == kApplySoftmax) {
      throw StateError(
        looksLikeProbs
            ? 'Model output is already a softmax; set kApplySoftmax = false.'
            : 'Model output is not a softmax; set kApplySoftmax = true.',
      );
    }
    final probs = kApplySoftmax
        ? softmax([for (final v in raw) v / kSoftmaxTemperature])
        : raw;
    return topK(probs, labels);
  }

  static void _checkSupported(Tensor t) {
    final quantized = t.type == TensorType.int8 || t.type == TensorType.uint8;
    if (t.type != TensorType.float32 && !quantized) {
      throw StateError('$kModelAsset: unsupported tensor type ${t.type}');
    }
    if (quantized && t.params.scale == 0) {
      throw StateError('$kModelAsset: ${t.type} tensor has no quantization');
    }
  }

  /// Fails if [preprocess] produces a different value range than the model
  /// was quantized for, e.g. [-1, 1] when the model expects 0..255. Only
  /// possible for quantized inputs: float inputs carry no range.
  static void _checkPreprocessRange(Tensor input, _Layout layout) {
    if (input.type == TensorType.float32) return;
    final (qMin, qMax) = _quantRange(input.type);
    final p = input.params;
    final lo = (qMin - p.zeroPoint) * p.scale;
    final hi = (qMax - p.zeroPoint) * p.scale;

    // Half black, half white: the extremes of what a photo can contain.
    final _Layout(:width, :height) = layout;
    final probe = img.fillRect(
      img.Image(width: width, height: height),
      x1: width ~/ 2,
      y1: 0,
      x2: width - 1,
      y2: height - 1,
      color: img.ColorRgb8(255, 255, 255),
    );
    final values = preprocess(probe, width, height);
    final min = values.reduce(math.min), max = values.reduce(math.max);

    final tolerance = 0.25 * (hi - lo);
    if ((min - lo).abs() > tolerance || (max - hi).abs() > tolerance) {
      throw StateError(
        'preprocess() in config.dart produces '
        '[${min.toStringAsFixed(2)}, ${max.toStringAsFixed(2)}] but the '
        'model was quantized for [${lo.toStringAsFixed(2)}, '
        '${hi.toStringAsFixed(2)}]. Make it match training.',
      );
    }
  }
}

Uint8List _prepareInput(
  ({
    Uint8List bytes,
    _Layout layout,
    TensorType type,
    QuantizationParams params,
  })
  a,
) {
  final photo = img.decodeImage(a.bytes);
  if (photo == null) throw const FormatException('Cannot decode photo');
  final _Layout(:width, :height, :channelsFirst) = a.layout;
  final hwc = preprocess(img.bakeOrientation(photo), width, height);
  return _quantize(
    channelsFirst ? _toChw(hwc, width, height) : hwc,
    a.type,
    a.params,
  );
}

/// Height x width x channel to channel x height x width.
Float32List _toChw(Float32List hwc, int width, int height) {
  final pixels = width * height;
  final chw = Float32List(hwc.length);
  for (var p = 0; p < pixels; p++) {
    for (var c = 0; c < 3; c++) {
      chw[c * pixels + p] = hwc[p * 3 + c];
    }
  }
  return chw;
}

(int, int) _quantRange(TensorType type) =>
    type == TensorType.int8 ? (-128, 127) : (0, 255);

/// Raw tensor bytes for [values], quantized if the model input is.
Uint8List _quantize(
  Float32List values,
  TensorType type,
  QuantizationParams params,
) {
  if (type == TensorType.float32) return values.buffer.asUint8List();
  final (qMin, qMax) = _quantRange(type);
  final q = [
    for (final v in values)
      ((v / params.scale).round() + params.zeroPoint).clamp(qMin, qMax),
  ];
  return type == TensorType.int8
      ? Int8List.fromList(q).buffer.asUint8List()
      : Uint8List.fromList(q);
}

List<double> _dequantize(Tensor t) {
  // Copy: the tensor's buffer is reused by the next inference.
  final bytes = Uint8List.fromList(t.data);
  if (t.type == TensorType.float32) return bytes.buffer.asFloat32List();
  final p = t.params;
  final List<int> q = t.type == TensorType.int8
      ? bytes.buffer.asInt8List()
      : bytes;
  return [for (final v in q) (v - p.zeroPoint) * p.scale];
}

/// Input geometry. PyTorch exports are channels-first ([1, 3, h, w]);
/// most TFLite converters produce channels-last ([1, h, w, 3]).
class _Layout {
  const _Layout(this.width, this.height, {required this.channelsFirst});

  factory _Layout.of(List<int> shape) => switch (shape) {
    [1, final h, final w, 3] => _Layout(w, h, channelsFirst: false),
    [1, 3, final h, final w] => _Layout(w, h, channelsFirst: true),
    _ => throw StateError(
      '$kModelAsset: expected input [1, h, w, 3] or [1, 3, h, w], '
      'got $shape',
    ),
  };

  final int width;
  final int height;
  final bool channelsFirst;
}
