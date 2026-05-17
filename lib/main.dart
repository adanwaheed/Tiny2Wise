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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clampedScale = media.textScaleFactor.clamp(0.85, 1.15).toDouble();
        return MediaQuery(
          data: media.copyWith(textScaleFactor: clampedScale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}