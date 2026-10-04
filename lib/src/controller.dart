// The running helper, one instance per app, created by FixmeFlutter.wrap in debug builds only.
//
// FIXME's overlay, Mac link, pairing, tickets and clips are native (PointerKit on iOS, the Android helper on Android).
// This is the Dart half: it asks the native helper whether it is running, captures the console and the taps, and answers
// the native overlay's "what do you know about these circles?" with the widgets under each circle, their source files and
// lines, the screen, the console and the widget tree (enrich.dart). It draws nothing and opens no connection.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'enrich.dart';
import 'geometry.dart';
import 'gesture.dart';
import 'native_bridge.dart';
import 'snapshot.dart';
import 'taps.dart';

/// Whether a native FIXME helper is in the app.
enum FixmeMode {
  /// Not decided yet (the first question to the native helper is still on its way).
  undecided,

  /// A native helper (PointerKit on iOS, the Android helper on Android) draws the overlay and talks to the Mac. Dart says
  /// which widget was circled, with its file and line, and what the app printed (enrich.dart).
  native,

  /// No native helper is running: a Profile or Release build, an iPhone older than iOS 16, a platform FIXME has no helper
  /// for. Nothing is drawn and nothing is sent.
  none,
}

class FixmeController {
  FixmeController({this.projectRoot, FixmeNativeBridge? native}) : native = native ?? FixmeNativeBridge();

  /// The native helper, when the app has one (see [mode]).
  final FixmeNativeBridge native;
  final ValueNotifier<FixmeMode> mode = ValueNotifier(FixmeMode.undecided);
  FixmeNativeInfo? nativeInfo;

  /// Absolute path of the app on the Mac, so sources are relative to it (else they are cut at `lib/`).
  final String? projectRoot;

  final List<(int, Map<String, Object?>)> _console = [];
  final List<(int, Map<String, Object?>)> _timeline = [];
  DebugPrintCallback? _previousDebugPrint;
  FlutterExceptionHandler? _previousOnError;
  bool _started = false;

  // ---- lifecycle ----

  void start() {
    if (_started) return;
    _started = true;
    _hookConsole();
    _hookPointers();
    if (!_creationTracked) {
      debugPrint('FIXME: this build does not record where widgets were created, so tickets will have no file and line. '
          'Run the app with flutter run, or from Xcode or Android Studio, instead of flutter build.');
    }
    unawaited(_decide());
  }

  /// Asks the native helper once: running means it draws the overlay and Dart answers its questions.
  Future<void> _decide() async {
    final info = await native.info();
    if (info != null && info.nativeOverlay) {
      nativeInfo = info;
      mode.value = FixmeMode.native;
      await native.startEnrichment(_enrich);
    } else {
      mode.value = FixmeMode.none;
    }
  }

  bool get _creationTracked => WidgetInspectorService.instance.isWidgetCreationTracked();

  /// The three-finger tap, from code (a debug menu item): the native overlay.
  void open() {
    if (mode.value != FixmeMode.native) return;
    _freeze();
    unawaited(native.openOverlay());
  }

  /// Clips the last `seconds` (the native helper's rewind buffer).
  Future<void> clip(int seconds) async {
    if (mode.value == FixmeMode.native) await native.clip(seconds);
  }

  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    mode.dispose();
    if (_previousDebugPrint != null) debugPrint = _previousDebugPrint!;
    if (_previousOnError != null) FlutterError.onError = _previousOnError;
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // ---- console ----

