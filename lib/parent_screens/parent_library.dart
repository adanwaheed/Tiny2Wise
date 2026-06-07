import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/news_article.dart';
import '../news/news_summary.dart';
import '../services/api_service.dart';
import 'parent_assigned_activities.dart';
import 'parent_story_telling.dart';
import 'parent_toddler_progress.dart';

class ParentLibraryScreen extends StatefulWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onActivityTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCenterTap;

  const ParentLibraryScreen({
    super.key,
    this.onHomeTap,
    this.onActivityTap,
    this.onBookmarkTap,
    this.onSettingsTap,
    this.onCenterTap,
  });

  @override
  State<ParentLibraryScreen> createState() => _ParentLibraryScreenState();
}

class _ParentLibraryScreenState extends State<ParentLibraryScreen> {
  static const Color bg = Color(0xFFF4FFF6);
  static const Color green = Color(0xFF27C267);
  static const Color greenDark = Color(0xFF179C4C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFE2EFE7);
  static const Color softGreen = Color(0xFFE7F8EE);

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  Timer? _liveTimer;
  bool _loading = true;
  bool _refreshing = false;
  String _error = '';
  String _selectedTopic = '';
  String? _speakingNewsId;
  String? _playingStoryId;
  DateTime? _lastUpdated;

  List<Map<String, dynamic>> _toddlers = [];
  Map<String, dynamic>? _activeToddler;
  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _categories = {};
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _teacherActivities = [];
  List<Map<String, dynamic>> _parentStories = [];
  List<Map<String, dynamic>> _assignedStories = [];
  List<NewsArticle> _savedNews = [];

