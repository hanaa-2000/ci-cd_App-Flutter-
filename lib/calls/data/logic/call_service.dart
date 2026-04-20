import 'dart:async';

import 'package:chat_ai/calls/data/logic/permission_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/calls_model.dart';
import 'webrtc_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _webrtc = WebRTCService();

  CallModel? _currentCall;
  CallStatus _status = CallStatus.idle;
  StreamSubscription? _callSubscription;
  StreamSubscription? _candidatesSubscription;

  CallModel? get currentCall => _currentCall;
  CallStatus get status => _status;

  // ── بدء مكالمة (المتصل) ───────────────────────────────
  Future<void> startCall({
    required String callerId,
    required String callerName,
    required String callerAvatar,
    required String receiverId,
  }) async
  {
    final hasPermission =
    await PermissionService.requestMicrophonePermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }
    _setStatus(CallStatus.calling);

    await _webrtc.initLocalStream();

    final callDoc = _firestore.collection('calls').doc();
    final callId = callDoc.id;

    _currentCall = CallModel(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      receiverId: receiverId,
      status: CallStatus.calling,
      createdAt: DateTime.now(),
    );

    await _webrtc.initPeerConnection(callId, true);
    final offer = await _webrtc.createOffer();

    await callDoc.set({
      ..._currentCall!.toMap(),
      'offer': {'type': offer.type, 'sdp': offer.sdp},
    });

    _listenForAnswer(callId);

    // ✅ الصح: استنى remote description يتحط الأول
    // ICE candidates بتتبعت تلقائيًا من onIceCandidate
    // مش محتاج تسمع للـ callee candidates هنا
    // المتصل بس محتاج يسمع لـ callee candidates بعد ما يجاوب

    notifyListeners();
  }

  Future<void> acceptCall(CallModel call) async {
    _currentCall = call;
    _setStatus(CallStatus.connected);

    await _webrtc.initLocalStream();

    final callDoc =
    await _firestore.collection('calls').doc(call.callId).get();
    final offerData = callDoc.data()!['offer'];
    final offer =
    RTCSessionDescription(offerData['sdp'], offerData['type']);

    await _webrtc.initPeerConnection(call.callId, false);
    final answer = await _webrtc.createAnswer(offer);

    await _firestore.collection('calls').doc(call.callId).update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': CallStatus.connected.name,
    });

    // ✅ المستقبِل يسمع لـ caller candidates
    _listenForIceCandidates(call.callId, false);

    notifyListeners();
  }

  void _listenForAnswer(String callId) {
    _callSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;

      if (data['answer'] != null && _status == CallStatus.calling) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await _webrtc.setRemoteAnswer(answer);
        _setStatus(CallStatus.connected);

        // ✅ الصح: ابدأ تسمع لـ ICE candidates بعد ما تحط الـ answer
        _listenForIceCandidates(callId, true);
      }

      if (data['status'] == CallStatus.ended.name) {
        await _cleanup();
      }
    });
  }
  // Future<void> startCall({
  //   required String callerId,
  //   required String callerName,
  //   required String callerAvatar,
  //   required String receiverId,
  // }) async
  // {
  //   try {
  //     final hasPermission =
  //     await PermissionService.requestMicrophonePermission();
  //     if (!hasPermission) {
  //       throw Exception('Microphone permission denied');
  //     }
  //     _setStatus(CallStatus.calling);
  //
  //     // 1) تهيئة الميكروفون
  //     await _webrtc.initLocalStream();
  //
  //     // 2) إنشاء وثيقة المكالمة في Firebase
  //     final callDoc = _firestore.collection('calls').doc();
  //     final callId = callDoc.id;
  //
  //     _currentCall = CallModel(
  //       callId: callId,
  //       callerId: callerId,
  //       callerName: callerName,
  //       callerAvatar: callerAvatar,
  //       receiverId: receiverId,
  //       status: CallStatus.calling,
  //       createdAt: DateTime.now(),
  //     );
  //
  //     // 3) إنشاء PeerConnection + Offer
  //     await _webrtc.initPeerConnection(callId, true);
  //     final offer = await _webrtc.createOffer();
  //
  //     // 4) حفظ المكالمة + Offer في Firebase
  //     await callDoc.set({
  //       ..._currentCall!.toMap(),
  //       'offer': {
  //         'type': offer.type,
  //         'sdp': offer.sdp,
  //       },
  //     });
  //
  //     // 5) الاستماع للـ Answer من المستقبِل
  //     _listenForAnswer(callId);
  //
  //     // 6) الاستماع لـ ICE Candidates من المستقبِل
  //     _listenForIceCandidates(callId, false);
  //
  //     notifyListeners();
  //   } catch (e) {
  //     _setStatus(CallStatus.ended);
  //     rethrow;
  //   }
  // }

  // ── قبول المكالمة (المستقبِل) ─────────────────────────
  // Future<void> acceptCall(CallModel call) async {
  //   try {
  //     _currentCall = call;
  //     _setStatus(CallStatus.connected);
  //
  //     // 1) تهيئة الميكروفون
  //     await _webrtc.initLocalStream();
  //
  //     // 2) جلب الـ Offer
  //     final callDoc = await _firestore
  //         .collection('calls')
  //         .doc(call.callId)
  //         .get();
  //
  //     final offerData = callDoc.data()!['offer'];
  //     final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
  //
  //     // 3) إنشاء PeerConnection + Answer
  //     await _webrtc.initPeerConnection(call.callId, false);
  //     final answer = await _webrtc.createAnswer(offer);
  //
  //     // 4) حفظ الـ Answer في Firebase
  //     await _firestore.collection('calls').doc(call.callId).update({
  //       'answer': {
  //         'type': answer.type,
  //         'sdp': answer.sdp,
  //       },
  //       'status': CallStatus.connected.name,
  //     });
  //
  //     // 5) الاستماع لـ ICE Candidates من المتصل
  //     _listenForIceCandidates(call.callId, true);
  //
  //     notifyListeners();
  //   } catch (e) {
  //     _setStatus(CallStatus.ended);
  //     rethrow;
  //   }
  // }
