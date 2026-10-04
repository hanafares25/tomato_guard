import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'answers/answers.dart';
import 'classifier/classifier.dart';
import 'classifier/fake_classifier.dart';
import 'classifier/labels.dart';
import 'classifier/tflite_classifier.dart';
import 'config.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kReleaseMode && kUseFakeClassifier) {
      throw StateError(
        'FakeClassifier is enabled in a release build. '
        'Set kUseFakeClassifier = false in config.dart.',
      );
    }
    final labels = await loadLabels();
    final answers = await AnswerBook.load(labels);
    final Classifier classifier = kUseFakeClassifier
        ? FakeClassifier(labels)
        : await TfliteClassifier.create(labels);
    runApp(
      TomatoGuardApp(
        home: HomeScreen(classifier: classifier, answers: answers),
      ),
    );
  } catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'startup'),
    );
    runApp(TomatoGuardApp(home: _StartupErrorScreen(error: e)));
  }
}

class TomatoGuardApp extends StatelessWidget {
  const TomatoGuardApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TomatoGuard',
      debugShowCheckedModeBanner: false,
      // Egyptian Arabic, which also makes the whole UI right-to-left.
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      home: home,
    );
  }
}

/// Shown when assets are missing or inconsistent. Meant for developers; a
/// correctly packaged app never shows it.
class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 120),
              const SizedBox(height: 24),
              SelectableText(
                '$error',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
