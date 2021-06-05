//

//var flvUrl = "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8";
//var urlType = 'application/x-mpegURL';
//var player ;

var videoElement
var flvPlayer=[];

function getVidElement(id){
    var vid = window.document.getElementById('ya_player' + id);
    if(vid != null ) return vid;
    var views = window.document.getElementsByTagName('flt-platform-view');
    for (var v of views) {
        vid = v.shadowRoot.getElementById('ya_player' + id);
        if(vid != null ) return vid;
        else alert('vid not found! ');
    }
}

function init(id, url){

    if (flvjs.isSupported()) {
        videoElement = getVidElement(id);
        //window.document.getElementsByTagName('flt-platform-view')[0].shadowRoot.getElementById('ya_player' + id);
        flvPlayer[id] = flvjs.createPlayer({
        type: 'flv',
        isLive: true,
        url: url,
        hasAudio: false,
        });
        flvPlayer[id].attachMediaElement(videoElement);
        flvPlayer[id].load();
        flvPlayer[id].play();
    }

//player = videojs('myplayer', {autoplay: 'any'});
// setTimeout(alert(), 300000);
//const player = videojs('myplayer');
//    player.src({
//      src: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
//      type: 'video/mp4'
//    });
}
//function init(){
//alert('---');
// player = videojs('videojs-flvjs-player', {
//    techOrder: ['html5', 'flvjs'],
//    flvjs: {
//        mediaDataSource: {
//            isLive: false,
//            cors: true,
//            withCredentials: false,
//        },
//    },
//    sources: [{
//        src: flvUrl,
//        type: 'video/mp4'
//    }],
//    controls: true,
//    preload: "none"
//}, function onPlayerReady() {
//    console.log('player ready')
//
//player.load(); player.play();
//
//    player.on('error', (err) => {
//        console.log('first source load fail')
//
//        player.src({
//            src: flvUrl,
//            type: urlType
//        });
//
//        player.ready(function() {
//            console.log('player ready2')
//            player.load();
//            player.play();
//        });
//    })
//});
//}
//
//
//var flvUrl = "http://39.108.64.20:6604/hls/1_60040_0_1.m3u8?JSESSIONID=f800c258-01b2-4062-b2aa-e1f635650d2f";
//var urlType = 'application/x-mpegURL';
//var flvUrl = "https://mister-ben.github.io/videojs-flvjs/bbb.flv";
//var urlType = 'video/x-flv';
//var flvUrl = "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8";
//var urlType = 'application/x-mpegURL';
//var player = videojs('videojs-flvjs-player', {
//    techOrder: ['html5', 'flvjs'],
//    flvjs: {
//        mediaDataSource: {
//            isLive: false,
//            cors: true,
//            withCredentials: false,
//        },
//    },
//    sources: [{
//        src: flvUrl,
//        type: 'video/mp4'
//    }],
//    controls: true,
//    preload: "none"
//}, function onPlayerReady() {
//    console.log('player ready')
//
//    player.on('error', (err) => {
//        console.log('first source load fail')
//
//        player.src({
//            src: flvUrl,
//            type: urlType
//        });
//
//        player.ready(function() {
//            console.log('player ready')
//            player.load();
//            player.play();
//        });
//    })
//});


function loadScript(url, callback)
{
    // Adding the script tag to the head as suggested before
    var head = document.head;
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.src = url;

    // Then bind the event to the callback function.
    // There are several events for cross browser compatibility.
    script.onreadystatechange = callback;
    script.onload = callback;

    // Fire the loading
    head.appendChild(script);
}


function destroy(id) {
    flvPlayer[id].destroy();
}

function load(id) {
    flvPlayer[id].load();
}

function unload(id) {
    flvPlayer[id].unload();
}

function play(id) {
    flvPlayer[id].play();
}

function pause(id) {
    flvPlayer[id].pause();
}