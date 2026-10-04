/// All tunable settings live here.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

// ---------------------------------------------------------------------------
// Classifier selection
// ---------------------------------------------------------------------------

/// true  -> random FakeClassifier (UI development only).
/// false -> real on-device TFLite model.
///
/// Release builds refuse to start with the fake classifier, so a random
/// "diagnosis" can never reach a farmer.
const bool kUseFakeClassifier = false;

// ---------------------------------------------------------------------------
// Decision thresholds
// ---------------------------------------------------------------------------

/// If the top-1 probability is below this, answer "_not_sure".
const double kConfidenceThreshold = 0.80;

/// If (top-1 - top-2) is below this, answer "_not_sure".
const double kMinMargin = 0.15;

/// Accepted answers at or above this top-1 probability are followed by the
/// "high confidence" clip, the rest by "medium confidence". From the
/// training export's calibration.json.
const double kHighConfidenceThreshold = 0.90;

/// Answer id used whenever the model should not guess.
const String kNotSureId = '_not_sure';

// ---------------------------------------------------------------------------
// Assets
// ---------------------------------------------------------------------------

const String kModelAsset = 'assets/model/tomato_fp32.tflite';
const String kLabelsAsset = 'assets/model/classes.json';
const String kAnswersAsset = 'assets/data/arabic_mapping.json';
const String kHighConfidenceAudio = 'assets/audio/high_confidence.mp3';
const String kMediumConfidenceAudio = 'assets/audio/medium_confidence.mp3';

/// The camera image is downscaled to at most this size before decoding,
/// which keeps decoding fast on cheap phones. Must be >= the model input size.
const double kCaptureMaxSide = 1024;

// ---------------------------------------------------------------------------
// Model input / output: MUST match how the model was trained
// ---------------------------------------------------------------------------

/// Turns an upright photo into the model input: [height] x [width] x RGB,
/// row-major, as the float values the network saw during training. The
/// classifier transposes to channels-first itself if the model wants that.
///
/// The model's input size is read from the .tflite file. Quantization of
/// int8/uint8 models is done by the caller with the tensor's own scale and
/// zero point, so this function only deals with "training space" floats.
///
/// Matches classes.json "preprocessing": the whole photo resized to the
/// model size (no crop), RGB / 255. ImageNet normalisation is inside the
/// model, so it must not be done here. `average` approximates the
/// antialiased resize torchvision applies when shrinking large photos.
Float32List preprocess(img.Image photo, int width, int height) {
  final resized = img.copyResize(
    photo,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
  final rgb = resized
      .convert(format: img.Format.uint8, numChannels: 3)
      .getBytes(order: img.ChannelOrder.rgb);
  return Float32List.fromList([for (final v in rgb) v / 255]);
}

/// true if the model outputs logits (softmax is applied in the app).
/// false if its last layer already is a softmax. Debug builds refuse to
/// classify if the model's output disagrees with this setting.
const bool kApplySoftmax = true;

/// Logits are divided by this before softmax (temperature scaling), so
/// probabilities are calibrated. From the training export's
/// calibration.json; 1.0 means no scaling. Ignored if [kApplySoftmax] is
/// false.
const double kSoftmaxTemperature = 0.8264204263687134;
