import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../answers/answers.dart';
import '../classifier/classifier.dart';
import '../classifier/decision.dart';
import '../config.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.classifier,
    required this.answers,
  });

  final Classifier classifier;
  final AnswerBook answers;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _recoverLostPhoto();
  }

  /// Android can kill the app while the camera is open (common on low-memory
  /// phones). The photo is then delivered here on the next launch.
  Future<void> _recoverLostPhoto() async {
    final lost = await _picker.retrieveLostData();
    final file = lost.file;
    if (file != null && mounted) await _classifyAndShow(File(file.path));
  }

  Future<void> _takePhoto() async {
    if (_busy) return;
    final XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: kCaptureMaxSide,
        maxHeight: kCaptureMaxSide,
        imageQuality: 95,
      );
    } on PlatformException catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'camera'),
      );
      return;
    }
    if (photo == null || !mounted) return; // Farmer cancelled.
    await _classifyAndShow(File(photo.path));
  }

  Future<void> _classifyAndShow(File photo) async {
    setState(() => _busy = true);
    String answerId;
    Confidence? confidence;
    try {
      final predictions = await widget.classifier.classify(photo);
      answerId = decideAnswerId(predictions);
      if (answerId != kNotSureId) confidence = confidenceOf(predictions);
      debugPrint('predictions: $predictions -> $answerId ($confidence)');
    } catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'classifier'),
      );
      answerId = kNotSureId;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final answer = widget.answers.forId(answerId);
    final newPhoto = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          answer: answer,
          audioPaths: widget.answers.audioFor(answer, confidence),
        ),
      ),
    );
    if (newPhoto == true && mounted) await _takePhoto();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest.shortestSide * 0.75;
            return Center(
              child: _busy
                  ? SizedBox.square(
                      dimension: size * 0.5,
                      child: const CircularProgressIndicator(strokeWidth: 12),
                    )
                  : Semantics(
                      button: true,
                      label: 'صوّر الورقة',
                      child: SizedBox.square(
                        dimension: size,
                        child: ElevatedButton(
                          onPressed: _takePhoto,
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            elevation: 8,
                          ),
                          child: Icon(Icons.photo_camera, size: size * 0.5),
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