  /// debugPrint and Flutter errors. (print() from your own code needs a Zone in main; the Mac also reads the VM
  /// service's Stdout stream when it is connected to the same app.)
  void _hookConsole() {
    _previousDebugPrint = debugPrint;
    final prev = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) _addLog('info', 'debugPrint', message);
      prev(message, wrapWidth: wrapWidth);
    };
    _previousOnError = FlutterError.onError;
    final prevError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final text = details.exceptionAsString();
      _addLog('error', 'flutter', text);
      _addEvent(text.contains('overflowed') ? 'warning' : 'error', text.split('\n').first);
      prevError?.call(details);
    };
  }

  void _addLog(String level, String source, String message) {
    _console.add((_now, {'level': level, 'source': source, 'message': message}));
    if (_console.length > 2000) _console.removeRange(0, _console.length - 2000);
  }

  void _addEvent(String kind, String summary) {
    _timeline.add((_now, {'kind': kind, 'summary': summary}));
    if (_timeline.length > 500) _timeline.removeRange(0, _timeline.length - 500);
  }

  // ---- the screen ----

  ui.FlutterView? get _view => WidgetsBinding.instance.platformDispatcher.views.firstOrNull;

  Size get logicalScreen {
    final v = _view;
    if (v == null) return Size.zero;
    return v.physicalSize / v.devicePixelRatio;
  }

  Map<String, Object?>? snapshot({int t = 0, Duration? deadline}) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    return SnapshotBuilder(projectRoot: projectRoot, screen: logicalScreen, deadline: deadline).build(root, t: t);
  }

  // ---- native mode: the answer to "what do you know about these circles?" ----

  final ThreeFingerDetector _fingers = ThreeFingerDetector();
  final Map<int, (Offset, int)> _downs = {};

  /// The widgets as they were when the screen froze (the three-finger tap), so a circle is matched against what the
  /// person saw even when the app moved on under the overlay (a refresh, an animation) before Send.
  Map<String, Object?>? _frozen;
  int _frozenAt = 0;
  static const int _frozenValidMs = 10 * 60 * 1000;

  void _hookPointers() => GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) {
      _downs[e.pointer] = (e.position, _now);
      if (_fingers.down(e.pointer, _now) && mode.value == FixmeMode.native) _freeze();
    } else if (e is PointerUpEvent) {
      final d = _downs.remove(e.pointer);
      _fingers.up(e.pointer);
      if (d != null && _downs.isEmpty && (e.position - d.$1).distance < 12 && _now - d.$2 < 500) _recordTap(e.position, e.viewId);
    } else if (e is PointerCancelEvent) {
      _downs.remove(e.pointer);
      _fingers.up(e.pointer);
    }
  }

  void _freeze() {
    _frozen = snapshot(deadline: _snapshotDeadline);
    _frozenAt = _now;
  }

  static const Duration _snapshotDeadline = Duration(milliseconds: 1400);

  /// A tap, in the timeline: "Tapped TextButton "Unlock Rituals Pro"".
  void _recordTap(Offset position, int viewId) {
    try {
      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(result, position, viewId);
      final summary = describeTap(result);
      if (summary != null) _addEvent('tap', summary);
    } catch (_) {
      // A tap that cannot be described is simply not in the timeline.
    }
  }

  /// The route on top of the root navigator (`/paywall`), read without changing anything, or null.
  String? _routeName() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    NavigatorState? navigator;
    void find(Element e) {
      if (navigator != null) return;
      if (e is StatefulElement && e.state is NavigatorState) {
        navigator = e.state as NavigatorState;
        return;
      }
      e.visitChildren(find);
    }

    root.visitChildren(find);
    String? name;
    try {
      // popUntil asks the predicate about the top route first and stops when it says yes: nothing is popped.
      navigator?.popUntil((route) {
        name = route.settings.name;
        return true;
      });
    } catch (_) {
      name = null;
    }
    return name;
  }

  /// The answer native would get for `request`, for tests.
  @visibleForTesting
  Future<String?> enrichForTest(Map<String, Object?> request) => _enrich(request);

  /// What the ticket's `state` says about this Flutter run.
  Map<String, String> _flutterState(Map<String, Object?>? snap) {
    final truncated = snap != null && snap['root'] is Map && ((snap['root'] as Map)['props'] as Map?)?['truncated'] == 'true';
    return {
      'flutter.mode': 'debug',
      'flutter.dart': Platform.version.split(' ').first,
      'flutter.widgetCreation': _creationTracked ? 'tracked' : 'off: this build was not made by flutter run or an IDE, so widgets have no file and line',
      if (truncated) 'flutter.tree': 'truncated: the widget tree was too large to read in time',
    };
  }

  Map<String, Object?>? _screenInfo(Map<String, Object?>? snap) {
    if (snap == null) return null;
    final info = compact({'name': screenNameOf(snap), 'route': _routeName()});
    return info.isEmpty ? null : info;
  }

  Future<String?> _enrich(Map<String, Object?> request) async {
    final isClip = request['kind'] == 'clip';
    // A mark ticket is matched against the tree as it was when the screen froze, when that was a moment ago.
    final fresh = !isClip && _frozen != null && _now - _frozenAt < _frozenValidMs;
    final snap = fresh ? _frozen : snapshot(deadline: _snapshotDeadline);
    final screen = _screenInfo(snap);
    return buildEnrichmentJson(
      request: request,
      snapshot: snap,
      console: _console,
      timeline: _timeline,
      state: _flutterState(snap),
      screenName: screen?['name'] as String?,
      route: screen?['route'] as String?,
    );
  }
}
