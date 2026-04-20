import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ============================================================
//  1) روح على: https://openrouter.ai  وسجل (مجاني تماماً)
//  2) من: https://openrouter.ai/keys  انسخ الـ API Key
//  3) حطه هنا 👇
// ============================================================
const String apiKey = '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';

// 'openrouter/free' = بيختار تلقائياً أفضل موديل مجاني متاح ✅ (الأضمن)
// أو اختار موديل محدد من الأحدث:
//  'meta-llama/llama-3.3-70b-instruct:free'
//  'deepseek/deepseek-r1:free'
//  'deepseek/deepseek-v3:free'
//  'google/gemma-3-27b-it:free'
const String aiModel = 'openrouter/free';

// fallback models لو رجع 404
const List<String> fallbackModels = [
  'deepseek/deepseek-v3:free',
  'deepseek/deepseek-r1:free',
  'meta-llama/llama-3.3-70b-instruct:free',
  'google/gemma-3-27b-it:free',
];




// ===== نموذج الرسالة =====
class Msg {
  final String text;
  final bool isUser;
  final DateTime time;
  Msg(this.text, this.isUser) : time = DateTime.now();
}

// ===== شاشة الشات الرئيسية =====
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Msg> _msgs = [];
  final List<Map<String, String>> _history = [];
  bool _loading = false;

  // ===== استدعاء OpenRouter API مع Fallback =====
  Future<String> _callAI(String text) async {
    _history.add({"role": "user", "content": text});

    // جرب aiModel الأول، لو فشل جرب الـ fallbackModels
    final modelsToTry = [aiModel, ...fallbackModels];

    for (final model in modelsToTry) {
      try {
        final res = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://flutter-ai-chat.app',
            'X-Title': 'Flutter AI Chat',
          },
          body: jsonEncode({
            "model": model,
            "messages": [
              {
                "role": "system",
                "content":
                "انت مساعد ذكاء اصطناعي ودود اسمك Zaki. بتتكلم عربي وانجليزي. ردودك مفيدة وواضحة."
              },
              ..._history,
            ],
            "max_tokens": 1024,
            "temperature": 0.8,
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final reply = data['choices'][0]['message']['content'] as String;
          _history.add({"role": "assistant", "content": reply});
          return reply.trim();
        }

        // لو 404 = الموديل مش متاح، جرب التالي
        if (res.statusCode == 404) continue;

        // باقي الأخطاء
        if (res.statusCode == 401) {
          return '❌ الـ API Key غلط\nروح openrouter.ai/keys وتأكد منه';
        }
        if (res.statusCode == 429) {
          return '⏳ طلبات كتير، استنى ثانية وحاول تاني';
        }
        final err = jsonDecode(res.body);
        final msg = err['error']?['message'] ?? '';
        return '⚠️ خطأ ${res.statusCode}: $msg';

      } catch (e) {
        if (model == modelsToTry.last) {
          return '❌ مشكلة في الاتصال - تأكد من النت';
        }
        continue; // جرب الموديل التالي
      }
    }

    return '❌ كل الموديلات المجانية مش متاحة دلوقتي، حاول بعدين';
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();

    setState(() {
      _msgs.add(Msg(text, true));
      _loading = true;
    });
    _toBottom();

    final reply = await _callAI(text);

    setState(() {
      _msgs.add(Msg(reply, false));
      _loading = false;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Row(children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF128C7E),
            radius: 19,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Zaki AI',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(
              _loading ? 'جاري الكتابة...' : 'متصل • مجاني 100%',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.8)),
            ),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'مسح المحادثة',
            onPressed: () => setState(() {
              _msgs.clear();
              _history.clear();
            }),
          )
        ],
      ),
      body: Column(children: [
        Expanded(child: _msgs.isEmpty ? _buildWelcome() : _buildList()),
        if (_loading) _buildTyping(),
        _buildInput(),
      ]),
    );
  }

  Widget _buildWelcome() {
    final tips = [
      '💡 اشرح لي الذكاء الاصطناعي',
      '📝 ساعدني في كتابة CV',
      '🔢 احل مسألة رياضيات',
      '🌍 ترجم جملة للإنجليزي',
      '💻 اكتب لي كود Python',
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF075E54).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                size: 55, color: Color(0xFF075E54)),
          ),
          const SizedBox(height: 18),
          const Text('أهلاً! أنا Zaki 👋',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF075E54))),
          const SizedBox(height: 8),
          Text('مساعد AI مجاني - اسألني أي حاجة',
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Text('يعمل بـ OpenRouter • مجاني 100%',
                style:
                TextStyle(fontSize: 12, color: Colors.green[700])),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: tips.map((t) {
              return GestureDetector(
                onTap: () {
                  _ctrl.text = t.substring(2).trim();
                  _send();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                        const Color(0xFF075E54).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3)
                    ],
                  ),
                  child: Text(t,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF075E54))),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      itemCount: _msgs.length,
      itemBuilder: (_, i) => _buildBubble(_msgs[i]),
    );
  }

  Widget _buildBubble(Msg m) {
    final time = DateFormat('hh:mm a').format(m.time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
        m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.isUser) ...[
            const CircleAvatar(
              radius: 13,
              backgroundColor: Color(0xFF075E54),
              child:
              Icon(Icons.smart_toy, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth:
                  MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: m.isUser
                    ? const Color(0xFFDCF8C6)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                  Radius.circular(m.isUser ? 16 : 4),
                  bottomRight:
                  Radius.circular(m.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 3)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.text,
                      style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1C1C1C),
                          height: 1.4),
                     // textDirection: TextDirection.rtl
                 ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500])),
                      if (m.isUser) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.done_all,
                            size: 13, color: Colors.blue[300]),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (m.isUser) const SizedBox(width: 5),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Row(children: [
        const CircleAvatar(
          radius: 13,
          backgroundColor: Color(0xFF075E54),
          child:
          Icon(Icons.smart_toy, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 3)
            ],
          ),
          child: const _Dots(),
        ),
      ]),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(0xFFECE5DD),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 4)
              ],
            ),
            child: TextField(
              controller: _ctrl,
              //textDirection: TextDirection.rtl,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'اكتب رسالتك...',
               // hintTextDirection: TextDirection.rtl,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _loading
                  ? Colors.grey
                  : const Color(0xFF075E54),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF075E54).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Icon(
              _loading
                  ? Icons.hourglass_empty
                  : Icons.send,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }
}

// ===== نقاط الكتابة المتحركة =====
class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final v =
          ((_ac.value * 3) - i).clamp(0.0, 1.0);
          final scale = v < 0.5 ? 1.0 + v : 2.0 - v;
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 3),
            child: Transform.scale(
              scale: scale.clamp(0.8, 1.3),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}