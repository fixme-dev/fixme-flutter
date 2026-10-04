package dev.fixme.flutter;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * The plugin class Flutter's tooling looks for (it checks src/main for the class named in pubspec.yaml). It does nothing itself:
 * the build variant supplies FixmeFlutterPluginImpl, the real bridge to the Android helper in debug builds (src/debug) and an
 * inert one in release and profile builds (src/release, src/profile), so a release build has no FIXME code behind this name.
 */
public class FixmeFlutterPlugin implements FlutterPlugin {
  private final FixmeFlutterPluginImpl impl = new FixmeFlutterPluginImpl();

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    impl.onAttachedToEngine(binding);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    impl.onDetachedFromEngine(binding);
  }
}
