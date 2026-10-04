# Changelog

## 0.1.0

- First release. Debug builds only: `FixmeFlutter.wrap` returns your app unchanged in profile and release builds, and the
  helper is tree-shaken away.
- iOS: FIXME's native overlay (the one a Swift app gets) opens inside your Flutter app with a three-finger tap. The package
  is a Flutter plugin that links the overlay into Debug configurations only; Dart answers which widget was circled, with its
  file and line, and sends the screen name and route, the widget tree, `debugPrint` and Flutter errors, and the taps that led
  there. Clips and Record come from the native overlay.
- Android: FIXME's Android helper's overlay opens inside your Flutter app (the plugin's `android/` library carries the helper in
  debug builds only; release and profile are inert), and Dart answers which widget was circled, with its file and line, exactly
  as on iOS. Clips and Record come from the native overlay.
- Works with `flutter run` and your IDE (they record where each widget was created). A build made without that says so in the
  ticket.
- `FixmeFlutter.open()` and `FixmeFlutter.clip(seconds:)` from your own debug menu.
