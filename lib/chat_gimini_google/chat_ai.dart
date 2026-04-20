// welcome_screen.dart
import 'package:chat_ai/chat_gimini_google/welcome_screen.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Gemini Logo / Icon
              // Container(
              //   width: 100,
              //   height: 100,
              //   decoration: BoxDecoration(
              //     gradient: const LinearGradient(
              //       colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
              //       begin: Alignment.topLeft,
              //       end: Alignment.bottomRight,
              //     ),
              //     borderRadius: BorderRadius.circular(24),
              //   ),
              //   child: const Icon(
              //     Icons.auto_awesome,
              //     color: Colors.white,
              //     size: 52,
              //   ),
              // ),
              Image.asset("assets/images/image.jpg"),
              const SizedBox(height: 32),

              const Text(
                'Google Gemini AI',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4285F4),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your smart AI assistant powered\nby Google Gemini',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // Features List
              // ...[
              //   [Icons.flash_on, 'Fast & Intelligent Responses'],
              //   [Icons.security, 'Safe & Reliable'],
              //   [Icons.language, 'Multilingual Support'],
              // ].map((item) => Padding(
              //   padding: const EdgeInsets.symmetric(vertical: 6),
              //   child: Row(
              //     children: [
              //       Icon(item[0] as IconData,
              //           color: const Color(0xFF4285F4), size: 20),
              //       const SizedBox(width: 10),
              //       Text(item[1] as String,
              //           style: const TextStyle(fontSize: 15)),
              //     ],
              //   ),
              // )),

              const Spacer(),

              // Start Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatAiScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Start Chatting',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
