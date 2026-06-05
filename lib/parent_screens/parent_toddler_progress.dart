import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

const Color bg = Color(0xFFF4FFF6);
const Color green = Color(0xFF27C267);
const Color greenDark = Color(0xFF179C4C);
const Color dark = Color(0xFF14201A);
const Color grey = Color(0xFF6E7B80);
const Color border = Color(0xFFE2EFE7);

class ParentToddlerProgressScreen extends StatefulWidget {
  final String toddlerId;
  final String toddlerName;

  const ParentToddlerProgressScreen({
    super.key,
    required this.toddlerId,
    required this.toddlerName,
  });

  @override
  State<ParentToddlerProgressScreen> createState() => _ParentToddlerProgressScreenState();
}

class _ParentToddlerProgressScreenState extends State<ParentToddlerProgressScreen>
    with WidgetsBindingObserver {
  static const Color bg = Color(0xFFF4FFF6);
  static const Color green = Color(0xFF27C267);
  static const Color greenDark = Color(0xFF179C4C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFE2EFE7);

  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _errorText;

  List<Map<String, dynamic>> _toddlers = [];
  late String _selectedToddlerId;
  late String _selectedToddlerName;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedToddlerId = widget.toddlerId;
    _selectedToddlerName = widget.toddlerName.trim().isEmpty ? 'Toddler' : widget.toddlerName.trim();
    _loadAll();
    _startRealtimeRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadProgress(silent: true);
    }
  }

  void _startRealtimeRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadProgress(silent: true);
    });
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final toddlerList = await ApiService.getToddlers();
      _toddlers = toddlerList
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (_toddlers.isNotEmpty && !_toddlers.any((t) => _idOf(t) == _selectedToddlerId)) {
        final active = _toddlers.firstWhere(
              (t) => t['isActive'] == true,
          orElse: () => _toddlers.first,
        );
        _selectedToddlerId = _idOf(active);
        _selectedToddlerName = _nameOf(active);
      }

      await _loadProgress(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadProgress({bool silent = false}) async {
    if (_selectedToddlerId.trim().isEmpty) return;
    if (!silent && mounted) setState(() => _refreshing = true);

    try {
      final result = await ApiService.getToddlerActivityProgress(
        toddlerId: _selectedToddlerId,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _errorText = null;
        final toddler = _mapOf(result['toddler']);
        final name = '${toddler['name'] ?? ''}'.trim();
        if (name.isNotEmpty) _selectedToddlerName = name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _idOf(Map<String, dynamic> item) => '${item['_id'] ?? item['id'] ?? ''}'.trim();

  String _nameOf(Map<String, dynamic> item) {
    final name = '${item['name'] ?? ''}'.trim();
    return name.isEmpty ? 'Toddler' : name;
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listOf(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  int _intOf(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  String _dateLabel(dynamic value) {
    final raw = '$value';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'mock_test':
        return const Color(0xFF2F80ED);
      case 'games':
        return const Color(0xFF8B5CF6);
      case 'puzzles':
        return const Color(0xFF00B884);
      case 'avatar':
        return const Color(0xFFFF8A00);
      case 'story_telling':
        return const Color(0xFFEC4899);
      default:
        return green;
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'mock_test':
        return Icons.assignment_rounded;
      case 'games':
        return Icons.sports_esports_rounded;
      case 'puzzles':
        return Icons.extension_rounded;
      case 'avatar':
        return Icons.record_voice_over_rounded;
      case 'story_telling':
        return Icons.menu_book_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  String _activityLabel(String type) {
    switch (type) {
      case 'mock_test':
        return 'Mock Tests';
      case 'games':
        return 'Games';
      case 'puzzles':
        return 'Puzzles';
      case 'avatar':
        return 'Avatar Talk';
      case 'story_telling':
        return 'Stories';
      default:
        return 'Activity';
    }
  }

  Future<void> _selectToddler(Map<String, dynamic> toddler) async {
    final id = _idOf(toddler);
    if (id.isEmpty || id == _selectedToddlerId) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedToddlerId = id;
      _selectedToddlerName = _nameOf(toddler);
      _data = null;
      _loading = true;
    });
    await _loadProgress(silent: true);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? <String, dynamic>{};
    final overview = _mapOf(data['overview']);
    final categories = _mapOf(data['categories']);
    final activities = _listOf(data['activities']);
    final badges = _listOf(data['badges']);
    final goals = _listOf(data['goals']);

    final overall = _intOf(overview['overallProgress']);
    final average = _intOf(overview['averageScore']);
    final activityCount = _intOf(overview['totalActivities']);
    final badgeCount = _intOf(overview['totalBadges']);
    final totalPoints = _intOf(overview['totalPoints']);
    final note = '${overview['note'] ?? 'Start practicing to see progress!'}';

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: green).copyWith(
          primary: green,
          surface: Colors.white,
          onSurface: dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: green))
              : RefreshIndicator(
            color: green,
            backgroundColor: Colors.white,
            onRefresh: () => _loadAll(silent: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          name: _selectedToddlerName,
                          refreshing: _refreshing,
                          onBack: () => Navigator.pop(context),
                          onRefresh: () => _loadAll(silent: true),
                        ),
                        const SizedBox(height: 14),
                        if (_toddlers.length > 1) ...[
                          _ToddlerSelector(
                            toddlers: _toddlers,
                            selectedId: _selectedToddlerId,
                            onTap: _selectToddler,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_errorText != null) ...[
                          _ErrorCard(
                            message: _errorText!,
                            onRetry: () => _loadAll(silent: true),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _HeroProgressCard(
                          toddlerName: _selectedToddlerName,
                          percent: overall,
                          note: note,
                          lastActivity: _dateLabel(overview['lastActivityAt']),
                        ),
                        const SizedBox(height: 14),
                        _StatsWrap(
                          activities: activityCount,
                          average: average,
                          badges: badgeCount,
                          points: totalPoints,
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle(
                          title: 'Activity Progress',
                          subtitle: 'Mock tests, games, puzzles, avatar and stories are tracked separately.',
                        ),
                        const SizedBox(height: 10),
                        _CategoryGrid(
                          categories: categories,
                          colorFor: _activityColor,
                          iconFor: _activityIcon,
                          labelFor: _activityLabel,
                          intOf: _intOf,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: _SectionTitle(
                                title: 'Recent Activity',
                                subtitle: 'Live updates every few seconds.',
                              ),
                            ),
                            if (_refreshing)
                              const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: green),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (activities.isEmpty)
                          const _EmptyActivityCard()
                        else
                          ...activities.take(12).map((activity) {
                            final type = '${activity['activityType'] ?? ''}';
                            return _ActivityTile(
                              title: '${activity['title'] ?? _activityLabel(type)}',
                              note: '${activity['note'] ?? ''}',
                              score: _intOf(activity['score']),
                              total: _intOf(activity['total']),
                              correct: _intOf(activity['correct']),
                              completed: _intOf(activity['completed']),
                              date: _dateLabel(activity['completedAt']),
                              color: _activityColor(type),
                              icon: _activityIcon(type),
                            );
                          }),
                        const SizedBox(height: 18),
                        const _SectionTitle(
                          title: 'Badges Earned',
                          subtitle: 'Trophies and stars unlocked by good practice.',
                        ),
                        const SizedBox(height: 10),
                        badges.isEmpty
                            ? const _SmallNotice(
                          icon: Icons.emoji_events_outlined,
                          text: 'No badges yet. Complete activities to unlock medals.',
                        )
                            : _BadgeStrip(badges: badges),
                        const SizedBox(height: 18),
                        const _SectionTitle(
                          title: 'What To Do Next',
                          subtitle: 'Simple next steps for better speech progress.',
                        ),
                        const SizedBox(height: 10),
                        if (goals.isEmpty)
                          const _SmallNotice(
                            icon: Icons.auto_awesome_rounded,
                            text: 'Keep daily practice going to build a strong streak.',
                          )
                        else
                          ...goals.map((goal) => _GoalTile(goal: goal)),
                      ],
                    ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.refreshing,
    required this.onBack,
    required this.onRefresh,
  });

  final String name;
  final bool refreshing;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Toddler Progress',
                style: TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w900),
              ),
              Text(
                'Live tracking for $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _CircleButton(
          icon: refreshing ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(icon, color: dark, size: 22),
        ),
      ),
    );
  }
}

