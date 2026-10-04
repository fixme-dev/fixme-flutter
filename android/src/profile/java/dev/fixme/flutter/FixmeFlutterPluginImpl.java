package dev.fixme.flutter;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * The release and profile variant: nothing of FIXME. The class exists only because Flutter's generated plugin registrant names
 * it in every build type; it answers "no native overlay" so Dart does nothing (its own code is behind kDebugMode anyway).
 */
public class FixmeFlutterPluginImpl implements FlutterPlugin, MethodCallHandler {
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "dev.fixme/bridge");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "getConstants": {
        Map<String, Object> c = new HashMap<>();
        c.put("contract", 1);
        c.put("platform", "android");
        c.put("nativeOverlay", false);
        result.success(c);
        return;
      }
      case "startEnrichment":
      case "resolveEnrichment":
      case "openOverlay":
      case "clip":
      case "toggleRecording":
        result.success(null);
        return;
      default:
        result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
    channel = null;
  }
}
