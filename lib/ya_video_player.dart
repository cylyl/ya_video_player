import 'dart:async';
import 'dart:io';

import 'package:ext_video_player/ext_video_player.dart';
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
  VideoPlayer _extPlayer;

  _VideoPlayerState() {}

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        width: 800,
        child: widget?.controller.getView(),
      );
    } else {
      _extPlayer = VideoPlayer(widget?.controller);
      return _extPlayer;
    }
  }
}

class YaVideoPlayerController extends VideoPlayerController {
  YaVideoPlayerInterface _interface = YaVideoPlayerInterface.instance;

  Future<void> _initializeVideoPlayerFuture;
  Completer<void> _creatingCompleter;
  StreamSubscription<dynamic> _eventSubscription;

  int _textureId;
  Timer _timer;
  bool _isDisposed = false;
  bool _isFlv = false;

  YaVideoPlayerController.asset(String dataSource) :
        _isFlv = kIsWeb && dataSource.endsWith("flv"),
        super.asset(dataSource);

  YaVideoPlayerController.network(String dataSource)
      :
        _isFlv = kIsWeb && dataSource.endsWith("flv"),
        super.network(dataSource);

  YaVideoPlayerController.file(File file) :
        _isFlv = kIsWeb && file.toString().endsWith("flv"),
        super.file(file);

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    if (_isFlv) {
      return await YaVideoPlayer._channel
          .invokeMapMethod('setPlaybackSpeed', [_textureId, speed]);
    } else {
      return await super.setPlaybackSpeed(speed);
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_isFlv) {
      return await YaVideoPlayer._channel
          .invokeMapMethod('setVolume', [_textureId, volume]);
    } else {
      return await super.setVolume(volume);
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (_isFlv) {
      return await YaVideoPlayer._channel
          .invokeMapMethod('seekTo', [_textureId, position]);
    } else {
      return await super.seekTo(position);
    }
  }

  @override
  Future<Duration> get position async {
    if (_isFlv) {
      return await YaVideoPlayer._channel
          .invokeMethod('getPosition', _textureId);
    } else {
      return await super.position;
    }
  }

  @override
  Future<void> pause() async {
    if (_isFlv) {
      return await YaVideoPlayer._channel.invokeMethod('pause', _textureId);
    } else {
      return await super.pause();
    }
  }

  @override
  Future<void> setLooping(bool looping) async {
    if (_isFlv) {
      return await YaVideoPlayer._channel
          .invokeMapMethod('setLooping', [_textureId, looping]);
    } else {
      return await super.setLooping(looping);
    }
  }

  @override
  Future<void> play() async {
    if (_isFlv) {
      return await YaVideoPlayer._channel.invokeMethod('play', _textureId);
    } else {
      return await super.play();
    }
  }

  @override
  Future<void> dispose() async {
    if (_isFlv) {
      return await YaVideoPlayer._channel.invokeMethod('dispose', _textureId);
    } else {
      return await super.dispose();
    }
  }

  @override
  Future<void> initialize() async {
    if (_isFlv) {
      _creatingCompleter = Completer<void>();

      DataSource dataSourceDescription;
      switch (dataSourceType) {
        case DataSourceType.asset:
          dataSourceDescription = DataSource(
            sourceType: DataSourceType.asset,
            asset: dataSource,
            package: package,
          );
          break;
        case DataSourceType.network:
          dataSourceDescription = DataSource(
            sourceType: DataSourceType.network,
            uri: dataSource,
            formatHint: formatHint,
          );
          break;
        case DataSourceType.file:
          dataSourceDescription = DataSource(
            sourceType: DataSourceType.file,
            uri: dataSource,
          );
          break;
      }

      if (videoPlayerOptions?.mixWithOthers != null) {
        await YaVideoPlayer._channel
            .invokeMethod('setMixWithOthers', videoPlayerOptions.mixWithOthers);
      }

      _interface
          ?.create(dataSourceDescription, _creatingCompleter)
          .asStream()
          .listen((event) {
        _textureId = event;
      });
      return _creatingCompleter.future;
    } else {
      return await super.initialize();
    }
  }

  @override
  int get textureId {
    if (_isFlv) {
      return _textureId;
    } else {
      return super.textureId;
    }
  }

  Widget getView() {
    return _interface?.getView(_textureId);
  }
}