class _ToddlerSelector extends StatelessWidget {
  const _ToddlerSelector({
    required this.toddlers,
    required this.selectedId,
    required this.onTap,
  });

  final List<Map<String, dynamic>> toddlers;
  final String selectedId;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: toddlers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final toddler = toddlers[index];
          final id = '${toddler['_id'] ?? toddler['id'] ?? ''}'.trim();
          final name = '${toddler['name'] ?? 'Toddler'}'.trim();
          final selected = id == selectedId;
          final rawPhoto = '${toddler['photoUrl'] ?? toddler['imageUrl'] ?? ''}'.trim();
          final photoUrl = rawPhoto.isEmpty ? '' : ApiService.absoluteUrl(rawPhoto);

          return GestureDetector(
            onTap: () => onTap(toddler),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? green.withOpacity(0.13) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? green : border, width: selected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ToddlerPhoto(name: name, photoUrl: photoUrl, active: selected),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? greenDark : dark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToddlerPhoto extends StatelessWidget {
  const _ToddlerPhoto({required this.name, required this.photoUrl, required this.active});

  final String name;
  final String photoUrl;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const double photoSize = 46;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'T';
    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(color: active ? greenDark : dark, fontWeight: FontWeight.w900, fontSize: 18),
      ),
    );

    Widget circleChild(Widget child) {
      return SizedBox(
        width: photoSize,
        height: photoSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: active ? green : const Color(0xFFD7F3E2), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: child),
          ),
        ),
      );
    }

    if (photoUrl.isEmpty) {
      return circleChild(Container(color: const Color(0xFFE8F8EE), child: fallback));
    }

    return FutureBuilder<String?>(
      future: ApiService.getToken(),
      builder: (context, snap) {
        return circleChild(
          Image.network(
            photoUrl,
            fit: BoxFit.cover,
            width: photoSize,
            height: photoSize,
            headers: snap.data == null ? null : {'Authorization': 'Bearer ${snap.data}'},
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8F8EE), child: fallback),
          ),
        );
      },
    );
  }
}

