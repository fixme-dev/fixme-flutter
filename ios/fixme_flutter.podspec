#
# The native half of the FIXME Flutter helper (iOS): a small plugin that lets Dart talk to PointerKit, the same native
# overlay, Mac link, pairing, tickets and clips that FIXME gives a Swift app, and PointerKit itself (a static, Debug-only
# binary, ios/PointerKit.xcframework; tool/vendor_pointerkit.sh puts it there).
#
# Debug only. Flutter's iOS tooling does not yet leave a dev_dependency plugin out of release builds
# (flutter/flutter#163874), so this pod is installed for every configuration and the link is what is conditional:
#   - PointerKit is linked into the app (-ObjC -framework PointerKit) in configurations named Debug* only, and the
#     slice is picked by SDK. Profile and Release get neither flag, so no PointerKit code reaches them.
#   - The plugin class below compiles to an empty shell without DEBUG (CocoaPods defines DEBUG=1 in Debug only).
#   - On the app side, FixmeFlutter.wrap returns the app untouched when kDebugMode is false.
#
# PointerKit starts itself (+[PKBoot load], before main) and refuses a build that is not debuggable. The plugin finds it
# by name at run time (NSClassFromString), so the pod has no link-time dependency on it.
#
Pod::Spec.new do |s|
  s.name             = 'fixme_flutter'
  s.version          = '0.1.5'
  s.summary          = 'FIXME for Flutter: circle a bug on your iPhone, your AI agent gets the file and line.'
  s.description      = <<-DESC
Debug-only helper for Flutter apps. On iOS it embeds FIXME's native overlay (PointerKit) and answers the one thing only
Dart knows: which widget is under each circle, with its source file and line, and what the app printed.
                       DESC
  s.homepage         = 'https://getfixme.dev'
  s.license          = { :type => 'Proprietary', :text => 'Copyright FIXME. Debug builds only.' }
  s.author           = { 'FIXME' => 'general@getfixme.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.preserve_paths   = 'PointerKit.xcframework/**/*'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  # The app target links PointerKit, Debug configurations only (the pod itself, a framework or a library, never does,
  # so the classes exist once, in the app). Flutter links every plugin pod through .symlinks/plugins/<name>.
  pointer_kit = '$(PODS_ROOT)/../.symlinks/plugins/fixme_flutter/ios/PointerKit.xcframework'
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS[config=Debug*]' => '$(inherited) -ObjC -framework PointerKit',
    'FRAMEWORK_SEARCH_PATHS[config=Debug*][sdk=iphoneos*]' => "$(inherited) \"#{pointer_kit}/ios-arm64\"",
    'FRAMEWORK_SEARCH_PATHS[config=Debug*][sdk=iphonesimulator*]' => "$(inherited) \"#{pointer_kit}/ios-arm64_x86_64-simulator\"",
  }
end
