// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:async';
//
// class WebRTCService {
//   static final WebRTCService _instance = WebRTCService._internal();
//   factory WebRTCService() => _instance;
//   WebRTCService._internal();
//
//   RTCPeerConnection? _peerConnection;
//   MediaStream? _localStream;
//   bool _isMuted = false;
//   bool _isSpeakerOn = false;
//
//   final _onRemoteStreamController = StreamController<MediaStream>.broadcast();
//   final _onConnectionStateController =
//   StreamController<RTCPeerConnectionState>.broadcast();
//
//   Stream<MediaStream> get onRemoteStream => _onRemoteStreamController.stream;
//   Stream<RTCPeerConnectionState> get onConnectionState =>
//       _onConnectionStateController.stream;
//
//   final Map<String, dynamic> _iceServers = {
//     'iceServers': [
//       {'urls': 'stun:stun.l.google.com:19302'},
//       {'urls': 'stun:stun1.l.google.com:19302'},
//       {
//         'urls': 'turn:openrelay.metered.ca:80',
//         'username': 'openrelayproject',
//         'credential': 'openrelayproject',
//       },
//     ],
//     'sdpSemantics': 'unified-plan',
//   };
//
//   // ✅ FIX 1: تهيئة الـ Audio Session الصح
//   Future<void> initLocalStream() async {
//     // iOS: لازم تهيئة RTCAudioSession قبل getUserMedia
//     if (WebRTC.platformIsIOS) {
//       final audioSession = RTCAudioSession.sharedInstance;
//       await audioSession.lockForConfiguration();
//       try {
//         await audioSession.setCategory(
//           'AVAudioSessionCategoryPlayAndRecord',
//         );
//         await audioSession.setMode(
//           'AVAudioSessionModeVoiceChat',
//         );
//         await audioSession.setActive(true);
//       } finally {
//         await audioSession.unlockForConfiguration();
//       }
//     }
//
//     // Android + iOS: الـ constraints الصح للصوت
//     final Map<String, dynamic> mediaConstraints = {
//       'audio': {
//         'mandatory': {
//           'googEchoCancellation': 'true',
//           'googAutoGainControl': 'true',
//           'googNoiseSuppression': 'true',
//           'googHighpassFilter': 'true',
//           // ✅ FIX 2: لازم تبقى enabled من الأول
//           'sourceId': 'default',
//         },
//         'optional': [],
//       },
//       'video': false,
//     };
//
//     _localStream =
//     await navigator.mediaDevices.getUserMedia(mediaConstraints);
//
//     // ✅ FIX 3: تأكد إن الـ audio track شغال
//     final audioTracks = _localStream!.getAudioTracks();
//     if (audioTracks.isNotEmpty) {
//       audioTracks.first.enabled = true;
//       print('✅ Audio track: ${audioTracks.first.label} — enabled');
//     } else {
//       print('❌ No audio tracks found!');
//     }
//   }
//
//   // ✅ FIX 4: إضافة الـ tracks قبل إنشاء الـ connection مش بعده
//   Future<void> initPeerConnection(String callId, bool isCaller) async {
//     // تأكد إن الـ local stream موجود
//     if (_localStream == null) {
//       await initLocalStream();
//     }
//
//     _peerConnection = await createPeerConnection(_iceServers);
//
//     // ✅ الصح: addTrack قبل أي event listeners
//     _localStream!.getTracks().forEach((track) {
//       print('➕ Adding track: ${track.kind} — ${track.label}');
//       _peerConnection!.addTrack(track, _localStream!);
//     });
//
//     // ✅ FIX 5: onTrack لازم يشغل الـ remote stream فورًا
//     _peerConnection!.onTrack = (RTCTrackEvent event) {
//       print('📡 Remote track received: ${event.track.kind}');
//
//       if (event.track.kind == 'audio') {
//         // تأكد إن الـ track مش معطل
//         event.track.enabled = true;
//
//         if (event.streams.isNotEmpty) {
//           final remoteStream = event.streams.first;
//           print('🔊 Remote stream id: ${remoteStream.id}');
//           _onRemoteStreamController.add(remoteStream);
//
//           // Android: تأكد إن السماعة شغالة
//           if (WebRTC.platformIsAndroid) {
//             Helper.setSpeakerphoneOn(false); // earpiece افتراضي زي الموبايل
//           }
//         }
//       }
//     };
//
//     _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
//       print('🔗 Connection state: $state');
//       _onConnectionStateController.add(state);
//     };
//
//     // ✅ FIX 6: مراقبة ICE state للـ debug
//     _peerConnection!.onIceConnectionState =
//         (RTCIceConnectionState state) {
//       print('🧊 ICE state: $state');
//       if (state ==
//           RTCIceConnectionState.RTCIceConnectionStateConnected ||
//           state ==
//               RTCIceConnectionState.RTCIceConnectionStateCompleted) {
//         print('✅ ICE Connected! Audio should work now');
//         // تأكيد تشغيل الصوت عند الاتصال
//         _ensureAudioActive();
//       }
//     };
//
//     _peerConnection!.onSignalingState = (RTCSignalingState state) {
//       print('📶 Signaling state: $state');
//     };
//
//     _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
//       if (candidate.candidate != null) {
//         print('🧊 New ICE candidate: ${candidate.candidate}');
//         _sendIceCandidate(callId, candidate, isCaller);
//       }
//     };
//   }
//
//   // ✅ FIX 7: دالة تضمن تشغيل الصوت بعد الاتصال
//   void _ensureAudioActive() {
//     // تأكد إن local tracks شغالة
//     _localStream?.getAudioTracks().forEach((track) {
//       if (!track.enabled) {
//         track.enabled = true;
//         print('🔧 Re-enabled local audio track');
//       }
//     });
//
//     // Android speaker
//     if (WebRTC.platformIsAndroid) {
//       Helper.setSpeakerphoneOn(_isSpeakerOn);
//     }
//   }
//
//   Future<RTCSessionDescription> createOffer() async {
//     final offer = await _peerConnection!.createOffer();
//     await _peerConnection!.setLocalDescription(offer);
//     print('📤 Offer created: ${offer.type}');
//     return offer;
//   }
//
//   Future<RTCSessionDescription> createAnswer(
//       RTCSessionDescription offer) async {
//     await _peerConnection!.setRemoteDescription(offer);
//     final answer = await _peerConnection!.createAnswer();
//     await _peerConnection!.setLocalDescription(answer);
//     print('📥 Answer created: ${answer.type}');
//     return answer;
//   }
//
//   Future<void> setRemoteAnswer(RTCSessionDescription answer) async {
//     print('📥 Setting remote answer...');
//     await _peerConnection?.setRemoteDescription(answer);
//   }
//
//   Future<void> addIceCandidate(RTCIceCandidate candidate) async {
//     try {
//       await _peerConnection?.addCandidate(candidate);
//     } catch (e) {
//       print('⚠️ ICE candidate error: $e');
//     }
//   }
//
//   Future<void> _sendIceCandidate(
//       String callId, RTCIceCandidate candidate, bool isCaller) async {
//     final collection =
//     isCaller ? 'callerCandidates' : 'calleeCandidates';
//     await FirebaseFirestore.instance
//         .collection('calls')
//         .doc(callId)
//         .collection(collection)
//         .add({
//       'candidate': candidate.candidate,
//       'sdpMid': candidate.sdpMid,
//       'sdpMLineIndex': candidate.sdpMLineIndex,
//     });
//   }
//
//   void toggleMute() {
//     _isMuted = !_isMuted;
//     _localStream?.getAudioTracks().forEach((track) {
//       track.enabled = !_isMuted;
//     });
//     print('🎤 Mute: $_isMuted');
//   }
//
//   void toggleSpeaker() {
//     _isSpeakerOn = !_isSpeakerOn;
//     Helper.setSpeakerphoneOn(_isSpeakerOn);
//     print('🔊 Speaker: $_isSpeakerOn');
//   }
//
//   bool get isMuted => _isMuted;
//   bool get isSpeakerOn => _isSpeakerOn;
//
//   Future<void> dispose() async {
//     _localStream?.getTracks().forEach((track) => track.stop());
//     await _localStream?.dispose();
//     await _peerConnection?.close();
//     _peerConnection = null;
//     _localStream = null;
//     _isMuted = false;
//     _isSpeakerOn = false;
//     print('🧹 WebRTC disposed');
//   }
// }
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart'; // ✅ الـ import الصح
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  final _onRemoteStreamController = StreamController<MediaStream>.broadcast();
  final _onConnectionStateController =
  StreamController<RTCPeerConnectionState>.broadcast();

  Stream<MediaStream> get onRemoteStream => _onRemoteStreamController.stream;
  Stream<RTCPeerConnectionState> get onConnectionState =>
      _onConnectionStateController.stream;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  // ✅ تهيئة الـ Audio Session بـ audio_session package
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;

    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
      AVAudioSessionCategoryOptions.allowBluetooth |
      AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      avAudioSessionRouteSharingPolicy:
      AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    await session.setActive(true);
    print('✅ Audio session configured');
  }

  Future<void> initLocalStream() async {
    // ✅ هيئ الـ audio session الأول على iOS و Android
    await _configureAudioSession();

    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'mandatory': {
          'googEchoCancellation': 'true',
          'googAutoGainControl': 'true',
          'googNoiseSuppression': 'true',
          'googHighpassFilter': 'true',
        },
        'optional': [],
      },
      'video': false,
    };

    _localStream =
    await navigator.mediaDevices.getUserMedia(mediaConstraints);

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      audioTracks.first.enabled = true;
      print('✅ Audio track ready: ${audioTracks.first.label}');
    } else {
      print('❌ No audio tracks!');
    }
  }

  Future<void> initPeerConnection(String callId, bool isCaller) async {
    if (_localStream == null) await initLocalStream();

    _peerConnection = await createPeerConnection(_iceServers);

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
      print('➕ Track added: ${track.kind}');
    });

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('📡 Remote track: ${event.track.kind}');
      if (event.track.kind == 'audio') {
        event.track.enabled = true;
        if (event.streams.isNotEmpty) {
          _onRemoteStreamController.add(event.streams.first);
        }
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('🔗 Connection: $state');
      _onConnectionStateController.add(state);
    };

    _peerConnection!.onIceConnectionState =
        (RTCIceConnectionState state) {
      print('🧊 ICE: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        print('✅ ICE Connected — audio should work!');
        // تأكيد تشغيل الصوت
        _localStream?.getAudioTracks().forEach((t) => t.enabled = true);
        Helper.setSpeakerphoneOn(_isSpeakerOn);
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _sendIceCandidate(callId, candidate, isCaller);
      }
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer(
      RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteAnswer(RTCSessionDescription answer) async {
    await _peerConnection?.setRemoteDescription(answer);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      print('⚠️ ICE error: $e');
    }
  }

  Future<void> _sendIceCandidate(
      String callId, RTCIceCandidate candidate, bool isCaller) async {
    final collection =
    isCaller ? 'callerCandidates' : 'calleeCandidates';
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .collection(collection)
        .add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  Future<void> dispose() async {
    // إيقاف الـ audio session
    final session = await AudioSession.instance;
    await session.setActive(false);

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _isMuted = false;
    _isSpeakerOn = false;
  }
}