class _HeroProgressCard extends StatelessWidget {
  const _HeroProgressCard({
    required this.toddlerName,
    required this.percent,
    required this.note,
    required this.lastActivity,
  });

  final String toddlerName;
  final int percent;
  final String note;
  final String lastActivity;

  @override
  Widget build(BuildContext context) {
    final progress = (percent.clamp(0, 100)) / 100;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: green.withOpacity(0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFE0F8E9), green.withOpacity(0.12)],
        ),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'REAL TIME PROGRESS',
                    style: TextStyle(color: greenDark, fontSize: 11.5, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$percent%',
                  style: const TextStyle(color: dark, fontSize: 42, fontWeight: FontWeight.w900, height: 1),
                ),
                const SizedBox(height: 8),
                Text(
                  '$toddlerName\'s activity progress is updated automatically.',
                  style: const TextStyle(color: dark, fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  note,
                  style: const TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last activity: $lastActivity',
                  style: TextStyle(color: greenDark.withOpacity(0.9), fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            height: 96,
            width: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 90,
                  width: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    color: green,
                    backgroundColor: const Color(0xFFDDF3E5),
                  ),
                ),
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: green, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsWrap extends StatelessWidget {
  const _StatsWrap({
    required this.activities,
    required this.average,
    required this.badges,
    required this.points,
  });

  final int activities;
  final int average;
  final int badges;
  final int points;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 390
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatCard(width: itemWidth, icon: Icons.task_alt_rounded, label: 'Activities', value: '$activities', color: green),
            _StatCard(width: itemWidth, icon: Icons.speed_rounded, label: 'Avg Score', value: '$average%', color: const Color(0xFF2F80ED)),
            _StatCard(width: itemWidth, icon: Icons.emoji_events_rounded, label: 'Badges', value: '$badges', color: const Color(0xFFFF8A00)),
            _StatCard(width: itemWidth, icon: Icons.stars_rounded, label: 'Points', value: '$points', color: const Color(0xFF8B5CF6)),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: grey, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: dark, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: grey, fontSize: 12.2, fontWeight: FontWeight.w700, height: 1.25)),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.colorFor,
    required this.iconFor,
    required this.labelFor,
    required this.intOf,
  });

  final Map<String, dynamic> categories;
  final Color Function(String type) colorFor;
  final IconData Function(String type) iconFor;
  final String Function(String type) labelFor;
  final int Function(dynamic value) intOf;

  @override
  Widget build(BuildContext context) {
    const types = ['mock_test', 'games', 'puzzles', 'avatar', 'story_telling'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 520 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: types.map((type) {
            final item = categories[type] is Map ? Map<String, dynamic>.from(categories[type]) : <String, dynamic>{};
            final count = intOf(item['count']);
            final score = intOf(item['averageScore']);
            final color = colorFor(type);
            return Container(
              width: width,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(16)),
                    child: Icon(iconFor(type), color: color, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(labelFor(type), style: const TextStyle(color: dark, fontSize: 13.2, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (score.clamp(0, 100)) / 100,
                            minHeight: 7,
                            backgroundColor: color.withOpacity(0.10),
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text('$count done • $score% avg', style: const TextStyle(color: grey, fontSize: 11.4, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.note,
    required this.score,
    required this.total,
    required this.correct,
    required this.completed,
    required this.date,
    required this.color,
    required this.icon,
  });

  final String title;
  final String note;
  final int score;
  final int total;
  final int correct;
  final int completed;
  final String date;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final detail = total > 0 ? '$correct/$total correct' : '$completed completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: dark, fontSize: 13.4, fontWeight: FontWeight.w900)),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: grey, fontSize: 11.8, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 6),
                Text('$detail • $date', style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(13)),
            child: Text('$score%', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _BadgeStrip extends StatelessWidget {
  const _BadgeStrip({required this.badges});

  final List<Map<String, dynamic>> badges;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final badge = badges[index];
          final icon = '${badge['icon'] ?? '🏅'}';
          final title = '${badge['title'] ?? 'Badge'}';
          final color = _hexToColor('${badge['colorHex'] ?? '#27C267'}');
          return Container(
            width: 118,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.22)),
            ),
            child: Column(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 25))),
                ),
                const SizedBox(height: 8),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: dark, fontSize: 11.5, fontWeight: FontWeight.w900)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final Map<String, dynamic> goal;

  @override
  Widget build(BuildContext context) {
    final title = '${goal['title'] ?? 'Next Goal'}';
    final description = '${goal['description'] ?? 'Keep practicing.'}';
    final icon = '${goal['icon'] ?? '⭐'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(color: green.withOpacity(0.11), borderRadius: BorderRadius.circular(15)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 23))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: dark, fontSize: 13.4, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(color: grey, fontSize: 11.8, fontWeight: FontWeight.w700, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallNotice extends StatelessWidget {
  const _SmallNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: green, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome_rounded, color: green, size: 44),
          SizedBox(height: 10),
          Text('No activity recorded yet', style: TextStyle(color: dark, fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text(
            'When your toddler completes mock tests, games, puzzles, avatar practice, or stories, progress will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: dark, fontSize: 12.5, fontWeight: FontWeight.w800))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

Color _hexToColor(String value) {
  var hex = value.replaceAll('#', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.tryParse(hex, radix: 16) ?? 0xFF27C267);
}
