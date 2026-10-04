import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../answers/answers.dart';

/// Pops with `true` when the farmer wants to take a new photo.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.answer,
    required this.audioPaths,
  });

  final Answer answer;

  /// Asset clips played one after another, e.g. the answer and then how
  /// confident the model is.
  final List<String> audioPaths;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Plays all clips from the start, also when they are already playing.
  Future<void> _play() async {
    final paths = widget.audioPaths;
    if (paths.isEmpty) return;
    try {
      if (_player.audioSource == null) {
        await _player.setAudioSources([
          for (final p in paths) AudioSource.asset(p),
        ]);
      }
      await _player.seek(Duration.zero, index: 0);
      // Not awaited: play() only completes when playback stops.
      unawaited(_player.play());
    } catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'audio'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;
    final (bg, fg) = switch (answer.color) {
      AnswerColor.green => (const Color(0xFF2E7D32), Colors.white),
      AnswerColor.amber => (const Color(0xFFFFB300), Colors.black87),
      AnswerColor.red => (const Color(0xFFC62828), Colors.white),
    };
    final icon = switch (answer.color) {
      AnswerColor.green => Icons.check_circle,
      AnswerColor.amber => Icons.help,
      AnswerColor.red => Icons.warning_rounded,
    };

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: FittedBox(child: Icon(icon, color: fg, size: 200)),
              ),
              Text(
                answer.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _BigButton(
                    icon: Icons.volume_up,
                    label: 'اسمع تاني',
                    color: bg,
                    onPressed: _play,
                  ),
                  const SizedBox(width: 24),
                  _BigButton(
                    icon: Icons.photo_camera,
                    label: 'صورة جديدة',
                    color: bg,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;

  /// Spoken by TalkBack; not shown on screen.
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          height: 140,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              elevation: 6,
            ),
            child: Icon(icon, size: 88),
          ),
        ),
      ),
    );
  }
}
