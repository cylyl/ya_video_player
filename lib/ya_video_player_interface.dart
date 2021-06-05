
import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

abstract class YaVideoPlayerInterface {

  static YaVideoPlayerInterface? _instance;

  static YaVideoPlayerInterface? get instance => _instance;

  bool get isMock => false;

  static setInstance(YaVideoPlayerInterface instance) {
    _instance = instance;
  }

  videoEventsFor(int textureId) {}

  Widget getView(int textureId) { return Container();}

  Future<int?> create(DataSource dataSourceDescription, Completer<void> creatingCompleter, {Size? size}) {
    return Future.value(-1);
  }
}