@JS()
library ya_video_player.js;

import 'dart:async';
// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:ya_video_player/ya_video_player_interface.dart';
import 'shims/dart_ui.dart' as ui; // Conditionally imports dart:ui in web
import 'package:flutter/material.dart';
import 'package:js/js.dart';
import 'package:import_js_library/import_js_library.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    show DataSource, VideoEvent, VideoEventType, DurationRange, DataSourceType;

@JS('alert')
external String alert(Object obj);
@JS('init')
external void jInit();
@JS('destroy')
external void jDestroy(int id);
@JS('load')
external void jLoad(int id);
@JS('unload')
external void jUnload(int id);
@JS('play')
external void jPlay(int id);
@JS('pause')
external void jPause(int id);

@JS('videojs')
external void videojs(String id);

// An error code value to error name Map.
// See: https://developer.mozilla.org/en-US/docs/Web/API/MediaError/code
const Map<int, String> _kErrorValueToErrorName = {
  1: 'MEDIA_ERR_ABORTED',
  2: 'MEDIA_ERR_NETWORK',
  3: 'MEDIA_ERR_DECODE',
  4: 'MEDIA_ERR_SRC_NOT_SUPPORTED',
};

// An error code value to description Map.
// See: https://developer.mozilla.org/en-US/docs/Web/API/MediaError/code
const Map<int, String> _kErrorValueToErrorDescription = {
  1: 'The user canceled the fetching of the video.',
  2: 'A network error occurred while fetching the video, despite having previously been available.',
  3: 'An error occurred while trying to decode the video, despite having previously been determined to be usable.',
  4: 'The video has been found to be unsuitable (missing or in a format not supported by your browser).',
};

// The default error message, when the error is an empty string
// See: https://developer.mozilla.org/en-US/docs/Web/API/MediaError/message
const String _kDefaultErrorMessage =
    'No further diagnostic information can be determined or provided.';

/// A web implementation of the YaVideoPlayer plugin.
class YaVideoPlayerWeb extends YaVideoPlayerInterface {
  int _textureCounter = 1;
  Map<int, _VideoPlayer> _videoPlayers = <int, _VideoPlayer>{};

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'ya_video_player',
      const StandardMethodCodec(),
      registrar.messenger,
    );

