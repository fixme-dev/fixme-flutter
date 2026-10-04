// Dart's end of the framework bridge: one MethodChannel to the native FIXME helper that draws the overlay and owns the
// Mac link (PointerKit on iOS). The member names are the contract the React Native module implements too
// (Packages/fixme-react-native/DEVELOPMENT.md, "Native bridge contract"), version 1:
//
//   getConstants          contract, platform, nativeOverlay, pointerKitVersion
//   startEnrichment       Dart is ready to answer: from now on native asks `FixmeEnrichRequest {id, request}`
//   resolveEnrichment     the answer to one request ({id, json}); an empty json means "nothing to add"
//   openOverlay / clip(seconds) / toggleRecording
//
// A platform without the native half (Android today, a Profile or Release build, an iPhone older than iOS 16) throws
// MissingPluginException on the first call, which is how `info()` learns that Dart has to draw the overlay itself.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// What the native helper says about itself (the constants of the bridge contract).
class FixmeNativeInfo {
  const FixmeNativeInfo({required this.contract, required this.platform, required this.nativeOverlay, this.pointerKitVersion});
  final int contract;
  final String platform;

  /// The native helper is in the app and running: it draws the overlay, so Dart draws none.
  final bool nativeOverlay;
  final String? pointerKitVersion;

  static const int supportedContract = 1;

  /// Null when the map is not from a module of a contract this package understands.
  static FixmeNativeInfo? parse(Object? raw) {
    if (raw is! Map) return null;
    final contract = raw['contract'];
    if (contract is! num || contract.toInt() != supportedContract) return null;
    final version = raw['pointerKitVersion'];
    return FixmeNativeInfo(
      contract: contract.toInt(),
      platform: raw['platform'] is String ? raw['platform'] as String : 'unknown',
      nativeOverlay: raw['nativeOverlay'] == true,
      pointerKitVersion: version is String ? version : null,
    );
  }
}

/// Answers "what do you know about these circles?". `request` is the decoded request (see enrich.dart); return the JSON
/// answer, or null for "nothing to add".
typedef FixmeEnricher = Future<String?> Function(Map<String, Object?> request);

class FixmeNativeBridge {
  FixmeNativeBridge({MethodChannel? channel, this.answerBudget = defaultAnswerBudget}) : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'dev.fixme/bridge';

  /// The native side gives Dart 2.5 s (iOS `FrameworkBridge.patience`) and sends the ticket without an answer after
  /// that, so the answer goes back inside 2.2 s with whatever there is.
  static const Duration defaultAnswerBudget = Duration(milliseconds: 2200);
  final Duration answerBudget;

  final MethodChannel _channel;
  FixmeEnricher? _enricher;

  /// The native helper, or null when there is none (no plugin half, or a contract this package does not know).
  Future<FixmeNativeInfo?> info() async {
    try {
      return FixmeNativeInfo.parse(await _channel.invokeMapMethod<String, Object?>('getConstants'));
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Registers `enricher` and tells native that Dart can answer. Safe to call again (a hot restart calls it again).
  Future<void> startEnrichment(FixmeEnricher enricher, {String framework = 'flutter'}) async {
    _enricher = enricher;
    _channel.setMethodCallHandler(_onCall);
    try {
      await _channel.invokeMethod<void>('startEnrichment', framework);
    } on MissingPluginException {
      // No native half: nothing will ask.
    }
  }

  Future<void> openOverlay() => _invoke('openOverlay');
  Future<void> clip(int seconds) => _invoke('clip', seconds);
  Future<void> toggleRecording() => _invoke('toggleRecording');

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Nothing to open without a native helper.
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'FixmeEnrichRequest') throw MissingPluginException(call.method);
    final args = call.arguments;
    if (args is! Map) return null;
    final id = args['id'];
    final request = args['request'];
    if (id is! String || request is! String) return null;
    // The native side waits for resolveEnrichment, not for this call, so the work does not hold the channel.
    unawaited(_answer(id, request));
    return null;
  }

  Future<void> _answer(String id, String requestJson) async {
    var json = '';
    try {
      final decoded = jsonDecode(requestJson);
      final enricher = _enricher;
      if (decoded is Map<String, Object?> && enricher != null) json = await _within(answerBudget, () => enricher(decoded)) ?? '';
    } catch (_) {
      json = '';
    }
    try {
      await _channel.invokeMethod<void>('resolveEnrichment', {'id': id, 'json': json});
    } on MissingPluginException {
      // The engine went away.
    }
  }

  /// The result of `work`, or null when it takes longer than `budget` or fails. (Future.timeout is not used: an async
  /// closure that returns a String is a Future<String> at run time, and its onTimeout then cannot return null.)
  static Future<String?> _within(Duration budget, Future<String?> Function() work) {
    final done = Completer<String?>();
    final timer = Timer(budget, () {
      if (!done.isCompleted) done.complete(null);
    });
    Future<String?>.sync(work).then((value) {
      if (!done.isCompleted) done.complete(value);
    }, onError: (Object _) {
      if (!done.isCompleted) done.complete(null);
    });
    return done.future.whenComplete(timer.cancel);
  }
}
