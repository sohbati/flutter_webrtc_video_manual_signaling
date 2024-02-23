import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Webrtc lets learn together'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;

  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();
  final sdpController = TextEditingController();

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderer();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });

    super.initState();
  }

  void initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"}
      ]
    };
    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceivevideo": true,
      },
      "optinal":[],
    };
    _localStream = await _getUserMedia();
    RTCPeerConnection pc =
      await createPeerConnection(configuration, offerSdpConstraints);
    pc.addStream(_localStream);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMLineIndex': e.sdpMLineIndex,
        }));
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };
    pc.onAddStream = (stream) {
      print('addStream:' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'user'
      }
    };
    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    _localRenderer.srcObject = stream;
    _localRenderer.mirror = true;
    return stream;
  }

  void _createOffer() async {
    RTCSessionDescription description =
       await _peerConnection.createOffer({'offerToReceiveVideo': 1});
    var sdp = description.sdp;
    var session = parse(sdp!);
    print(json.encode(session));

    _offer = true;
    _peerConnection.setLocalDescription(description!);

  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    String sdp = write(session, null);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer? 'answer' : 'offer');
    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
        await _peerConnection.createAnswer({'offerToReceiveVideo': 1});
    String sdp = description.sdp!;
    var session = parse(sdp);
    print(json.encode(session));
    _peerConnection.setLocalDescription(description);

  }

  void _setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);
    print(session['candidate']);
    dynamic candidate =
      new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMLineIndex']);
    await _peerConnection.addCandidate(candidate);

  }

  SizedBox videoRenderers() => new SizedBox(
    height: 210,
    child: Row(
      children: [
        Flexible(
          child: Container(
            key: Key('local'),
            margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
            decoration: BoxDecoration(color: Colors.black),
            child: RTCVideoView(_localRenderer),
          ),
        ),
        Flexible(
          child: Container(
            key: Key('remote'),
            margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
            decoration: BoxDecoration(color: Colors.black),
            child: RTCVideoView(_remoteRenderer),
          ),
        ),
      ],
    ),
  );

  Row offerAndAnswerButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      ElevatedButton(
        onPressed: _createOffer,
        child: Text('offer'),
        style: ElevatedButton.styleFrom(foregroundColor: Colors.amber),
      ),
      ElevatedButton(
        onPressed: _createAnswer,
        child: Text('answer'),
        style: ElevatedButton.styleFrom(foregroundColor: Colors.amber),
      ),
    ],
  );

  Padding sdpCandidateTF() => Padding (
    padding: const EdgeInsets.all(16.0),
    child: TextField(
      controller: sdpController,
      keyboardType: TextInputType.multiline,
      maxLines: 4,
      maxLength: TextField.noMaxLength,
    ),
  );

  Row sdpCandidateButton() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      ElevatedButton(
          onPressed: _setRemoteDescription,
          child: Text('Set Remote Desc'),
          style: ElevatedButton.styleFrom(foregroundColor: Colors.amber),
      ),
      ElevatedButton(
        onPressed: _setCandidate,
        child: Text('Set Candidate'),
        style: ElevatedButton.styleFrom(foregroundColor: Colors.amber),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body:  Container(
        child: Column(
          children: [
            videoRenderers(),
            offerAndAnswerButtons(),
            sdpCandidateTF(),
            sdpCandidateButton(),

          ]

        ),
      ),
        // This trailing comma makes auto-formatting nicer for build methods.
    );
  }


}
