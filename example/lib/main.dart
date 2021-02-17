import 'package:flutter/material.dart';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:ya_video_player/ya_video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

   YaVideoPlayerController _controller;
  Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    initPlatformState();
//    <!--var flvUrl = "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8";-->
//    <!--var urlType = 'application/x-mpegURL';-->
    _controller = YaVideoPlayerController.network(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
//      'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
//      closedCaptionFile: _loadCaptions(),
//      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    _controller.addListener(() {
      setState(() {});
    });
    _controller.setLooping(true);
    _initializeVideoPlayerFuture = _controller.initialize();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await YaVideoPlayer.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Row(
            children: [
//              Text('Running on: $_platformVersion\n'),
              FutureBuilder(
                future: _initializeVideoPlayerFuture,
                builder: (context, snapshot){
                  if(snapshot.connectionState != ConnectionState.done) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return YaVideoPlayer(_controller);
                },
              ),
            ],
          ),
//          child: YaVideoPlayer(_controller),
        ),
      ),
    );
  }
}