// أضفهم في CallService

// ✅ FIX 3: stream لمراقبة حالة المكالمة من Firebase
  Stream<CallStatus> listenToCallStatus(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return CallStatus.ended;
      final data = snap.data()!;
      return CallStatus.values.byName(data['status'] ?? 'idle');
    });
  }

// ✅ FIX 1: cleanup محلي بدون Firebase update
// بيتعمل لما الطرف الآخر يكون هو اللي أنهى
  Future<void> localCleanup() async {
    await _callSubscription?.cancel();
    await _candidatesSubscription?.cancel();
    await _webrtc.dispose();
    _currentCall = null;
    _setStatus(CallStatus.idle);
  }
  // ── رفض / إنهاء المكالمة ─────────────────────────────
  Future<void> endCall() async {
    if (_currentCall == null) return;

    await _firestore
        .collection('calls')
        .doc(_currentCall!.callId)
        .update({'status': CallStatus.ended.name});

    await _cleanup();
  }

  // ── الاستماع للـ Answer ───────────────────────────────
  // void _listenForAnswer(String callId) {
  //   _callSubscription = _firestore
  //       .collection('calls')
  //       .doc(callId)
  //       .snapshots()
  //       .listen((snapshot) async {
  //     if (!snapshot.exists) return;
  //     final data = snapshot.data()!;
  //
  //     // المستقبِل قبل → تطبيق الـ Answer
  //     if (data['answer'] != null && _status == CallStatus.calling) {
  //       final answer = RTCSessionDescription(
  //         data['answer']['sdp'],
  //         data['answer']['type'],
  //       );
  //       await _webrtc.setRemoteAnswer(answer);
  //       _setStatus(CallStatus.connected);
  //     }
  //
  //     // المكالمة انتهت
  //     if (data['status'] == CallStatus.ended.name) {
  //       await _cleanup();
  //     }
  //   });
  // }

  // ── الاستماع لـ ICE Candidates ───────────────────────
  void _listenForIceCandidates(String callId, bool isCaller) {
    // إذا أنا المتصل → أسمع لـ calleeCandidates والعكس
    final collection = isCaller ? 'calleeCandidates' : 'callerCandidates';

    _candidatesSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection(collection)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _webrtc.addIceCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  // ── الاستماع للمكالمات الواردة ────────────────────────
  Stream<CallModel?> listenForIncomingCall(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: CallStatus.calling.name)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CallModel.fromMap(snapshot.docs.first.data());
    });
  }

  void _setStatus(CallStatus s) {
    _status = s;
    notifyListeners();
  }

  Future<void> _cleanup() async {
    await _callSubscription?.cancel();
    await _candidatesSubscription?.cancel();
    await _webrtc.dispose();
    _currentCall = null;
    _setStatus(CallStatus.idle);
  }
}