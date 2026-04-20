import 'package:chat_ai/calls/screens/home_screen.dart';
import 'package:chat_ai/chat_gimini_google/chat_ai.dart';
import 'package:chat_ai/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'calls/data/logic/call_service.dart';
import 'calls/screens/in_call_screen.dart';
import 'chat_gimini_google/chat_gimin_google.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CallService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        theme: ThemeData(
         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: const HomeScreen(),
       // home: const WelcomeScreen(),
        routes: {
          '/in-call': (_) => const InCallScreen(),
        },
      ),
    );
  }
}
