/// FIXME for Flutter. Debug builds only: in profile and release builds `FixmeFlutter.wrap` returns your app
/// unchanged and the rest is tree-shaken away.
///
/// ```dart
/// void main() => runApp(FixmeFlutter.wrap(const MyApp()));
/// ```
///
/// FIXME's overlay is native (on iOS and Android it is the same overlay a native app gets). This package tells it which
/// widget is under each circle, with the file and line where it was created, and what the app printed.
library fixme_flutter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'src/controller.dart';

export 'src/controller.dart' show FixmeController, FixmeMode;

class FixmeFlutter {
  FixmeFlutter._();

  static FixmeController? _controller;

  /// The running helper (null in release builds or before `wrap`).
  static FixmeController? get controller => _controller;

  /// Starts the helper and returns `app` unchanged (nothing is drawn by Dart; FIXME's overlay is native).
  ///
  /// - `projectRoot`: absolute path of the app on your Mac, when sources should be relative to it
  ///   (defaults to `--dart-define=FIXME_PROJECT_ROOT`, else paths are made relative at `lib/`).
  static Widget wrap(Widget app, {String? projectRoot}) {
    if (!kDebugMode) return app;
    const fromEnvironment = String.fromEnvironment('FIXME_PROJECT_ROOT');
    _controller ??= FixmeController(projectRoot: projectRoot ?? (fromEnvironment.isEmpty ? null : fromEnvironment));
    WidgetsFlutterBinding.ensureInitialized();
    _controller!.start();
    return app;
  }

  /// Opens FIXME's overlay from your own code (a debug menu item, for example), as a three-finger tap does.
  static void open() {
    if (!kDebugMode) return;
    _controller?.open();
  }

  /// Clips the last `seconds` (5 to 60) and sends it to the Mac for review.
  static Future<void> clip({int seconds = 30}) async {
    if (!kDebugMode) return;
    await _controller?.clip(seconds.clamp(5, 60));
  }
}
