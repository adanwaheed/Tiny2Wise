import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/api_service.dart';

class ToddlerPuzzleScreen extends StatefulWidget {
  const ToddlerPuzzleScreen({super.key});

  @override
  State<ToddlerPuzzleScreen> createState() => _ToddlerPuzzleScreenState();
}

class _ToddlerPuzzleScreenState extends State<ToddlerPuzzleScreen> {
  bool _loading = true;
  bool _usingFallback = false;
  String _error = '';
  List<ToddlerPuzzleGame> _games = [];

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  Future<void> _loadPuzzles() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final data = await ApiService.generateToddlerPuzzles(
        countPerGame: 6,
        languageMode: 'mixed',
      );
      final rawGames = data['games'] as List<dynamic>? ?? [];
      final parsed = rawGames
          .map((item) => ToddlerPuzzleGame.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((game) => game.pieces.isNotEmpty && game.slots.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _games = parsed.isEmpty ? _localPuzzleGames() : parsed;
        _usingFallback = data['source']?.toString() != 'gemini';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _games = _localPuzzleGames();
        _usingFallback = true;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FBFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF12536F),
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.extension_rounded, color: Color(0xFF2865F0)),
            const SizedBox(width: 8),
            Text(
              'Puzzle Time 🧩',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2865F0),
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7FAFF), Color(0xFFFFF5F8), Color(0xFFFFF9DE)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: _loading
              ? const _PuzzleLoadingView()
              : RefreshIndicator(
            onRefresh: _loadPuzzles,
            color: const Color(0xFF2865F0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final horizontalPadding = width > 700 ? 28.0 : 16.0;
                final crossAxisCount = width >= 900
                    ? 4
                    : width >= 620
                    ? 3
                    : 2;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          18,
                          horizontalPadding,
                          10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Solve Fun Puzzles! 🧩',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: width < 360 ? 19 : 23,
                                      height: 1.12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF12344A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Choose a puzzle to complete, then say the words clearly.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF6D8795),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _PuzzleTipBar(
                              icon: _usingFallback ? Icons.offline_bolt_rounded : Icons.auto_awesome_rounded,
                              text: _usingFallback
                                  ? 'Safe local puzzles are ready. AI puzzles will load when the server key is available.'
                                  : 'AI generated toddler speech puzzles are ready!',
                            ),
                            if (_error.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Offline fallback used: $_error',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF9A6470),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 20),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final game = _games[index];
                            return _PuzzleGameCard(
                              game: game,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ToddlerPuzzlePlayScreen(game: game),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: _games.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: width < 360 ? 0.79 : 0.84,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              '🧠 Build Your Brain Power! 🎙️',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF2865F0),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ToddlerPuzzlePlayScreen extends StatefulWidget {
  const ToddlerPuzzlePlayScreen({super.key, required this.game});

  final ToddlerPuzzleGame game;

  @override
  State<ToddlerPuzzlePlayScreen> createState() => _ToddlerPuzzlePlayScreenState();
}

class _ToddlerPuzzlePlayScreenState extends State<ToddlerPuzzlePlayScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Map<String, ToddlerPuzzlePiece> _placedBySlot = {};
  final Set<String> _spokenPieceIds = {};

  late List<ToddlerPuzzlePiece> _availablePieces;
  bool _speechReady = false;
  bool _isListening = false;
  bool _speechAnswerHandled = false;
  bool _badgeAwardChecked = false;
  bool _progressSaved = false;
  ToddlerPuzzlePiece? _speechPiece;
  String _speechStatus = 'Finish a match, then say the word clearly.';
  String _recognizedWords = '';
  String _selectedLocaleId = '';
  Timer? _stopTimer;
  Timer? _resultFinishTimer;

  @override
  void initState() {
    super.initState();
    _availablePieces = [...widget.game.pieces]..shuffle(Random());
    _initSpeech();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _resultFinishTimer?.cancel();
    try {
      _speech.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _speechStatus = 'Microphone permission is required. Please allow the mic and try again.';
      });
      return;
    }

    final available = await _speech.initialize(
      finalTimeout: const Duration(seconds: 3),
      onStatus: (status) {
        if (!mounted) return;

        if (status == 'listening' && _isListening) {
          setState(() => _speechStatus = 'Listening... speak now!');
          return;
        }

        if ((status == 'done' || status == 'notListening') &&
            _isListening &&
            !_speechAnswerHandled) {
          _finishListening();
        }
      },
      onError: (error) {
        if (!mounted) return;

        if (_isListening && !_speechAnswerHandled) {
          _finishListening();
        } else {
          setState(() {
            _isListening = false;
            _speechStatus = 'Speech listening stopped. Tap the red button and try again.';
          });
        }
      },
    );

    if (available) {
      await _pickBestSpeechLocale();
    }

    if (!mounted) return;
    setState(() {
      _speechReady = available;
      if (!available) {
        _speechStatus = 'Speech recognition is not available on this device.';
      }
    });
  }

  Future<void> _pickBestSpeechLocale() async {
    try {
      final locales = await _speech.locales();
      String norm(String value) => value.toLowerCase().replaceAll('-', '_');

      String? englishPk;
      String? english;
      String? urdu;

      for (final locale in locales) {
        final id = norm(locale.localeId);
        if (englishPk == null && (id == 'en_pk' || id == 'en_in')) {
          englishPk = locale.localeId;
        }
        if (english == null && (id == 'en_us' || id == 'en_gb' || id.startsWith('en_') || id == 'en')) {
          english = locale.localeId;
        }
        if (urdu == null && (id == 'ur_pk' || id.startsWith('ur_') || id == 'ur')) {
          urdu = locale.localeId;
        }
      }

      _selectedLocaleId = englishPk ?? english ?? urdu ?? (locales.isNotEmpty ? locales.first.localeId : '');
    } catch (_) {
      _selectedLocaleId = '';
    }
  }

  Future<void> _startListening(ToddlerPuzzlePiece piece) async {
    if (_isListening) {
      await _finishListening();
      return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _speechStatus = 'Microphone permission is required. Please allow the mic and try again.';
      });
      return;
    }

    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        if (!mounted) return;
        setState(() => _speechStatus = 'Speech recognition is not available on this device.');
        return;
      }
    }

    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}

    HapticFeedback.lightImpact();
    _stopTimer?.cancel();
    _resultFinishTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _speechPiece = piece;
      _recognizedWords = '';
      _isListening = true;
      _speechAnswerHandled = false;
      _speechStatus = 'Listening... say ${piece.wordEnglish} now!';
    });

    try {
      await _speech.listen(
        localeId: _selectedLocaleId.trim().isEmpty ? null : _selectedLocaleId.trim(),
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          final words = result.recognizedWords.trim();

          if (words.isNotEmpty && mounted) {
            setState(() {
              _recognizedWords = words;
              _speechStatus = 'I heard: $words';
            });

            _resultFinishTimer?.cancel();
            _resultFinishTimer = Timer(const Duration(milliseconds: 1500), () {
              if (_isListening && !_speechAnswerHandled) _finishListening();
            });
          }

          if (result.finalResult && !_speechAnswerHandled) {
            _finishListening();
          }
        },
      );

      _stopTimer?.cancel();
      _stopTimer = Timer(const Duration(seconds: 11), () {
        if (_isListening && !_speechAnswerHandled) _finishListening();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _speechAnswerHandled = true;
        _speechStatus = 'Speech could not start. Check mic permission and try again.';
      });
    }
  }

  Future<void> _finishListening() async {
    if (_speechAnswerHandled) return;
    _speechAnswerHandled = true;
    _stopTimer?.cancel();
    _resultFinishTimer?.cancel();

    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}

    final piece = _speechPiece;
    final words = _recognizedWords.trim();
    if (!mounted || piece == null) return;

    final correct = _isSpeechCorrect(words, piece.acceptedAnswers);

    setState(() {
      _isListening = false;
      if (correct) {
        _spokenPieceIds.add(piece.id);
        _speechStatus = 'Great speaking! You said ${piece.wordEnglish} clearly.';
      } else if (words.isEmpty) {
        _speechStatus = 'I did not hear a word. Move closer and say ${piece.wordEnglish} again.';
      } else {
        _speechStatus = 'I heard "$words". Try again: ${piece.wordEnglish} / ${piece.wordUrdu}';
      }
    });
  }

  bool _isSpeechCorrect(String recognized, List<String> acceptedAnswers) {
    final answer = _normalizeSpeech(recognized);
    if (answer.isEmpty) return false;

    return acceptedAnswers.any((expected) {
      final normalizedExpected = _normalizeSpeech(expected);
      if (normalizedExpected.isEmpty) return false;
      return answer == normalizedExpected ||
          answer.contains(normalizedExpected) ||
          normalizedExpected.contains(answer);
    });
  }

  String _normalizeSpeech(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[ًٌٍَُِّْٰـ]'), '')
        .replaceAll(RegExp(r'[اآأإ]'), 'ا')
        .replaceAll(RegExp(r'[يى]'), 'ی')
        .replaceAll(RegExp(r'[ھہ]'), 'ہ')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _placePiece(String slotId, ToddlerPuzzlePiece piece) {
    if (piece.slotId != slotId) {
      _showSnack('Try another spot for ${piece.wordEnglish} ${piece.emoji}');
      return;
    }

    setState(() {
      final previous = _placedBySlot[slotId];
      if (previous != null) {
        _availablePieces.add(previous);
        _spokenPieceIds.remove(previous.id);
      }
      _placedBySlot[slotId] = piece;
      _availablePieces.removeWhere((p) => p.id == piece.id);
      _speechPiece = piece;
      _speechStatus = 'Nice match! Now say ${piece.wordEnglish} / ${piece.wordUrdu}';
    });
  }

  void _removePlacedPiece(String slotId) {
    final piece = _placedBySlot[slotId];
    if (piece == null) return;

    setState(() {
      _placedBySlot.remove(slotId);
      _availablePieces.add(piece);
      _availablePieces.shuffle(Random());
      _spokenPieceIds.remove(piece.id);
      _speechStatus = 'Drag the piece back to the correct spot.';
    });
  }

  void _startOver() {
    setState(() {
      _placedBySlot.clear();
      _spokenPieceIds.clear();
      _availablePieces = [...widget.game.pieces]..shuffle(Random());
      _speechPiece = null;
      _recognizedWords = '';
      _speechAnswerHandled = false;
      _badgeAwardChecked = false;
      _progressSaved = false;
      _speechStatus = 'Finish a match, then say the word clearly.';
    });
  }

  Future<void> _savePuzzleProgressIfComplete() async {
    if (_progressSaved) return;
    final allMatched = _placedBySlot.length == widget.game.slots.length;
    final allSpoken = _spokenPieceIds.length == widget.game.pieces.length;
    if (!allMatched || !allSpoken) return;

    _progressSaved = true;

    try {
      final toddler = await ApiService.getActiveToddler();
      if (toddler == null) return;

      final toddlerId = (toddler['_id'] ?? toddler['id'] ?? '').toString().trim();
      if (toddlerId.isEmpty) return;

      final total = widget.game.pieces.length;
      await ApiService.recordToddlerActivityProgress(
        toddlerId: toddlerId,
        activityType: 'puzzles',
        title: '${widget.game.title} Solved',
        score: 100,
        total: total,
        correct: total,
        completed: total,
        sourceId: 'puzzle_${widget.game.key}_${DateTime.now().millisecondsSinceEpoch}',
        note: 'Solved ${widget.game.title} and spoke all words clearly.',
        metadata: {
          'puzzleKey': widget.game.key,
          'puzzleTitle': widget.game.title,
          'matchedPieces': total,
        },
      );
    } catch (_) {
      // Progress saving must never interrupt puzzle play.
    }
  }

  Future<void> _awardPuzzleBadgeIfComplete() async {
    if (_badgeAwardChecked) return;
    final allMatched = _placedBySlot.length == widget.game.slots.length;
    final allSpoken = _spokenPieceIds.length == widget.game.pieces.length;
    if (!allMatched || !allSpoken) return;

    _badgeAwardChecked = true;

    try {
      final toddler = await ApiService.getActiveToddler();
      if (toddler == null) return;

      final toddlerId = (toddler['_id'] ?? toddler['id'] ?? '').toString().trim();
      if (toddlerId.isEmpty) return;

      final total = widget.game.pieces.length;
      final data = await ApiService.awardToddlerBadge(
        toddlerId: toddlerId,
        badgeKey: 'puzzle_master',
        source: 'puzzle',
        score: 100,
        total: total,
        correct: total,
        goalText: 'Complete a puzzle and say every word clearly.',
        details: {
          'puzzleKey': widget.game.key,
          'puzzleTitle': widget.game.title,
        },
      );

      if (!mounted) return;
      if (data['newlyUnlocked'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New badge unlocked: ${data['badge']?['title'] ?? 'Puzzle Master'} 🧩"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Badge saving is a bonus and should not block puzzle play.
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final bg = game.backgroundColor;
    final main = game.color;
    final completedMatches = _placedBySlot.length;
    final completedSpeech = _spokenPieceIds.length;
    final allDone = completedMatches == game.slots.length && completedSpeech == game.pieces.length;

    if (allDone && (!_progressSaved || !_badgeAwardChecked)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_savePuzzleProgressIfComplete());
        unawaited(_awardPuzzleBadgeIfComplete());
      });
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: main,
        titleSpacing: 0,
        title: Text(
          '${game.emoji} ${game.title}',
          style: GoogleFonts.poppins(
            color: main,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg, Colors.white, bg.withOpacity(0.7)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final gridColumns = width >= 700 ? 4 : 3;
              final pieceColumns = width >= 700 ? 6 : 3;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  width > 700 ? 30 : 16,
                  18,
                  width > 700 ? 30 : 16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      children: [
                        _InstructionCard(
                          game: game,
                          completedMatches: completedMatches,
                          totalMatches: game.slots.length,
                          completedSpeech: completedSpeech,
                          totalSpeech: game.pieces.length,
                        ),
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: game.slots.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridColumns,
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 9,
                            childAspectRatio: width < 360 ? 0.88 : 0.95,
                          ),
                          itemBuilder: (context, index) {
                            final slot = game.slots[index];
                            final placed = _placedBySlot[slot.id];
                            final spoken = placed != null && _spokenPieceIds.contains(placed.id);

                            return DragTarget<ToddlerPuzzlePiece>(
                              onWillAccept: (piece) => piece != null,
                              onAccept: (piece) => _placePiece(slot.id, piece),
                              builder: (context, candidates, rejected) {
                                final hovering = candidates.isNotEmpty;
                                return _PuzzleSlotCard(
                                  slot: slot,
                                  piece: placed,
                                  mainColor: main,
                                  hovering: hovering,
                                  spoken: spoken,
                                  onRemove: placed == null ? null : () => _removePlacedPiece(slot.id),
                                  onSpeak: placed == null ? null : () => _startListening(placed),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _SpeechPracticePanel(
                          mainColor: main,
                          speechReady: _speechReady,
                          isListening: _isListening,
                          status: allDone
                              ? 'Amazing! Puzzle solved and all words practiced. 🌟'
                              : _speechStatus,
                          recognizedWords: _recognizedWords,
                          selectedPiece: _speechPiece,
                          onSpeak: _speechPiece == null ? null : () => _startListening(_speechPiece!),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Available Pieces',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF253746),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        if (_availablePieces.isEmpty)
                          _AllPiecesPlacedCard(mainColor: main)
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _availablePieces.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: pieceColumns,
                              crossAxisSpacing: 9,
                              mainAxisSpacing: 9,
                              childAspectRatio: width < 360 ? 1.05 : 1.18,
                            ),
                            itemBuilder: (context, index) {
                              final piece = _availablePieces[index];
                              return Draggable<ToddlerPuzzlePiece>(
                                data: piece,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Transform.scale(
                                    scale: 1.05,
                                    child: _PuzzlePieceCard(piece: piece, mainColor: main, dragging: true),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.28,
                                  child: _PuzzlePieceCard(piece: piece, mainColor: main),
                                ),
                                child: _PuzzlePieceCard(piece: piece, mainColor: main),
                              );
                            },
                          ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _startOver,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF607080),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              'Start Over',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PuzzleLoadingView extends StatelessWidget {
  const _PuzzleLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF2865F0)),
          const SizedBox(height: 14),
          Text(
            'Creating AI puzzles...',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF12344A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleTipBar extends StatelessWidget {
  const _PuzzleTipBar({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDAECFF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2865F0), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: const Color(0xFF4E6878),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleGameCard extends StatelessWidget {
  const _PuzzleGameCard({required this.game, required this.onTap});

  final ToddlerPuzzleGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rawColor = game.color;
    final color = rawColor.computeLuminance() > 0.72 ? const Color(0xFF2865F0) : rawColor;
    final softColor = Color.lerp(Colors.white, color, 0.10)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, softColor],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.22), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  top: -22,
                  child: Container(
                    height: 76,
                    width: 76,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -18,
                  bottom: -20,
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 58,
                            width: 58,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [color.withOpacity(0.92), color],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(game.emoji, style: const TextStyle(fontSize: 29)),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withOpacity(0.18)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: color, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  'Play',
                                  style: GoogleFonts.poppins(
                                    color: color,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        game.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1F3442),
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        game.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          height: 1.18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5F7483),
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _PuzzleInfoChip(text: '${game.pieces.length} pieces', color: color),
                          _PuzzleInfoChip(text: game.ageRange, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PuzzleInfoChip extends StatelessWidget {
  const _PuzzleInfoChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallWhiteChip extends StatelessWidget {
  const _SmallWhiteChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.game,
    required this.completedMatches,
    required this.totalMatches,
    required this.completedSpeech,
    required this.totalSpeech,
  });

  final ToddlerPuzzleGame game;
  final int completedMatches;
  final int totalMatches;
  final int completedSpeech;
  final int totalSpeech;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            game.instruction,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF203447),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProgressPill(
                icon: Icons.extension_rounded,
                label: '$completedMatches / $totalMatches matched',
                color: game.color,
              ),
              _ProgressPill(
                icon: Icons.mic_rounded,
                label: '$completedSpeech / $totalSpeech spoken',
                color: const Color(0xFFFF3F91),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleSlotCard extends StatelessWidget {
  const _PuzzleSlotCard({
    required this.slot,
    required this.piece,
    required this.mainColor,
    required this.hovering,
    required this.spoken,
    required this.onRemove,
    required this.onSpeak,
  });

  final ToddlerPuzzleSlot slot;
  final ToddlerPuzzlePiece? piece;
  final Color mainColor;
  final bool hovering;
  final bool spoken;
  final VoidCallback? onRemove;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final isFilled = piece != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isFilled ? mainColor : Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hovering
              ? mainColor
              : isFilled
              ? Colors.white.withOpacity(0.7)
              : const Color(0xFFCAD9E3),
          width: hovering ? 2.2 : 1.3,
        ),
        boxShadow: [
          if (isFilled)
            BoxShadow(
              color: mainColor.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: isFilled
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(piece!.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 3),
                  Text(
                    piece!.wordEnglish,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    piece!.wordUrdu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: onSpeak,
                    child: Icon(
                      spoken ? Icons.check_circle_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(slot.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    'Drop',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9AAAB5),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    slot.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9AAAB5),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFilled)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  height: 18,
                  width: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: mainColor, size: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PuzzlePieceCard extends StatelessWidget {
  const _PuzzlePieceCard({required this.piece, required this.mainColor, this.dragging = false});

  final ToddlerPuzzlePiece piece;
  final Color mainColor;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dragging ? 96 : null,
      height: dragging ? 84 : null,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: piece.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: piece.cardColor.withOpacity(0.28),
            blurRadius: dragging ? 18 : 9,
            offset: Offset(0, dragging ? 10 : 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(piece.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            piece.wordEnglish,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            piece.wordUrdu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechPracticePanel extends StatelessWidget {
  const _SpeechPracticePanel({
    required this.mainColor,
    required this.speechReady,
    required this.isListening,
    required this.status,
    required this.recognizedWords,
    required this.selectedPiece,
    required this.onSpeak,
  });

  final Color mainColor;
  final bool speechReady;
  final bool isListening;
  final String status;
  final String recognizedWords;
  final ToddlerPuzzlePiece? selectedPiece;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(isListening ? Icons.hearing_rounded : Icons.mic_rounded, color: mainColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF253746),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (recognizedWords.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Heard: $recognizedWords',
              style: GoogleFonts.poppins(
                color: const Color(0xFF607080),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: speechReady && selectedPiece != null ? onSpeak : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                disabledBackgroundColor: const Color(0xFFE3E9ED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded, size: 18),
              label: Text(
                isListening
                    ? 'Listening... Tap to Stop'
                    : selectedPiece == null
                    ? 'Match a piece first'
                    : 'Tap Mic & Say ${selectedPiece!.wordEnglish}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllPiecesPlacedCard extends StatelessWidget {
  const _AllPiecesPlacedCard({required this.mainColor});

  final Color mainColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'All pieces are placed. Tap the mic on each matched card to practice speech.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: mainColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ToddlerPuzzleGame {
  ToddlerPuzzleGame({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.instruction,
    required this.level,
    required this.ageRange,
    required this.emoji,
    required this.colorHex,
    required this.backgroundHex,
    required this.slots,
    required this.pieces,
  });

  final String key;
  final String title;
  final String subtitle;
  final String instruction;
  final String level;
  final String ageRange;
  final String emoji;
  final String colorHex;
  final String backgroundHex;
  final List<ToddlerPuzzleSlot> slots;
  final List<ToddlerPuzzlePiece> pieces;

  Color get color => _parseColor(colorHex, const Color(0xFF2865F0));
  Color get backgroundColor => _parseColor(backgroundHex, const Color(0xFFE7FAFF));

  factory ToddlerPuzzleGame.fromJson(Map<String, dynamic> json) {
    final slots = (json['slots'] as List<dynamic>? ?? [])
        .map((item) => ToddlerPuzzleSlot.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((slot) => slot.id.isNotEmpty)
        .toList();
    final pieces = (json['pieces'] as List<dynamic>? ?? [])
        .map((item) => ToddlerPuzzlePiece.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((piece) => piece.id.isNotEmpty && piece.slotId.isNotEmpty)
        .toList();

    return ToddlerPuzzleGame(
      key: _clean(json['key'], fallback: 'puzzle'),
      title: _clean(json['title'], fallback: 'Puzzle Game'),
      subtitle: _clean(json['subtitle'], fallback: 'Drag and Speak'),
      instruction: _clean(json['instruction'], fallback: 'Drag each piece to the correct spot, then say the word.'),
      level: _clean(json['level'], fallback: 'Easy'),
      ageRange: _clean(json['ageRange'], fallback: '3-6 years'),
      emoji: _clean(json['emoji'], fallback: '🧩'),
      colorHex: _clean(json['colorHex'], fallback: '#2865F0'),
      backgroundHex: _clean(json['backgroundHex'], fallback: '#E7FAFF'),
      slots: slots,
      pieces: pieces,
    );
  }
}

class ToddlerPuzzleSlot {
  ToddlerPuzzleSlot({
    required this.id,
    required this.label,
    required this.hint,
    required this.emoji,
  });

  final String id;
  final String label;
  final String hint;
  final String emoji;

  factory ToddlerPuzzleSlot.fromJson(Map<String, dynamic> json) {
    return ToddlerPuzzleSlot(
      id: _clean(json['id']),
      label: _clean(json['label'], fallback: 'Spot'),
      hint: _clean(json['hint'], fallback: 'Drop here'),
      emoji: _clean(json['emoji'], fallback: '⬜'),
    );
  }
}

class ToddlerPuzzlePiece {
  ToddlerPuzzlePiece({
    required this.id,
    required this.slotId,
    required this.emoji,
    required this.wordUrdu,
    required this.wordEnglish,
    required this.cardColorHex,
    required this.acceptedAnswers,
  });

  final String id;
  final String slotId;
  final String emoji;
  final String wordUrdu;
  final String wordEnglish;
  final String cardColorHex;
  final List<String> acceptedAnswers;

  Color get cardColor => _parseColor(cardColorHex, const Color(0xFFFFA21B));

  factory ToddlerPuzzlePiece.fromJson(Map<String, dynamic> json) {
    final answers = (json['acceptedAnswers'] as List<dynamic>? ?? [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final wordUrdu = _clean(json['wordUrdu'] ?? json['labelUrdu'], fallback: 'لفظ');
    final wordEnglish = _clean(json['wordEnglish'] ?? json['label'], fallback: 'Word');

    return ToddlerPuzzlePiece(
      id: _clean(json['id']),
      slotId: _clean(json['slotId']),
      emoji: _clean(json['emoji'], fallback: '⭐'),
      wordUrdu: wordUrdu,
      wordEnglish: wordEnglish,
      cardColorHex: _clean(json['cardColorHex'], fallback: '#FFA21B'),
      acceptedAnswers: {
        wordUrdu,
        wordEnglish,
        ...answers,
      }.where((item) => item.trim().isNotEmpty).toList(),
    );
  }
}

String _clean(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

Color _parseColor(String hex, Color fallback) {
  try {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  } catch (_) {
    return fallback;
  }
}

List<ToddlerPuzzleGame> _localPuzzleGames() {
  ToddlerPuzzleGame game({
    required String key,
    required String title,
    required String subtitle,
    required String instruction,
    required String emoji,
    required String color,
    required String bg,
    required List<Map<String, String>> data,
  }) {
    final slots = <ToddlerPuzzleSlot>[];
    final pieces = <ToddlerPuzzlePiece>[];
    final cardColors = ['#FF5A3F', '#5B8CFF', '#00C88F', '#FF3F91', '#FFA21B', '#8B5CF6'];

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final id = '$key-$i';
      slots.add(
        ToddlerPuzzleSlot(
          id: 'slot-$id',
          label: item['en'] ?? 'Spot',
          hint: 'Drop ${item['en'] ?? 'piece'} here',
          emoji: item['slotEmoji'] ?? '⬜',
        ),
      );
      pieces.add(
        ToddlerPuzzlePiece(
          id: 'piece-$id',
          slotId: 'slot-$id',
          emoji: item['emoji'] ?? '⭐',
          wordUrdu: item['ur'] ?? '',
          wordEnglish: item['en'] ?? '',
          cardColorHex: cardColors[i % cardColors.length],
          acceptedAnswers: [
            item['ur'] ?? '',
            item['en'] ?? '',
            item['roman'] ?? '',
          ],
        ),
      );
    }

    return ToddlerPuzzleGame(
      key: key,
      title: title,
      subtitle: subtitle,
      instruction: instruction,
      level: key == 'space_adventure' ? 'Hard' : 'Easy',
      ageRange: key == 'space_adventure' ? '5-6 years' : '3-5 years',
      emoji: emoji,
      colorHex: color,
      backgroundHex: bg,
      slots: slots,
      pieces: pieces,
    );
  }

  return [
    game(
      key: 'animal_friends',
      title: 'Animal Friends',
      subtitle: 'Match animals and say names',
      instruction: 'Drag each animal to the correct spot! 🐾',
      emoji: '🦁',
      color: '#FF5A3F',
      bg: '#FFF5DD',
      data: const [
        {'emoji': '🦁', 'slotEmoji': '⭐', 'en': 'Lion', 'ur': 'شیر', 'roman': 'sher'},
        {'emoji': '🐘', 'slotEmoji': '⭐', 'en': 'Elephant', 'ur': 'ہاتھی', 'roman': 'hathi'},
        {'emoji': '🦒', 'slotEmoji': '⬜', 'en': 'Giraffe', 'ur': 'زرافہ', 'roman': 'zarafa'},
        {'emoji': '🐻', 'slotEmoji': '⬜', 'en': 'Bear', 'ur': 'ریچھ', 'roman': 'reech'},
      ],
    ),
    game(
      key: 'shape_match',
      title: 'Shape Match',
      subtitle: 'Match shapes and sounds',
      instruction: 'Match each shape to its spot! 🔷',
      emoji: '🔷',
      color: '#5B8CFF',
      bg: '#EEF3FF',
      data: const [
        {'emoji': '🔺', 'slotEmoji': '⬜', 'en': 'Triangle', 'ur': 'مثلث', 'roman': 'musallas'},
        {'emoji': '⭐', 'slotEmoji': '⭐', 'en': 'Star', 'ur': 'ستارہ', 'roman': 'sitara'},
        {'emoji': '♦️', 'slotEmoji': '🔷', 'en': 'Diamond', 'ur': 'ہیرا', 'roman': 'heera'},
        {'emoji': '⚪', 'slotEmoji': '⚪', 'en': 'Circle', 'ur': 'گول', 'roman': 'gol'},
      ],
    ),
    game(
      key: 'fun_vehicles',
      title: 'Fun Vehicles',
      subtitle: 'Name vehicles clearly',
      instruction: 'Match all the vehicles! 🚗',
      emoji: '🚗',
      color: '#00C88F',
      bg: '#E7FFF6',
      data: const [
        {'emoji': '🚌', 'slotEmoji': '⬜', 'en': 'Bus', 'ur': 'بس', 'roman': 'bus'},
        {'emoji': '🚗', 'slotEmoji': '⬜', 'en': 'Car', 'ur': 'گاڑی', 'roman': 'gari'},
        {'emoji': '✈️', 'slotEmoji': '⬜', 'en': 'Airplane', 'ur': 'جہاز', 'roman': 'jahaz'},
        {'emoji': '🚲', 'slotEmoji': '⬜', 'en': 'Bicycle', 'ur': 'سائیکل', 'roman': 'cycle'},
        {'emoji': '🛴', 'slotEmoji': '⬜', 'en': 'Scooter', 'ur': 'سکوٹر', 'roman': 'scooter'},
        {'emoji': '🚂', 'slotEmoji': '⬜', 'en': 'Train', 'ur': 'ریل', 'roman': 'rail'},
      ],
    ),
    game(
      key: 'yummy_fruits',
      title: 'Yummy Fruits',
      subtitle: 'Say fruit names',
      instruction: 'Match all the delicious fruits! 🍓',
      emoji: '🍓',
      color: '#FF3F91',
      bg: '#FFF0F5',
      data: const [
        {'emoji': '🍇', 'slotEmoji': '⬜', 'en': 'Grapes', 'ur': 'انگور', 'roman': 'angoor'},
        {'emoji': '🍉', 'slotEmoji': '⬜', 'en': 'Watermelon', 'ur': 'تربوز', 'roman': 'tarbooz'},
        {'emoji': '🍎', 'slotEmoji': '⬜', 'en': 'Apple', 'ur': 'سیب', 'roman': 'seb'},
        {'emoji': '🍊', 'slotEmoji': '⬜', 'en': 'Orange', 'ur': 'مالٹا', 'roman': 'malta'},
        {'emoji': '🍓', 'slotEmoji': '⬜', 'en': 'Strawberry', 'ur': 'اسٹرابیری', 'roman': 'strawberry'},
        {'emoji': '🍒', 'slotEmoji': '⬜', 'en': 'Cherry', 'ur': 'چیری', 'roman': 'cherry'},
      ],
    ),
    game(
      key: 'nature_scene',
      title: 'Nature Scene',
      subtitle: 'Build a nature picture',
      instruction: 'Complete the beautiful nature scene! 🌳',
      emoji: '🌳',
      color: '#1CBF72',
      bg: '#EEFFE6',
      data: const [
        {'emoji': '🌳', 'slotEmoji': '⬜', 'en': 'Tree', 'ur': 'درخت', 'roman': 'darakht'},
        {'emoji': '🌸', 'slotEmoji': '⬜', 'en': 'Flower', 'ur': 'پھول', 'roman': 'phool'},
        {'emoji': '🦋', 'slotEmoji': '⬜', 'en': 'Butterfly', 'ur': 'تتلی', 'roman': 'titli'},
        {'emoji': '🌻', 'slotEmoji': '⬜', 'en': 'Sunflower', 'ur': 'سورج مکھی', 'roman': 'suraj mukhi'},
        {'emoji': '☀️', 'slotEmoji': '⬜', 'en': 'Sun', 'ur': 'سورج', 'roman': 'suraj'},
        {'emoji': '🌈', 'slotEmoji': '⬜', 'en': 'Rainbow', 'ur': 'قوس قزح', 'roman': 'rainbow'},
        {'emoji': '☁️', 'slotEmoji': '⬜', 'en': 'Cloud', 'ur': 'بادل', 'roman': 'badal'},
        {'emoji': '🐛', 'slotEmoji': '⬜', 'en': 'Caterpillar', 'ur': 'سنڈی', 'roman': 'sundi'},
      ],
    ),
    game(
      key: 'space_adventure',
      title: 'Space Adventure',
      subtitle: 'Build a space world',
      instruction: 'Build the space scene! 🚀',
      emoji: '🚀',
      color: '#6D28D9',
      bg: '#EFE6FF',
      data: const [
        {'emoji': '🚀', 'slotEmoji': '⬜', 'en': 'Rocket', 'ur': 'راکٹ', 'roman': 'rocket'},
        {'emoji': '🌍', 'slotEmoji': '⬜', 'en': 'Earth', 'ur': 'زمین', 'roman': 'zameen'},
        {'emoji': '⭐', 'slotEmoji': '⬜', 'en': 'Star', 'ur': 'ستارہ', 'roman': 'sitara'},
        {'emoji': '🌙', 'slotEmoji': '⬜', 'en': 'Moon', 'ur': 'چاند', 'roman': 'chand'},
        {'emoji': '☀️', 'slotEmoji': '⬜', 'en': 'Sun', 'ur': 'سورج', 'roman': 'suraj'},
        {'emoji': '🪐', 'slotEmoji': '⬜', 'en': 'Saturn', 'ur': 'سیارہ', 'roman': 'sayara'},
        {'emoji': '👨‍🚀', 'slotEmoji': '⬜', 'en': 'Astronaut', 'ur': 'خلانورد', 'roman': 'khalanaward'},
        {'emoji': '🛸', 'slotEmoji': '⬜', 'en': 'Spaceship', 'ur': 'خلائی جہاز', 'roman': 'spaceship'},
        {'emoji': '💫', 'slotEmoji': '⬜', 'en': 'Meteor', 'ur': 'شہاب', 'roman': 'shahab'},
      ],
    ),
  ];
}
