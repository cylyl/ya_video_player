# ya_video_player

A YET ANOTHER Video player Flutter plugin for iOS, Android and Web (FLV) for playing back video on a Widget surface.

Note: This plugin is still under development, and some APIs might not be available yet. Feedback welcome and Pull Requests are most welcome!

## Installation First, add video_player as a dependency in your pubspec.yaml file.

## iOS Warning: The video player is not functional on iOS simulators. An iOS device must be used during development/testing.

Add the following entry to your Info.plist file, located in <project root>/ios/Runner/Info.plist:

<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
This entry allows your app to access video files by URL.

## Android Ensure the following permission is present in your Android Manifest file, located in <project root>/android/app/src/main/AndroidManifest.xml:

<uses-permission android:name="android.permission.INTERNET"/>
The Flutter project template adds it, so it may already be there.

## Web This plugin compiles for the web platform since version 0.10.5, in recent enough versions of Flutter (>=1.12.13+hotfix.4).

* The Web platform does not suppport dart:io, so avoid using the VideoPlayerController.file constructor for the plugin. Using the constructor attempts to create a VideoPlayerController.file that will throw an UnimplementedError.

* Different web browsers may have different video-playback capabilities (supported formats, autoplay...). Check package:video_player_web for more web-specific information.

## Supported Formats On iOS, the backing player is AVPlayer. The supported formats vary depending on the version of iOS, AVURLAsset class has audiovisualTypes that you can query for supported av formats.
* On Android, the backing player is ExoPlayer, please refer here for list of supported formats.
* On Web, available formats depend on your users' browsers (vendor and version). Check package:video_player_web for more specific information.
