import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/news_article.dart';
import '../services/api_service.dart';
import 'news_summary_screen.dart';
import 'saved_news.dart';

class UrduNewsScreen extends StatefulWidget {
  const UrduNewsScreen({super.key});

  @override
  State<UrduNewsScreen> createState() => _UrduNewsScreenState();
}

class _UrduNewsScreenState extends State<UrduNewsScreen> {
  static const Color bg = Color(0xFFF2F3F1);
  static const Color green = Color(0xFF31C46C);
  static const Color dark = Color(0xFF202428);
  static const Color textGrey = Color(0xFF81878F);
  static const Color cardBorder = Color(0xFFDDE3D8);

  final List<int> _tabs = const [7, 14, 30];
  final List<Map<String, String>> _topics = const [
    {'key': '', 'label': 'All News', 'urdu': 'تمام خبریں'},
    {'key': 'education', 'label': 'Education', 'urdu': 'تعلیم'},
    {'key': 'sports', 'label': 'Sports', 'urdu': 'کھیل'},
    {'key': 'politics', 'label': 'Politics', 'urdu': 'سیاست'},
  ];

  final List<NewsArticle> _articles = [];
  int _selectedDays = 7;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String _query = '';
  String _selectedTopic = '';

  @override
  void initState() {
    super.initState();
    _loadNews(reset: true);
  }

  TextStyle _urduCardTitleStyle() {
    return GoogleFonts.getFont(
      'Noto Nastaliq Urdu',
      textStyle: const TextStyle(
        color: dark,
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.85,
      ),
    );
  }

  TextStyle _urduExcerptStyle() {
    return GoogleFonts.getFont(
      'Noto Nastaliq Urdu',
      textStyle: const TextStyle(
        color: textGrey,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.85,
      ),
    );
  }

  String get _selectedTopicLabel {
    final match = _topics.where((e) => e['key'] == _selectedTopic).toList();
    if (match.isEmpty) return '';
    return match.first['label'] ?? '';
  }

  Future<void> _loadNews({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final data = await ApiService.getNewsArticles(
        days: _selectedDays,
        page: reset ? 1 : _page,
        limit: 8,
        query: _query,
        topic: _selectedTopic,
      );

      final fetched = (data['articles'] as List<dynamic>? ?? [])
          .map((e) => NewsArticle.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final pagination = Map<String, dynamic>.from(
        data['pagination'] as Map? ?? const {},
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _articles
            ..clear()
            ..addAll(fetched);
        } else {
          _articles.addAll(fetched);
        }
        _hasMore = pagination['hasMore'] == true;
        _page = (pagination['page'] as num?)?.toInt() ?? (reset ? 1 : _page);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _page += 1);
    await _loadNews(reset: false);
  }

  Future<void> _refreshNow() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ApiService.refreshNews();
      await _loadNews(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _refreshing = false);
    }
  }

  Future<void> _openTopicSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose News Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap one category to filter the latest summarized news.',
                  style: TextStyle(color: textGrey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final item in _topics)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: item['key'] == _selectedTopic
                          ? green.withOpacity(0.16)
                          : const Color(0xFFF1F4EF),
                      child: Icon(
                        item['key'] == 'education'
                            ? Icons.school_rounded
                            : item['key'] == 'sports'
                            ? Icons.sports_cricket_rounded
                            : item['key'] == 'politics'
                            ? Icons.account_balance_rounded
                            : Icons.newspaper_rounded,
                        color: item['key'] == _selectedTopic ? green : dark,
                      ),
                    ),
                    title: Text(
                      item['label'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(item['urdu'] ?? ''),
                    trailing: item['key'] == _selectedTopic
                        ? const Icon(Icons.check_circle_rounded, color: green)
                        : null,
                    onTap: () => Navigator.pop(context, item['key']),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    setState(() {
      _selectedTopic = result;
      _query = '';
    });
    await _loadNews(reset: true);
  }

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'recently';
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Color _badgeColor(String category) {
    final c = category.toLowerCase();
    if (c.contains('education') || c.contains('تعلیم')) return const Color(0xFF3B82F6);
    if (c.contains('national') || c.contains('قومی') || c.contains('politic')) return const Color(0xFFEF4444);
    if (c.contains('sports') || c.contains('کھیل')) return const Color(0xFFF59E0B);
    if (c.contains('weather') || c.contains('موسم')) return const Color(0xFF06B6D4);
    if (c.contains('technology') || c.contains('ٹیک')) return const Color(0xFFA855F7);
    return const Color(0xFF64748B);
  }

  Widget _buildChip(int day) {
    final selected = _selectedDays == day;
    return GestureDetector(
      onTap: () async {
        if (_selectedDays == day) return;
        setState(() => _selectedDays = day);
        await _loadNews(reset: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? green : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? green : const Color(0xFFD8DDD7)),
          boxShadow: selected
              ? [
            BoxShadow(
              color: green.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Text(
          'Last $day Days',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF626971),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(NewsArticle article) {
    final imageUrl = article.imageUrl.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsSummaryScreen(initialArticle: article),
          ),
        );
        await _loadNews(reset: true);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _badgeColor(article.category),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          article.category.isEmpty ? 'GENERAL' : article.category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _urduCardTitleStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: imageUrl.isEmpty
                        ? Container(
                      color: const Color(0xFFE7ECE6),
                      child: const Icon(Icons.image_outlined, color: textGrey),
                    )
                        : Image.network(
                      ApiService.absoluteUrl(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE7ECE6),
                        child: const Icon(Icons.broken_image_outlined, color: textGrey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                article.shortExcerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _urduExcerptStyle(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${article.sourceName} • ${_timeAgo(article.publishedAt)}',
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _onBottomTap(int index) {
    if (index == 0) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UrduNewsScreen()),
        );
      }
      return;
    }

    if (index == 1) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SavedNewsScreen()),
        );
      }
    }
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? green : textGrey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? green : textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _bottomNavItem(
              icon: Icons.newspaper_rounded,
              label: 'News',
              selected: true,
              onTap: () {},
            ),
            _bottomNavItem(
              icon: Icons.bookmark_rounded,
              label: 'Saved',
              selected: false,
              onTap: () => _onBottomTap(1),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: RefreshIndicator(
          color: green,
          onRefresh: _refreshNow,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  ),
                  const Expanded(
                    child: Text(
                      'Urdu News',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openTopicSheet,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final day in _tabs) ...[
                      _buildChip(day),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              if (_selectedTopic.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Text(
                        'Category: $_selectedTopicLabel',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        setState(() => _selectedTopic = '');
                        await _loadNews(reset: true);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator(color: green)),
                )
              else if (_articles.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.newspaper_rounded, size: 42, color: textGrey),
                      const SizedBox(height: 12),
                      Text(
                        _selectedTopic.isEmpty
                            ? 'No news found right now.'
                            : 'No $_selectedTopicLabel news found for the selected days.',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pull down to refresh or try another day filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textGrey),
                      ),
                    ],
                  ),
                )
              else ...[
                  for (final article in _articles) _buildCard(article),
                  const SizedBox(height: 10),
                  if (_loadingMore)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(color: green),
                      ),
                    )
                  else if (_hasMore)
                    Center(
                      child: OutlinedButton(
                        onPressed: _loadMore,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: dark,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          side: const BorderSide(color: cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Load More Articles',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _refreshing ? null : _refreshNow,
                  icon: _refreshing
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: green),
                  )
                      : const Icon(Icons.refresh_rounded, color: green),
                  label: Text(
                    _refreshing ? 'Refreshing...' : 'Refresh Latest News',
                    style: const TextStyle(color: green, fontWeight: FontWeight.w700),
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