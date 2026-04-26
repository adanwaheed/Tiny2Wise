import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/api_service.dart';
import '../widgets/avatar_webview_widget.dart';

class ToddlerAvatarScreen extends StatefulWidget {
  const ToddlerAvatarScreen({super.key});

  @override
  State<ToddlerAvatarScreen> createState() => _ToddlerAvatarScreenState();
}

class _ToddlerAvatarScreenState extends State<ToddlerAvatarScreen> {
  final GlobalKey<AvatarWebViewWidgetState> avatarKey =
  GlobalKey<AvatarWebViewWidgetState>();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _speechReady = false;
  bool _isThinking = false;
  bool _finalResultHandled = false;
  bool _manualStop = false;

  String _bubbleText = 'السلام علیکم، میں شیرو ہوں';
  String _recognizedWords = '';
  String _selectedLocaleId = 'ur_PK';

  int _restartCount = 0;
  static const int _maxRestartCount = 6;

  Timer? _restartTimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final micPermission = await Permission.microphone.request();

    if (!micPermission.isGranted) {
      if (!mounted) return;

      setState(() {
        _speechReady = false;
        _bubbleText = 'مائیکروفون کی اجازت نہیں ملی';
      });
      return;
    }

    final available = await _speech.initialize(
      debugLogging: true,
      finalTimeout: const Duration(seconds: 5),
      onStatus: (status) {
        debugPrint('Speech status: $status');

        if (status == 'done' || status == 'notListening') {
          _onSpeechStatusStopped();
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');

        if (_manualStop) return;

        if (_isListening && !_isThinking) {
          _restartListeningIfNeeded();
          return;
        }

        const fallback = 'میں آپ کی آواز نہیں سن سکا، دوبارہ کوشش کریں';

        if (!mounted) return;

        setState(() {
          _isListening = false;
          _isThinking = false;
          _bubbleText = fallback;
        });

        avatarKey.currentState?.speak(fallback);
      },
    );

    if (available) {
      await _pickBestSpeechLocale();
    }

    if (!mounted) return;

    setState(() {
      _speechReady = available;
      if (!available) {
        _bubbleText = 'اس ڈیوائس پر آواز سننے کی سہولت دستیاب نہیں';
      }
    });
  }

  Future<void> _pickBestSpeechLocale() async {
    try {
      final locales = await _speech.locales();

      String normalize(String value) {
        return value.toLowerCase().replaceAll('-', '_');
      }

      final urduLocale = locales.where((locale) {
        final id = normalize(locale.localeId);
        return id == 'ur_pk' || id.startsWith('ur_') || id == 'ur';
      }).toList();

      final englishLocale = locales.where((locale) {
        final id = normalize(locale.localeId);
        return id == 'en_us' || id.startsWith('en_') || id == 'en';
      }).toList();

      if (urduLocale.isNotEmpty) {
        _selectedLocaleId = urduLocale.first.localeId;
      } else if (englishLocale.isNotEmpty) {
        _selectedLocaleId = englishLocale.first.localeId;
      } else if (locales.isNotEmpty) {
        _selectedLocaleId = locales.first.localeId;
      }

      debugPrint('Selected speech locale: $_selectedLocaleId');
    } catch (e) {
      debugPrint('Locale selection error: $e');
      _selectedLocaleId = 'ur_PK';
    }
  }

  Future<void> _onSpeechStatusStopped() async {
    if (!mounted) return;
    if (_manualStop) return;
    if (_isThinking) return;
    if (!_isListening) return;

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    if (_manualStop) return;
    if (_isThinking) return;

    final words = _recognizedWords.trim();

    if (words.isNotEmpty && !_finalResultHandled) {
      _finalResultHandled = true;

      setState(() {
        _isListening = false;
      });

      await _askGeminiAndSpeak(words);
      return;
    }

    await _restartListeningIfNeeded();
  }

