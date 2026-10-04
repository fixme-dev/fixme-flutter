#import <Flutter/Flutter.h>

/// The bridge between Dart and FIXME's native overlay (PointerKit). One MethodChannel, `dev.fixme/bridge`, with the member
/// names of the framework bridge contract (Packages/fixme-react-native/DEVELOPMENT.md, "Native bridge contract"):
///
///   Dart -> native: getConstants (contract, platform, nativeOverlay, pointerKitVersion), startEnrichment(framework),
///                   resolveEnrichment({id, json}), openOverlay, clip(seconds), toggleRecording
///   native -> Dart: FixmeEnrichRequest({id, request})
///
/// Debug builds only do anything; in Profile and Release the class exists (the generated plugin registrant names it) but
/// reports nativeOverlay false and never touches PointerKit.
@interface FixmeFlutterPlugin : NSObject <FlutterPlugin>
@end
