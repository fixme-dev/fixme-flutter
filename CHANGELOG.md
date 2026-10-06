# Changelog

## 0.1.4

- The Android helper is now 0.1.4 (from `https://maven.getfixme.dev`) and iOS links FIXME's iOS overlay 0.1.7.
- Dark mode and screen readers on Android: the app behind FIXME's cards is hidden from a screen reader while they are up, every control says what it is, notices and send steps are spoken, a screen reader can circle the whole screen with an action, and the dark or light chrome follows the app instead of the phone. Text and icon contrast is held to 4.5:1 and 3:1.
- Hands-free is opt-in. The phone's microphone stays closed for "FIXME, clip that" unless the person turned on Hands-free on the Mac (the `handsFree` capability the Mac sends; absent, an older Mac or no Mac all mean off). Dictation with the mic button in the note box works either way, and turning the switch off closes the microphone at once.
- A movable dock, on Android and iOS. Drag the dock by its body (not its buttons) and it glides to the top or bottom of the screen and stays there for that app; it steps aside once when a circle lands under it, never while a finger is down, and the boxes, the Undo notice, the send status, the first-run lesson and the keyboard all follow it. Reduce Motion crossfades instead, and VoiceOver and TalkBack offer "Move to top" and "Move to bottom".
- A quiet "free fixes left" line after Send during the free trial (5 left or fewer): "N free fixes left", and "1 free fix left. Get FIXME on your Mac for no limits." at the last one. Nothing shows with plenty left or once licensed.
- A small connection glyph before the destination line: a cable over USB, Wi-Fi on the local network, a cloud through the relay. It says "connected over USB" or "over Wi-Fi" to a screen reader.
- Words said before you tap the note box's mic never reach the note, on Android and iOS. The phone listens all the time for "FIXME", so someone talking nearby could fill the note the moment you tapped. Tapping the mic now starts a fresh listener that only hears what comes after.
- To update: change `ref: v0.1.3` to `ref: v0.1.4` in `pubspec.yaml` and run `flutter pub get`, then run your app again.

## 0.1.3

- The Android helper is now 0.1.3 (from `https://maven.getfixme.dev`) and iOS links FIXME's iOS overlay 0.1.6.
- Clips on Android are ready in about a second, not about eight.
- Flutter screens are no longer black in Android clips, circle screenshots and live screenshots.
- The first-time lesson shows the real dock and the real edge tab, on Android and iOS, instead of a drawn copy.
- The edge tab on Android and iOS only opens the overlay. Its film button was taken for the way in.
- The "FIXME" on the edge tab no longer clips at a large font size on Android.
- When your agent drives your app through FIXME on Android, each answer waits until the screen has stopped moving.
- Live control never answers with an empty screen. If the app is in the background the answer says so (Android and iOS), and a window that is visible but paused, such as a permission dialog, the share sheet or split screen, is still driven on Android.
- On Android, if the phone's speech recognizer stops answering, the note box says so and lets you type, instead of listening forever.
- To update: change `ref: v0.1.2` to `ref: v0.1.3` in `pubspec.yaml` and run `flutter pub get`, then run your app again.

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
