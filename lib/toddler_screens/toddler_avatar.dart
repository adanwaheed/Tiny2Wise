import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/api_service.dart';
import 'toddler_mocktest.dart';
import 'toddler_games.dart';
import 'toddler_puzzle.dart';
import 'toddler_story_telling.dart';
import 'toddler_badges.dart';
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
  bool _isSubmittingSpeech = false;

  // Default is Urdu because Tiny2Wise toddler avatar screen is mainly Urdu.
  // If you want English testing, double-tap the mic button to switch language.
  String _speechLanguageMode = 'urdu';

  String _bubbleText = 'السلام علیکم، میں نور ہوں۔ آپ آج کیا سیکھنا چاہتے ہیں؟';
  String _recognizedWords = '';
  String _selectedLocaleId = '';
  String? _urduLocaleId;
  String? _englishLocaleId;
  String? _romanUrduLocaleId;
  String? _systemLocaleId;

  int _restartCount = 0;

  Timer? _restartTimer;
  Timer? _autoSubmitTimer;

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

        const fallback = 'میں آپ کی آواز نہیں سن سکا، دوبارہ کوشش کریں';

        if (!mounted) return;

        setState(() {
          _isListening = false;
          _isThinking = false;
          _bubbleText = fallback;
        });

        avatarKey.currentState?.playGentle();
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
      final systemLocale = await _speech.systemLocale();
      _systemLocaleId = systemLocale?.localeId;

      final locales = await _speech.locales();

      String normalize(String value) {
        return value.toLowerCase().replaceAll('-', '_');
      }

      for (final locale in locales) {
        final id = normalize(locale.localeId);

        if (_urduLocaleId == null &&
            (id == 'ur_pk' || id.startsWith('ur_') || id == 'ur')) {
          _urduLocaleId = locale.localeId;
        }

        if (_romanUrduLocaleId == null &&
            (id == 'en_pk' || id == 'en_in' || id == 'en_us' || id == 'en_gb')) {
          _romanUrduLocaleId = locale.localeId;
        }

        if (_englishLocaleId == null &&
            (id == 'en_us' || id == 'en_gb' || id.startsWith('en_') || id == 'en')) {
          _englishLocaleId = locale.localeId;
        }
      }

      // Tiny2Wise screen is Urdu-first, so Urdu STT must be selected by default.
      // If Urdu locale is missing on the phone, Android default is used.
      _selectedLocaleId = _localeForCurrentSpeechMode();

      debugPrint(
        'Speech locales -> system: $_systemLocaleId, selected: $_selectedLocaleId, urdu: $_urduLocaleId, romanUrdu: $_romanUrduLocaleId, english: $_englishLocaleId',
      );
    } catch (e) {
      debugPrint('Locale selection error: $e');
      _selectedLocaleId = '';
    }
  }

  String _localeForCurrentSpeechMode() {
    if (_speechLanguageMode == 'urdu') {
      // Many Pakistani children speak Urdu as Roman Urdu sounds.
      // Android often hears this more accurately through en-PK/en-US than ur-PK,
      // while the backend still returns Urdu text because we send languageMode=urdu.
      return _romanUrduLocaleId ?? _systemLocaleId ?? _englishLocaleId ?? _urduLocaleId ?? '';
    }
    if (_speechLanguageMode == 'english') {
      return _englishLocaleId ?? _systemLocaleId ?? '';
    }
    return _systemLocaleId ?? _romanUrduLocaleId ?? _englishLocaleId ?? '';
  }

  String _micLanguageLabel() {
    if (_speechLanguageMode == 'urdu') return 'Urdu mic';
    if (_speechLanguageMode == 'english') return 'English mic';
    return 'Auto mic';
  }

  void _toggleSpeechLanguageMode() {
    if (_isListening || _isThinking) return;

    setState(() {
      if (_speechLanguageMode == 'urdu') {
        _speechLanguageMode = 'english';
        _bubbleText = 'English mic selected. Now speak in English.';
      } else if (_speechLanguageMode == 'english') {
        _speechLanguageMode = 'auto';
        _bubbleText = 'Auto mic selected. Speak clearly.';
      } else {
        _speechLanguageMode = 'urdu';
        _bubbleText = 'اردو مائیک منتخب ہے، اب اردو میں بولیں۔';
      }
      _selectedLocaleId = _localeForCurrentSpeechMode();
    });
  }

  Future<void> _onSpeechStatusStopped() async {
    if (!mounted) return;
    if (_manualStop) return;
    if (_isThinking) return;
    if (!_isListening) return;
    if (_isSubmittingSpeech) return;

    // Android sometimes sends the final recognized words a little after status=done.
    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;
    if (_manualStop || _isThinking || !_isListening || _isSubmittingSpeech) return;

    final words = _recognizedWords.trim();

    if (words.isNotEmpty) {
      await _submitRecognizedSpeech(words);
      return;
    }

    const fallback = 'مجھے آواز صاف سنائی نہیں دی، مائیک کے قریب آ کر دوبارہ بولیں۔';

    setState(() {
      _isListening = false;
      _bubbleText = fallback;
    });

    await avatarKey.currentState?.playGentle();
  }

  Future<void> _submitRecognizedSpeech(String words) async {
    final cleanWords = words.trim();
    if (cleanWords.isEmpty) return;
    if (_isSubmittingSpeech || _finalResultHandled) return;

    _isSubmittingSpeech = true;
    _finalResultHandled = true;
    _autoSubmitTimer?.cancel();
    _restartTimer?.cancel();

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });

    await _askGeminiAndSpeak(cleanWords);
    _isSubmittingSpeech = false;
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
    _autoSubmitTimer?.cancel();
    _restartTimer?.cancel();

    // Stop avatar/TTS first. Otherwise Android STT may hear Noor's voice instead of the child.
    await avatarKey.currentState?.stopSpeaking();
    await Future.delayed(const Duration(milliseconds: 700));

    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } catch (_) {}

    _selectedLocaleId = _localeForCurrentSpeechMode();

    setState(() {
      _isListening = true;
      _isThinking = false;
      _manualStop = false;
      _finalResultHandled = false;
      _isSubmittingSpeech = false;
      _recognizedWords = '';
      _restartCount = 0;
      _bubbleText = _speechLanguageMode == 'urdu'
          ? 'میں سن رہی ہوں، اردو میں واضح بولیں...'
          : _speechLanguageMode == 'english'
          ? 'I am listening, speak clearly in English...'
          : 'I am listening, speak clearly...';
    });

    await avatarKey.currentState?.playListening();

    await _listenOnce();
  }

  Future<void> _listenOnce() async {
    if (!mounted) return;
    if (!_isListening) return;
    if (_isThinking) return;

    try {
      _autoSubmitTimer?.cancel();

      final localeToUse = _selectedLocaleId.trim().isEmpty ? null : _selectedLocaleId.trim();

      debugPrint('Starting speech listen. mode=$_speechLanguageMode localeId=$localeToUse');

      await _speech.listen(
        localeId: localeToUse,
        // Dictation gives Android more time and usually captures Urdu sentences better.
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 70),
        pauseFor: const Duration(seconds: 8),
        partialResults: true,
        cancelOnError: false,
        onSoundLevelChange: (level) {
          // Keep this for debugging. If it stays near 0, the phone mic/permission is the issue.
          debugPrint('Mic sound level: $level');
        },
        onResult: (result) async {
          final words = result.recognizedWords.trim();

          debugPrint('Speech result: "$words", final: ${result.finalResult}');

          if (words.isNotEmpty) {
            _recognizedWords = words;
            _restartCount = 0;

            // Show live speech-to-text in the top bubble while the child is talking.
            if (mounted && !_isThinking && !_finalResultHandled) {
              setState(() {
                _bubbleText = words;
              });
            }

            // Backup auto-submit: Android may not send finalResult on some phones.
            // Wait longer than before so the child is not cut off.
            _autoSubmitTimer?.cancel();
            _autoSubmitTimer = Timer(const Duration(milliseconds: 6500), () async {
              if (!mounted) return;
              if (_manualStop) return;
              if (!_isListening) return;
              if (_isThinking) return;
              if (_finalResultHandled) return;

              final finalWords = _recognizedWords.trim();
              if (finalWords.isEmpty) return;

              await _submitRecognizedSpeech(finalWords);
            });
          }

          if (result.finalResult &&
              words.isNotEmpty &&
              !_finalResultHandled &&
              !_manualStop) {
            await _submitRecognizedSpeech(words);
          }
        },
      );
    } catch (e) {
      debugPrint('Listen once error: $e');

      if (!mounted) return;
      if (_manualStop) return;

      const fallback = 'مائیک شروع نہیں ہو سکا، فون کی مائیک اجازت چیک کریں۔';

      setState(() {
        _isListening = false;
        _isThinking = false;
        _bubbleText = fallback;
      });

      await avatarKey.currentState?.playGentle();
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
        _bubbleText = question;
      });

      await Future.delayed(const Duration(milliseconds: 180));

      if (!mounted) return;

      setState(() {
        _bubbleText = 'نور جواب سوچ رہی ہے...';
      });

      await avatarKey.currentState?.playThinking();

      final backendLanguageMode = _speechLanguageMode == 'english'
          ? 'english'
          : _speechLanguageMode == 'urdu'
          ? 'urdu'
          : 'auto';

      final avatarTurn = await ApiService.sendToddlerAvatarTurn(
        message: question,
        languageMode: backendLanguageMode,
      );

      final reply = avatarTurn['reply']?.toString() ?? '';
      final ttsLanguage = avatarTurn['ttsLanguage']?.toString() ?? _detectTtsLanguage(reply);
      final avatarAction = avatarTurn['avatarAction']?.toString() ?? 'talk';
      final avatarEmotion = avatarTurn['avatarEmotion']?.toString() ?? 'friendly';

      if (!mounted) return;

      setState(() {
        _bubbleText = reply;
        _isThinking = false;
      });

      _isSubmittingSpeech = false;

      await avatarKey.currentState?.speak(
        reply,
        languageCode: ttsLanguage,
        action: avatarAction,
        emotion: avatarEmotion,
      );

      if (avatarAction == 'celebrate') {
        await avatarKey.currentState?.playHappy();
      } else if (avatarAction == 'gentle') {
        await avatarKey.currentState?.playGentle();
      }

      unawaited(_awardAvatarBadge(question: question, reply: reply));
    } catch (e) {
      debugPrint('Gemini avatar error: $e');

      final errorText = 'سرور سے رابطہ نہیں ہو سکا، دوبارہ کوشش کریں۔';

      if (!mounted) return;

      setState(() {
        _bubbleText = errorText;
        _isThinking = false;
        _isListening = false;
      });

      _isSubmittingSpeech = false;

      await avatarKey.currentState?.speak(errorText, languageCode: 'ur-PK', action: 'gentle');
    }
  }

  Future<void> _awardAvatarBadge({required String question, required String reply}) async {
    try {
      final toddler = await ApiService.getActiveToddler();
      if (toddler == null) return;

      final toddlerId = (toddler['_id'] ?? toddler['id'] ?? '').toString().trim();
      if (toddlerId.isEmpty) return;

      await ApiService.recordToddlerActivityProgress(
        toddlerId: toddlerId,
        activityType: 'avatar',
        title: 'Talked With Noor',
        score: 100,
        total: 1,
        correct: 1,
        completed: 1,
        sourceId: 'avatar_${DateTime.now().millisecondsSinceEpoch}',
        note: 'Answered Noor clearly during avatar practice.',
        metadata: {
          'childSpeech': question,
          'avatarReply': reply,
        },
      );

      final data = await ApiService.awardToddlerBadge(
        toddlerId: toddlerId,
        badgeKey: 'avatar_good_listener',
        source: 'avatar',
        score: 100,
        total: 1,
        correct: 1,
        goalText: 'Talk with Noor and answer clearly.',
        details: {
          'childSpeech': question,
          'avatarReply': reply,
        },
      );

      if (!mounted) return;
      if (data['newlyUnlocked'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New badge unlocked: ${data['badge']?['title'] ?? 'Good Listener'} 🎧"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Badge awarding should never interrupt the avatar conversation.
    }
  }

  Future<void> _stopListening() async {
    _manualStop = true;
    _restartTimer?.cancel();
    _autoSubmitTimer?.cancel();

    try {
      await _speech.stop();
    } catch (_) {}

    final words = _recognizedWords.trim();

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });

    if (words.isNotEmpty && !_finalResultHandled) {
      _manualStop = false;
      await _submitRecognizedSpeech(words);
    } else if (words.isEmpty) {
      const fallback = 'مجھے آواز صاف سنائی نہیں دی، دوبارہ بولیں';

      setState(() {
        _bubbleText = fallback;
      });

      await avatarKey.currentState?.playGentle();
    }
  }

  Future<void> _showTypedQuestionDialog() async {
    final controller = TextEditingController();

    final typedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ask Noor with typing'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Example: What color is an apple? / سیب کا رنگ کیا ہے؟',
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
      _bubbleText = 'نور جواب سوچ رہی ہے...';
    });

    await _askGeminiAndSpeak(typedText.trim());
  }

  String _detectTtsLanguage(String text) {
    final hasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    return hasUrdu ? 'ur-PK' : 'en-US';
  }

  @override
  void dispose() {
    _manualStop = true;
    _restartTimer?.cancel();
    _autoSubmitTimer?.cancel();
    _speech.cancel();
    avatarKey.currentState?.stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6D8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final isNarrow = width < 360;
            final isShort = height < 700;
            final pageWidth = width > 520 ? 520.0 : width;
            final horizontalPadding = isNarrow ? 12.0 : 16.0;
            final contentWidth = (pageWidth - (horizontalPadding * 2)).clamp(292.0, 488.0).toDouble();
            final headerHeight = isShort ? 148.0 : 166.0;
            final avatarHeight = (height * (isShort ? 0.27 : 0.30)).clamp(210.0, 292.0).toDouble();
            final avatarWidth = (contentWidth * (isNarrow ? 0.76 : 0.68)).clamp(230.0, 310.0).toDouble();

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF176),
                    Color(0xFFFFF8DC),
                    Color(0xFFEAF7FF),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height),
                  child: Center(
                    child: SizedBox(
                      width: pageWidth,
                      child: Column(
                        children: [
                          _LightHeader(
                            height: headerHeight,
                            isNarrow: isNarrow,
                            isListening: _isListening,
                            isThinking: _isThinking,
                            onBack: () => Navigator.pop(context),
                            onMockTest: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ToddlerMockTestScreen(),
                                ),
                              );
                            },
                            onBadges: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ToddlerBadgesScreen(),
                                ),
                              );
                            },
                          ),

                          Transform.translate(
                            offset: Offset(0, isShort ? -10 : -14),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              child: _SpeechBubble(
                                text: _bubbleText,
                                maxWidth: contentWidth,
                              ),
                            ),
                          ),

                          SizedBox(height: isShort ? 4 : 10),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            child: _StableAvatarCard(
                              width: contentWidth,
                              avatarWidth: avatarWidth,
                              avatarHeight: avatarHeight,
                              avatarKey: avatarKey,
                            ),
                          ),

                          SizedBox(height: isShort ? 10 : 14),

                          GestureDetector(
                            onTap: _onMicTap,
                            onDoubleTap: _toggleSpeechLanguageMode,
                            onLongPress: _showTypedQuestionDialog,
                            child: Container(
                              height: isNarrow ? 74 : 80,
                              width: isNarrow ? 74 : 80,
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? const Color(0xFFFF6B1A)
                                    : _isThinking
                                    ? const Color(0xFF8B5CF6)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isListening || _isThinking
                                      ? Colors.white
                                      : const Color(0xFFFF6B1A),
                                  width: 4,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isThinking
                                    ? const SizedBox(
                                  height: 30,
                                  width: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                                    : Icon(
                                  _isListening ? Icons.hearing_rounded : Icons.mic_rounded,
                                  color: _isListening ? Colors.white : const Color(0xFFFF6B1A),
                                  size: isNarrow ? 39 : 43,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          GestureDetector(
                            onTap: _toggleSpeechLanguageMode,
                            child: _MicModePill(label: '${_micLanguageLabel()} • tap to switch'),
                          ),

                          SizedBox(height: isShort ? 14 : 18),

                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              0,
                              horizontalPadding,
                              isShort ? 12 : 18,
                            ),
                            child: _BottomNavBar(
                              onGames: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ToddlerGamesScreen(),
                                  ),
                                );
                              },
                              onPuzzles: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ToddlerPuzzleScreen(),
                                  ),
                                );
                              },
                              onStory: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ToddlerStoryTellingScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LightHeader extends StatelessWidget {
  const _LightHeader({
    required this.height,
    required this.isNarrow,
    required this.isListening,
    required this.isThinking,
    required this.onBack,
    required this.onMockTest,
    required this.onBadges,
  });

  final double height;
  final bool isNarrow;
  final bool isListening;
  final bool isThinking;
  final VoidCallback onBack;
  final VoidCallback onMockTest;
  final VoidCallback onBadges;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C3AED),
            Color(0xFFB56EF4),
            Color(0xFFFF83C1),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 14,
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              color: const Color(0xFF24182E),
              iconColor: Colors.white,
              onTap: onBack,
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _StatusPill(
              text: isListening
                  ? 'Listening'
                  : isThinking
                  ? 'Thinking'
                  : 'Noor Ready',
              color: isListening
                  ? const Color(0xFFFF6B1A)
                  : isThinking
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF22C55E),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: isNarrow ? 52 : 56,
            child: Column(
              children: [
                Text(
                  'Learn With Noor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isNarrow ? 18 : 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TopActionButton(
                      icon: Icons.description_rounded,
                      label: 'Mock Test',
                      color: const Color(0xFF3193FF),
                      onTap: onMockTest,
                    ),
                    SizedBox(width: isNarrow ? 14 : 24),
                    _TopActionButton(
                      icon: Icons.emoji_events_rounded,
                      label: 'Badges',
                      color: const Color(0xFFFF8A1E),
                      onTap: onBadges,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StableAvatarCard extends StatelessWidget {
  const _StableAvatarCard({
    required this.width,
    required this.avatarWidth,
    required this.avatarHeight,
    required this.avatarKey,
  });

  final double width;
  final double avatarWidth;
  final double avatarHeight;
  final GlobalKey<AvatarWebViewWidgetState> avatarKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TinyChip(icon: Icons.auto_awesome_rounded, text: 'Speak'),
                const SizedBox(width: 8),
                _TinyChip(icon: Icons.hearing_rounded, text: 'Listen'),
                const SizedBox(width: 8),
                _TinyChip(icon: Icons.star_rounded, text: 'Learn'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: avatarHeight,
              width: avatarWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: ColoredBox(
                  color: const Color(0xFFFFF7E8),
                  child: AvatarWebViewWidget(
                    key: avatarKey,
                    initialMessage: 'السلام علیکم، میں نور ہوں۔',
                  ),
                ),
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
    required this.maxWidth,
  });

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(text);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minHeight: 58,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF9D66D9), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDF7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF4FA3), size: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: isUrdu
                      ? GoogleFonts.notoNaskhArabic(
                    fontSize: 15,
                    height: 1.45,
                    color: const Color(0xFF1F2A2E),
                    fontWeight: FontWeight.w900,
                  )
                      : GoogleFonts.poppins(
                    fontSize: 14.5,
                    height: 1.35,
                    color: const Color(0xFF1F2A2E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -10,
          child: Transform.rotate(
            angle: 0.78,
            child: Container(
              height: 20,
              width: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Color(0xFF9D66D9), width: 2),
                  bottom: BorderSide(color: Color(0xFF9D66D9), width: 2),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 122,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 35,
              width: 35,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2B1D45),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.onGames,
    required this.onPuzzles,
    required this.onStory,
  });

  final VoidCallback onGames;
  final VoidCallback onPuzzles;
  final VoidCallback onStory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BottomItem(
              icon: Icons.sports_esports_rounded,
              label: 'Games',
              color: const Color(0xFF2865F0),
              onTap: onGames,
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: Icons.extension_rounded,
              label: 'Puzzles',
              color: const Color(0xFF21C95B),
              onTap: onPuzzles,
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: Icons.menu_book_rounded,
              label: 'Story Time',
              color: const Color(0xFF8A6D20),
              onTap: onStory,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        width: 38,
        decoration: const BoxDecoration(
          color: Color(0xFF24182E),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF34264B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicModePill extends StatelessWidget {
  const _MicModePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9D66D9), width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language_rounded, size: 15, color: Color(0xFF7144B8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF5D3C84),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFFF8A1E)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF5D3C84),
            ),
          ),
        ],
      ),
    );
  }
}
