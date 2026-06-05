import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class ToddlerBadgesScreen extends StatefulWidget {
  const ToddlerBadgesScreen({super.key});

  @override
  State<ToddlerBadgesScreen> createState() => _ToddlerBadgesScreenState();
}

class _ToddlerBadgesScreenState extends State<ToddlerBadgesScreen> {
  static const Color _purple = Color(0xFF7C35F2);
  static const Color _pink = Color(0xFFFF4CA8);
  static const Color _orange = Color(0xFFFF9F1C);
  static const Color _green = Color(0xFF18C964);
  static const Color _blue = Color(0xFF3193FF);
  static const Color _dark = Color(0xFF152238);
  static const Color _muted = Color(0xFF6E7B8A);

  bool _loading = true;
  bool _refreshing = false;
  String _error = '';
  Map<String, dynamic>? _activeToddler;
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _nextGoals = [];
  int _earnedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (silent) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = '';
    });

    try {
      final toddler = await ApiService.getActiveToddler();
      if (toddler == null) {
        throw 'Please add and select a toddler profile first.';
      }

      final toddlerId = (toddler['_id'] ?? toddler['id'] ?? '').toString();
      if (toddlerId.trim().isEmpty) throw 'Active toddler id not found.';

      final data = await ApiService.getToddlerBadges(toddlerId: toddlerId);
      final rawBadges = data['badges'] as List<dynamic>? ?? [];
      final rawGoals = data['nextGoals'] as List<dynamic>? ?? [];
      final summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});

      if (!mounted) return;
      setState(() {
        _activeToddler = toddler;
        _badges = rawBadges
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _nextGoals = rawGoals
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _earnedCount = _toInt(summary['earnedCount'], fallback: _badges.length);
        _totalCount = _toInt(summary['totalCount'], fallback: _nextGoals.length + _badges.length);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _toddlerName() {
    final name = (_activeToddler?['name'] ?? 'Little Star').toString().trim();
    return name.isEmpty ? 'Little Star' : name;
  }

  Color _colorFor(String key) {
    switch (key) {
      case 'mock_test_trophy':
        return const Color(0xFFFFB703);
      case 'puzzle_master':
        return const Color(0xFF4F46E5);
      case 'games_speaker_star':
        return const Color(0xFFFF4CA8);
      case 'avatar_good_listener':
        return const Color(0xFF00B894);
      case 'practice_champion':
        return const Color(0xFFFF6B1A);
      default:
        return _purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : _error.isNotEmpty
            ? _ErrorState(message: _error, onRetry: () => _loadBadges())
            : RefreshIndicator(
          color: _purple,
          onRefresh: () => _loadBadges(silent: true),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isWide = width >= 720;
              final columns = width >= 920 ? 4 : width >= 620 ? 3 : 2;
              final progress = _totalCount == 0 ? 0.0 : (_earnedCount / _totalCount).clamp(0.0, 1.0);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isWide ? 28 : 16,
                  12,
                  isWide ? 28 : 16,
                  30 + MediaQuery.of(context).padding.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          toddlerName: _toddlerName(),
                          refreshing: _refreshing,
                          onBack: () => Navigator.pop(context),
                          onRefresh: () => _loadBadges(silent: true),
                        ),
                        const SizedBox(height: 18),
                        _HeroCard(
                          earnedCount: _earnedCount,
                          totalCount: _totalCount,
                          progress: progress,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'My Badges',
                          style: GoogleFonts.poppins(
                            color: _dark,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_badges.isEmpty)
                          _EmptyBadgesCard(name: _toddlerName())
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _badges.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: width < 360 ? 0.76 : 0.84,
                            ),
                            itemBuilder: (context, index) {
                              final badge = _badges[index];
                              final key = badge['badgeKey']?.toString() ?? '';
                              return _BadgeCard(
                                badge: badge,
                                color: _colorFor(key),
                              );
                            },
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'What To Do Next?',
                          style: GoogleFonts.poppins(
                            color: _dark,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _GoalList(
                          goals: _nextGoals,
                          colorFor: _colorFor,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.toddlerName,
    required this.refreshing,
    required this.onBack,
    required this.onRefresh,
  });

  final String toddlerName;
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
              Text(
                'Badges & Medals 🏅',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF152238),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$toddlerName\'s achievement shelf',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF6E7B8A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.earnedCount,
    required this.totalCount,
    required this.progress,
  });

  final int earnedCount;
  final int totalCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C35F2), Color(0xFFFF4CA8), Color(0xFFFFB703)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C35F2).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.45), width: 2),
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 54)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Super Star Progress',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$earnedCount of ${totalCount == 0 ? 5 : totalCount} badges earned',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 11,
                    backgroundColor: Colors.white.withOpacity(0.28),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.color});

  final Map<String, dynamic> badge;
  final Color color;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final emoji = (badge['iconEmoji'] ?? '🏅').toString();
    final title = (badge['title'] ?? 'Badge').toString();
    final description = (badge['description'] ?? '').toString();
    final source = (badge['source'] ?? 'Tiny2Wise').toString();
    final score = _toInt(badge['score']);
    final count = _toInt(badge['progressCount']);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(0.22), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.70)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 38))),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF152238),
              fontSize: 13.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF6E7B8A),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.center,
            children: [
              _TinyChip(text: source, color: color),
              if (score > 0) _TinyChip(text: '$score%', color: color),
              if (count > 1) _TinyChip(text: 'x$count', color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList({required this.goals, required this.colorFor});

  final List<Map<String, dynamic>> goals;
  final Color Function(String key) colorFor;

  @override
  Widget build(BuildContext context) {
    final visibleGoals = goals.isEmpty ? _fallbackGoals : goals;
    return Column(
      children: visibleGoals.map((goal) {
        final key = goal['badgeKey']?.toString() ?? '';
        final earned = goal['earned'] == true;
        final color = colorFor(key);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: earned ? const Color(0xFF18C964).withOpacity(0.35) : color.withOpacity(0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: earned ? const Color(0xFF18C964).withOpacity(0.14) : color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    (goal['iconEmoji'] ?? '⭐').toString(),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (goal['title'] ?? 'Next Badge').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF152238),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      earned
                          ? 'Already earned. Keep practicing to shine more!'
                          : (goal['goalText'] ?? goal['description'] ?? 'Practice more to unlock this badge.').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6E7B8A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                earned ? Icons.check_circle_rounded : Icons.lock_open_rounded,
                color: earned ? const Color(0xFF18C964) : color,
                size: 25,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static final List<Map<String, dynamic>> _fallbackGoals = [
    {
      'badgeKey': 'games_speaker_star',
      'title': 'Speaker Star',
      'iconEmoji': '⭐',
      'goalText': 'Score 70% or more in Speech Games.',
      'earned': false,
    },
    {
      'badgeKey': 'puzzle_master',
      'title': 'Puzzle Master',
      'iconEmoji': '🧩',
      'goalText': 'Complete a puzzle and say every word.',
      'earned': false,
    },
    {
      'badgeKey': 'mock_test_trophy',
      'title': 'Mock Test Trophy',
      'iconEmoji': '🏆',
      'goalText': 'Score 70% or more in a mock test.',
      'earned': false,
    },
  ];
}

class _EmptyBadgesCard extends StatelessWidget {
  const _EmptyBadgesCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.45), width: 2),
            ),
            child: const Center(child: Text('🏅', style: TextStyle(fontSize: 46))),
          ),
          const SizedBox(height: 14),
          Text(
            'No badges yet for $name',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF152238),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Play games, solve puzzles, complete mock tests, and talk with Noor to unlock shiny medals.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF6E7B8A),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
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
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.14),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(icon, color: const Color(0xFF152238), size: 22),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😕', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 12),
              Text(
                'Badges could not load',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Color(0xFF152238),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Color(0xFF6E7B8A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF7C35F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: Icon(Icons.refresh_rounded),
                label: Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
