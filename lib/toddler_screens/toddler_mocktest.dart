import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/api_service.dart';

class ToddlerMockTestScreen extends StatefulWidget {
  final String? toddlerId;
  final String? toddlerName;
  final bool teacherMode;

  const ToddlerMockTestScreen({
    super.key,
    this.toddlerId,
    this.toddlerName,
    this.teacherMode = false,
  });

  @override
  State<ToddlerMockTestScreen> createState() => _ToddlerMockTestScreenState();
}

class _ToddlerMockTestScreenState extends State<ToddlerMockTestScreen> {
  static const Color bg = Color(0xFFF4FFF6);
  static const Color green = Color(0xFF00F020);
  static const Color greenDark = Color(0xFF19B95C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFE2EFE7);

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _loading = true;
  bool _saving = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _answerHandled = false;
  bool _showResult = false;
  bool _sendingToTeacher = false;

  String _selectedLocaleId = 'ur_PK';
  String _heardText = '';
  String _statusText = 'Tap the mic and say the word';
  String? _resolvedToddlerId;
  String _resolvedToddlerName = 'Child';
  String _role = 'parent';

  int _currentIndex = 0;
  DateTime _startedAt = DateTime.now();
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _answers = [];
  Map<String, dynamic>? _savedResult;

  int _nextMockQuestionCount() => 30 + Random().nextInt(21);

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadTest();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _statusText = 'Microphone permission is required';
      });
      return;
    }

    final available = await _speech.initialize(
      finalTimeout: const Duration(seconds: 3),
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isListening && !_answerHandled) {
          _handleSpokenAnswer(_heardText);
        }
      },
      onError: (_) {
        if (_isListening && !_answerHandled) {
          _handleSpokenAnswer(_heardText);
        }
      },
    );

    if (available) {
      await _pickBestSpeechLocale();
    }

    if (!mounted) return;
    setState(() => _speechReady = available);
  }

  Future<void> _pickBestSpeechLocale() async {
    try {
      final locales = await _speech.locales();
      String norm(String value) => value.toLowerCase().replaceAll('-', '_');

      final urdu = locales.where((l) {
        final id = norm(l.localeId);
        return id == 'ur_pk' || id.startsWith('ur_') || id == 'ur';
      }).toList();

      final english = locales.where((l) {
        final id = norm(l.localeId);
        return id == 'en_us' || id.startsWith('en_') || id == 'en';
      }).toList();

      if (urdu.isNotEmpty) {
        _selectedLocaleId = urdu.first.localeId;
      } else if (english.isNotEmpty) {
        _selectedLocaleId = english.first.localeId;
      } else if (locales.isNotEmpty) {
        _selectedLocaleId = locales.first.localeId;
      }
    } catch (_) {
      _selectedLocaleId = 'ur_PK';
    }
  }

  Future<void> _resolveToddlerTarget() async {
    final directId = widget.toddlerId?.trim() ?? '';
    if (directId.isNotEmpty) {
      _resolvedToddlerId = directId;
      _resolvedToddlerName = (widget.toddlerName?.trim().isNotEmpty ?? false) ? widget.toddlerName!.trim() : 'Child';
      return;
    }

    final me = await ApiService.getMe();
    final user = Map<String, dynamic>.from(me['user'] as Map? ?? {});
    _role = user['role']?.toString() ?? (widget.teacherMode ? 'teacher' : 'parent');

    if (_role == 'teacher' || widget.teacherMode) {
      final targets = await ApiService.getTeacherActivityTargets();
      final students = (targets['students'] as List<dynamic>? ?? []);
      if (students.isEmpty) throw 'No student is linked to your class yet';
      final first = Map<String, dynamic>.from(students.first as Map);
      _resolvedToddlerId = (first['_id'] ?? first['id'] ?? '').toString();
      _resolvedToddlerName = (first['name'] ?? 'Student').toString();
      return;
    }

    final toddlers = await ApiService.getToddlers();
    if (toddlers.isEmpty) throw 'Please add a child first';
    final active = toddlers.cast<Map>().firstWhere(
          (t) => t['isActive'] == true,
      orElse: () => toddlers.first as Map,
    );
    _resolvedToddlerId = (active['_id'] ?? active['id'] ?? '').toString();
    _resolvedToddlerName = (active['name'] ?? 'Child').toString();
  }

  Future<void> _loadTest() async {
    setState(() {
      _loading = true;
      _showResult = false;
      _currentIndex = 0;
      _answers = [];
      _savedResult = null;
      _startedAt = DateTime.now();
      _heardText = '';
      _statusText = 'Generating 30 to 50 AI examples with matching images...';
    });

    try {
      await _resolveToddlerTarget();
      final toddlerId = _resolvedToddlerId;
      if (toddlerId == null || toddlerId.isEmpty) throw 'Toddler not selected';

      final questionCount = _nextMockQuestionCount();
      final data = await ApiService.generateToddlerMockTest(
        toddlerId: toddlerId,
        count: questionCount,
      );
      final raw = data['questions'] as List<dynamic>? ?? [];
      _questions = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (_questions.isEmpty) throw 'No questions generated';
      _statusText = 'Tap the mic and say the word';
    } catch (e) {
      _statusText = 'Could not load mock test: $e';
      _questions = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizeSpeech(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[ًٌٍَُِّْٰـ]'), '')
        .replaceAll(RegExp(r'[اآأإ]'), 'ا')
        .replaceAll(RegExp(r'[يى]'), 'ی')
        .replaceAll(RegExp(r'[ھہ]'), 'ہ')
        .replaceAll(RegExp(r'[^A-Za-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isCorrectAnswer(String spoken, Map<String, dynamic> question) {
    final normalizedSpoken = _normalizeSpeech(spoken);
    if (normalizedSpoken.isEmpty) return false;

    final accepted = <String>{
      (question['wordUrdu'] ?? '').toString(),
      (question['wordEnglish'] ?? '').toString(),
      ...((question['acceptedAnswers'] as List<dynamic>? ?? []).map((e) => e.toString())),
    };

    for (final expected in accepted) {
      if (normalizedSpoken == _normalizeSpeech(expected)) return true;
    }
    return false;
  }

  Future<void> _startListening() async {
    if (_loading || _saving || _showResult || _questions.isEmpty) return;

    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      setState(() => _statusText = 'Microphone permission is required');
      return;
    }

    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        setState(() => _statusText = 'Speech recognition is not available on this device');
        return;
      }
    }

    if (_speech.isListening) await _speech.cancel();

    HapticFeedback.lightImpact();
    setState(() {
      _isListening = true;
      _answerHandled = false;
      _heardText = '';
      _statusText = 'Listening... say the exact word';
    });

    await _speech.listen(
      localeId: _selectedLocaleId,
      listenMode: stt.ListenMode.dictation,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          setState(() => _heardText = words);
        }
        if (result.finalResult && !_answerHandled) {
          _handleSpokenAnswer(words);
        }
      },
    );
  }

  Future<void> _handleSpokenAnswer(String spoken) async {
    if (_answerHandled || _showResult || _questions.isEmpty) return;
    _answerHandled = true;

    if (_speech.isListening) {
      await _speech.stop();
    }

    final question = _questions[_currentIndex];
    final correct = _isCorrectAnswer(spoken, question);

    final answer = {
      ...question,
      'recognizedText': spoken.trim(),
      'isCorrect': correct,
    };

    if (!mounted) return;
    setState(() {
      _isListening = false;
      _answers.add(answer);
      _statusText = correct ? 'Correct!' : 'Wrong answer';
    });

    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex += 1;
        _heardText = '';
        _statusText = 'Tap the mic and say the word';
      });
    } else {
      await _finishTest();
    }
  }

  Future<void> _finishTest() async {
    setState(() {
      _saving = true;
      _showResult = true;
      _statusText = 'Saving result...';
    });

    try {
      final toddlerId = _resolvedToddlerId;
      if (toddlerId == null || toddlerId.isEmpty) throw 'Toddler not selected';

      final data = await ApiService.submitToddlerMockTestResult(
        toddlerId: toddlerId,
        answers: _answers,
        startedAt: _startedAt,
      );
      _savedResult = Map<String, dynamic>.from(data['result'] as Map);
    } catch (_) {
      final correct = _answers.where((a) => a['isCorrect'] == true).length;
      _savedResult = {
        'toddlerName': _resolvedToddlerName,
        'totalQuestions': _answers.length,
        'correctCount': correct,
        'percentage': _answers.isEmpty ? 0 : ((correct / _answers.length) * 100).round(),
        'needsPractice': _answers
            .where((a) => a['isCorrect'] != true)
            .map((a) => {
          'wordUrdu': a['wordUrdu'],
          'wordEnglish': a['wordEnglish'],
          'imageKey': a['imageKey'],
          'imageUrl': a['imageUrl'],
          'imageEmoji': a['imageEmoji'],
          'recognizedText': a['recognizedText'],
        })
            .toList(),
      };
    }

    await _awardMockTestBadgeIfGood();

    if (mounted) setState(() => _saving = false);
  }

  Future<void> _awardMockTestBadgeIfGood() async {
    final toddlerId = _resolvedToddlerId?.trim() ?? '';
    if (toddlerId.isEmpty || _savedResult == null) return;

    final percentage = _toInt(_savedResult?['percentage']);
    final total = _toInt(_savedResult?['totalQuestions']);
    final correct = _toInt(_savedResult?['correctCount']);
    if (percentage < 70) return;

    try {
      final data = await ApiService.awardToddlerBadge(
        toddlerId: toddlerId,
        badgeKey: 'mock_test_trophy',
        source: 'mock_test',
        score: percentage,
        total: total,
        correct: correct,
        goalText: 'Score 70% or more in a mock test.',
        details: {
          'resultId': (_savedResult?['_id'] ?? _savedResult?['id'] ?? '').toString(),
        },
      );

      if (!mounted) return;
      if (data['newlyUnlocked'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New badge unlocked: ${data['badge']?['title'] ?? 'Mock Test Trophy'} 🏆"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Do not block the result screen if badge saving fails.
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _sendReportToTeacher() async {
    final resultId = (_savedResult?['_id'] ?? _savedResult?['id'] ?? '').toString();
    if (resultId.isEmpty) return;

    setState(() => _sendingToTeacher = true);
    try {
      final data = await ApiService.sendMockTestReportToTeacher(resultId: resultId);
      final updated = Map<String, dynamic>.from(data['result'] as Map? ?? {});
      if (updated.isNotEmpty) _savedResult = updated;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to teacher')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send report: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingToTeacher = false);
    }
  }

  Map<String, dynamic> get _currentQuestion => _questions[_currentIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: greenDark))
            : _showResult
            ? _buildResultView()
            : _buildTestView(),
      ),
    );
  }

  Widget _buildTestView() {
    if (_questions.isEmpty) {
      return _SimpleState(
        icon: Icons.error_outline_rounded,
        title: 'Mock test unavailable',
        message: _statusText,
        buttonText: 'Try Again',
        onPressed: _loadTest,
      );
    }

    final q = _currentQuestion;
    final progress = (_currentIndex + 1) / _questions.length;
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch((q['wordUrdu'] ?? '').toString());
    final feedbackMode = _statusText == 'Correct!'
        ? 'correct'
        : _statusText == 'Wrong answer'
        ? 'wrong'
        : '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded, color: dark),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${widget.teacherMode ? 'Teacher Mock Test' : 'Weekly Mock Quiz'} • Q${_currentIndex + 1}/${_questions.length}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFDCEBE1),
                        color: greenDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 1.12,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutBack,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) => ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(opacity: animation, child: child),
                                ),
                                child: _MockWordVisual(
                                  key: ValueKey((q['questionId'] ?? q['imageKey'] ?? _currentIndex).toString()),
                                  question: q,
                                  feedback: feedbackMode,
                                  onSpeakHint: () {
                                    HapticFeedback.selectionClick();
                                    final word = (q['wordEnglish'] ?? q['wordUrdu'] ?? '').toString();
                                    if (!mounted) return;
                                    setState(() => _statusText = 'Say "$word" clearly');
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              const _InfoPill(icon: Icons.auto_awesome_rounded, text: 'AI Generated'),
                              _InfoPill(
                                icon: Icons.category_rounded,
                                text: (q['category'] ?? 'Learning').toString(),
                              ),
                              const _InfoPill(icon: Icons.verified_rounded, text: 'Exact image'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              (q['wordUrdu'] ?? '').toString(),
                              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoNaskhArabic(
                                fontSize: 42,
                                height: 1.1,
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (q['wordEnglish'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _startListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: _isListening ? greenDark : green,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: greenDark.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.hearing_rounded : Icons.mic_rounded,
                          color: Colors.black,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _statusText == 'Correct!'
                            ? greenDark
                            : _statusText == 'Wrong answer'
                            ? Colors.redAccent
                            : grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_heardText.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Heard: $_heardText',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: dark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final result = _savedResult ?? {};
    final total = NumberHelper.toInt(result['totalQuestions']);
    final correct = NumberHelper.toInt(result['correctCount']);
    final percentage = NumberHelper.toInt(result['percentage']);
    final needsPractice = (result['needsPractice'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final sentToTeacher = result['sentToTeacher'] == true;
    final sentToParent = result['sentToParent'] == true || widget.teacherMode;
    final teacherCreated = (result['createdByRole'] ?? '').toString() == 'teacher' || widget.teacherMode;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.arrow_back_rounded, color: dark),
                  ),
                  const Expanded(
                    child: Text(
                      'Mock Test Result',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: dark, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadTest,
                    icon: const Icon(Icons.refresh_rounded, color: dark),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: Column(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 42)),
                    const SizedBox(height: 6),
                    const Text(
                      'Great Job!',
                      style: TextStyle(color: dark, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      teacherCreated
                          ? 'The mock test report has been sent to the parent.'
                          : 'You have completed the AI mock test.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TOTAL SCORE', style: TextStyle(color: Color(0xFF9AA6AC), fontSize: 11, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text('$percentage%', style: const TextStyle(color: dark, fontSize: 32, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('$correct/$total Correct', style: const TextStyle(color: greenDark, fontSize: 12.5, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(color: greenDark, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text('Needs Practice', style: TextStyle(color: dark, fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFFFE5E8), borderRadius: BorderRadius.circular(8)),
                    child: Text('${needsPractice.length} items', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (needsPractice.isEmpty)
                _PracticeTile(
                  title: 'Excellent',
                  subtitle: 'All answers were clear.',
                  imageKey: 'book',
                  imageUrl: '',
                  retryText: 'Done',
                  onRetry: () => Navigator.pop(context, true),
                )
              else
                ...needsPractice.map(
                      (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PracticeTile(
                      title: (item['wordEnglish'] ?? item['wordUrdu'] ?? 'Word').toString(),
                      subtitle: 'Said: ${(item['recognizedText'] ?? 'Not clear').toString()}',
                      imageKey: (item['imageKey'] ?? '').toString(),
                      imageUrl: (item['imageUrl'] ?? '').toString(),
                      retryText: 'Retry',
                      onRetry: _loadTest,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (!teacherCreated)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sentToTeacher || _sendingToTeacher ? null : _sendReportToTeacher,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFFE8FFF2),
                      disabledForegroundColor: greenDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _sendingToTeacher
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(sentToTeacher ? Icons.done_all_rounded : Icons.send_rounded),
                    label: Text(
                      sentToTeacher ? 'Report Sent to Teacher' : 'Send Report to Teacher',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              if (teacherCreated && sentToParent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8FFF2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Text(
                    'This report is now visible to the parent in Teacher Assigned Activities.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: greenDark, fontWeight: FontWeight.w900, fontSize: 12.5),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dark,
                    side: const BorderSide(color: border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text('SESSION ID: 4TWA-2025-89', style: TextStyle(color: Color(0xFFB3C4BA), fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FFF2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF19B95C)),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF19B95C),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockVisualData {
  final String key;
  final String emoji;
  final String imageUrl;
  final Color bg1;
  final Color bg2;

  const _MockVisualData({
    required this.key,
    required this.emoji,
    required this.imageUrl,
    required this.bg1,
    required this.bg2,
  });
}

String _normalizeMockKey(String value) => value.toLowerCase().trim();

String _resolveMockImageKey({String imageKey = '', String wordEnglish = '', String wordUrdu = ''}) {
  final key = _normalizeMockKey(imageKey);
  if (_mockVisuals.containsKey(key)) return key;

  final en = _normalizeMockKey(wordEnglish);
  final ur = wordUrdu.trim();
  final byEnglish = <String, String>{
    "cat": "cat",
    "dog": "dog",
    "frog": "frog",
    "fish": "fish",
    "bird": "bird",
    "rabbit": "rabbit",
    "lion": "lion",
    "cow": "cow",
    "goat": "goat",
    "sheep": "sheep",
    "horse": "horse",
    "duck": "duck",
    "chicken": "chicken",
    "butterfly": "butterfly",
    "bee": "bee",
    "apple": "apple",
    "banana": "banana",
    "orange": "orange",
    "mango": "mango",
    "grapes": "grapes",
    "watermelon": "watermelon",
    "strawberry": "strawberry",
    "carrot": "carrot",
    "tomato": "tomato",
    "bread": "bread",
    "milk": "milk",
    "water": "water",
    "egg": "egg",
    "rice": "rice",
    "cake": "cake",
    "ball": "ball",
    "book": "book",
    "car": "car",
    "bus": "bus",
    "train": "train",
    "bike": "bike",
    "house": "house",
    "school": "school",
    "pencil": "pencil",
    "bag": "bag",
    "chair": "chair",
    "bed": "bed",
    "clock": "clock",
    "sun": "sun",
    "moon": "moon",
    "star": "star",
    "cloud": "cloud",
    "rainbow": "rainbow",
    "flower": "flower",
    "tree": "tree",
  };
  if (byEnglish.containsKey(en)) return byEnglish[en]!;

  final byUrdu = <String, String>{
    "بلی": "cat",
    "کتا": "dog",
    "مینڈک": "frog",
    "مچھلی": "fish",
    "پرندہ": "bird",
    "خرگوش": "rabbit",
    "شیر": "lion",
    "گائے": "cow",
    "بکری": "goat",
    "بھیڑ": "sheep",
    "گھوڑا": "horse",
    "بطخ": "duck",
    "مرغی": "chicken",
    "تتلی": "butterfly",
    "مکھی": "bee",
    "سیب": "apple",
    "کیلا": "banana",
    "مالٹا": "orange",
    "آم": "mango",
    "انگور": "grapes",
    "تربوز": "watermelon",
    "اسٹرابیری": "strawberry",
    "گاجر": "carrot",
    "ٹماٹر": "tomato",
    "ڈبل روٹی": "bread",
    "دودھ": "milk",
    "پانی": "water",
    "انڈا": "egg",
    "چاول": "rice",
    "کیک": "cake",
    "گیند": "ball",
    "کتاب": "book",
    "گاڑی": "car",
    "بس": "bus",
    "ریل گاڑی": "train",
    "سائیکل": "bike",
    "گھر": "house",
    "اسکول": "school",
    "پنسل": "pencil",
    "بیگ": "bag",
    "کرسی": "chair",
    "بستر": "bed",
    "گھڑی": "clock",
    "سورج": "sun",
    "چاند": "moon",
    "ستارہ": "star",
    "بادل": "cloud",
    "قوس قزح": "rainbow",
    "پھول": "flower",
    "درخت": "tree",
  };
  return byUrdu[ur] ?? 'book';
}

const Map<String, _MockVisualData> _mockVisuals = {
  "cat": _MockVisualData(
    key: "cat",
    emoji: "🐱",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f431.png",
    bg1: Color(0xFFFFF3D9),
    bg2: Color(0xFFFFD6A5),
  ),
  "dog": _MockVisualData(
    key: "dog",
    emoji: "🐶",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f436.png",
    bg1: Color(0xFFFFF1E6),
    bg2: Color(0xFFFFC7A8),
  ),
  "frog": _MockVisualData(
    key: "frog",
    emoji: "🐸",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f438.png",
    bg1: Color(0xFFE8FFF2),
    bg2: Color(0xFFB8F7CF),
  ),
  "fish": _MockVisualData(
    key: "fish",
    emoji: "🐟",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f41f.png",
    bg1: Color(0xFFE7FAFF),
    bg2: Color(0xFFB8F0FF),
  ),
  "bird": _MockVisualData(
    key: "bird",
    emoji: "🐦",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f426.png",
    bg1: Color(0xFFEAF2FF),
    bg2: Color(0xFFBFD6FF),
  ),
  "rabbit": _MockVisualData(
    key: "rabbit",
    emoji: "🐰",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f430.png",
    bg1: Color(0xFFFFF0F6),
    bg2: Color(0xFFFFCFE2),
  ),
  "lion": _MockVisualData(
    key: "lion",
    emoji: "🦁",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f981.png",
    bg1: Color(0xFFFFECEF),
    bg2: Color(0xFFFFB3BF),
  ),
  "cow": _MockVisualData(
    key: "cow",
    emoji: "🐮",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f42e.png",
    bg1: Color(0xFFFFF9DB),
    bg2: Color(0xFFFFE58A),
  ),
  "goat": _MockVisualData(
    key: "goat",
    emoji: "🐐",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f410.png",
    bg1: Color(0xFFF0ECFF),
    bg2: Color(0xFFD4C8FF),
  ),
  "sheep": _MockVisualData(
    key: "sheep",
    emoji: "🐑",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f411.png",
    bg1: Color(0xFFE8F5E9),
    bg2: Color(0xFFC8E6C9),
  ),
  "horse": _MockVisualData(
    key: "horse",
    emoji: "🐴",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f434.png",
    bg1: Color(0xFFFFF4C2),
    bg2: Color(0xFFFFD66B),
  ),
  "duck": _MockVisualData(
    key: "duck",
    emoji: "🦆",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f986.png",
    bg1: Color(0xFFEAEAFF),
    bg2: Color(0xFFC8C7FF),
  ),
  "chicken": _MockVisualData(
    key: "chicken",
    emoji: "🐔",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f414.png",
    bg1: Color(0xFFE6F0FF),
    bg2: Color(0xFFC9DCFF),
  ),
  "butterfly": _MockVisualData(
    key: "butterfly",
    emoji: "🦋",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f98b.png",
    bg1: Color(0xFFFFECEF),
    bg2: Color(0xFFFFC8D0),
  ),
  "bee": _MockVisualData(
    key: "bee",
    emoji: "🐝",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f41d.png",
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFE6F0FF),
  ),
  "apple": _MockVisualData(
    key: "apple",
    emoji: "🍎",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f34e.png",
    bg1: Color(0xFFFFF3D9),
    bg2: Color(0xFFFFD6A5),
  ),
  "banana": _MockVisualData(
    key: "banana",
    emoji: "🍌",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f34c.png",
    bg1: Color(0xFFFFF1E6),
    bg2: Color(0xFFFFC7A8),
  ),
  "orange": _MockVisualData(
    key: "orange",
    emoji: "🍊",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f34a.png",
    bg1: Color(0xFFE8FFF2),
    bg2: Color(0xFFB8F7CF),
  ),
  "mango": _MockVisualData(
    key: "mango",
    emoji: "🥭",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f96d.png",
    bg1: Color(0xFFE7FAFF),
    bg2: Color(0xFFB8F0FF),
  ),
  "grapes": _MockVisualData(
    key: "grapes",
    emoji: "🍇",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f347.png",
    bg1: Color(0xFFEAF2FF),
    bg2: Color(0xFFBFD6FF),
  ),
  "watermelon": _MockVisualData(
    key: "watermelon",
    emoji: "🍉",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f349.png",
    bg1: Color(0xFFFFF0F6),
    bg2: Color(0xFFFFCFE2),
  ),
  "strawberry": _MockVisualData(
    key: "strawberry",
    emoji: "🍓",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f353.png",
    bg1: Color(0xFFFFECEF),
    bg2: Color(0xFFFFB3BF),
  ),
  "carrot": _MockVisualData(
    key: "carrot",
    emoji: "🥕",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f955.png",
    bg1: Color(0xFFFFF9DB),
    bg2: Color(0xFFFFE58A),
  ),
  "tomato": _MockVisualData(
    key: "tomato",
    emoji: "🍅",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f345.png",
    bg1: Color(0xFFF0ECFF),
    bg2: Color(0xFFD4C8FF),
  ),
  "bread": _MockVisualData(
    key: "bread",
    emoji: "🍞",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f35e.png",
    bg1: Color(0xFFE8F5E9),
    bg2: Color(0xFFC8E6C9),
  ),
  "milk": _MockVisualData(
    key: "milk",
    emoji: "🥛",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f95b.png",
    bg1: Color(0xFFFFF4C2),
    bg2: Color(0xFFFFD66B),
  ),
  "water": _MockVisualData(
    key: "water",
    emoji: "💧",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4a7.png",
    bg1: Color(0xFFEAEAFF),
    bg2: Color(0xFFC8C7FF),
  ),
  "egg": _MockVisualData(
    key: "egg",
    emoji: "🥚",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f95a.png",
    bg1: Color(0xFFE6F0FF),
    bg2: Color(0xFFC9DCFF),
  ),
  "rice": _MockVisualData(
    key: "rice",
    emoji: "🍚",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f35a.png",
    bg1: Color(0xFFFFECEF),
    bg2: Color(0xFFFFC8D0),
  ),
  "cake": _MockVisualData(
    key: "cake",
    emoji: "🍰",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f370.png",
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFE6F0FF),
  ),
  "ball": _MockVisualData(
    key: "ball",
    emoji: "⚽",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/26bd.png",
    bg1: Color(0xFFFFF3D9),
    bg2: Color(0xFFFFD6A5),
  ),
  "book": _MockVisualData(
    key: "book",
    emoji: "📖",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4d6.png",
    bg1: Color(0xFFFFF1E6),
    bg2: Color(0xFFFFC7A8),
  ),
  "car": _MockVisualData(
    key: "car",
    emoji: "🚗",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f697.png",
    bg1: Color(0xFFE8FFF2),
    bg2: Color(0xFFB8F7CF),
  ),
  "bus": _MockVisualData(
    key: "bus",
    emoji: "🚌",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f68c.png",
    bg1: Color(0xFFE7FAFF),
    bg2: Color(0xFFB8F0FF),
  ),
  "train": _MockVisualData(
    key: "train",
    emoji: "🚆",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f686.png",
    bg1: Color(0xFFEAF2FF),
    bg2: Color(0xFFBFD6FF),
  ),
  "bike": _MockVisualData(
    key: "bike",
    emoji: "🚲",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f6b2.png",
    bg1: Color(0xFFFFF0F6),
    bg2: Color(0xFFFFCFE2),
  ),
  "house": _MockVisualData(
    key: "house",
    emoji: "🏠",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f3e0.png",
    bg1: Color(0xFFFFECEF),
    bg2: Color(0xFFFFB3BF),
  ),
  "school": _MockVisualData(
    key: "school",
    emoji: "🏫",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f3eb.png",
    bg1: Color(0xFFFFF9DB),
    bg2: Color(0xFFFFE58A),
  ),
  "pencil": _MockVisualData(
    key: "pencil",
    emoji: "✏️",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/270f.png",
    bg1: Color(0xFFF0ECFF),
    bg2: Color(0xFFD4C8FF),
  ),
  "bag": _MockVisualData(
    key: "bag",
    emoji: "🎒",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f392.png",
    bg1: Color(0xFFE8F5E9),
    bg2: Color(0xFFC8E6C9),
  ),
  "chair": _MockVisualData(
    key: "chair",
    emoji: "🪑",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1fa91.png",
    bg1: Color(0xFFFFF4C2),
    bg2: Color(0xFFFFD66B),
  ),
  "bed": _MockVisualData(
    key: "bed",
    emoji: "🛏️",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f6cf.png",
    bg1: Color(0xFFEAEAFF),
    bg2: Color(0xFFC8C7FF),
  ),
  "clock": _MockVisualData(
    key: "clock",
    emoji: "⏰",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/23f0.png",
    bg1: Color(0xFFE6F0FF),
    bg2: Color(0xFFC9DCFF),
  ),
  "sun": _MockVisualData(
    key: "sun",
    emoji: "☀️",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2600.png",
    bg1: Color(0xFFFFECEF),
    bg2: Color(0xFFFFC8D0),
  ),
  "moon": _MockVisualData(
    key: "moon",
    emoji: "🌙",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f319.png",
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFE6F0FF),
  ),
  "star": _MockVisualData(
    key: "star",
    emoji: "⭐",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2b50.png",
    bg1: Color(0xFFFFF3D9),
    bg2: Color(0xFFFFD6A5),
  ),
  "cloud": _MockVisualData(
    key: "cloud",
    emoji: "☁️",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2601.png",
    bg1: Color(0xFFFFF1E6),
    bg2: Color(0xFFFFC7A8),
  ),
  "rainbow": _MockVisualData(
    key: "rainbow",
    emoji: "🌈",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f308.png",
    bg1: Color(0xFFE8FFF2),
    bg2: Color(0xFFB8F7CF),
  ),
  "flower": _MockVisualData(
    key: "flower",
    emoji: "🌼",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f33c.png",
    bg1: Color(0xFFE7FAFF),
    bg2: Color(0xFFB8F0FF),
  ),
  "tree": _MockVisualData(
    key: "tree",
    emoji: "🌳",
    imageUrl: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f333.png",
    bg1: Color(0xFFEAF2FF),
    bg2: Color(0xFFBFD6FF),
  ),
};

class _MockWordVisual extends StatelessWidget {
  final Map<String, dynamic> question;
  final String feedback;
  final VoidCallback onSpeakHint;

  const _MockWordVisual({
    super.key,
    required this.question,
    required this.feedback,
    required this.onSpeakHint,
  });

  @override
  Widget build(BuildContext context) {
    final keyName = _resolveMockImageKey(
      imageKey: (question['imageKey'] ?? '').toString(),
      wordEnglish: (question['wordEnglish'] ?? '').toString(),
      wordUrdu: (question['wordUrdu'] ?? '').toString(),
    );
    final data = _mockVisuals[keyName] ?? _mockVisuals['book']!;
    final serverImageUrl = (question['imageUrl'] ?? '').toString().trim();
    final resolvedImageUrl = _mockVisuals.containsKey(keyName) ? data.imageUrl : (serverImageUrl.isNotEmpty ? serverImageUrl : data.imageUrl);
    final wordEnglish = (question['wordEnglish'] ?? '').toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.biggest.shortestSide * 0.56).clamp(92.0, 190.0).toDouble();
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [data.bg1, data.bg2],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 18,
                left: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    keyName.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF14201A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: size,
                  height: size,
                  padding: EdgeInsets.all(size * 0.12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.86),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.network(
                    resolvedImageUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => FittedBox(
                      fit: BoxFit.contain,
                      child: Text(data.emoji, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onSpeakHint,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(Icons.volume_up_rounded, color: Color(0xFF19B95C)),
                    ),
                  ),
                ),
              ),
              if (feedback.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: feedback == 'correct' ? const Color(0xFF19B95C) : Colors.redAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          feedback == 'correct' ? Icons.check_rounded : Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          feedback == 'correct' ? 'Correct' : 'Try again',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 14,
                right: 14,
                top: 54,
                child: Text(
                  wordEnglish.isEmpty ? 'Say the word' : 'Say: $wordEnglish',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF14201A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniMockWordVisual extends StatelessWidget {
  final String imageKey;
  final String imageUrl;
  final String wordEnglish;

  const _MiniMockWordVisual({
    required this.imageKey,
    required this.imageUrl,
    required this.wordEnglish,
  });

  @override
  Widget build(BuildContext context) {
    final keyName = _resolveMockImageKey(imageKey: imageKey, wordEnglish: wordEnglish);
    final data = _mockVisuals[keyName] ?? _mockVisuals['book']!;
    final resolvedUrl = _mockVisuals.containsKey(keyName) ? data.imageUrl : (imageUrl.isNotEmpty ? imageUrl : data.imageUrl);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [data.bg1, data.bg2]),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Image.network(
        resolvedUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => FittedBox(child: Text(data.emoji)),
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageKey;
  final String imageUrl;
  final String retryText;
  final VoidCallback onRetry;

  const _PracticeTile({
    required this.title,
    required this.subtitle,
    required this.imageKey,
    required this.imageUrl,
    required this.retryText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: _MiniMockWordVisual(
                imageKey: imageKey,
                imageUrl: imageUrl,
                wordEnglish: title,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF14201A), fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFECEF),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(retryText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

class _SimpleState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _SimpleState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF19B95C), size: 52),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF14201A), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27C267),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class NumberHelper {
  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}