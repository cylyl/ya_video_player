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
  // late VideoPlayer _extPlayer;
  late FijkView _extPlayer;

  _VideoPlayerState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return widget.controller.getView();
    } else {
      // _extPlayer = VideoPlayer(widget.controller);
      _extPlayer = FijkView(
        player: widget.controller._fijkPlayer,
      );
      return _extPlayer;
    }
  }
}

class YaVideoPlayerController {
  YaVideoPlayerInterface? _interface = YaVideoPlayerInterface.instance;
  VideoPlayerController? _extPlayer;
  VideoPlayerController? _flvPlayer;
  final FijkPlayer _fijkPlayer = FijkPlayer();

  late Future<void> _initializeVideoPlayerFuture;
  late Completer<void> _creatingCompleter;
  late StreamSubscription<dynamic> _eventSubscription;

  @visibleForTesting
//  static const int kUninitializedTextureId = -1;
//  int _textureId = kUninitializedTextureId;
  int _textureId = -1;
  Timer? _timer;
  bool _isDisposed = false;
  bool isFlv = false;

  YaVideoPlayerController.asset(String dataSource,
      {bool isFlv = false, bool extPlayer = false})
      : isFlv = isFlv || (kIsWeb && dataSource.endsWith("flv")) {
    isFlv
        ? _flvPlayer = VideoPlayerController.asset(dataSource)
        : extPlayer
            ? _extPlayer = VideoPlayerController.asset(dataSource)
            : _fijkPlayer.setDataSource(dataSource, autoPlay: true);
  }

  YaVideoPlayerController.network(String dataSource,
      {bool isFlv = false, bool extPlayer = false})
      : isFlv = isFlv || (kIsWeb && dataSource.endsWith("flv")) {
    isFlv
        ? _flvPlayer = VideoPlayerController.network(dataSource)
        : extPlayer
        ? _extPlayer = VideoPlayerController.network(dataSource)
        : _fijkPlayer.setDataSource(dataSource, autoPlay: true);
  }

  YaVideoPlayerController.file(File file,
      {bool isFlv = false, bool extPlayer = false})
      : isFlv = isFlv || (kIsWeb && file.toString().endsWith("flv")) {
    isFlv
        ? _flvPlayer = VideoPlayerController.file(file)
        : extPlayer
        ? _extPlayer = VideoPlayerController.file(file)
        : _fijkPlayer.setDataSource(file.path, autoPlay: true);
  }

   value () {
    return isFlv
        ? _flvPlayer!.value
        : (_extPlayer != null)
        ? _extPlayer!.value
        : _fijkPlayer.value;
  }

  void addListener(listener) {
    return isFlv
        ? _flvPlayer!.addListener(listener)
        : (_extPlayer != null)
        ? _extPlayer!.addListener(listener)
        : _fijkPlayer.addListener(listener);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    if (isFlv) {
      await YaVideoPlayer._channel
          .invokeMapMethod('setPlaybackSpeed', [_textureId, speed]);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.setPlaybackSpeed(speed);
      } else {
        return await _fijkPlayer.setSpeed(speed);
      }
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (isFlv) {
      await YaVideoPlayer._channel
          .invokeMapMethod('setVolume', [_textureId, volume]);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.setVolume(volume);
      } else {
        return await _fijkPlayer.setVolume(volume);
      }
    }
  }

  @override
  Future<void> seekTo(Duration? position) async {
    if (isFlv) {
      await YaVideoPlayer._channel
          .invokeMapMethod('seekTo', [_textureId, position]);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.seekTo(position);
      } else {
        return await _fijkPlayer.seekTo(position?.inMicroseconds ?? 0);
      }
    }
  }

  @override
  Future<Duration?> get position async {
    if (isFlv) {
      return await YaVideoPlayer._channel
          .invokeMethod('getPosition', _textureId);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.position;
      } else {
        return await _fijkPlayer.currentPos;
      }
    }
  }

  @override
  Future<void> pause() async {
    if (isFlv) {
      return await YaVideoPlayer._channel.invokeMethod('pause', _textureId);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.pause();
      } else {
        return await _fijkPlayer.pause();
      }
    }
  }

  @override
  Future<void> setLooping(bool looping) async {
    if (isFlv) {
      await YaVideoPlayer._channel
          .invokeMapMethod('setLooping', [_textureId, looping]);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.setLooping(looping);
      } else {
        return await _fijkPlayer.setLoop(100);
      }
    }
  }

  @override
  Future<void> play() async {
    if (isFlv) {
      return await YaVideoPlayer._channel.invokeMethod('play', _textureId);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.play();
      } else {
        return await _fijkPlayer.start();
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (isFlv) {
      return await YaVideoPlayer._channel.invokeMethod('dispose', _textureId);
    } else {
      if (_extPlayer != null) {
        return await _extPlayer!.dispose();
      } else {
        return _fijkPlayer.dispose();
      }
    }
  }

  @override
  Future<void> initialize({Size? size}) async {
    if (size == null) {
      size = Size.square(480.0);
      print("Default size " + size.width.toString());
    }
    if (isFlv) {
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
        if(_flvPlayer != null) {
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
              _flvPlayer!.value =
                  _flvPlayer!.value.copyWith(isPlaying: false,
                      position: _flvPlayer!.value.duration);
              _timer?.cancel();
              break;
            case VideoEventType.bufferingUpdate:
              _flvPlayer!.value = _flvPlayer!.value.copyWith(buffered: event.buffered);
              break;
            case VideoEventType.bufferingStart:
              _flvPlayer!.value = _flvPlayer!.value.copyWith(isBuffering: true);
              break;
            case VideoEventType.bufferingEnd:
              _flvPlayer!.value = _flvPlayer!.value.copyWith(isBuffering: false);
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
    if (isFlv) {
      return _textureId;
    } else {
      return _flvPlayer?.textureId ?? 0;
    }
  }

  Widget getView() {
    return _interface!.getView(_textureId);
  }
}
