# FIXME for Flutter

The Flutter helper for [FIXME](https://getfixme.dev), the Mac app that turns "this looks wrong" into a fix. Tap your
app with three fingers, circle what's wrong, say what you see, and your coding agent on the Mac (Claude Code, Codex,
Cursor and others) gets the exact file and line of the widget, a screenshot, the widget tree, the console and a short
clip.

It runs only in debug builds. On iOS you get FIXME's own native overlay, the same one FIXME gives a Swift app, with your
widgets named in the ticket. On Android you get the same overlay from FIXME's Android helper (the plugin brings it in, in
debug builds only). In profile and release builds nothing runs, and the native parts are not linked at all.

**You may not need it.** With the FIXME Mac app, any Flutter debug build started with `flutter run` already works with
no package: circle on the Mac (Simulator, Emulator or a mirrored phone) and FIXME reads the exact file and line over
the Dart VM service. Add this package when you want to circle **on the phone itself**.

## Install

**The easy way:** open FIXME on your Mac and choose **Add FIXME to your app** in onboarding (or Settings › General ›
Exact mode). FIXME shows the change first, and you can undo it any time.

**By hand.** Add the package as a dev dependency, from its Git repository:

```yaml
# pubspec.yaml
dev_dependencies:
  fixme_flutter:
    git:
      url: https://github.com/fixme-dev/fixme-flutter.git
      ref: v0.1.5
```

and wrap your root widget:

```dart
import 'package:fixme_flutter/fixme_flutter.dart'; // ignore: depend_on_referenced_packages

void main() => runApp(FixmeFlutter.wrap(const MyApp()));
```

Then run your app from your IDE or with `flutter run`. That's it. (A dev dependency is fine to import from `lib/`; the
analyzer's `depend_on_referenced_packages` lint flags it, hence the comment. Add it under `dependencies:` instead if you
prefer a clean analyzer.)

In profile and release builds `FixmeFlutter.wrap` returns your app unchanged and the helper is tree-shaken away.

### Run with `flutter run`

FIXME finds the file and line of a widget from the location Flutter records when the widget is created. `flutter run`
and your IDE's Run button record it; a build made with `flutter build ios --debug` does not, and FIXME says so in the
ticket instead of guessing.

### iOS

The first iOS build runs `pod install` by itself. The native overlay is linked into the **Debug** configurations only,
so Profile and Release builds contain no FIXME code. It needs iOS 16 or later; on an older iPhone FIXME's overlay is not available and the app runs as usual.

On a real iPhone, iOS asks before an app may look for your Mac on the Wi-Fi, and only for services the app declares. Add
these to `ios/Runner/Info.plist` (the Mac app's installer does this for you; the Simulator needs none of them):

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>FIXME uses the local network in debug builds to send bug reports to your Mac.</string>
<key>NSBonjourServices</key>
<array><string>_pointer._tcp</string></array>
<key>NSMicrophoneUsageDescription</key>
<string>Lets you describe a bug out loud while debugging (debug builds only).</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Turns your spoken bug notes into text while debugging (debug builds only).</string>
```

The last two are optional: without them the phone doesn't listen, and FIXME's bar says the Mac's microphone is used
instead. These are inert declarations in a release build, because the code that would use the network or the
microphone is never linked into it.

### Android

Nothing to add in your project. The plugin's `android/` folder is a library with a debug variant that depends on FIXME's Android
helper (`dev.getfixme:fixme-android`, from `https://maven.getfixme.dev`; the plugin adds that repository, limited to its own
group, to your build) and release and profile variants that contain nothing, so a release APK has no FIXME code. The helper draws
the overlay and owns the Mac link; Dart answers which widget was circled. The Mac app runs `adb reverse tcp:47822 tcp:47822`
for attached devices, so a phone on USB or an emulator finds your Mac at once. To try an unpublished helper, point Gradle at a folder:
`FIXME_MAVEN_URL=file:///path/to/maven flutter run`.

## Using it

1. Start your app in debug on a phone, Simulator or emulator, with FIXME open on your Mac (on the same Wi-Fi for a
   phone without a cable).
2. The first time, allow the phone on your Mac.
3. Tap with three fingers, circle what's wrong, and send. Tap the mic to say what you see (tap it again to stop), or
   tap Type; each circle keeps its own note. Say "FIXME, clip that" to send the last 30 seconds as a clip.
4. `FixmeFlutter.open()` opens the same overlay from your own debug menu, and `FixmeFlutter.clip(seconds: 10)` sends a
   clip from code.
5. While your coding agent drives your app through FIXME, a pill with a Stop button shows on the phone. Touch the screen
   yourself, or tap Stop, and you have control again.
6. When your free fixes are used up, a card on the phone says so instead of opening the overlay. Its button opens FIXME on
   your Mac, and buying FIXME unlocks the phone with nothing to set up again.

## What a ticket contains

- For each circle, the widgets under it, best first: type, text, `ValueKey`, frame, the widgets around it and **the
  file and line where it was created** (`lib/screens/paywall_screen.dart:114`). A widget your own code builds inside
  another of your widgets also names that outer call site.
- The name of the screen and its route, the widget tree with a frame, text and source for every widget your code
  created (with `clipped` on ellipsized text and overflowing rows), what the app printed with `debugPrint`, Flutter
  errors, and the taps that led there (`Tapped TextButton "Unlock Pro"`).
- A screenshot, the clip, the device, the app and the Flutter version. Network requests are filled in by the Mac when it is
  connected to the same `flutter run` session.

## Requirements

Flutter 3.10 or later, and the FIXME Mac app. The native overlay needs iOS 16 or later.

## Privacy

The helper talks only to your own Mac: directly over your network or USB cable, or, on iOS, through FIXME's end-to-end
encrypted relay. Nothing goes to any other server.

## Bugs and ideas

Found a bug, or have an idea? Open an issue at https://github.com/fixme-dev/fixme-issues. Issues there are public, so
leave out file paths, phone names and anything private. In the FIXME app, Help, then Report a Bug, fills in your versions for you.

## License

See [LICENSE](LICENSE). Free to use in development builds alongside FIXME.
