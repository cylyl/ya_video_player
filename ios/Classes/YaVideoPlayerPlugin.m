#import "YaVideoPlayerPlugin.h"
#if __has_include(<ya_video_player/ya_video_player-Swift.h>)
#import <ya_video_player/ya_video_player-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "ya_video_player-Swift.h"
#endif

@implementation YaVideoPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftYaVideoPlayerPlugin registerWithRegistrar:registrar];
}
@end
