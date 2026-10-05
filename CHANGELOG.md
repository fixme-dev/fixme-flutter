# Changelog

## 0.1.2

- The Android helper is now 0.1.2 (from `https://maven.getfixme.dev`). iOS is unchanged: it still links FIXME's iOS overlay 0.1.5.
- Circle ink on Android is crisp and solid.
- The notice that appears when the mic is off has a new, calmer design and fits the dock.
- If the mic permission was denied, the overlay says so and has an Open Settings button that takes you straight to the right screen.
- Fixes to the sheet and the layout on Android screens drawn by Flutter, a steadier mic, and a faster overlay open.
- To update: change `ref: v0.1.1` to `ref: v0.1.2` in `pubspec.yaml` and run `flutter pub get`, then run your app again.

## 0.1.1

- A new overlay, on iOS and on Android. It was rebuilt for a real phone: three fingers open and close it, every circle gets a numbered ring and a note box beside it, and there is one dock at the bottom. iOS links FIXME's iOS overlay 0.1.5 (it was 0.1.4) and Android pulls the Android helper 0.1.1 (it was 0.1.0) from `https://maven.getfixme.dev`.
- Start the mic when I circle. It is off until you turn it on; once on, the mic starts listening as soon as you circle something.
- Live control on Android. While your coding agent drives your app through FIXME, a small pill with a Stop button stays on the phone or emulator, a soft ring shows where the agent taps, and touching the screen yourself takes over at once. Taps now activate a switch once, scrolling goes to the list you can see, and typing goes into the field that has focus. A screen drawn by Flutter is reported as Flutter. iOS has the same pill.
- A small tab on the right edge of the screen on Android opens the overlay, tells you when a report is on its way or waiting for your Mac, and is the way in when TalkBack is on. Two fingers scroll your app under the overlay, and a circle drawn over a native list moves with it. Over a Flutter list, ink stays where you drew it.
- When your free fixes are used up, a card on the phone says so instead of opening an overlay that would lose your work. Its button opens FIXME on your Mac. Buying FIXME unlocks the phone at once, with no new pairing and nothing to set up again.
- To update: change `ref: v0.1.0` to `ref: v0.1.1` in `pubspec.yaml` and run `flutter pub get`, then run your app again.

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