  @override
  void initState() {
    super.initState();
    _setupTts();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingStoryId = null);
    });
    _loadLibrary(showLoader: true);
    _liveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_refreshing) {
        _loadLibrary(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _tts.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.42);
      await _tts.setLanguage('ur-PK');
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speakingNewsId = null);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _speakingNewsId = null);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _speakingNewsId = null);
      });
    } catch (_) {}
  }

  Future<T?> _tryLoad<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLibrary({bool showLoader = false}) async {
    if (!mounted) return;
    setState(() {
      if (showLoader) _loading = true;
      _refreshing = true;
      _error = '';
    });

    try {
      final toddlersRaw = await _tryLoad<List<dynamic>>(() => ApiService.getToddlers()) ?? [];
      final toddlers = toddlersRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      Map<String, dynamic>? active;
      if (toddlers.isNotEmpty) {
        active = toddlers.firstWhere(
              (t) => t['isActive'] == true,
          orElse: () => toddlers.first,
        );
      }

      final savedNewsData = await _tryLoad<Map<String, dynamic>>(
            () => ApiService.getMySavedNews(page: 1, limit: 30),
      );
      final savedNews = (savedNewsData?['articles'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => NewsArticle.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final storiesRaw = await _tryLoad<List<dynamic>>(() => ApiService.getStories()) ?? [];
      final parentStories = storiesRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      Map<String, dynamic> overview = {};
      Map<String, dynamic> categories = {};
      List<Map<String, dynamic>> activities = [];
      List<Map<String, dynamic>> badges = [];
      List<Map<String, dynamic>> goals = [];
      List<Map<String, dynamic>> teacherActivities = [];
      List<Map<String, dynamic>> assignedStories = [];

      final toddlerId = _idOf(active);
      if (toddlerId.isNotEmpty) {
        final progressData = await _tryLoad<Map<String, dynamic>>(
              () => ApiService.getToddlerActivityProgress(toddlerId: toddlerId),
        );
        if (progressData != null) {
          overview = Map<String, dynamic>.from(progressData['overview'] as Map? ?? {});
          categories = Map<String, dynamic>.from(progressData['categories'] as Map? ?? {});
          activities = (progressData['activities'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          badges = (progressData['badges'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          goals = (progressData['goals'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        final assignmentsRaw = await _tryLoad<List<dynamic>>(
              () => ApiService.getToddlerAssignedActivities(toddlerId),
        ) ?? [];
        teacherActivities = assignmentsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final assignedStoryData = await _tryLoad<Map<String, dynamic>>(
              () => ApiService.getToddlerAssignedStories(toddlerId),
        );
        assignedStories = (assignedStoryData?['stories'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _toddlers = toddlers;
        _activeToddler = active;
        _savedNews = savedNews;
        _parentStories = parentStories;
        _overview = overview;
        _categories = categories;
        _activities = activities;
        _badges = badges;
        _goals = goals;
        _teacherActivities = teacherActivities;
        _assignedStories = assignedStories;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  String _idOf(Map<String, dynamic>? value) {
    if (value == null) return '';
    return (value['_id'] ?? value['id'] ?? '').toString();
  }

  String _activeName() {
    return (_activeToddler?['name'] ?? 'Child').toString();
  }

  String _formatTime(DateTime? value) {
    if (value == null) return 'Just now';
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(dynamic value) {
    final text = value?.toString() ?? '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return 'Recently';
    final d = parsed.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<NewsArticle> get _filteredNews {
    if (_selectedTopic.isEmpty) return _savedNews;
    final topic = _selectedTopic.toLowerCase();
    return _savedNews.where((article) {
      final text = '${article.category} ${article.title} ${article.shortExcerpt}'.toLowerCase();
      if (topic == 'education') {
        return text.contains('education') || text.contains('تعلیم') || text.contains('school') || text.contains('student');
      }
      if (topic == 'sports') {
        return text.contains('sports') || text.contains('کھیل') || text.contains('cricket') || text.contains('match');
      }
      if (topic == 'politics') {
        return text.contains('politics') || text.contains('سیاست') || text.contains('government') || text.contains('election');
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _mockReports {
    return _activities.where((item) => item['activityType'] == 'mock_test').toList();
  }

  int _averageScoreForDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final scored = _activities.where((item) {
      final raw = (item['completedAt'] ?? item['createdAt'])?.toString() ?? '';
      final date = DateTime.tryParse(raw)?.toLocal();
      if (date == null || date.isBefore(cutoff)) return false;
      return _toInt(item['score']) > 0;
    }).toList();
    if (scored.isEmpty) return 0;
    final sum = scored.fold<int>(0, (total, item) => total + _toInt(item['score']));
    return (sum / scored.length).round();
  }

  int _teacherSharedCount() {
    return _mockReports.where((item) {
      final meta = Map<String, dynamic>.from(item['metadata'] as Map? ?? {});
      final createdBy = (meta['createdByRole'] ?? '').toString().toLowerCase();
      return createdBy == 'teacher' || (item['note'] ?? '').toString().toLowerCase().contains('teacher');
    }).length;
  }

  Future<void> _speakNews(NewsArticle article) async {
    final id = article.preferredIdentifier;
    if (_speakingNewsId == id) {
      await _tts.stop();
      if (mounted) setState(() => _speakingNewsId = null);
      return;
    }

    final text = article.summaryUrdu.trim().isNotEmpty
        ? article.summaryUrdu.trim()
        : (article.shortExcerpt.trim().isNotEmpty ? article.shortExcerpt.trim() : article.title.trim());
    if (text.isEmpty) return;

    try {
      await _player.stop();
      setState(() {
        _playingStoryId = null;
        _speakingNewsId = id;
      });
      final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
      await _tts.setLanguage(isUrdu ? 'ur-PK' : 'en-US');
      await _tts.setSpeechRate(isUrdu ? 0.42 : 0.48);
      await _tts.speak(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _speakingNewsId = null);
      _showSnack('Unable to play summary: $e');
    }
  }

  Future<void> _playStory(Map<String, dynamic> story) async {
    final storyId = (story['_id'] ?? story['id'] ?? '').toString();
    if (storyId.isEmpty) return;

    if (_playingStoryId == storyId) {
      await _player.stop();
      if (mounted) setState(() => _playingStoryId = null);
      return;
    }

    try {
      await _tts.stop();
      setState(() {
        _speakingNewsId = null;
        _playingStoryId = storyId;
      });

      final response = await http.get(
        Uri.parse(ApiService.storyAudioUrl(storyId)),
        headers: await ApiService.getAuthHeaders(),
      );

      if (response.statusCode != 200) throw 'Audio not found';

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/parent_library_story_$storyId.m4a';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes, flush: true);

      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      if (!mounted) return;
      setState(() => _playingStoryId = null);
      _showSnack('Unable to play story: $e');
    }
  }

  void _openNews(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewsSummaryScreen(initialArticle: article)),
    );
  }

  void _openProgress() {
    final toddlerId = _idOf(_activeToddler);
    if (toddlerId.isEmpty) {
      _showSnack('Select a child first');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentToddlerProgressScreen(
          toddlerId: toddlerId,
          toddlerName: _activeName(),
        ),
      ),
    );
  }

  void _openStoryStudio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryTellingScreen(
          onHomeTap: widget.onHomeTap == null
              ? null
              : () {
            Navigator.pop(context);
            widget.onHomeTap?.call();
          },
          onActivityTap: widget.onActivityTap == null
              ? null
              : () {
            Navigator.pop(context);
            widget.onActivityTap?.call();
          },
          onBookmarkTap: () => Navigator.pop(context),
          onSettingsTap: widget.onSettingsTap == null
              ? null
              : () {
            Navigator.pop(context);
            widget.onSettingsTap?.call();
          },
          onCenterTap: widget.onCenterTap,
        ),
      ),
    );
  }

  void _openTeacherActivities() {
    final toddlerId = _idOf(_activeToddler);
    if (toddlerId.isEmpty) {
      _showSnack('Select a child first');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignedActivitiesScreen(
          toddlerId: toddlerId,
          toddlerName: _activeName(),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width > 760 ? 720.0 : double.infinity;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green).copyWith(
          primary: green,
          secondary: greenDark,
          surface: Colors.white,
          onSurface: dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: bg,
        bottomNavigationBar: _ParentBottomBar(
          activeIndex: 2,
          centerBadgeCount: _teacherActivities.length,
          onHomeTap: widget.onHomeTap ?? () => Navigator.pop(context),
          onActivityTap: widget.onActivityTap ?? _openProgress,
          onBookmarkTap: () => HapticFeedback.selectionClick(),
          onSettingsTap: widget.onSettingsTap ?? () => Navigator.maybePop(context),
          onCenterTap: widget.onCenterTap ?? _openTeacherActivities,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: green))
              : RefreshIndicator(
            color: green,
            backgroundColor: Colors.white,
            onRefresh: () => _loadLibrary(showLoader: false),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      if (_error.isNotEmpty) _errorCard(),
                      _activeChildCard(),
                      const SizedBox(height: 16),
                      _quickStats(),
                      const SizedBox(height: 18),
                      _savedNewsSection(),
                      const SizedBox(height: 18),
                      _progressReportsSection(),
                      const SizedBox(height: 18),
                      _storiesSection(),
                      const SizedBox(height: 18),
                      _teacherActivitiesSection(),
                      const SizedBox(height: 12),
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

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parent Library',
                style: TextStyle(color: dark, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Saved news, reports, stories, and teacher activities',
                style: TextStyle(color: grey.withOpacity(0.95), fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _RefreshButton(
          refreshing: _refreshing,
          label: _formatTime(_lastUpdated),
          onTap: () => _loadLibrary(showLoader: false),
        ),
      ],
    );
  }

  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFC7C7)),
        ),
        child: Text(_error, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _activeChildCard() {
    final progress = _toInt(_overview['overallProgress'] ?? _overview['speechAccuracy']);
    final suffix = _toddlers.length == 1 ? '' : 's';
    final childProfileText = '${_toddlers.length} child profile$suffix • Live tracking enabled';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFE7F8EE)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: softGreen,
              border: Border.all(color: green.withOpacity(0.25), width: 2),
            ),
            child: const Icon(Icons.family_restroom_rounded, color: greenDark, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Managing ${_activeName()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: dark, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  childProfileText,
                  style: const TextStyle(color: grey, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _CirclePercent(value: progress),
        ],
      ),
    );
  }

  Widget _quickStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final children = [
          _StatCard(icon: Icons.bookmark_rounded, label: 'Saved News', value: '${_savedNews.length}', color: const Color(0xFF2563EB)),
          _StatCard(icon: Icons.assignment_turned_in_rounded, label: 'Reports', value: '${_mockReports.length}', color: green),
          _StatCard(icon: Icons.auto_stories_rounded, label: 'Stories', value: '${_parentStories.length}', color: const Color(0xFFF97316)),
          _StatCard(icon: Icons.school_rounded, label: 'Teacher Tasks', value: '${_teacherActivities.length}', color: const Color(0xFF8B5CF6)),
        ];
        if (compact) {
          return Column(
            children: [
              Row(children: [Expanded(child: children[0]), const SizedBox(width: 10), Expanded(child: children[1])]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: children[2]), const SizedBox(width: 10), Expanded(child: children[3])]),
            ],
          );
        }
        return Row(children: children.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: w))).toList());
      },
    );
  }

  Widget _savedNewsSection() {
    final news = _filteredNews;
    return _SectionCard(
      title: 'Saved Urdu News Summaries',
      subtitle: 'AI Urdu summaries, TTS listening, and continue-reading list',
      icon: Icons.article_rounded,
      actionText: 'Refresh',
      onAction: () => _loadLibrary(showLoader: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TopicChipData('', 'All'),
              _TopicChipData('education', 'Education'),
              _TopicChipData('sports', 'Sports'),
              _TopicChipData('politics', 'Politics'),
            ].map((data) {
              final selected = _selectedTopic == data.key;
              return ChoiceChip(
                selected: selected,
                label: Text(data.label),
                selectedColor: green,
                backgroundColor: const Color(0xFFF5FBF7),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : dark,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
                side: BorderSide(color: selected ? green : border),
                onSelected: (_) => setState(() => _selectedTopic = data.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (news.isEmpty)
            const _EmptyCard(
              icon: Icons.bookmark_add_outlined,
              title: 'No saved news yet',
              subtitle: 'Save Urdu news summaries to continue reading or listening later.',
            )
          else
            ...news.take(5).map((article) => _NewsTile(
              article: article,
              speaking: _speakingNewsId == article.preferredIdentifier,
              onOpen: () => _openNews(article),
              onListen: () => _speakNews(article),
            )),
        ],
      ),
    );
  }

  Widget _progressReportsSection() {
    final weekly = _averageScoreForDays(7);
    final monthly = _averageScoreForDays(30);
    final teacherShared = _teacherSharedCount();

    return _SectionCard(
      title: 'Saved Progress Reports',
      subtitle: 'Mock tests, weekly/monthly progress, and teacher-shared reports',
      icon: Icons.insights_rounded,
      actionText: 'View Details',
      onAction: _openProgress,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final cards = [
                _MiniMetric(title: 'Weekly', value: '$weekly%', icon: Icons.calendar_view_week_rounded, color: green),
                _MiniMetric(title: 'Monthly', value: '$monthly%', icon: Icons.calendar_month_rounded, color: const Color(0xFF2563EB)),
                _MiniMetric(title: 'Teacher Shared', value: '$teacherShared', icon: Icons.forward_to_inbox_rounded, color: const Color(0xFF8B5CF6)),
              ];
              if (compact) {
                return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList());
              }
              return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: c))).toList());
            },
          ),
          const SizedBox(height: 12),
          if (_mockReports.isEmpty)
            const _EmptyCard(
              icon: Icons.assignment_outlined,
              title: 'No mock reports yet',
              subtitle: 'Completed mock tests will appear here in real time.',
            )
          else
            ..._mockReports.take(4).map((report) => _ReportTile(report: report, date: _formatDate(report['completedAt'] ?? report['createdAt']))),
          const SizedBox(height: 8),
          _ComingSoonTile(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Export / Share PDF',
            subtitle: 'PDF report export can be added in the next build.',
          ),
        ],
      ),
    );
  }

  Widget _storiesSection() {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final story in [..._assignedStories, ..._parentStories]) {
      final id = (story['_id'] ?? story['id'] ?? '').toString();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      merged.add(story);
    }

    return _SectionCard(
      title: 'Saved Stories & Poems',
      subtitle: 'Parent recordings, assigned stories, favorites, and recent listening',
      icon: Icons.menu_book_rounded,
      actionText: 'Story Studio',
      onAction: _openStoryStudio,
      child: Column(
        children: [
          if (merged.isEmpty)
            const _EmptyCard(
              icon: Icons.library_books_outlined,
              title: 'No stories saved yet',
              subtitle: 'Record and assign stories from Story Studio to see them here.',
            )
          else
            ...merged.take(5).map((story) => _StoryTile(
              story: story,
              assigned: _assignedStories.any((s) => (s['_id'] ?? s['id']).toString() == (story['_id'] ?? story['id']).toString()),
              playing: _playingStoryId == (story['_id'] ?? story['id']).toString(),
              onPlay: () => _playStory(story),
            )),
          const SizedBox(height: 8),
          const _ComingSoonTile(
            icon: Icons.favorite_rounded,
            title: 'Favorite recordings',
            subtitle: 'Parents will be able to mark best stories as favorites.',
          ),
        ],
      ),
    );
  }

  Widget _teacherActivitiesSection() {
    return _SectionCard(
      title: 'Important Teacher Activities',
      subtitle: 'Assigned mock tests, puzzle activities, pending and completed work',
      icon: Icons.school_rounded,
      actionText: 'View All',
      onAction: _openTeacherActivities,
      child: Column(
        children: [
          if (_teacherActivities.isEmpty)
            const _EmptyCard(
              icon: Icons.task_alt_rounded,
              title: 'No important activities',
              subtitle: 'Teacher assigned tasks will appear here automatically.',
            )
          else
            ..._teacherActivities.take(5).map((task) => _TeacherTaskTile(task: task)),
          if (_goals.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What to do next',
                style: TextStyle(color: dark.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            ..._goals.take(3).map((goal) => _GoalTile(goal: goal)),
          ],
        ],
      ),
    );
  }
}

