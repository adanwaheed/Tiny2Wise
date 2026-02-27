import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color bg = Color(0xFFEFF7ED);
  static const Color green = Color(0xFF1E8B5A);
  static const Color textDark = Color(0xFF1F2A2E);
  static const Color textGrey = Color(0xFF6E7B80);

  late final AnimationController _controller;
  late final Animation<double> _progress;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Loads from 0 to 100% in 10 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _progress = CurvedAnimation(parent: _controller, curve: Curves.linear);

    _controller.forward();

    _navTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Background watermark icons (books)
            const _WatermarkIcons(),

            // Main content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo block (rounded square + inner logo)
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFF499A54).withOpacity(0.35), // #F8FFF9
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Color(0xFFDEDEA4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            "assets/logo.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Tiny2Wise text (with green "2")
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                          height: 1.1,
                        ),
                        children: [
                          TextSpan(text: "Tiny"),
                          TextSpan(
                            text: "2",
                            style: TextStyle(color: green),
                          ),
                          TextSpan(text: "Wise"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Tagline
                    const Text(
                      "Voice Across Generations 🌱",
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 46),

                    // Loading + percent line
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) {
                        final percent = (_progress.value * 100).round();

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Loading your experience...",
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  "$percent%",
                                  style: const TextStyle(
                                    color: textGrey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: _progress.value,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFDDE8D9),
                                valueColor:
                                const AlwaysStoppedAnimation<Color>(green),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Version
                            const Text(
                              "v3.0.1",
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatermarkIcons extends StatelessWidget {
  const _WatermarkIcons();

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xFF1E8B5A);

    return Stack(
      children: const [
        Positioned(
          left: 22,
          top: 120,
          child: Opacity(
            opacity: 0.12,
            child: Icon(Icons.menu_book_outlined, size: 34, color: iconColor),
          ),
        ),
        Positioned(
          right: 26,
          top: 170,
          child: Opacity(
            opacity: 0.12,
            child: Icon(Icons.menu_book_outlined, size: 30, color: iconColor),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 130,
          child: Opacity(
            opacity: 0.12,
            child: Icon(Icons.menu_book_outlined, size: 44, color: iconColor),
          ),
        ),
        Positioned(
          right: 22,
          bottom: 180,
          child: Opacity(
            opacity: 0.12,
            child: Icon(Icons.menu_book_outlined, size: 46, color: iconColor),
          ),
        ),
      ],
    );
  }
}
