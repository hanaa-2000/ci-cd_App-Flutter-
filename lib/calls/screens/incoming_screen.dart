import 'package:chat_ai/calls/data/logic/call_service.dart';
import 'package:chat_ai/calls/data/models/calls_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3460),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // نبضات الرنين
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // حلقة خارجية
                    Transform.scale(
                      scale: 1.0 + _ringController.value * 0.5,
                      child: Opacity(
                        opacity: 1 - _ringController.value,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                        ),
                      ),
                    ),
                    // الصورة
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: const Color(0xFF16213E),
                      child: Text(
                        widget.call.callerName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 48,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
            Text(
              widget.call.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'مكالمة صوتية واردة',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const Spacer(),

            // أزرار القبول والرفض
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // رفض
                  _ActionButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'رفض',
                    onTap: () async {
                      await context.read<CallService>().endCall();
                      if (mounted) Navigator.pop(context);
                    },
                  ),

                  // قبول
                  _ActionButton(
                    icon: Icons.call,
                    color: Colors.green,
                    label: 'قبول',
                    onTap: () async {
                      await context.read<CallService>().acceptCall(widget.call);
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/in-call');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}