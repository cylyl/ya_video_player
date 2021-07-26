import 'dart:async';
import 'dart:io';

import 'package:ext_video_player/ext_video_player.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    show DataSource, VideoEvent, VideoEventType;
import 'package:ya_video_player/ya_video_player_interface.dart';
import 'package:yoyo_player/yoyo_player.dart';

class YaVideoPlayer extends StatefulWidget {
  static const MethodChannel _channel = const MethodChannel('ya_video_player');

  final YaVideoPlayerController controller;

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  YaVideoPlayer(this.controller);

  @override
  State<StatefulWidget> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<YaVideoPlayer> {
  _VideoPlayerState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.controller.getView();
  }
}

enum Player {
  flv,
  ext,
  ijk,
  yoyo,
}

/// The duration, current position, buffering state, error state and settings
/// of a [YaVideoPlayerController].
class YaVideoPlayerValue {
  /// Constructs a video with the given values. Only [duration] is required. The
  /// rest will initialize with default values when unset.
  YaVideoPlayerValue({
    required this.duration,
    this.size = Size.zero,
    this.position = Duration.zero,
    this.caption,
    this.buffered = const <DurationRange>[],
    this.isInitialized = false,
    this.isPlaying = false,
    this.isLooping = false,
    this.isBuffering = false,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.errorDescription,
  });

  /// Returns an instance for a video that hasn't been loaded.
  YaVideoPlayerValue.uninitialized()
      : this(duration: Duration.zero, isInitialized: false);

  /// Returns an instance with the given [errorDescription].
  YaVideoPlayerValue.erroneous(String errorDescription)
      : this(
            duration: Duration.zero,
            isInitialized: false,
            errorDescription: errorDescription);

  /// The total duration of the video.
  ///
  /// The duration is [Duration.zero] if the video hasn't been initialized.
  final Duration duration;

  /// The current playback position.
  final Duration position;

  /// The [Caption] that should be displayed based on the current [position].
  ///
  /// This field will never be null. If there is no caption for the current
  /// [position], this will be a [Caption.none] object.
  final Caption? caption;

  /// The currently buffered ranges.
  final List<DurationRange> buffered;

  /// True if the video is playing. False if it's paused.
  final bool isPlaying;

  /// True if the video is looping.
  final bool isLooping;

  /// True if the video is currently buffering.
  final bool isBuffering;

  /// The current volume of the playback.
  final double volume;

  /// The current speed of the playback.
  final double playbackSpeed;

  /// A description of the error if present.
  ///
  /// If [hasError] is false this is `null`.
  final String? errorDescription;

  /// The [size] of the currently loaded video.
  final Size size;

  /// Indicates whether or not the video has been loaded and is ready to play.
  final bool isInitialized;

  /// Indicates whether or not the video is in an error state. If this is true
  /// [errorDescription] should have information about the problem.
  bool get hasError => errorDescription != null;

  /// Returns [size.width] / [size.height].
  ///
  /// Will return `1.0` if:
  /// * [isInitialized] is `false`
  /// * [size.width], or [size.height] is equal to `0.0`
  /// * aspect ratio would be less than or equal to `0.0`
  double get aspectRatio {
    if (!isInitialized || size.width == 0 || size.height == 0) {
      return 1.0;
    }
    final double aspectRatio = size.width / size.height;
    if (aspectRatio <= 0) {
      return 1.0;
    }
    return aspectRatio;
  }

  /// Returns a new instance that has the same values as this current instance,
  /// except for any overrides passed in as arguments to [copyWidth].
  YaVideoPlayerValue copyWith({
    Duration? duration,
    Size? size,
    Duration? position,
    Caption? caption,
    List<DurationRange>? buffered,
    bool? isInitialized,
    bool? isPlaying,
    bool? isLooping,
    bool? isBuffering,
    double? volume,
    double? playbackSpeed,
    String? errorDescription,
  }) {
    return YaVideoPlayerValue(
      duration: duration ?? this.duration,
      size: size ?? this.size,
      position: position ?? this.position,
      caption: caption ?? this.caption,
      buffered: buffered ?? this.buffered,
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isBuffering: isBuffering ?? this.isBuffering,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorDescription: errorDescription ?? this.errorDescription,
    );
  }

