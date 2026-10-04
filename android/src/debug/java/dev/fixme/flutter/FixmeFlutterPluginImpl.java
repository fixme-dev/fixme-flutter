package dev.fixme.flutter;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * The bridge between Dart and FIXME's native overlay (the Android helper, dev.getfixme:fixme-android). The Android twin of
 * ios/Classes/FixmeFlutterPlugin.m and of fixme-react-native's FixmeBridgeModule: the same channel name, constants, methods and
 * event (Packages/fixme-react-native/DEVELOPMENT.md, "Native bridge contract", version 1; Dart's end is lib/src/native_bridge.dart).
 *
 *   getConstants        {contract: 1, platform: "android", nativeOverlay, pointerKitVersion}
 *   startEnrichment     Dart is ready to answer (the framework name); the helper's questions now come as FixmeEnrichRequest
 *   resolveEnrichment   the answer ({id, json}); an empty json means "nothing to add"
 *   openOverlay / clip(seconds) / toggleRecording
 *   FixmeEnrichRequest  native to Dart: {id, request}, request being the JSON the contract describes
 *
 * The helper is found by name at run time (Class.forName on dev.fixme.android.FrameworkBridge) and called by reflection, so this
 * plugin has no compile-time dependency on it and still loads, reporting nativeOverlay false, if the helper is not there. The
 * helper's functions take Kotlin function types, implemented here with a dynamic proxy so no Kotlin runtime is needed to build.
 */
public class FixmeFlutterPluginImpl implements FlutterPlugin, MethodCallHandler {
  private static final String CHANNEL = "dev.fixme/bridge";
  private static final String EVENT = "FixmeEnrichRequest";
  /** The helper waits 2.5 s for an answer; a reply older than this is dropped. */
  private static final long REPLY_EXPIRY_MS = 10_000;

  private final Handler main = new Handler(Looper.getMainLooper());
  private final Object lock = new Object();
  private final Map<String, Object> replies = new HashMap<>();
  private final Map<String, Long> asked = new HashMap<>();
  private MethodChannel channel;
  private boolean registered = false;
  private String framework = "flutter";

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    release();
    if (channel != null) channel.setMethodCallHandler(null);
    channel = null;
  }

  // ---- the helper, by name ----

  @Nullable
  private static Class<?> helper() {
    try {
      return Class.forName("dev.fixme.android.FrameworkBridge");
    } catch (Throwable t) {
      return null;
    }
  }

  @Nullable
  private static Object call(String method, Class<?>[] types, Object... args) {
    Class<?> cls = helper();
    if (cls == null) return null;
    try {
      return cls.getMethod(method, types).invoke(null, args);
    } catch (Throwable t) {
      return null;
    }
  }

  private static boolean running() {
    Object r = call("isRunning", new Class<?>[0]);
    return r instanceof Boolean && (Boolean) r;
  }

  // ---- the contract ----

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "getConstants": {
        boolean on = running();
        Map<String, Object> c = new HashMap<>();
        c.put("contract", 1);
        c.put("platform", "android");
        // True when the helper is in this app and started (a debuggable build): Dart then draws no UI of its own.
        c.put("nativeOverlay", on);
        Object v = on ? call("sdkVersion", new Class<?>[0]) : null;
        c.put("pointerKitVersion", v instanceof String ? v : null);
        result.success(c);
        return;
      }
      case "startEnrichment": {
        startEnrichment(call.arguments instanceof String ? (String) call.arguments : "flutter");
        result.success(null);
        return;
      }
      case "resolveEnrichment": {
        String id = call.argument("id");
        String json = call.argument("json");
        resolve(id, json);
        result.success(null);
        return;
      }
      case "openOverlay":
        call("openOverlay", new Class<?>[0]);
        result.success(null);
        return;
      case "clip": {
        int seconds = call.arguments instanceof Number ? ((Number) call.arguments).intValue() : 30;
        call("clip", new Class<?>[] { int.class }, seconds);
        result.success(null);
        return;
      }
      case "toggleRecording":
        call("toggleRecording", new Class<?>[0]);
        result.success(null);
        return;
      default:
        result.notImplemented();
    }
  }

  private void startEnrichment(String name) {
    Class<?> cls = helper();
    if (cls == null) return;
    framework = name == null || name.isEmpty() ? "flutter" : name;
    try {
      final Class<?> function2 = Class.forName("kotlin.jvm.functions.Function2");
      final Object unit = Class.forName("kotlin.Unit").getField("INSTANCE").get(null);
      Object handler = Proxy.newProxyInstance(function2.getClassLoader(), new Class<?>[] { function2 }, new InvocationHandler() {
        @Override
        public Object invoke(Object proxy, Method method, Object[] args) {
          if ("invoke".equals(method.getName()) && args != null && args.length == 2) {
            ask((String) args[0], args[1]);
            return unit;
          }
          if ("toString".equals(method.getName())) return "FixmeEnricher";
          if ("hashCode".equals(method.getName())) return System.identityHashCode(proxy);
          if ("equals".equals(method.getName())) return proxy == args[0];
          return null;
        }
      });
      cls.getMethod("setEnricher", String.class, function2).invoke(null, framework, handler);
      registered = true;
    } catch (Throwable t) {
      registered = false;
    }
  }

  /** The helper asks (on its worker thread): pass the question to Dart on the main thread and hold the reply until it answers. */
  private void ask(final String requestJson, final Object reply) {
    final String id = UUID.randomUUID().toString();
    long now = System.currentTimeMillis();
    List<Object> expired = new ArrayList<>();
    synchronized (lock) {
      for (String old : new ArrayList<>(asked.keySet())) {
        if (now - asked.get(old) > REPLY_EXPIRY_MS) { asked.remove(old); Object r = replies.remove(old); if (r != null) expired.add(r); }
      }
      replies.put(id, reply);
      asked.put(id, now);
    }
    for (Object r : expired) reply(r, null);
    main.post(new Runnable() {
      @Override
      public void run() {
        MethodChannel ch = channel;
        if (ch == null) { resolve(id, null); return; }
        Map<String, Object> args = new HashMap<>();
        args.put("id", id);
        args.put("request", requestJson);
        try {
          ch.invokeMethod(EVENT, args, new Result() {
            @Override public void success(@Nullable Object o) { /* Dart answers with resolveEnrichment */ }
            // Dart is not listening (a hot restart is between two main functions): nothing to wait for.
            @Override public void error(@NonNull String code, @Nullable String message, @Nullable Object details) { resolve(id, null); }
            @Override public void notImplemented() { resolve(id, null); }
          });
        } catch (Throwable t) {
          resolve(id, null);
        }
      }
    });
  }

  private static void reply(Object function1, @Nullable String json) {
    try {
      Class<?> f1 = Class.forName("kotlin.jvm.functions.Function1");
      f1.getMethod("invoke", Object.class).invoke(function1, json);
    } catch (Throwable t) {
      // The helper has moved on.
    }
  }

  /** The answer: a JSON string, or an empty one (or null) for "nothing to add". */
  private void resolve(@Nullable String id, @Nullable String json) {
    if (id == null) return;
    Object r;
    synchronized (lock) { r = replies.remove(id); asked.remove(id); }
    if (r != null) reply(r, json == null || json.isEmpty() ? null : json);
  }

  /** The engine went away (a hot restart, a detach): the helper stops asking until Dart registers again. */
  private void release() {
    Class<?> cls = helper();
    if (cls != null && registered) {
      try {
        Class<?> function2 = Class.forName("kotlin.jvm.functions.Function2");
        cls.getMethod("setEnricher", String.class, function2).invoke(null, framework, null);
      } catch (Throwable t) {
        // Nothing to undo.
      }
    }
    registered = false;
    List<Object> pending;
    synchronized (lock) { pending = new ArrayList<>(replies.values()); replies.clear(); asked.clear(); }
    for (Object r : pending) reply(r, null);
  }
}
