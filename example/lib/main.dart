import 'package:flutter/material.dart';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter/services.dart';
//import 'package:video_player/video_player.dart';
import 'package:ya_video_player/ya_video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _platformVersion = 'Unknown';

   List<YaVideoPlayerController> _controllers = [];
  List<Future<void>?> _initializeVideoPlayerFuture = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
//    <!--var flvUrl = "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8";-->
//    <!--var urlType = 'application/x-mpegURL';-->
    _controllers.add(YaVideoPlayerController.network(
//      'http://r.ossrs.net/live/livestream.flv'
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
//      'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
//      closedCaptionFile: _loadCaptions(),
//      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    ));

    int i = 0;
    _controllers.forEach((c) {
      init(i++, c);
    });
  }

  init(index, _controller) {
    _controller.addListener(() {
      setState(() {});
    });
    _controller.setLooping(true);
    _initializeVideoPlayerFuture.add( _controller.initialize());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String? platformVersion;
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
             ..._controllers.map((e) => FutureBuilder(
               future: _initializeVideoPlayerFuture[
                 _controllers.indexOf(e)
               ],
               builder: (context, snapshot){
                 if(snapshot.connectionState != ConnectionState.done) {
                   return Center(child: Text(snapshot.connectionState.toString()));
                 }
//                 print('>>>>>>>>>>>>>>>>>.' + e.value.size!.width.toString());
                 return
                   FittedBox(
                       fit: BoxFit.scaleDown,
                       child:
                   SizedBox(
                   width: e.value.size?.width ?? 500 ,
                   height: e.value.size?.height ?? 400,
                   child:  YaVideoPlayer(e),
                   ));
               },
             ),),
            ],
          ),
//          child: YaVideoPlayer(_controller),
        ),
      ),
    );
  }

}

class View extends StatefulWidget{
  final Widget? p;

  const View({Key? key, this.p}) : super(key: key);


  @override
  State<StatefulWidget> createState()=> _ViewState();
}

class _ViewState extends State<View>{

  @override
  Widget build(BuildContext context) {
    return widget.p!;
  }
}

