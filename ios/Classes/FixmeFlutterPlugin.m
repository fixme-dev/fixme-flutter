// The bridge between Dart and FIXME's native overlay (PointerKit).
//
// On iOS the overlay, the Mac link, pairing, tickets, clips and the destination sheet are all native (PointerKit, linked
// into the app by this pod's xcconfig, Debug configurations only). This plugin does the one thing only Dart can: when the
// person sends a ticket, PointerKit asks "what do you know about these circles?" and Dart answers with the widget under
// each circle and its file and line, the Flutter console and the current screen. Everything else is the contract in
// Packages/fixme-react-native/DEVELOPMENT.md ("Native bridge contract"), which the React Native module implements too.
//
// PointerKit is found by name at run time (NSClassFromString), so nothing here links against it; the plugin still loads,
// reporting nativeOverlay false, when PointerKit is not in the app (Profile, Release, an iPhone older than iOS 16).

#import "FixmeFlutterPlugin.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if DEBUG
static NSString *const kChannelName = @"dev.fixme/bridge";
static NSString *const kEnrichEvent = @"FixmeEnrichRequest";
/// PointerKit waits 2.5 s for an answer; a reply block older than this is dropped.
static const NSTimeInterval kReplyExpiry = 10.0;
#endif

#if DEBUG
/// The selectors PKFrameworkBridge (PointerKit/iOS/FrameworkBridge.swift) answers to.
@protocol FixmePointerKitBridge <NSObject>
+ (BOOL)isRunning;
+ (NSString *)sdkVersion;
+ (void)setEnricher:(NSString *)framework handler:(nullable void (^)(NSString *requestJSON, void (^reply)(NSString *_Nullable replyJSON)))handler;
+ (void)openOverlay;
+ (void)clipSeconds:(NSInteger)seconds;
+ (void)toggleRecording;
@end

static Class<FixmePointerKitBridge> _Nullable PointerKitBridge(void) {
  Class cls = NSClassFromString(@"PKFrameworkBridge");
  return cls && [cls respondsToSelector:@selector(isRunning)] ? (Class<FixmePointerKitBridge>)cls : nil;
}
#endif

@implementation FixmeFlutterPlugin {
  FlutterMethodChannel *_Nullable _channel;
  __weak NSObject<FlutterPluginRegistrar> *_registrar;
  BOOL _registered;
  NSMutableDictionary<NSString *, void (^)(NSString *_Nullable)> *_replies;
  NSMutableDictionary<NSString *, NSDate *> *_asked;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
#if DEBUG
  FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:kChannelName binaryMessenger:[registrar messenger]];
  FixmeFlutterPlugin *instance = [FixmeFlutterPlugin new];
  instance->_channel = channel;
  instance->_registrar = registrar;
  instance->_replies = [NSMutableDictionary new];
  instance->_asked = [NSMutableDictionary new];
  [registrar addMethodCallDelegate:instance channel:channel];
#endif
  // Profile and Release: nothing is registered. The class exists only because the generated plugin registrant names it
  // (Flutter's iOS tooling does not leave dev_dependency plugins out of release builds yet).
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *method = call.method;
#if DEBUG
  Class<FixmePointerKitBridge> bridge = PointerKitBridge();
#endif

  if ([method isEqualToString:@"getConstants"]) {
#if DEBUG
    BOOL running = bridge ? [bridge isRunning] : NO;
    // `nativeOverlay` is true when PointerKit is in this app and started (a Debug build): Dart then draws no UI of its own.
    result(@{ @"contract" : @1, @"platform" : @"ios", @"nativeOverlay" : @(running), @"pointerKitVersion" : running ? [bridge sdkVersion] : [NSNull null] });
#else
    result(@{ @"contract" : @1, @"platform" : @"ios", @"nativeOverlay" : @NO });
#endif
    return;
  }