  @override
  String toString() {
    return '$runtimeType('
        'duration: $duration, '
        'size: $size, '
        'position: $position, '
        'caption: $caption, '
        'buffered: [${buffered.join(', ')}], '
        'isInitialized: $isInitialized, '
        'isPlaying: $isPlaying, '
        'isLooping: $isLooping, '
        'isBuffering: $isBuffering, '
        'volume: $volume, '
        'playbackSpeed: $playbackSpeed, '
        'errorDescription: $errorDescription)';
  }
}

class YaVideoPlayerController {
  YaVideoPlayerInterface? _interface = YaVideoPlayerInterface.instance;
  VideoPlayerController? _extPlayer;
  VideoPlayerController? _flvPlayer;
  FijkPlayer? _fijkPlayer;
  YoYoPlayer? _yoYoPlayer;

  late Future<void> _initializeVideoPlayerFuture;
  late Completer<void> _creatingCompleter;
  late StreamSubscription<dynamic> _eventSubscription;

  @visibleForTesting
  int _textureId = -1;
  Timer? _timer;
  bool _isDisposed = false;
  Player? player;

  YaVideoPlayerController.asset(String dataSource, {Player? player}) {
    this.player = player;
    bool isFlv = (kIsWeb || dataSource.contains(".flv"));
    bool isHls = (dataSource.contains(".m3u8"));

    if (isFlv) {
      this.player = Player.ijk;
    } else if (isHls) {
      this.player = Player.yoyo;
    }
    switch (this.player) {
      case Player.ijk:
        {
          _fijkPlayer = FijkPlayer();
          _fijkPlayer!.setDataSource(dataSource, autoPlay: true);
          break;
        }
      case Player.ext:
      case Player.flv:
      default:
        {
          _flvPlayer = VideoPlayerController.asset(dataSource);
        }
    }
  }

  YaVideoPlayerController.network(String dataSource, {Player? player}) {
    bool isFlv = (dataSource.contains(".flv"));
    bool isHls = (dataSource.contains(".m3u8"));

    if (isFlv) {
      this.player = kIsWeb ? Player.flv : Player.ijk;
    } else if (isHls) {
      this.player = Player.yoyo;
    }
    this.player = player;
    switch (this.player) {
      case Player.ijk:
        {
          _fijkPlayer = FijkPlayer();
          _fijkPlayer!.setDataSource(dataSource, autoPlay: true);
          break;
        }
      case Player.yoyo:
        {
          _yoYoPlayer = YoYoPlayer(
            aspectRatio: 1,
            url: dataSource,
            videoStyle: VideoStyle(),
            videoLoadingStyle: VideoLoadingStyle(
              loading: Center(
                child: Text("LOADING..."),
              ),
            ),
          );
          break;
        }
      case Player.ext:
        {
          _extPlayer = VideoPlayerController.network(dataSource);
          break;
        }
      case Player.flv:
      default:
        {
          _flvPlayer = VideoPlayerController.network(dataSource);
        }
    }
  }

  YaVideoPlayerController.file(File file, {Player? player}) {
    this.player = player;
    switch (this.player) {
      case Player.ijk:
        {
          _fijkPlayer = FijkPlayer();
          _fijkPlayer!.setDataSource(file.path, autoPlay: true);
          break;
        }
      case Player.ext:
      case Player.flv:
      default:
        {
          _flvPlayer = VideoPlayerController.file(file);
        }
    }
  }

  YaVideoPlayerValue value({Size defaultSize = const Size.square(450)}) {
    switch (this.player) {
      case Player.ijk:
        {
          return copyVideoPlayerValue(_fijkPlayer!.value,
              defaultSize: defaultSize);
        }
      case Player.ext:
        {
          return copyVideoPlayerValue(_extPlayer!.value,
              defaultSize: defaultSize);
        }
      case Player.flv:
      default:
        {
          return copyVideoPlayerValue(_flvPlayer!.value,
              defaultSize: defaultSize);
        }
    }
  }

