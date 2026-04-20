// chat_ai_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatAiScreen extends StatefulWidget {
  const ChatAiScreen({super.key});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _showScrollDown = false;

  static const String _apiKey = 'AIzaSyAiUg4bOhzrqNsbS0yB_2ZD6rHQsHwyjX0';
  static const String _model = 'gemini-2.5-flash';

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // بناء الـ history للـ API
      final contents = _messages.map((msg) => {
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [{'text': msg['text']}],
      }).toList();

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': contents}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _messages.add({'role': 'model', 'text': reply});
          _isLoading = false;
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _messages.add({'role': 'model', 'text': 'Error: ${error['error']['message']}'});
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'model', 'text': 'Error: $e'});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }
// استبدل _scrollToBottom بالكامل
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,   // ✅ أحسن من easeOut
        );
      }
    });
  }

  // void _scrollToBottom() {
  //   Future.delayed(const Duration(milliseconds: 100), () {
  //     if (_scrollController.hasClients) {
  //       _scrollController.animateTo(
  //         _scrollController.position.maxScrollExtent,
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     }
  //   });
  // }
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final isNotAtBottom =
          _scrollController.position.pixels <
              _scrollController.position.maxScrollExtent - 100;
      if (isNotAtBottom != _showScrollDown) {
        setState(() => _showScrollDown = isNotAtBottom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,  // ✅ أضف دي
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF4285F4),
          foregroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, size: 22),
              SizedBox(width: 8),
              Text('Gemini AI',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          elevation: 0,
        ),

        // استبدل الـ body بالكامل — أضفنا Stack مع FloatingActionButton
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i]),
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                  ),
                _buildInputBar(),
              ],
            ),

            // زرار السهم لتحت
            if (_showScrollDown)
              Positioned(
                bottom: 80,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _showScrollDown ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: FloatingActionButton.small(
                    onPressed: _scrollToBottom,
                    backgroundColor: const Color(0xFF4285F4),
                    elevation: 2,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // body:
        //
        // Column(
        //   children: [
        //     Expanded(
        //       child: _messages.isEmpty
        //           ? _buildEmptyState()
        //           : ListView.builder(
        //         controller: _scrollController,
        //         padding: const EdgeInsets.all(16),
        //         itemCount: _messages.length,
        //         itemBuilder: (_, i) => _buildMessage(_messages[i]),
        //       ),
        //     ),
        //     if (_isLoading)
        //       const Padding(
        //         padding: EdgeInsets.symmetric(horizontal: 16),
        //         child: Align(
        //           alignment: Alignment.centerLeft,
        //           child: CircularProgressIndicator(
        //             strokeWidth: 2,
        //             color: Color(0xFF4285F4),
        //           ),
        //         ),
        //       ),
        //     _buildInputBar(),
        //   ],
        // ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              size: 64, color: Color(0xFF4285F4)),
          SizedBox(height: 16),
          Text('Ask me anything!',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF4285F4)
              : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          msg['text'],
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF202124),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8, bottom: 12,  // ✅ fixed padding
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Message Gemini...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F3F4),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF4285F4),
            child: IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
