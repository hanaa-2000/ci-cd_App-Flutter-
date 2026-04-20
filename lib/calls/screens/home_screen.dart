// lib/screens/home_screen.dart
import 'package:chat_ai/calls/data/logic/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'calling_screen.dart';
import 'incoming_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // بيانات تجريبية — استبدلها ببيانات Firebase Auth الحقيقية
  final String _myId = 'user_001';
  final String _myName = 'أحمد';
  final String _myAvatar = '';

  // جهات الاتصال (استبدلها بقائمة من Firestore)
  final List<Map<String, String>> _contacts = [
    {'id': 'user_002', 'name': 'محمد', 'avatar': ''},
    {'id': 'user_003', 'name': 'سارة', 'avatar': ''},
   // {'id': 'user_001', 'name': 'أحمد', 'avatar': ''},
    {'id': 'user_005', 'name': 'فاطمة', 'avatar': ''},
    {'id': 'user_006', 'name': 'خالد', 'avatar': ''},
  ];

  @override
  void initState() {
    super.initState();
    // الاستماع للمكالمات الواردة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForIncomingCalls();
    });
  }

  void _listenForIncomingCalls() {
    final callService = context.read<CallService>();
    callService.listenForIncomingCall(_myId).listen((call) {
      if (call != null && mounted) {
        // فتح شاشة المكالمة الواردة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(call: call),
          ),
        );
      }
    });
  }

  Future<void> _startCall(Map<String, String> contact) async {
    final callService = context.read<CallService>();

    // فتح شاشة "جاري الاتصال" أولًا
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          receiverName: contact['name']!,
          receiverAvatar: contact['avatar']!,
        ),
      ),
    );

    // ثم بدء المكالمة فعليًا
    await callService.startCall(
      callerId: _myId,
      callerName: _myName,
      callerAvatar: _myAvatar,
      receiverId: contact['id']!,
    );
  }

  // ✅ حط الدالة هنا جوه الـ State
  Future<void> testAudioOnly() async {
    print('=== START AUDIO TEST ===');

    final mic = await Permission.microphone.request();
    print('🎤 Permission: $mic');

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    print('🎙️ Tracks: ${stream.getAudioTracks().length}');
    print('🎙️ Track enabled: ${stream.getAudioTracks().first.enabled}');

    final pc1 = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
      'sdpSemantics': 'unified-plan',
    });

    final pc2 = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
      'sdpSemantics': 'unified-plan',
    });

    stream.getTracks().forEach((t) => pc1.addTrack(t, stream));

    pc2.onTrack = (event) {
      print('📡 pc2 got track: ${event.track.kind}');
      print('📡 Track enabled: ${event.track.enabled}');
    };

    pc1.onIceCandidate = (c) {
      if (c.candidate != null) pc2.addCandidate(c);
    };
    pc2.onIceCandidate = (c) {
      if (c.candidate != null) pc1.addCandidate(c);
    };

    pc1.onIceConnectionState = (s) => print('🧊 pc1 ICE: $s');
    pc2.onIceConnectionState = (s) => print('🧊 pc2 ICE: $s');

    final offer = await pc1.createOffer();
    await pc1.setLocalDescription(offer);
    await pc2.setRemoteDescription(offer);

    final answer = await pc2.createAnswer();
    await pc2.setLocalDescription(answer);
    await pc1.setRemoteDescription(answer);

    print('=== TEST DONE ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'المكالمات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // رأس الصفحة — بيانات المستخدم الحالي
          _buildMyProfile(),
// ✅ زر الـ Test — امسحه بعد ما تخلص
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange,
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 24, vertical: 14),
//             ),
//             icon: const Icon(Icons.bug_report),
//             label: const Text('Test Audio'),
//             onPressed: testAudioOnly,
//           ),
          // فاصل
          Divider(
            color: Colors.white.withOpacity(0.1),
            height: 1,
          ),

          // عنوان القائمة
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                Text(
                  'جهات الاتصال (${_contacts.length})',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // قائمة جهات الاتصال
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withOpacity(0.05),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return _ContactTile(
                  contact: contact,
                  onCallTap: () => _startCall(contact),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyProfile() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // صورة المستخدم
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF0F3460),
            child: Text(
              _myName[0],
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // الاسم والحالة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _myName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'متاح',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // زر الإعدادات
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white38),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// ── عنصر جهة الاتصال ──────────────────────────────────────
class _ContactTile extends StatelessWidget {
  final Map<String, String> contact;
  final VoidCallback onCallTap;

  const _ContactTile({required this.contact, required this.onCallTap});

  // لون عشوائي ثابت بناءً على الاسم
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF0F3460),
      const Color(0xFF533483),
      const Color(0xFF1B4F72),
      const Color(0xFF117A65),
      const Color(0xFF784212),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final name = contact['name']!;
    final avatar = contact['avatar']!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _avatarColor(name),
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty
            ? Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        )
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: const Text(
        'اضغط للاتصال',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // زر الاتصال الصوتي
          GestureDetector(
            onTap: onCallTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call,
                color: Colors.greenAccent,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      onTap: onCallTap,
    );
  }
}