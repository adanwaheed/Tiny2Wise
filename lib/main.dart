import 'package:flutter/material.dart';
import 'startup_screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiny2Wise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E8B5A)),
      ),
      home: const SplashScreen(),
    );
  }
}

//
// import 'package:flutter/material.dart';
// import 'toddler_screens/toddler_avatar_screen.dart';
//
// void main() {
//   runApp(const Tiny2WiseTestApp());
// }
//
// class Tiny2WiseTestApp extends StatelessWidget {
//   const Tiny2WiseTestApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: ToddlerAvatarScreen(),
//     );
//   }
// }