  YaVideoPlayerValue copyVideoPlayerValue(value,
      {Size defaultSize = const Size.square(450)}) {
    if (value is VideoPlayerValue) {
      return YaVideoPlayerValue(
          duration: value.duration ?? Duration(),
          size: value.size ?? defaultSize,
          errorDescription: value.errorDescription);
    } else if (value is FijkValue) {
      return YaVideoPlayerValue(
        duration: value.duration,
        size: value.size ?? defaultSize,
        errorDescription: value.exception.message,
      );
    } else {
      return YaVideoPlayerValue.uninitialized();
    }
  }

  void addListener(listener) {
    switch (player) {
      case Player.flv:
        {
          _flvPlayer!.addListener(listener);
          break;
        }
      case Player.ext:
        {
          _extPlayer!.addListener(listener);
          break;
        }
      case Player.ijk:
        {
          _fijkPlayer!.addListener(listener);
          break;
        }
    }
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    switch (player) {
      case Player.flv:
        {
          await YaVideoPlayer._channel
              .invokeMapMethod('setPlaybackSpeed', [_textureId, speed]);
          break;
        }
      case Player.ext:
        {
          return await _extPlayer!.setPlaybackSpeed(speed);
        }
      case Player.ijk:
        {
          return await _fijkPlayer!.setSpeed(speed);
        }
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    switch (player) {
      case Player.flv:
        {
          await YaVideoPlayer._channel
              .invokeMapMethod('setVolume', [_textureId, volume]);
          break;
        }
      case Player.ext:
        {
          return await _extPlayer!.setVolume(volume);
        }
      case Player.ijk:
        {
          return await _fijkPlayer!.setVolume(volume);
        }
    }
  }

  @override
  Future<void> seekTo(Duration? position) async {
    switch (player) {
      case Player.flv:
        {
          await YaVideoPlayer._channel
              .invokeMapMethod('seekTo', [_textureId, position]);
          break;
        }
      case Player.ext:
        {
          return await _extPlayer!.seekTo(position);
        }
      case Player.ijk:
        {
          return await _fijkPlayer!.seekTo(position?.inMicroseconds ?? 0);
        }
    }
  }

  @override
  Future<Duration?> get position async {
    switch (player) {
      case Player.flv:
        {
          return await YaVideoPlayer._channel
              .invokeMethod('getPosition', _textureId);
        }
      case Player.ext:
        {
          return await _extPlayer!.position;
        }
      case Player.ijk:
        {
          return await _fijkPlayer!.currentPos;
        }
    }
  }

  @override
  Future<void> pause() async {
    switch (player) {
      case Player.flv:
        {
          return await YaVideoPlayer._channel.invokeMethod('pause', _textureId);
        }
      case Player.ext:
        {
          return await _extPlayer!.pause();
        }
      case Player.ijk:
        {
          return await _fijkPlayer!.pause();
        }
    }
  }

  @override
  Future<void> setLooping(bool looping) async {
    switch (player) {
      case Player.flv:
        {
          await YaVideoPlayer._channel
              .invokeMapMethod('setLooping', [_textureId, looping]);
          break;
        }
      case Player.ext:
        {
          return await _extPlayer!.setLooping(looping);
        }
      case Player.ijk:
        {
          return await _fijkPlayer!.setLoop(100);
        }
    }
  }

  @override
  Future<void> play() async {
    switch (player) {
      case Player.flv:
        {
          return await YaVideoPlayer._channel.invokeMethod('play', _textureId);
        }
      case Player.ext:
        {
          return await _extPlayer!.play();
        }
      case Player.ijk:
        {
          return await _fijkPlayer!.start();
        }
    }
  }

  @override
  Future<void> dispose() async {
    switch (player) {
      case Player.flv:
        {
          return await YaVideoPlayer._channel
              .invokeMethod('dispose', _textureId);
          break;
        }
      case Player.ext:
        {
          return await _extPlayer!.dispose();
        }
      case Player.ijk:
        {
          return _fijkPlayer!.dispose();
        }
    }
  }

  @override
  Future<void> initialize({Size? size}) async {
    if (size == null) {
      size = Size.square(480.0);
      print("Default size " + size.width.toString());
    }
    if (_flvPlayer != null) {
      _creatingCompleter = Completer<void>();

      late DataSource dataSourceDescription;
      switch (_flvPlayer?.dataSourceType) {
        case DataSourceType.asset:
          dataSourceDescription = DataSource(
            sourceType: DataSourceType.asset,
            asset: _flvPlayer?.dataSource,
            package: _flvPlayer?.package,
          );
          break;
        case DataSourceType.network:
          dataSourceDescription = DataSource(
            sourceType: DataSourceType.network,
            uri: _flvPlayer?.dataSource,
            formatHint: _flvPlayer?.formatHint,
          );
          break;
        case DataSourceType.file:
          dataSourceDescription = DataSource(
            sourceType: DataSourceType.file,
            uri: _flvPlayer?.dataSource,
          );
          break;
      }

      if (_flvPlayer?.videoPlayerOptions?.mixWithOthers != null) {
        await YaVideoPlayer._channel.invokeMethod(
            'setMixWithOthers', _flvPlayer?.videoPlayerOptions?.mixWithOthers);
      }

      _textureId = (await _interface!
              .create(dataSourceDescription, _creatingCompleter, size: size)) ??
          -1;
      _creatingCompleter.complete(null);

      final Completer<void> initializingCompleter = Completer<void>();

      void eventListener(VideoEvent event) {
        if (_isDisposed) {
          return;
        }
        if (_flvPlayer != null) {
          switch (event.eventType) {
            case VideoEventType.initialized:
              _flvPlayer!.value = _flvPlayer!.value.copyWith(
                duration: event.duration,
                size: event.size,
//              isInitialized: event.duration != null,
              );

              initializingCompleter.complete(null);
//            _applyLooping();
//            _applyVolume();
//            _applyPlayPause();
              break;
            case VideoEventType.completed:
              _flvPlayer!.value = _flvPlayer!.value.copyWith(
                  isPlaying: false, position: _flvPlayer!.value.duration);
              _timer?.cancel();
              break;
            case VideoEventType.bufferingUpdate:
              _flvPlayer!.value =
                  _flvPlayer!.value.copyWith(buffered: event.buffered);
              break;
            case VideoEventType.bufferingStart:
              _flvPlayer!.value = _flvPlayer!.value.copyWith(isBuffering: true);
              break;
            case VideoEventType.bufferingEnd:
              _flvPlayer!.value =
                  _flvPlayer!.value.copyWith(isBuffering: false);
              break;
            case VideoEventType.unknown:
              break;
          }
        }
      }

//      if (closedCaptionFile != null) {
//        if (_closedCaptionFile == null) {
//          _closedCaptionFile = await closedCaptionFile;
//        }
//        value = value.copyWith(caption: _getCaptionAt(value.position));
//      }

      void errorListener(Object obj) {
        final PlatformException e = obj as PlatformException;
//        value = VideoPlayerValue.erroneous(e.message!);
        _timer?.cancel();
        if (!initializingCompleter.isCompleted) {
          initializingCompleter.completeError(obj);
        }
      }

      _eventSubscription = _interface!
          .videoEventsFor(_textureId)
          .listen(eventListener, onError: errorListener);
      return initializingCompleter.future;
    } else {
      return await _flvPlayer?.initialize();
    }
  }

  @override
  int get textureId {
    if (_flvPlayer != null) {
      return _textureId;
    } else {
      return _flvPlayer?.textureId ?? 0;
    }
  }

  Widget getView() {
    if (kIsWeb) {
      return _interface!.getView(_textureId);
    }
    switch (player) {
      case Player.yoyo:
        {
          return _yoYoPlayer!;
        }
      case Player.ijk:
        {
          return FijkView(
            player: _fijkPlayer!,
          );
        }

      case Player.ext:
        {
          return VideoPlayer(_extPlayer!);
        }
      case Player.flv:
      default:
        {
          return VideoPlayer(_flvPlayer!);
        }
    }
  }
}
