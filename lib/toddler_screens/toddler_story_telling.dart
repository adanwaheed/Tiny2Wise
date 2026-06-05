import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';

class ToddlerStoryTellingScreen extends StatefulWidget {
  const ToddlerStoryTellingScreen({super.key});

  @override
  State<ToddlerStoryTellingScreen> createState() => _ToddlerStoryTellingScreenState();
}

class _ToddlerStoryTellingScreenState extends State<ToddlerStoryTellingScreen>
    with WidgetsBindingObserver {
  static const Color _purple = Color(0xFF7C3AED);

  final AudioPlayer _player = AudioPlayer();
  Timer? _autoRefreshTimer;

  bool _loading = true;
  bool _refreshing = false;
  String? _currentlyPlayingId;
  String? _errorText;

  Map<String, dynamic>? _activeToddler;
  Map<String, dynamic>? _currentlyPlayingStory;
  List<Map<String, dynamic>> _stories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStories();
    _startAutoRefresh();
    _player.onPlayerComplete.listen((_) {
      final completedStory = _currentlyPlayingStory;
      if (completedStory != null) {
        unawaited(_recordStoryProgress(completedStory));
      }
      if (!mounted) return;
      setState(() {
        _currentlyPlayingId = null;
        _currentlyPlayingStory = null;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStories(silent: true);
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _loading || _refreshing) return;
      _loadStories(silent: true);
    });
  }

  String _normalizeId(Object? value) {
    return '$value'.trim();
  }

  bool _storyMatchesToddler(Map<String, dynamic> story, String toddlerId) {
    final activeToddlerId = _normalizeId(toddlerId);
    if (activeToddlerId.isEmpty) return false;

    if (story['isDraft'] == true) return false;

    if (story['assignedToAll'] == true) return true;

    final directToddlerId = _normalizeId(story['toddlerId']);
    if (directToddlerId == activeToddlerId) return true;

    final assigned = story['assignedToddlerIds'];
    if (assigned is List) {
      return assigned.any((id) => _normalizeId(id) == activeToddlerId);
    }

    return false;
  }

  List<Map<String, dynamic>> _filterStoriesForToddler(
      List<dynamic> rawStories,
      String toddlerId,
      ) {
    return rawStories
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((story) => _storyMatchesToddler(story, toddlerId))
        .toList();
  }

  Future<void> _loadStories({bool pullToRefresh = false, bool silent = false}) async {
    if (!mounted) return;

    if (pullToRefresh) {
      setState(() => _refreshing = true);
    } else if (!silent) {
      setState(() {
        _loading = true;
        _errorText = null;
      });
    }

    try {
      final toddlersRaw = await ApiService.getToddlers();
      final toddlers = toddlersRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (toddlers.isEmpty) {
        setState(() {
          _activeToddler = null;
          _stories = [];
          _errorText = null;
        });
        return;
      }

      final active = toddlers.firstWhere(
            (t) => t['isActive'] == true,
        orElse: () => toddlers.first,
      );

      final toddlerId = '${active['_id'] ?? active['id'] ?? ''}'.trim();
      if (toddlerId.isEmpty) {
        throw 'Active toddler profile is missing.';
      }

      Map<String, dynamic>? toddlerFromServer;
      List<Map<String, dynamic>> stories = [];

      try {
        final payload = await ApiService.getToddlerAssignedStories(toddlerId);
        toddlerFromServer = payload['toddler'] is Map
            ? Map<String, dynamic>.from(payload['toddler'] as Map)
            : active;
        stories = (payload['stories'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        toddlerFromServer = active;
      }

      // Real-time safety fallback:
      // If the specific toddler endpoint is still empty, read the parent story list
      // and filter it locally by the active toddler id. This makes newly assigned
      // stories appear immediately even if the server cache/device is behind.
      if (stories.isEmpty) {
        final allStories = await ApiService.getStories();
        stories = _filterStoriesForToddler(allStories, toddlerId);
      }

      if (!mounted) return;
      setState(() {
        _activeToddler = toddlerFromServer ?? active;
        _stories = stories;
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _errorText = e.toString();
        });
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _playOrStopStory(Map<String, dynamic> story) async {
    final storyId = '${story['_id'] ?? story['id'] ?? ''}'.trim();
    if (storyId.isEmpty) return;

    if (_currentlyPlayingId == storyId) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _currentlyPlayingId = null;
          _currentlyPlayingStory = null;
        });
      }
      return;
    }

    try {
      final url = ApiService.storyAudioUrl(storyId);
      final headers = await ApiService.getAuthHeaders();
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) {
        throw 'Unable to load story audio.';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/toddler_story_$storyId.m4a');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      await _player.stop();
      await _player.play(DeviceFileSource(file.path));

      if (mounted) {
        setState(() {
          _currentlyPlayingId = storyId;
          _currentlyPlayingStory = story;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to play story: $e');
    }
  }

  Future<void> _recordStoryProgress(Map<String, dynamic> story) async {
    try {
      final toddlerId = '${_activeToddler?['_id'] ?? _activeToddler?['id'] ?? ''}'.trim();
      if (toddlerId.isEmpty) return;

      final storyId = '${story['_id'] ?? story['id'] ?? ''}'.trim();
      final title = '${story['title'] ?? 'Story Time'}'.trim();
      final duration = _durationSeconds(story);

      await ApiService.recordToddlerActivityProgress(
        toddlerId: toddlerId,
        activityType: 'story_telling',
        title: 'Listened: $title',
        score: 100,
        total: duration > 0 ? duration : 1,
        correct: duration > 0 ? duration : 1,
        completed: 1,
        sourceId: storyId.isNotEmpty ? storyId : 'story_${DateTime.now().millisecondsSinceEpoch}',
        note: 'Listened to an assigned story.',
        metadata: {
          'storyId': storyId,
          'storyTitle': title,
          'durationSec': duration,
        },
      );
    } catch (_) {
      // Story progress should never interrupt audio playback.
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  int _durationSeconds(Map<String, dynamic> story) {
    final raw = story['durationSec'];
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse('$raw') ?? 0;
  }

  String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final min = safe ~/ 60;
    final sec = safe % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String _formatDate(Object? value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return 'Story Time';
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  String _toddlerName() {
    return '${_activeToddler?['name'] ?? 'Little Listener'}'.trim();
  }

  bool _isStoryUrdu(Map<String, dynamic> story) {
    final language = '${story['language'] ?? ''}'.toLowerCase();
    final title = '${story['title'] ?? ''}';
    return language.contains('urdu') || RegExp(r'[\u0600-\u06FF]').hasMatch(title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 360;

            return RefreshIndicator(
              onRefresh: () => _loadStories(pullToRefresh: true),
              color: _purple,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      toddlerName: _toddlerName(),
                      storyCount: _stories.length,
                      onBack: () => Navigator.pop(context),
                      onRefresh: _refreshing ? null : () => _loadStories(pullToRefresh: true),
                    ),
                  ),
                  if (_loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: _purple),
                      ),
                    )
                  else if (_errorText != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessageState(
                        icon: Icons.cloud_off_rounded,
                        iconText: '☁️',
                        title: 'Stories could not load',
                        message: _errorText!,
                        buttonLabel: 'Try Again',
                        onPressed: () => _loadStories(),
                      ),
                    )
                  else if (_activeToddler == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          icon: Icons.child_care_rounded,
                          iconText: '👶',
                          title: 'No toddler profile found',
                          message: 'Please add a toddler profile from the parent dashboard first.',
                          buttonLabel: 'Go Back',
                          onPressed: () => Navigator.pop(context),
                        ),
                      )
                    else if (_stories.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _MessageState(
                            icon: Icons.menu_book_rounded,
                            iconText: '📚',
                            title: 'No stories for ${_toddlerName()} yet',
                            message:
                            'Only stories assigned to the active toddler will appear here. Ask parent to record and assign a story.',
                            buttonLabel: 'Refresh',
                            onPressed: () => _loadStories(pullToRefresh: true),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            isSmall ? 14 : 18,
                            10,
                            isSmall ? 14 : 18,
                            28,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                Widget child;
                                if (index == 0) {
                                  child = _IntroCard(
                                    toddlerName: _toddlerName(),
                                    storyCount: _stories.length,
                                  );
                                } else {
                                  final story = _stories[index - 1];
                                  final storyId = '${story['_id'] ?? story['id'] ?? ''}';
                                  final isPlaying = _currentlyPlayingId == storyId;
                                  child = _StoryCard(
                                    story: story,
                                    isPlaying: isPlaying,
                                    isUrdu: _isStoryUrdu(story),
                                    duration: _formatDuration(_durationSeconds(story)),
                                    dateLabel: _formatDate(story['createdAt']),
                                    toddlerName: _toddlerName(),
                                    onTap: () => _playOrStopStory(story),
                                  );
                                }

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == _stories.length ? 0 : 14,
                                  ),
                                  child: child,
                                );
                              },
                              childCount: _stories.length + 1,
                            ),
                          ),
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.toddlerName,
    required this.storyCount,
    required this.onBack,
    required this.onRefresh,
  });

  final String toddlerName;
  final int storyCount;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF1A8),
            Color(0xFFFFE0EE),
            Color(0xFFE7F7FF),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                color: const Color(0xFF27364B),
                onTap: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Story Time 📖',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF27364B),
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.refresh_rounded,
                color: const Color(0xFF7C3AED),
                onTap: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 66,
                  width: 66,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🧸', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi $toddlerName!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1B2233),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        storyCount == 1
                            ? '1 story is waiting for you'
                            : '$storyCount stories are waiting for you',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.toddlerName,
    required this.storyCount,
  });

  final String toddlerName;
  final int storyCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFDF6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB8F7D7), width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00B884),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only $toddlerName\'s stories are shown here',
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF064E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a card to listen. These are the stories your parent recorded and assigned to this active profile.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.8,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.isPlaying,
    required this.isUrdu,
    required this.duration,
    required this.dateLabel,
    required this.toddlerName,
    required this.onTap,
  });

  final Map<String, dynamic> story;
  final bool isPlaying;
  final bool isUrdu;
  final String duration;
  final String dateLabel;
  final String toddlerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = '${story['title'] ?? 'Story Time'}'.trim();
    final assignedToAll = story['assignedToAll'] == true;
    final accent = isPlaying ? const Color(0xFFFF4DA6) : const Color(0xFF7C3AED);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isPlaying ? const Color(0xFFFF9ED0) : const Color(0xFFEDE9FE),
            width: isPlaying ? 2.2 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isPlaying ? 0.22 : 0.10),
              blurRadius: isPlaying ? 24 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 74,
                  width: 74,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isPlaying
                          ? const [Color(0xFFFF8AC3), Color(0xFFFFC05B)]
                          : const [Color(0xFF8B5CF6), Color(0xFF60A5FA)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isPlaying ? '🔊' : '📖',
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                        child: Text(
                          title.isEmpty ? 'Story Time' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B2233),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _SmallChip(icon: Icons.timer_rounded, label: duration, color: const Color(0xFFFF8A1C)),
                          _SmallChip(icon: Icons.language_rounded, label: '${story['language'] ?? 'Urdu'}', color: const Color(0xFF00B884)),
                          _SmallChip(icon: Icons.calendar_month_rounded, label: dateLabel, color: const Color(0xFF3B82F6)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      assignedToAll ? 'Assigned to all toddlers' : 'Assigned to $toddlerName only',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isPlaying ? const Color(0xFFFF4DA6) : const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPlaying ? 'Stop' : 'Play',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.iconText,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String iconText;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1D6),
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: Text(iconText, style: const TextStyle(fontSize: 42)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B2233),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: Icon(icon, size: 20),
                  label: Text(
                    buttonLabel,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
