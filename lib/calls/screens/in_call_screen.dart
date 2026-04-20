// lib/screens/in_call_screen.dart — كامل ومصحح
import 'dart:async';
import 'package:chat_ai/calls/data/logic/call_service.dart';
import 'package:chat_ai/calls/data/logic/webrtc_service.dart';
import 'package:chat_ai/calls/data/models/calls_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';


class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen>
    with WidgetsBindingObserver {
  final _webrtc = WebRTCService();
  Timer? _timer;
  int _seconds = 0;
  StreamSubscription? _connectionSub;
  StreamSubscription? _callStatusSub;
  bool _isEnding = false; // ✅ FIX 1: منع double dispose

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _listenConnection();
    _listenRemoteHangup(); // ✅ FIX 3: الاستماع لإنهاء الطرف الآخر
  }

  // ─────────────────────────────────────────────────────
  // FIX 1: منع الكراش عند الغلق — dispose آمن
  // ─────────────────────────────────────────────────────
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connectionSub?.cancel();
    _callStatusSub?.cancel();
    // ✅ مش بنعمل endCall هنا عشان dispose بيتعمل بعد endCall
    // لو عملنا endCall هنا هيعمل crash لأن الـ context مش موجود
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // FIX 1: لو التطبيق اتقفل من الخارج
  // ─────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _safeEndCall();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  // ─────────────────────────────────────────────────────
  // FIX 2: الاستماع لانقطاع الاتصال بأمان
  // ─────────────────────────────────────────────────────
  void _listenConnection() {
    _connectionSub = _webrtc.onConnectionState.listen((state) {
      print('🔗 InCall connection state: $state');
      if (!mounted || _isEnding) return;

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _safeEndCall();
      }
    });
  }

  // ─────────────────────────────────────────────────────
  // FIX 3: الاستماع لإنهاء الطرف الآخر من Firebase
  // ─────────────────────────────────────────────────────
  void _listenRemoteHangup() {
    final callService = context.read<CallService>();
    final callId = callService.currentCall?.callId;
    if (callId == null) return;

    _callStatusSub = callService.listenToCallStatus(callId).listen((status) {
      print('📞 Call status from Firebase: $status');
      if (!mounted || _isEnding) return;

      if (status == CallStatus.ended) {
        // الطرف الآخر أنهى المكالمة
        _showEndedSnackbar('انتهت المكالمة');
        _safeEndCall(remoteEnded: true);
      }
    });
  }

  // ─────────────────────────────────────────────────────
  // FIX 1 + 2 + 3: دالة إنهاء آمنة
  // ─────────────────────────────────────────────────────
  Future<void> _safeEndCall({bool remoteEnded = false}) async {
    if (_isEnding || !mounted) return;
    _isEnding = true;

    _timer?.cancel();
    _connectionSub?.cancel();
    _callStatusSub?.cancel();

    try {
      final callService = context.read<CallService>();
      // لو الطرف الآخر أنهى → مش محتاج نبعت update لـ Firebase تاني
      if (!remoteEnded) {
        await callService.endCall();
      } else {
        // بس نعمل cleanup محلي
        await callService.localCleanup();
      }
    } catch (e) {
      print('⚠️ endCall error: $e');
    }

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showEndedSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String get _duration {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callService = context.watch<CallService>();
    final call = callService.currentCall;

    // ✅ FIX 2: لو currentCall null مش بيعمل crash
    if (call == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return PopScope(
      // ✅ FIX 1: منع الرجوع بالـ back button بدون إنهاء المكالمة
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) await _safeEndCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────
              _buildHeader(call),

              const Spacer(),

              // ── Avatar ──────────────────────────────────
              _buildAvatar(call),

              const SizedBox(height: 16),

              // ── Duration ────────────────────────────────
              _buildDuration(),

              const Spacer(),

              // ── Controls ────────────────────────────────
              _buildControls(callService),

              const SizedBox(height: 52),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // UI Widgets
  // ─────────────────────────────────────────────────────
  Widget _buildHeader(CallModel call) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          // جودة الاتصال indicator
          StreamBuilder<RTCPeerConnectionState>(
            stream: _webrtc.onConnectionState,
            builder: (context, snapshot) {
              final connected = snapshot.data ==
                  RTCPeerConnectionState.RTCPeerConnectionStateConnected;
              return Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connected ? Colors.greenAccent : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connected ? 'متصل' : 'جاري الاتصال...',
                    style: TextStyle(
                      color: connected ? Colors.greenAccent : Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          Text(
            call.callerName,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(CallModel call) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // حلقة خارجية
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
          ),
        ),
        // الصورة
        CircleAvatar(
          radius: 64,
          backgroundColor: const Color(0xFF0F3460),
          backgroundImage: (call.callerAvatar.isNotEmpty)
              ? NetworkImage(call.callerAvatar)
              : null,
          child: call.callerAvatar.isEmpty
              ? Text(
            call.callerName[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 48,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          )
              : null,
        ),
      ],
    );
  }

  Widget _buildDuration() {
    return Column(
      children: [
        Text(
          _duration,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 36,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'مكالمة صوتية',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildControls(CallService callService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // كتم الصوت
          _ControlButton(
            icon: _webrtc.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _webrtc.isMuted ? 'فتح الصوت' : 'كتم',
            active: _webrtc.isMuted,
            activeColor: Colors.red.shade400,
            onTap: () {
              _webrtc.toggleMute();
              setState(() {});
            },
          ),

          // إنهاء المكالمة — الزر الرئيسي
          GestureDetector(
            onTap: _isEnding ? null : _safeEndCall,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _isEnding ? Colors.grey : Colors.red,
                shape: BoxShape.circle,
              ),
              child: _isEnding
                  ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // مكبر الصوت
          _ControlButton(
            icon: _webrtc.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: _webrtc.isSpeakerOn ? 'سماعة' : 'هاتف',
            active: _webrtc.isSpeakerOn,
            activeColor: Colors.greenAccent,
            onTap: () {
              _webrtc.toggleSpeaker();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Control Button Widget
// ─────────────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active
                  ? activeColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? activeColor : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: active ? activeColor : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? activeColor : Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}