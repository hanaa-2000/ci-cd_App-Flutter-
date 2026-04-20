// lib/screens/calling_screen.dart — كامل ومصحح
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/logic/call_service.dart';
import '../data/models/calls_model.dart';

class CallingScreen extends StatefulWidget {
  final String receiverName;
  final String receiverAvatar;

  const CallingScreen({
    super.key,
    required this.receiverName,
    required this.receiverAvatar,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with TickerProviderStateMixin {
  // ── Animations ────────────────────────────────────────
  late AnimationController _ringController;
  late AnimationController _dotsController;

  // ── State ─────────────────────────────────────────────
  int _seconds = 0;
  Timer? _timer;
  bool _isEnding = false; // ✅ FIX: منع double dispose
  int _dotIndex = 0;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();

    // Ring pulse animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Dots controller للـ scale
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startTimer();
    _startDotsTimer();
    _listenForAnswer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  // الـ dots animation
  void _startDotsTimer() {
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotIndex = (_dotIndex + 1) % 3);
    });
  }

  // ✅ FIX: listener صح بدون memory leak
  void _listenForAnswer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callService = context.read<CallService>();

      // استخدم stream مش addListener عشان تقدر تعمل cancel
      callService.addListener(_onCallStatusChanged);
    });
  }

  void _onCallStatusChanged() {
    if (!mounted || _isEnding) return;
    final callService = context.read<CallService>();

    if (callService.status == CallStatus.connected) {
      _isEnding = true;
      Navigator.pushReplacementNamed(context, '/in-call');
    } else if (callService.status == CallStatus.ended) {
      _safeEnd();
    }
  }

  String get _timeText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _safeEnd() async {
    if (_isEnding || !mounted) return;
    _isEnding = true;

    _timer?.cancel();
    _dotsTimer?.cancel();

    try {
      await context.read<CallService>().endCall();
    } catch (e) {
      print('⚠️ endCall error: $e');
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    // ✅ FIX: إزالة الـ listener عند الخروج
    try {
      context.read<CallService>().removeListener(_onCallStatusChanged);
    } catch (_) {}

    _ringController.dispose();
    _dotsController.dispose();
    _timer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) await _safeEnd();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ─────────────────────────────────
              _buildTopBar(),

              const Spacer(flex: 2),

              // ── Avatar + rings ──────────────────────────
              _buildAnimatedAvatar(),

              const SizedBox(height: 32),

              // ── Name ────────────────────────────────────
              Text(
                widget.receiverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 12),

              // ── Status + timer ──────────────────────────
              _buildStatusRow(),

              const Spacer(flex: 3),

              // ── End call button ─────────────────────────
              _buildEndButton(),

              const SizedBox(height: 52),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // مش بيسمح يرجع إلا عبر زر الإنهاء
          const SizedBox(width: 40),
          const Spacer(),
          Text(
            _timeText,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 14,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  Widget _buildAnimatedAvatar() {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (_, __) {
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // حلقة 3 — خارجية (أبطأ)
              Opacity(
                opacity: (1 - _ringController.value).clamp(0.0, 0.3),
                child: Transform.scale(
                  scale: 1.0 + _ringController.value * 0.6,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // حلقة 2 — وسط
              Opacity(
                opacity: (0.8 - _ringController.value * 0.8).clamp(0.0, 0.5),
                child: Transform.scale(
                  scale: 1.0 + _ringController.value * 0.35,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              ),

              // Avatar الأساسي
              CircleAvatar(
                radius: 64,
                backgroundColor: const Color(0xFF0F3460),
                backgroundImage: widget.receiverAvatar.isNotEmpty
                    ? NetworkImage(widget.receiverAvatar)
                    : null,
                child: widget.receiverAvatar.isEmpty
                    ? Text(
                  widget.receiverName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────
  Widget _buildStatusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _dotIndex == i ? 8 : 5,
              height: _dotIndex == i ? 8 : 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotIndex == i
                    ? Colors.white70
                    : Colors.white30,
              ),
            );
          }),
        ),
        const SizedBox(width: 10),
        const Text(
          'جاري الاتصال',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  Widget _buildEndButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isEnding ? null : _safeEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _isEnding ? Colors.grey.shade700 : Colors.red,
              shape: BoxShape.circle,
              boxShadow: _isEnding
                  ? []
                  : [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                )
              ],
            ),
            child: _isEnding
                ? const Padding(
              padding: EdgeInsets.all(22),
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
        const SizedBox(height: 10),
        Text(
          _isEnding ? 'جاري الإنهاء...' : 'إنهاء',
          style: TextStyle(
            color: _isEnding ? Colors.white38 : Colors.white54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}