//    _importCSS(["./assets/packages/ya_video_player/assets/video-js.css"]);
//    importJsLibrary(url: "./assets/video.min.js",
//        flutterPluginName: "ya_video_player");
//    importJsLibrary(url: "./assets/flv.min.js",
//        flutterPluginName: "ya_video_player");
//    importJsLibrary(url: "./assets/videojs-flvjs.js",
//        flutterPluginName: "ya_video_player");
    importJsLibrary(
        url: "./assets/ya-video-player.js",
        flutterPluginName: "ya_video_player");

    final pluginInstance = YaVideoPlayerWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
    YaVideoPlayerInterface.setInstance(pluginInstance);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    print('handleMethodCall  > ' + call.method);
    switch (call.method) {
      case 'init':
        return init();
        break;
      case 'dispose':
        return dispose(call.arguments);
        break;
      case 'create':
      case 'setLooping':
        return setLooping(call.arguments);
        break;
      case 'play':
        return play(call.arguments);
        break;
      case 'pause':
        return pause(call.arguments);
        break;
      case 'setVolume':
        return setVolume(call.arguments);
        break;
      case 'seekTo':
        return seekTo(call.arguments);
        break;
      case 'setPlaybackSpeed':
        return setPlaybackSpeed(call.arguments);
        break;
      case 'getPosition':
        return getPosition(call.arguments);
        break;
      case 'setMixWithOthers':
        return setMixWithOthers(call.arguments);
        break;
      case 'videoEventsFor':
        return videoEventsFor(call.arguments);
        break;
      case 'getPlatformVersion':
        return getPlatformVersion();
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'ya_video_player for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  static Future<void> _importCSS(List<String> styles) {
    final List<Future<void>> loading = <Future<void>>[];
    final head = html.querySelector('head');

    styles.forEach((String css) {
      if (!isImported(css)) {
        final scriptTag = html.LinkElement()
          ..href = css
          ..rel = "stylesheet";
        head.children.add(scriptTag);
        loading.add(scriptTag.onLoad.first);
      }
    });
    return Future.wait(loading);
  }

  static bool _isLoaded(html.Element head, String url) {
    if (url.startsWith("./")) {
      url = url.replaceFirst("./", "");
    }
    for (var element in head.children) {
      if (element is html.LinkElement) {
        if (element.href.endsWith(url)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool isImported(String url) {
    final head = html.querySelector('head');
    return _isLoaded(head, url);
  }

  /// Returns a [String] containing the version of the platform.
  Future<String> getPlatformVersion() {
    final version = html.window.navigator.userAgent;
    return Future.value(version);
  }

  Future<void> init() {}

  Future<void> dispose(int textureId) {
    _videoPlayers[textureId]?.dispose();
  }

  Future<int> create(
      DataSource dataSource, Completer<void> creatingCompleter) async {
    final int textureId = _textureCounter;
    _textureCounter++;

    String uri;
    switch (dataSource.sourceType) {
      case DataSourceType.network:
        // Do NOT modify the incoming uri, it can be a Blob, and Safari doesn't
        // like blobs that have changed.
        uri = dataSource.uri;
        break;
      case DataSourceType.asset:
        String assetUrl = dataSource.asset;
        if (dataSource.package != null && dataSource.package.isNotEmpty) {
          assetUrl = 'packages/${dataSource.package}/$assetUrl';
        }
        assetUrl = ui.webOnlyAssetManager.getAssetUrl(assetUrl);
        uri = assetUrl;
        break;
      case DataSourceType.file:
        return Future.error(UnimplementedError(
            'web implementation of video_player cannot play local files'));
    }

    final _VideoPlayer player = _VideoPlayer(
      uri: uri,
      textureId: textureId,
    );

    _videoPlayers[textureId] = player;
    creatingCompleter.complete(null);

    player.initialize();
    return textureId;
  }

  Future<void> setLooping(List<dynamic> args) {
    int textureId = args[0];
    bool looping = args[1];
    _videoPlayers[textureId]?.setLooping(looping);
  }

  Future<void> play(int textureId) {
    _videoPlayers[textureId]?.play();
  }

  Future<void> pause(int textureId) {
    _videoPlayers[textureId]?.pause();
  }

  Future<void> setVolume(List<dynamic> args) {
    int textureId = args[0];
    double volume = args[1];

    _videoPlayers[textureId]?.setVolume(volume);
  }

  Future<void> seekTo(List<dynamic> args) {
    int textureId = args[0];
    Duration position = args[1];
    _videoPlayers[textureId]?.seekTo(position);
  }

  Future<void> setPlaybackSpeed(List<dynamic> args) {
    int textureId = args[0];
    double speed = args[1];
    _videoPlayers[textureId]?.setPlaybackSpeed(speed);
  }

  Future<Duration> getPosition(int textureId) {
    return Future.value(_videoPlayers[textureId]?.getPosition());
  }

  Future<void> setMixWithOthers(bool mixWithOthers) {}

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _videoPlayers[textureId]?.eventController.stream;
  }

  static String _getViewType(int textureId) =>
      'plugins.ya_video_player_$textureId';

  getView(int textureId) {
    return _videoPlayers[textureId]?.playerView;
  }
}

class _VideoPlayer {
  _VideoPlayer({this.uri, this.textureId});

  final StreamController<VideoEvent> eventController =
      StreamController<VideoEvent>();

  final String uri;
  final int textureId;
  HtmlElementView playerView;
  html.VideoElement videoElement;
  html.DivElement divElement;
  bool isInitialized = false;

  void buildView() {
    /**
     *
        <div>
        <video id="videojs-flvjs-player" class="video-js vjs-default-skin vjs-big-play-centered"  width="1024" height="768"> </video>
        </div>
     */
//    videoElement = html.VideoElement()
//      ..id = "videojs-flvjs-player"
//      ..classes = "video-js vjs-default-skin vjs-big-play-centered".split(" ")
//      ..width = 1024
//      ..height = 768
//      ..src = uri
////      ..autoplay = false
//      ..controls = true
////      ..style.border = 'none'
//        ;

    /**
     * <video class="video-js"  data-setup='{"controls": true, "autoplay": false, "preload": "auto"}'>
        <source src='https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' type="video/mp4">
        </video>
     */
//    divElement = html.querySelector('div');
//    videoElement = html.querySelector('#ya_player')
    videoElement = html.VideoElement()
      ..attributes = {
        'id': 'ya_player' + textureId.toString(),
        'width': '800',
//      'class' : 'video-js  vjs-default-skin' ,
//      'data-setup' :  '{}',
        'controls': '',
        'autoplay': '',
//      'preload' : 'auto',
//      'liveui' : 'true',
        'playsinline': 'true'
      };
//    videoElement.children = [html.SourceElement()
//    ..src = uri
//    ..type = "video/" + _getType(uri)
//    ]
//    ;

    // Allows Safari iOS to play the video inline
//    videoElement.setAttribute('playsinline', 'true');

    divElement = html.DivElement();

//    html.ButtonElement playBtn = html.ButtonElement()
//      ..text = "Play";
//    playBtn.onClick.listen((event) {
//      jPlay(textureId);
//    });
//    html.ButtonElement pauseBtn = html.ButtonElement()
//      ..text = "Pause";
//    pauseBtn.onClick.listen((event) {
//      jPause(textureId);
//    });

    divElement.children = [
      html.DivElement()
        ..children = [
          videoElement,
//          playBtn,
//          pauseBtn ,
          html.ScriptElement()
            ///https://github.com/flutter/flutter/issues/40080
            ..text = "init($textureId, '$uri');"
        ]
    ];

    // TODO(hterkelsen): Use initialization parameters once they are available
    ui.platformViewRegistry.registerViewFactory(
        YaVideoPlayerWeb._getViewType(textureId), (int viewId) => divElement);

    playerView = HtmlElementView(
      viewType: YaVideoPlayerWeb._getViewType(textureId),
    );
  }

  void initialize() {
    buildView();

    videoElement.onCanPlay.listen((dynamic _) {
      if (!isInitialized) {
        isInitialized = true;
        sendInitialized();
      }
    });

    // The error event fires when some form of error occurs while attempting to load or perform the media.
    videoElement.onError.listen((html.Event _) {
      // The Event itself (_) doesn't contain info about the actual error.
      // We need to look at the HTMLMediaElement.error.
      // See: https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/error
      html.MediaError error = videoElement.error;
      eventController.addError(PlatformException(
        code: _kErrorValueToErrorName[error.code],
        message: error.message != '' ? error.message : _kDefaultErrorMessage,
        details: _kErrorValueToErrorDescription[error.code],
      ));
    });

    videoElement.onEnded.listen((dynamic _) {
      eventController.add(VideoEvent(eventType: VideoEventType.completed));
    });
  }

  void sendBufferingUpdate() {
    eventController.add(VideoEvent(
      buffered: _toDurationRange(videoElement.buffered),
      eventType: VideoEventType.bufferingUpdate,
    ));
  }

  Future<void> play() {
    jPlay(textureId);
  }

  void pause() {
    jPause(textureId);
  }

  void setLooping(bool value) {
    print('un-support setLooping');
  }

  void setVolume(double value) {
    print('un-support setVolume');
  }

  void setPlaybackSpeed(double speed) {
    print('un-support setPlaybackSpeed');
  }

  void seekTo(Duration position) {
    videoElement.currentTime = position.inMilliseconds.toDouble() / 1000;
  }

  Duration getPosition() {
    return Duration(milliseconds: (videoElement.currentTime * 1000).round());
  }

  void sendInitialized() {
    eventController.add(
      VideoEvent(
        eventType: VideoEventType.initialized,

        ///TODO
//        duration: Duration(
//          milliseconds: (videoElement.duration * 1000).round(),
//        ),
//        size: Size(
//          videoElement.videoWidth.toDouble() ?? 0.0,
//          videoElement.videoHeight.toDouble() ?? 0.0,
//        ),
      ),
    );
  }

  void dispose() {
    jUnload(textureId);
    jDestroy(textureId);
  }

  List<DurationRange> _toDurationRange(html.TimeRanges buffered) {
    final List<DurationRange> durationRange = <DurationRange>[];
    for (int i = 0; i < buffered.length; i++) {
      durationRange.add(DurationRange(
        Duration(milliseconds: (buffered.start(i) * 1000).round()),
        Duration(milliseconds: (buffered.end(i) * 1000).round()),
      ));
    }
    return durationRange;
  }

  String _getType(String uri) {
    if (uri.endsWith("mp4")) return "mp4";
    if (uri.endsWith("m3u8")) return "x-mpegURL";
    if (uri.endsWith("flv"))
      return "x-flv";
    else
      return "mp4";
  }
}
