import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/api_service.dart';

class ToddlerGamesScreen extends StatefulWidget {
  const ToddlerGamesScreen({super.key});

  @override
  State<ToddlerGamesScreen> createState() => _ToddlerGamesScreenState();
}

class _ToddlerGamesScreenState extends State<ToddlerGamesScreen> {
  static const Color _bgTop = Color(0xFFFFF9FD);
  static const Color _bgBottom = Color(0xFFFFF1DE);
  static const Color _pink = Color(0xFFFF3F91);
  static const Color _dark = Color(0xFF21313A);
  static const Color _muted = Color(0xFF75838C);

  bool _loading = true;
  String _message = 'Generating speech games for today...';
  List<ToddlerSpeechGame> _games = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _loading = true;
      _message = 'Generating speech games for today...';
    });

    try {
      final data = await ApiService.generateToddlerSpeechGames(
        countPerGame: 5,
        languageMode: 'mixed',
      );
      final rawGames = data['games'] as List<dynamic>? ?? [];
      final parsed = rawGames
          .whereType<Map>()
          .map((e) => ToddlerSpeechGame.fromJson(Map<String, dynamic>.from(e)))
          .where((g) => g.items.isNotEmpty)
          .toList();

      if (parsed.length >= 6) {
        _games = parsed.take(6).toList();
        _message = 'Practice speaking with fun AI generated games.';
      } else {
        _games = ToddlerSpeechGame.localGames();
        _message = 'Practice speaking with fun AI generated games.';
      }
    } catch (_) {
      _games = ToddlerSpeechGame.localGames();
      _message = 'Practice speaking with fun AI generated games.';
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _dark,
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.mic_rounded, color: _pink, size: 21),
            const SizedBox(width: 8),
            Text(
              'Speech Practice',
              style: GoogleFonts.poppins(
                color: _pink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: _loading
              ? _LoadingState(message: _message)
              : RefreshIndicator(
            onRefresh: _loadGames,
            color: _pink,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderCard(message: _message),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final gap = constraints.maxWidth < 360 ? 10.0 : 14.0;
                          final columns = constraints.maxWidth < 270 ? 1 : 2;
                          final cardWidth = (constraints.maxWidth - (gap * (columns - 1))) / columns;

                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: _games.map((game) {
                              return SizedBox(
                                width: cardWidth,
                                child: _SpeechGameCard(
                                  game: game,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ToddlerGamePlayScreen(game: game),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, color: _pink, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Practice Makes Perfect!',
                                style: GoogleFonts.poppins(
                                  color: _dark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.mic_rounded, color: _pink, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToddlerGamePlayScreen extends StatefulWidget {
  final ToddlerSpeechGame game;

  const ToddlerGamePlayScreen({super.key, required this.game});

  @override
  State<ToddlerGamePlayScreen> createState() => _ToddlerGamePlayScreenState();
}

class _ToddlerGamePlayScreenState extends State<ToddlerGamePlayScreen> {
  static const Color _dark = Color(0xFF21313A);
  static const Color _muted = Color(0xFF75838C);
  static const Color _green = Color(0xFF00C875);
  static const Color _red = Color(0xFFFF4C6A);

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  bool _answerHandled = false;
  bool _finished = false;
  bool _badgeAwardChecked = false;
  bool _progressSaved = false;

  String _selectedLocaleId = '';
  String _heardText = '';
  String _status = 'Tap the mic and speak clearly.';

  int _index = 0;
  int _correct = 0;
  final List<bool> _results = [];

  Timer? _fallbackTimer;

  ToddlerSpeechItem get _item => widget.game.items[_index];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _status = 'Microphone permission is required.';
      });
      return;
    }

    final ready = await _speech.initialize(
      finalTimeout: const Duration(seconds: 3),
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _listening && !_answerHandled) {
          _finishAnswer();
        }
      },
      onError: (_) {
        if (_listening && !_answerHandled) _finishAnswer();
      },
    );

    if (ready) await _pickBestLocale();
    if (!mounted) return;
    setState(() => _speechReady = ready);
  }

  Future<void> _pickBestLocale() async {
    try {
      final locales = await _speech.locales();
      String norm(String value) => value.toLowerCase().replaceAll('-', '_');

      String? urdu;
      String? englishPk;
      String? english;
      for (final locale in locales) {
        final id = norm(locale.localeId);
        if (urdu == null && (id == 'ur_pk' || id.startsWith('ur_') || id == 'ur')) {
          urdu = locale.localeId;
        }
        if (englishPk == null && (id == 'en_pk' || id == 'en_in')) {
          englishPk = locale.localeId;
        }
        if (english == null && (id == 'en_us' || id.startsWith('en_') || id == 'en')) {
          english = locale.localeId;
        }
      }
      _selectedLocaleId = englishPk ?? english ?? urdu ?? (locales.isNotEmpty ? locales.first.localeId : '');
    } catch (_) {
      _selectedLocaleId = '';
    }
  }

  Future<void> _startListening() async {
    if (_finished || _listening) return;

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      setState(() => _status = 'Microphone permission is required.');
      return;
    }

    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        setState(() => _status = 'Speech recognition is not available on this device.');
        return;
      }
    }

    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}

    HapticFeedback.lightImpact();
    _fallbackTimer?.cancel();

    setState(() {
      _listening = true;
      _answerHandled = false;
      _heardText = '';
      _status = 'Listening... say it now!';
    });

    await _speech.listen(
      localeId: _selectedLocaleId.trim().isEmpty ? null : _selectedLocaleId.trim(),
      listenMode: stt.ListenMode.dictation,
      listenFor: const Duration(seconds: 9),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty && mounted) {
          setState(() => _heardText = words);
        }

        _fallbackTimer?.cancel();
        _fallbackTimer = Timer(const Duration(milliseconds: 1300), () {
          if (_listening && !_answerHandled) _finishAnswer();
        });

        if (result.finalResult && !_answerHandled) _finishAnswer();
      },
    );
  }

  Future<void> _finishAnswer() async {
    if (_answerHandled) return;
    _answerHandled = true;
    _fallbackTimer?.cancel();

    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}

    final heard = _heardText.trim();
    final correct = _isCorrect(heard, _item);

    if (!mounted) return;
    setState(() {
      _listening = false;
      _results.add(correct);
      if (correct) _correct += 1;
      _status = heard.isEmpty
          ? 'I could not hear you. Try the next one.'
          : correct
          ? 'Correct! Great speaking!'
          : 'Good try! Say it again later.';
    });

    await Future.delayed(Duration(milliseconds: correct ? 850 : 1250));
    if (!mounted) return;
    _goNext();
  }

  void _goNext() {
    if (_index + 1 >= widget.game.items.length) {
      setState(() {
        _finished = true;
        _status = 'Game complete!';
      });
      unawaited(_saveGameProgress());
      unawaited(_awardBadgeIfGoodProgress());
      return;
    }

    setState(() {
      _index += 1;
      _heardText = '';
      _answerHandled = false;
      _status = 'Tap the mic and speak clearly.';
    });
  }

  Future<void> _saveGameProgress() async {
    if (_progressSaved) return;
    _progressSaved = true;

    final total = widget.game.items.length;
    final percent = total == 0 ? 0 : ((_correct / total) * 100).round();

    try {
      final toddler = await ApiService.getActiveToddler();
      if (toddler == null) return;

      final toddlerId = (toddler['_id'] ?? toddler['id'] ?? '').toString().trim();
      if (toddlerId.isEmpty) return;

      await ApiService.recordToddlerActivityProgress(
        toddlerId: toddlerId,
        activityType: 'games',
        title: '${widget.game.title} Completed',
        score: percent,
        total: total,
        correct: _correct,
        completed: total,
        sourceId: 'game_${widget.game.key}_${DateTime.now().millisecondsSinceEpoch}',
        note: 'Completed ${widget.game.title} with $percent% score.',
        metadata: {
          'gameKey': widget.game.key,
          'gameTitle': widget.game.title,
          'results': _results,
        },
      );
    } catch (_) {
      // Progress saving must never block the game screen.
    }
  }

  Future<void> _awardBadgeIfGoodProgress() async {
    if (_badgeAwardChecked) return;
    _badgeAwardChecked = true;

    final total = widget.game.items.length;
    final percent = total == 0 ? 0 : ((_correct / total) * 100).round();
    if (percent < 70) return;

    try {
      final toddler = await ApiService.getActiveToddler();
      if (toddler == null) return;

      final toddlerId = (toddler['_id'] ?? toddler['id'] ?? '').toString().trim();
      if (toddlerId.isEmpty) return;

      final data = await ApiService.awardToddlerBadge(
        toddlerId: toddlerId,
        badgeKey: 'games_speaker_star',
        source: 'speech_games',
        score: percent,
        total: total,
        correct: _correct,
        goalText: 'Score 70% or more in Speech Games.',
        details: {
          'gameKey': widget.game.key,
          'gameTitle': widget.game.title,
        },
      );

      if (!mounted) return;
      if (data['newlyUnlocked'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New badge unlocked: ${data['badge']?['title'] ?? 'Speaker Star'} ⭐"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Keep the game result screen working even if badges cannot be saved.
    }
  }

  void _retryCurrent() {
    if (_listening) return;
    setState(() {
      _heardText = '';
      _answerHandled = false;
      _status = 'Tap the mic and speak clearly.';
    });
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

  bool _isCorrect(String spoken, ToddlerSpeechItem item) {
    final cleanSpoken = _normalizeSpeech(spoken);
    if (cleanSpoken.isEmpty) return false;

    for (final accepted in item.acceptedAnswers) {
      final cleanExpected = _normalizeSpeech(accepted);
      if (cleanExpected.isEmpty) continue;
      if (cleanSpoken == cleanExpected) return true;
      if (cleanExpected.length > 2 && cleanSpoken.contains(cleanExpected)) return true;
      if (cleanSpoken.length > 2 && cleanExpected.contains(cleanSpoken)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lighten(widget.game.color, 0.88),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _dark,
        titleSpacing: 0,
        title: Row(
          children: [
            Icon(widget.game.icon, color: widget.game.color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.game.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: widget.game.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _finished ? _buildResultView() : _buildGameView(),
      ),
    );
  }

  Widget _buildGameView() {
    final progress = (_index + 1) / widget.game.items.length;
    final item = _item;
    final hasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(item.displayText + item.subText + item.prompt);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Question ${_index + 1}/${widget.game.items.length}',
                    style: GoogleFonts.poppins(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _DifficultyChip(text: widget.game.level, color: widget.game.color),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress,
                  backgroundColor: Colors.white,
                  color: widget.game.color,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      decoration: BoxDecoration(
                        color: widget.game.color,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: widget.game.color.withOpacity(0.26),
                            blurRadius: 22,
                            offset: const Offset(0, 13),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 96,
                            width: 96,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.24),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Center(
                              child: Text(
                                item.emoji,
                                style: const TextStyle(fontSize: 50),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            item.prompt,
                            textDirection: hasUrdu ? TextDirection.rtl : TextDirection.ltr,
                            textAlign: TextAlign.center,
                            style: hasUrdu
                                ? GoogleFonts.notoNaskhArabic(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.45,
                              fontWeight: FontWeight.w900,
                            )
                                : GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    item.displayText,
                                    textAlign: TextAlign.center,
                                    textDirection: hasUrdu ? TextDirection.rtl : TextDirection.ltr,
                                    style: hasUrdu
                                        ? GoogleFonts.notoNaskhArabic(
                                      color: Colors.white,
                                      fontSize: 45,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                    )
                                        : GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 42,
                                      height: 1.05,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (item.subText.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.subText,
                                    textAlign: TextAlign.center,
                                    textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(item.subText)
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.90),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SmallActionButton(
                          icon: Icons.refresh_rounded,
                          label: 'Retry',
                          onTap: _retryCurrent,
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: _startListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 82,
                            width: 82,
                            decoration: BoxDecoration(
                              color: _listening ? widget.game.color : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: widget.game.color, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.game.color.withOpacity(_listening ? 0.36 : 0.20),
                                  blurRadius: _listening ? 24 : 16,
                                  spreadRadius: _listening ? 3 : 0,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              _listening ? Icons.hearing_rounded : Icons.mic_rounded,
                              color: _listening ? Colors.white : widget.game.color,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        _SmallActionButton(
                          icon: Icons.skip_next_rounded,
                          label: 'Next',
                          onTap: _goNext,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: _status.startsWith('Correct')
                            ? _green
                            : _status.startsWith('Good') || _status.startsWith('I could')
                            ? _red
                            : _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_heardText.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Heard: $_heardText',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: _dark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                    _HintBox(text: item.hint),
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
    final total = widget.game.items.length;
    final percent = total == 0 ? 0 : ((_correct / total) * 100).round();

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 25,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    color: widget.game.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      percent >= 70 ? '🏆' : '⭐',
                      style: const TextStyle(fontSize: 50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Great Practice!',
                  style: GoogleFonts.poppins(
                    color: _dark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score $_correct/$total • $percent%',
                  style: GoogleFonts.poppins(
                    color: widget.game.color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(total, (i) {
                    final ok = i < _results.length && _results[i];
                    return Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: ok ? _green.withOpacity(0.16) : _red.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ok ? Icons.check_rounded : Icons.close_rounded,
                        color: ok ? _green : _red,
                        size: 19,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _index = 0;
                            _correct = 0;
                            _results.clear();
                            _finished = false;
                            _badgeAwardChecked = false;
                            _progressSaved = false;
                            _heardText = '';
                            _status = 'Tap the mic and speak clearly.';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.game.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Play Again'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.game.color,
                          side: BorderSide(color: widget.game.color, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.apps_rounded),
                        label: const Text('All Games'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToddlerSpeechGame {
  final String key;
  final String title;
  final String subtitle;
  final String description;
  final String level;
  final String emoji;
  final Color color;
  final List<ToddlerSpeechItem> items;

  ToddlerSpeechGame({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.level,
    required this.emoji,
    required this.color,
    required this.items,
  });

  IconData get icon {
    switch (key) {
      case 'repeat_word':
        return Icons.mic_rounded;
      case 'animal_sounds':
        return Icons.volume_up_rounded;
      case 'letter_sounds':
        return Icons.chat_bubble_outline_rounded;
      case 'rhyme_time':
        return Icons.music_note_rounded;
      case 'sound_match':
        return Icons.headphones_rounded;
      case 'silly_sentences':
        return Icons.sentiment_satisfied_alt_rounded;
      default:
        return Icons.sports_esports_rounded;
    }
  }

  factory ToddlerSpeechGame.fromJson(Map<String, dynamic> json) {
    final key = (json['key'] ?? json['gameType'] ?? '').toString().trim();
    final fallback = _localByKey(key);
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .whereType<Map>()
        .map((e) => ToddlerSpeechItem.fromJson(Map<String, dynamic>.from(e), key))
        .where((i) => i.displayText.trim().isNotEmpty)
        .toList();

    return ToddlerSpeechGame(
      key: key.isNotEmpty ? key : fallback.key,
      title: (json['title'] ?? fallback.title).toString(),
      subtitle: (json['subtitle'] ?? fallback.subtitle).toString(),
      description: (json['description'] ?? fallback.description).toString(),
      level: (json['level'] ?? fallback.level).toString(),
      emoji: (json['emoji'] ?? fallback.emoji).toString(),
      color: _colorFromHex((json['colorHex'] ?? '').toString(), fallback.color),
      items: parsedItems.isNotEmpty ? parsedItems : fallback.items,
    );
  }

  static ToddlerSpeechGame _localByKey(String key) {
    return localGames().firstWhere(
          (g) => g.key == key,
      orElse: () => localGames().first,
    );
  }

  static List<ToddlerSpeechGame> localGames() {
    return [
      ToddlerSpeechGame(
        key: 'repeat_word',
        title: 'Repeat the Word',
        subtitle: 'Say clear words',
        description: 'The toddler repeats Urdu and English words to improve pronunciation.',
        level: 'Easy',
        emoji: '🎙️',
        color: const Color(0xFFFF3F91),
        items: [
          ToddlerSpeechItem.word('🐱', 'بلی', 'Cat', ['بلی', 'billi', 'cat'], 'Can you say this word?', 'Tap the mic and say: بلی / Cat'),
          ToddlerSpeechItem.word('🐶', 'کتا', 'Dog', ['کتا', 'kutta', 'dog'], 'Can you say this word?', 'Tap the mic and say: کتا / Dog'),
          ToddlerSpeechItem.word('🍎', 'سیب', 'Apple', ['سیب', 'saib', 'seb', 'apple'], 'Can you say this word?', 'Tap the mic and say: سیب / Apple'),
          ToddlerSpeechItem.word('⚽', 'گیند', 'Ball', ['گیند', 'gend', 'ball'], 'Can you say this word?', 'Tap the mic and say: گیند / Ball'),
          ToddlerSpeechItem.word('📖', 'کتاب', 'Book', ['کتاب', 'kitab', 'book'], 'Can you say this word?', 'Tap the mic and say: کتاب / Book'),
        ],
      ),
      ToddlerSpeechGame(
        key: 'animal_sounds',
        title: 'Animal Sounds',
        subtitle: 'Copy fun sounds',
        description: 'The toddler makes animal sounds to practice mouth movement.',
        level: 'Easy',
        emoji: '🐶',
        color: const Color(0xFFFF6922),
        items: [
          ToddlerSpeechItem.sound('🐶', 'Dog', 'WOOF WOOF!', ['woof', 'woof woof', 'bhow', 'bow wow'], 'What sound does it make?', 'Open your mouth and say: woof woof'),
          ToddlerSpeechItem.sound('🐱', 'Cat', 'MEOW MEOW!', ['meow', 'meow meow', 'miyau'], 'What sound does it make?', 'Say it softly: meow'),
          ToddlerSpeechItem.sound('🐮', 'Cow', 'MOO MOO!', ['moo', 'moo moo'], 'What sound does it make?', 'Round your lips and say: moo'),
          ToddlerSpeechItem.sound('🐐', 'Goat', 'MAA MAA!', ['maa', 'maa maa', 'meh'], 'What sound does it make?', 'Say: maa maa'),
          ToddlerSpeechItem.sound('🐦', 'Bird', 'TWEET TWEET!', ['tweet', 'tweet tweet', 'chirp'], 'What sound does it make?', 'Say: tweet tweet'),
        ],
      ),
      ToddlerSpeechGame(
        key: 'letter_sounds',
        title: 'Letter Sounds',
        subtitle: 'Learn first sounds',
        description: 'The toddler practices letter sounds with familiar objects.',
        level: 'Medium',
        emoji: '🔤',
        color: const Color(0xFF5B8CFF),
        items: [
          ToddlerSpeechItem.letter('🍎', 'A', 'Sounds like: AH', ['a', 'ah', 'apple'], 'Learn Letter Sounds!', 'A is for Apple. Say AH.'),
          ToddlerSpeechItem.letter('⚽', 'B', 'Sounds like: BUH', ['b', 'buh', 'ball'], 'Learn Letter Sounds!', 'B is for Ball. Say BUH.'),
          ToddlerSpeechItem.letter('🐱', 'C', 'Sounds like: KUH', ['c', 'kuh', 'cat'], 'Learn Letter Sounds!', 'C is for Cat. Say KUH.'),
          ToddlerSpeechItem.letter('🐶', 'D', 'Sounds like: DUH', ['d', 'duh', 'dog'], 'Learn Letter Sounds!', 'D is for Dog. Say DUH.'),
          ToddlerSpeechItem.letter('🐘', 'E', 'Sounds like: EH', ['e', 'eh', 'elephant'], 'Learn Letter Sounds!', 'E is for Elephant. Say EH.'),
        ],
      ),
      ToddlerSpeechGame(
        key: 'rhyme_time',
        title: 'Rhyme Time',
        subtitle: 'Say rhyming words',
        description: 'The toddler repeats rhyming pairs to improve rhythm and fluency.',
        level: 'Medium',
        emoji: '🎵',
        color: const Color(0xFFD45CE6),
        items: [
          ToddlerSpeechItem.rhyme('🐱🎩', 'CAT', 'CAT rhymes with HAT!', ['cat', 'hat'], 'These words rhyme!', 'Say: cat, hat'),
          ToddlerSpeechItem.rhyme('🐝🌳', 'BEE', 'BEE rhymes with TREE!', ['bee', 'tree'], 'These words rhyme!', 'Say: bee, tree'),
          ToddlerSpeechItem.rhyme('☀️🏃', 'SUN', 'SUN rhymes with RUN!', ['sun', 'run'], 'These words rhyme!', 'Say: sun, run'),
          ToddlerSpeechItem.rhyme('🐶🪵', 'DOG', 'DOG rhymes with LOG!', ['dog', 'log'], 'These words rhyme!', 'Say: dog, log'),
          ToddlerSpeechItem.rhyme('🚗⭐', 'CAR', 'CAR rhymes with STAR!', ['car', 'star'], 'These words rhyme!', 'Say: car, star'),
        ],
      ),
      ToddlerSpeechGame(
        key: 'sound_match',
        title: 'Sound Match',
        subtitle: 'Find target sounds',
        description: 'The toddler finds and says words that start with the same sound.',
        level: 'Medium',
        emoji: '👂',
        color: const Color(0xFF16C9A4),
        items: [
          ToddlerSpeechItem.match('⚽🍌🦋', 'B', 'Ball, Banana, Butterfly', ['b', 'ball', 'banana', 'butterfly'], 'Find words with B sound!', 'Say the B sound: buh'),
          ToddlerSpeechItem.match('☀️⭐🐍', 'S', 'Sun, Star, Snake', ['s', 'sun', 'star', 'snake'], 'Find words with S sound!', 'Say the S sound: sss'),
          ToddlerSpeechItem.match('🐱🚗🍰', 'C', 'Cat, Car, Cake', ['c', 'cat', 'car', 'cake'], 'Find words with C sound!', 'Say the C sound: kuh'),
          ToddlerSpeechItem.match('🐶🦆🚪', 'D', 'Dog, Duck, Door', ['d', 'dog', 'duck', 'door'], 'Find words with D sound!', 'Say the D sound: duh'),
          ToddlerSpeechItem.match('🐟🌸🍟', 'F', 'Fish, Flower, Fries', ['f', 'fish', 'flower', 'fries'], 'Find words with F sound!', 'Say the F sound: fff'),
        ],
      ),
      ToddlerSpeechGame(
        key: 'silly_sentences',
        title: 'Silly Sentences',
        subtitle: 'Speak funny lines',
        description: 'The toddler says short silly sentences to improve fluency.',
        level: 'Hard',
        emoji: '😊',
        color: const Color(0xFFFFA21B),
        items: [
          ToddlerSpeechItem.sentence('🦛🍔', 'The happy hippo eats hamburgers!', ['the happy hippo eats hamburgers', 'happy hippo eats hamburgers'], 'Say This Silly Sentence!', 'Say it slowly word by word.'),
          ToddlerSpeechItem.sentence('🐯🎾', 'A tiny tiger teaches tennis!', ['a tiny tiger teaches tennis', 'tiny tiger teaches tennis'], 'Say This Silly Sentence!', 'Keep your tongue relaxed.'),
          ToddlerSpeechItem.sentence('🐸🧁', 'Five funny frogs find cupcakes!', ['five funny frogs find cupcakes', 'funny frogs find cupcakes'], 'Say This Silly Sentence!', 'Say the F sound clearly.'),
          ToddlerSpeechItem.sentence('🐝🚌', 'Busy bees bounce by buses!', ['busy bees bounce by buses', 'bees bounce by buses'], 'Say This Silly Sentence!', 'Say the B sound clearly.'),
          ToddlerSpeechItem.sentence('🐱🎩', 'Cool cats carry colorful caps!', ['cool cats carry colorful caps', 'cats carry colorful caps'], 'Say This Silly Sentence!', 'Say each word slowly.'),
        ],
      ),
    ];
  }
}

class ToddlerSpeechItem {
  final String emoji;
  final String prompt;
  final String displayText;
  final String subText;
  final String hint;
  final List<String> acceptedAnswers;

  ToddlerSpeechItem({
    required this.emoji,
    required this.prompt,
    required this.displayText,
    required this.subText,
    required this.hint,
    required this.acceptedAnswers,
  });

  factory ToddlerSpeechItem.fromJson(Map<String, dynamic> json, String gameKey) {
    final accepted = <String>[
      ...((json['acceptedAnswers'] as List<dynamic>? ?? []).map((e) => e.toString())),
      (json['targetText'] ?? '').toString(),
      (json['wordEnglish'] ?? '').toString(),
      (json['wordUrdu'] ?? '').toString(),
      (json['sound'] ?? '').toString(),
      (json['letter'] ?? '').toString(),
      (json['sentence'] ?? '').toString(),
    ].where((e) => e.trim().isNotEmpty).toSet().toList();

    final display = (json['displayText'] ??
        json['wordUrdu'] ??
        json['letter'] ??
        json['sentence'] ??
        json['targetText'] ??
        json['wordEnglish'] ??
        '')
        .toString();

    return ToddlerSpeechItem(
      emoji: (json['emoji'] ?? '⭐').toString(),
      prompt: (json['prompt'] ?? _promptForGame(gameKey)).toString(),
      displayText: display,
      subText: (json['subText'] ?? json['wordEnglish'] ?? json['sound'] ?? json['targetSound'] ?? '').toString(),
      hint: (json['hint'] ?? 'Speak slowly and clearly.').toString(),
      acceptedAnswers: accepted.isNotEmpty ? accepted : [display],
    );
  }

  factory ToddlerSpeechItem.word(
      String emoji,
      String urdu,
      String english,
      List<String> accepted,
      String prompt,
      String hint,
      ) {
    return ToddlerSpeechItem(
      emoji: emoji,
      prompt: prompt,
      displayText: urdu,
      subText: english,
      hint: hint,
      acceptedAnswers: [urdu, english, ...accepted],
    );
  }

  factory ToddlerSpeechItem.sound(
      String emoji,
      String animal,
      String sound,
      List<String> accepted,
      String prompt,
      String hint,
      ) {
    return ToddlerSpeechItem(
      emoji: emoji,
      prompt: prompt,
      displayText: animal,
      subText: sound,
      hint: hint,
      acceptedAnswers: [animal, sound, ...accepted],
    );
  }

  factory ToddlerSpeechItem.letter(
      String emoji,
      String letter,
      String sound,
      List<String> accepted,
      String prompt,
      String hint,
      ) {
    return ToddlerSpeechItem(
      emoji: emoji,
      prompt: prompt,
      displayText: letter,
      subText: sound,
      hint: hint,
      acceptedAnswers: [letter, sound, ...accepted],
    );
  }

  factory ToddlerSpeechItem.rhyme(
      String emoji,
      String word,
      String rhyme,
      List<String> accepted,
      String prompt,
      String hint,
      ) {
    return ToddlerSpeechItem(
      emoji: emoji,
      prompt: prompt,
      displayText: word,
      subText: rhyme,
      hint: hint,
      acceptedAnswers: [word, rhyme, ...accepted],
    );
  }

  factory ToddlerSpeechItem.match(
      String emoji,
      String sound,
      String words,
      List<String> accepted,
      String prompt,
      String hint,
      ) {
    return ToddlerSpeechItem(
      emoji: emoji,
      prompt: prompt,
      displayText: sound,
      subText: words,
      hint: hint,
      acceptedAnswers: [sound, words, ...accepted],
    );
  }

  factory ToddlerSpeechItem.sentence(
      String emoji,
      String sentence,
      List<String> accepted,
      String prompt,
      String hint,
      ) {
    return ToddlerSpeechItem(
      emoji: emoji,
      prompt: prompt,
      displayText: sentence,
      subText: '',
      hint: hint,
      acceptedAnswers: [sentence, ...accepted],
    );
  }

  static String _promptForGame(String key) {
    switch (key) {
      case 'animal_sounds':
        return 'What sound does it make?';
      case 'letter_sounds':
        return 'Learn Letter Sounds!';
      case 'rhyme_time':
        return 'These Words Rhyme!';
      case 'sound_match':
        return 'Find words with this sound!';
      case 'silly_sentences':
        return 'Say This Silly Sentence!';
      default:
        return 'Can you say this word?';
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final String message;

  const _HeaderCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Practice Speaking! 🗣️',
                style: GoogleFonts.poppins(
                  color: Color(0xFF21313A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: GoogleFonts.poppins(
                  color: Color(0xFF75838C),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          right: 18,
          top: 14,
          child: Text('✨', style: TextStyle(fontSize: 24)),
        ),
      ],
    );
  }
}

class _SpeechGameCard extends StatelessWidget {
  final ToddlerSpeechGame game;
  final VoidCallback onTap;

  const _SpeechGameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 158),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [game.color.withOpacity(0.88), game.color],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: game.color.withOpacity(0.26),
              blurRadius: 18,
              offset: const Offset(0, 11),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Text(game.emoji, style: const TextStyle(fontSize: 20)),
            ),
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(game.icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 12),
            Text(
              game.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                height: 1.16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              game.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.88),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 11),
            _DifficultyChip(text: game.level, color: Colors.white.withOpacity(0.26), textColor: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;

  const _DifficultyChip({required this.text, required this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: textColor ?? Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF21313A), size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF21313A),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  final String text;

  const _HintBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFA21B), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: const Color(0xFF21313A),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String message;

  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF3F91)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF21313A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorFromHex(String value, Color fallback) {
  final cleaned = value.replaceAll('#', '').trim();
  if (cleaned.length != 6 && cleaned.length != 8) return fallback;
  final parsed = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

Color _lighten(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness(min(1, max(0, hsl.lightness + amount))).toColor();
}