#if DEBUG
  if ([method isEqualToString:@"startEnrichment"]) {
    NSString *framework = [call.arguments isKindOfClass:[NSString class]] ? call.arguments : @"flutter";
    if (bridge) {
      _registered = YES;
      __weak FixmeFlutterPlugin *weakSelf = self;
      // PointerKit calls this off the main thread, at Send. The channel is main-thread only.
      [bridge setEnricher:framework handler:^(NSString *requestJSON, void (^reply)(NSString *_Nullable)) {
        dispatch_async(dispatch_get_main_queue(), ^{
          FixmeFlutterPlugin *strongSelf = weakSelf;
          if (strongSelf) { [strongSelf ask:requestJSON reply:reply]; } else { reply(nil); }
        });
      }];
    }
    result(nil);
    return;
  }

  if ([method isEqualToString:@"resolveEnrichment"]) {
    NSDictionary *args = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : @{};
    NSString *json = [args[@"json"] isKindOfClass:[NSString class]] ? args[@"json"] : nil;
    [self resolve:args[@"id"] json:json];
    result(nil);
    return;
  }

  if ([method isEqualToString:@"openOverlay"]) { if (bridge) [bridge openOverlay]; result(nil); return; }
  if ([method isEqualToString:@"clip"]) {
    NSNumber *seconds = [call.arguments isKindOfClass:[NSNumber class]] ? call.arguments : @30;
    if (bridge) [bridge clipSeconds:seconds.integerValue];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"toggleRecording"]) { if (bridge) [bridge toggleRecording]; result(nil); return; }
#endif

  // Everything else is a no-op outside Debug builds, so a Dart side one version ahead never throws.
  if ([method isEqualToString:@"startEnrichment"] || [method isEqualToString:@"resolveEnrichment"] || [method isEqualToString:@"openOverlay"] ||
      [method isEqualToString:@"clip"] || [method isEqualToString:@"toggleRecording"]) {
    result(nil);
    return;
  }
  result(FlutterMethodNotImplemented);
}

#if DEBUG
/// The question PointerKit asked, forwarded to Dart. Dart answers with `resolveEnrichment`.
- (void)ask:(NSString *)requestJSON reply:(void (^)(NSString *_Nullable))reply {
  if (!_channel) { reply(nil); return; }
  NSString *identifier = [[NSUUID UUID] UUIDString];
  NSDate *now = [NSDate date];
  for (NSString *old in [_asked allKeys]) {
    if ([now timeIntervalSinceDate:_asked[old]] > kReplyExpiry) { [_asked removeObjectForKey:old]; [_replies removeObjectForKey:old]; }
  }
  _replies[identifier] = [reply copy];
  _asked[identifier] = now;
  __weak FixmeFlutterPlugin *weakSelf = self;
  [_channel invokeMethod:kEnrichEvent
               arguments:@{ @"id" : identifier, @"request" : [self requestJSON:requestJSON withViewFrameIn:_registrar] }
                  result:^(id _Nullable answer) {
                    // Dart is not listening (a hot restart is between two main functions): nothing to wait for.
                    if (answer == FlutterMethodNotImplemented || [answer isKindOfClass:[FlutterError class]]) [weakSelf resolve:identifier json:nil];
                  }];
}

/// PointerKit's marks are in the window's points. Flutter's logical pixels start at the Flutter view, which is not at the
/// window's origin in every app (a split view, an iPad window, Flutter added to a native screen), so the view's frame in
/// the window goes along as `viewFrame` and Dart subtracts its origin.
- (NSString *)requestJSON:(NSString *)json withViewFrameIn:(nullable NSObject<FlutterPluginRegistrar> *)registrar {
  UIView *view = registrar.viewController.view;
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] : nil;
  if (!view || ![parsed isKindOfClass:[NSMutableDictionary class]]) return json;
  CGRect frame = [view convertRect:view.bounds toView:nil];
  ((NSMutableDictionary *)parsed)[@"viewFrame"] = @{ @"x" : @(frame.origin.x), @"y" : @(frame.origin.y), @"width" : @(frame.size.width), @"height" : @(frame.size.height) };
  NSData *out = [NSJSONSerialization dataWithJSONObject:parsed options:0 error:nil];
  return out ? [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding] : json;
}

- (void)resolve:(nullable NSString *)identifier json:(nullable NSString *)json {
  if (![identifier isKindOfClass:[NSString class]]) return;
  void (^reply)(NSString *_Nullable) = _replies[identifier];
  [_replies removeObjectForKey:identifier];
  [_asked removeObjectForKey:identifier];
  if (reply) reply(json.length ? json : nil);
}

/// The engine went away: PointerKit stops asking until a new Dart isolate registers again.
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  Class<FixmePointerKitBridge> bridge = PointerKitBridge();
  if (bridge && _registered) [bridge setEnricher:@"flutter" handler:nil];
  _registered = NO;
  _channel = nil;
  NSArray *pending = [_replies allValues];
  [_replies removeAllObjects];
  [_asked removeAllObjects];
  for (void (^reply)(NSString *_Nullable) in pending) reply(nil);
}
#endif

@end

NS_ASSUME_NONNULL_END