class _TopicChipData {
  final String key;
  final String label;
  const _TopicChipData(this.key, this.label);
}

class _RefreshButton extends StatelessWidget {
  final bool refreshing;
  final String label;
  final VoidCallback onTap;

  const _RefreshButton({required this.refreshing, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2EFE7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            refreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF27C267)))
                : const Icon(Icons.refresh_rounded, size: 17, color: Color(0xFF27C267)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF14201A), fontSize: 11.5, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _CirclePercent extends StatelessWidget {
  final int value;
  const _CirclePercent({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFF27C267).withOpacity(0.28), width: 4),
      ),
      alignment: Alignment.center,
      child: Text('$value%', style: const TextStyle(color: Color(0xFF179C4C), fontSize: 14, fontWeight: FontWeight.w900)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Color(0xFF14201A), fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionText;
  final VoidCallback onAction;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionText,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EFE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8EE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF179C4C), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF14201A), fontSize: 15.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 11.2, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              TextButton(onPressed: onAction, child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  final NewsArticle article;
  final bool speaking;
  final VoidCallback onOpen;
  final VoidCallback onListen;

  const _NewsTile({required this.article, required this.speaking, required this.onOpen, required this.onListen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF14201A), fontSize: 13.5, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(text: article.category, color: const Color(0xFF2563EB)),
            ],
          ),
          if (article.summaryUrdu.trim().isNotEmpty || article.shortExcerpt.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              article.summaryUrdu.trim().isNotEmpty ? article.summaryUrdu : article.shortExcerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(article.summaryUrdu) ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 12, height: 1.5, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Continue Reading'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onListen,
                style: ElevatedButton.styleFrom(backgroundColor: speaking ? Colors.redAccent : const Color(0xFF27C267), foregroundColor: Colors.white),
                icon: Icon(speaking ? Icons.stop_rounded : Icons.volume_up_rounded, size: 16),
                label: Text(speaking ? 'Stop' : 'Listen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniMetric({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 11.5, fontWeight: FontWeight.w800))),
          Text(value, style: const TextStyle(color: Color(0xFF14201A), fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final String date;

  const _ReportTile({required this.report, required this.date});

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final score = _toInt(report['score']);
    final correct = _toInt(report['correct']);
    final total = _toInt(report['total']);
    final scoreText = total > 0
        ? 'Score $score% • $correct/$total correct • $date'
        : 'Score $score% • $date';

    return _SimpleTile(
      icon: Icons.assignment_rounded,
      iconColor: const Color(0xFF27C267),
      title: report['title']?.toString() ?? 'Mock Test Report',
      subtitle: scoreText,
      trailing: _Pill(text: '$score%', color: const Color(0xFF27C267)),
    );
  }
}

class _StoryTile extends StatelessWidget {
  final Map<String, dynamic> story;
  final bool assigned;
  final bool playing;
  final VoidCallback onPlay;

  const _StoryTile({required this.story, required this.assigned, required this.playing, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final title = (story['title'] ?? 'Story').toString();
    final duration = int.tryParse((story['durationSec'] ?? 0).toString()) ?? 0;
    final min = (duration ~/ 60).toString().padLeft(2, '0');
    final sec = (duration % 60).toString().padLeft(2, '0');
    final childName = (story['toddlerName'] ?? 'child').toString();
    final assignedText = assigned ? 'Assigned to $childName' : 'Parent recording';
    return _SimpleTile(
      icon: assigned ? Icons.mark_email_read_rounded : Icons.auto_stories_rounded,
      iconColor: const Color(0xFFF97316),
      title: title,
      subtitle: '$assignedText • $min:$sec',
      trailing: IconButton(
        onPressed: onPlay,
        icon: Icon(playing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: playing ? Colors.redAccent : const Color(0xFF27C267), size: 30),
      ),
    );
  }
}

class _TeacherTaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  const _TeacherTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final title = (task['title'] ?? 'Teacher Activity').toString();
    final teacherName = (task['teacherName'] ?? 'Teacher').toString();
    final type = (task['activityType'] ?? '').toString().replaceAll('_', ' ');
    return _SimpleTile(
      icon: Icons.star_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: title,
      subtitle: 'By $teacherName • Pending • $type',
      trailing: const _Pill(text: 'Important', color: Color(0xFF8B5CF6)),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Map<String, dynamic> goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F8EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text((goal['icon'] ?? '⭐').toString(), style: const TextStyle(fontSize: 19)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((goal['title'] ?? 'Next Goal').toString(), style: const TextStyle(color: Color(0xFF14201A), fontSize: 12.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text((goal['description'] ?? '').toString(), style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ComingSoonTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return _SimpleTile(
      icon: icon,
      iconColor: const Color(0xFF6E7B80),
      title: title,
      subtitle: subtitle,
      trailing: const _Pill(text: 'Later', color: Color(0xFF6E7B80)),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SimpleTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF14201A), fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 11.2, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF27C267), size: 30),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF14201A), fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ParentBottomBar extends StatelessWidget {
  final int activeIndex;
  final int centerBadgeCount;
  final VoidCallback? onHomeTap;
  final VoidCallback? onActivityTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCenterTap;

  const _ParentBottomBar({
    required this.activeIndex,
    this.centerBadgeCount = 0,
    this.onHomeTap,
    this.onActivityTap,
    this.onBookmarkTap,
    this.onSettingsTap,
    this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.only(left: 18, right: 18, bottom: 10, top: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavIcon(icon: Icons.home_rounded, active: activeIndex == 0, onTap: onHomeTap),
              _NavIcon(icon: Icons.bar_chart_rounded, active: activeIndex == 1, onTap: onActivityTap),
              const SizedBox(width: 46),
              _NavIcon(icon: Icons.bookmark_rounded, active: activeIndex == 2, onTap: onBookmarkTap),
              _NavIcon(icon: Icons.settings_rounded, active: activeIndex == 3, onTap: onSettingsTap),
            ],
          ),
          Positioned(
            bottom: 10,
            child: InkWell(
              onTap: onCenterTap,
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27C267),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF27C267).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 10))],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                  ),
                  if (centerBadgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Text('$centerBadgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _NavIcon({required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, color: active ? const Color(0xFF27C267) : Colors.white70, size: 24),
      ),
    );
  }
}