  Future<void> _restartListeningIfNeeded() async {
    if (!mounted) return;
    if (_manualStop) return;
    if (_isThinking) return;
    if (!_isListening) return;

    if (_recognizedWords.trim().isNotEmpty) return;

    if (_restartCount >= _maxRestartCount) {
      const fallback = 'مجھے آواز صاف سنائی نہیں دی، دوبارہ مائیک دبائیں';

      setState(() {
        _isListening = false;
        _bubbleText = fallback;
      });

      await avatarKey.currentState?.speak(fallback);
      return;
    }

    _restartCount++;

    setState(() {
      _bubbleText = 'میں سن رہا ہوں، آرام سے بولیں...';
    });

    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      if (_manualStop) return;
      if (!_isListening) return;
      if (_isThinking) return;

      await _listenOnce();
    });
  }

  Future<void> _onMicTap() async {
    if (_isThinking) return;

    final micPermission = await Permission.microphone.request();

    if (!micPermission.isGranted) {
      const fallback = 'مائیکروفون کی اجازت نہیں ملی';

      setState(() {
        _bubbleText = fallback;
      });

      await avatarKey.currentState?.speak(fallback);
      return;
    }

    if (!_speechReady) {
      await _initSpeech();

      if (!_speechReady) {
        const fallback = 'مائیکروفون دستیاب نہیں ہے';

        setState(() {
          _bubbleText = fallback;
        });

        await avatarKey.currentState?.speak(fallback);
        return;
      }
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    await avatarKey.currentState?.stopSpeaking();

    _restartTimer?.cancel();

    if (_speech.isListening) {
      await _speech.cancel();
    }

    setState(() {
      _isListening = true;
      _isThinking = false;
      _manualStop = false;
      _finalResultHandled = false;
      _recognizedWords = '';
      _restartCount = 0;
      _bubbleText = 'میں سن رہا ہوں، آرام سے بولیں...';
    });

    await avatarKey.currentState?.playListening();

    await _listenOnce();
  }

  Future<void> _listenOnce() async {
    if (!mounted) return;
    if (!_isListening) return;
    if (_isThinking) return;

    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }

      await Future.delayed(const Duration(milliseconds: 150));

      await _speech.listen(
        localeId: _selectedLocaleId,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 8),
        partialResults: true,
        cancelOnError: false,
        onResult: (result) async {
          final words = result.recognizedWords.trim();

          debugPrint('Speech result: "$words", final: ${result.finalResult}');

          if (words.isNotEmpty && mounted) {
            _recognizedWords = words;

            setState(() {
              _bubbleText = words;
            });
          }

          if (result.finalResult &&
              words.isNotEmpty &&
              !_finalResultHandled &&
              !_manualStop) {
            _finalResultHandled = true;

            await _speech.stop();

            if (!mounted) return;

            setState(() {
              _isListening = false;
            });

            await _askGeminiAndSpeak(words);
          }
        },
      );
    } catch (e) {
      debugPrint('Listen once error: $e');

      if (!_manualStop && _isListening) {
        await _restartListeningIfNeeded();
      }
    }
  }

  Future<void> _askGeminiAndSpeak(String toddlerWords) async {
    final question = toddlerWords.trim();

    if (question.isEmpty) {
      const fallback = 'مجھے آواز صاف سنائی نہیں دی، دوبارہ بولیں';

      if (!mounted) return;

      setState(() {
        _bubbleText = fallback;
        _isThinking = false;
        _isListening = false;
      });

      await avatarKey.currentState?.speak(fallback);
      return;
    }

    try {
      if (!mounted) return;

      setState(() {
        _isListening = false;
        _isThinking = true;
        _bubbleText = 'شیرو سوچ رہا ہے...';
      });

      final reply = await ApiService.sendToddlerMessage(
        message: question,
        languageMode: 'auto',
      );

      if (!mounted) return;

      setState(() {
        _bubbleText = reply;
        _isThinking = false;
      });

      await avatarKey.currentState?.speak(reply);
      await avatarKey.currentState?.playHappy();
    } catch (e) {
      debugPrint('Gemini avatar error: $e');

      final errorText = 'AI error: ${e.toString()}';

      if (!mounted) return;

      setState(() {
        _bubbleText = errorText;
        _isThinking = false;
        _isListening = false;
      });

      await avatarKey.currentState?.speak('AI reply error');
    }
  }

  Future<void> _stopListening() async {
    _manualStop = true;
    _restartTimer?.cancel();

    await _speech.stop();

    final words = _recognizedWords.trim();

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });

    if (words.isNotEmpty && !_finalResultHandled) {
      _finalResultHandled = true;
      await _askGeminiAndSpeak(words);
    } else if (words.isEmpty) {
      const fallback = 'مجھے آواز صاف سنائی نہیں دی، دوبارہ بولیں';

      setState(() {
        _bubbleText = fallback;
      });

      await avatarKey.currentState?.speak(fallback);
    }
  }

  Future<void> _showTypedQuestionDialog() async {
    final controller = TextEditingController();

    final typedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Test Sheru with typing'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Example: What color is an apple?',
            ),
            minLines: 1,
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Ask'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (typedText == null || typedText.trim().isEmpty) return;

    if (!mounted) return;

    setState(() {
      _bubbleText = typedText.trim();
    });

    await _askGeminiAndSpeak(typedText.trim());
  }

  @override
  void dispose() {
    _manualStop = true;
    _restartTimer?.cancel();
    _speech.cancel();
    avatarKey.currentState?.stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFFEB2E),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 170,
              child: Container(
                color: const Color(0xFF9D66D9),
              ),
            ),

            Positioned(
              top: 96,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: Size(size.width, 100),
                painter: _WavePainter(),
              ),
            ),

            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),

            Positioned(
              top: 44,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TopActionButton(
                    icon: Icons.description_rounded,
                    label: 'Mock Test',
                    color: const Color(0xFF3193FF),
                    onTap: () {},
                  ),
                  const SizedBox(width: 34),
                  _TopActionButton(
                    icon: Icons.star_rounded,
                    label: 'Badges',
                    color: const Color(0xFFFF6B1A),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            Positioned(
              top: 176,
              left: 0,
              right: 0,
              bottom: 105,
              child: Column(
                children: [
                  _SpeechBubble(
                    text: _bubbleText,
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: Center(
                      child: SizedBox(
                        height: 290,
                        width: 300,
                        child: AvatarWebViewWidget(
                          key: avatarKey,
                          initialMessage: _bubbleText,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: _onMicTap,
                    onLongPress: _showTypedQuestionDialog,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 76,
                      width: 76,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? const Color(0xFFFF6B1A)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF6B1A),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B1A).withOpacity(0.25),
                            blurRadius: _isListening ? 18 : 12,
                            spreadRadius: _isListening ? 4 : 1,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _isThinking
                          ? const SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFFF6B1A),
                        ),
                      )
                          : Icon(
                        Icons.mic_rounded,
                        color: _isListening
                            ? Colors.white
                            : const Color(0xFFFF6B1A),
                        size: 42,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _BottomItem(
                    icon: Icons.sports_esports_rounded,
                    label: 'Games',
                    color: Color(0xFF2865F0),
                  ),
                  _BottomItem(
                    icon: Icons.extension_rounded,
                    label: 'Puzzles',
                    color: Color(0xFF49D83F),
                  ),
                  _BottomItem(
                    icon: Icons.menu_book_rounded,
                    label: 'Story Time',
                    color: Color(0xFF8A6D20),
                  ),
                  _BottomItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chatbot',
                    color: Color(0xFFFF5A2A),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(text);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: 285,
            minHeight: 52,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFB98BE8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            text,
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: isUrdu
                ? GoogleFonts.notoNaskhArabic(
              fontSize: 16,
              height: 1.45,
              color: const Color(0xFF1F2A2E),
              fontWeight: FontWeight.w900,
            )
                : GoogleFonts.poppins(
              fontSize: 15,
              height: 1.35,
              color: const Color(0xFF1F2A2E),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Positioned(
          bottom: -13,
          child: Transform.rotate(
            angle: 0.78,
            child: Container(
              height: 24,
              width: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(
                    color: Color(0xFFB98BE8),
                    width: 2,
                  ),
                  bottom: BorderSide(
                    color: Color(0xFFB98BE8),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 9,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 33,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final yellowPaint = Paint()
      ..color = const Color(0xFFFFEB2E)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(0, 35);

    path.cubicTo(
      size.width * 0.18,
      20,
      size.width * 0.26,
      85,
      size.width * 0.43,
      58,
    );

    path.cubicTo(
      size.width * 0.58,
      32,
      size.width * 0.65,
      10,
      size.width * 0.74,
      55,
    );

    path.cubicTo(
      size.width * 0.84,
      95,
      size.width * 0.93,
      45,
      size.width,
      62,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, yellowPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFFFBE24)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.66, 48),
      4,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
