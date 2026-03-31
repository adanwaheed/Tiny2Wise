import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/news_article.dart';
import '../services/api_service.dart';
import 'news_summary_screen.dart';
import 'urdu_news_screen.dart';

class SavedNewsScreen extends StatefulWidget {
  const SavedNewsScreen({super.key});

  @override
  State<SavedNewsScreen> createState() => _SavedNewsScreenState();
}

class _SavedNewsScreenState extends State<SavedNewsScreen> {
  static const Color bg = Color(0xFFF2F3F1);
  static const Color green = Color(0xFF31C46C);
  static const Color dark = Color(0xFF202428);
  static const Color textGrey = Color(0xFF81878F);
  static const Color cardBorder = Color(0xFFDDE3D8);

  final List<NewsArticle> _articles = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadSaved(reset: true);
  }

  TextStyle _urduCardTitleStyle() {
    return GoogleFonts.getFont(
      'Noto Nastaliq Urdu',
      textStyle: const TextStyle(
        color: dark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.9,
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
        height: 1.9,
      ),
    );
  }

  String _identifierFor(NewsArticle article) {
    return article.preferredIdentifier;
  }

  Future<void> _loadSaved({required bool reset}) async {
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
      final data = await ApiService.getMySavedNews(
        page: reset ? 1 : _page,
        limit: 20,
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
    await _loadSaved(reset: false);
  }

  Future<bool> _confirmDelete(NewsArticle article) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Saved News'),
          content: const Text(
            'Do you want to remove this news from your saved library?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _deleteSavedNews(NewsArticle article) async {
    final identifier = _identifierFor(article);
    if (identifier.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article identifier missing')),
      );
      return;
    }

    final confirmed = await _confirmDelete(article);
    if (!confirmed) return;

    try {
      final data = await ApiService.saveNewsToLibrary(identifier, saved: false);
      if (!mounted) return;
      setState(() {
        _articles.removeWhere((item) {
          final sameId = item.id.isNotEmpty && article.id.isNotEmpty && item.id == article.id;
          final sameUrl = item.articleUrl.isNotEmpty &&
              article.articleUrl.isNotEmpty &&
              item.articleUrl == article.articleUrl;
          return sameId || sameUrl;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Removed from library')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
    if (c.contains('education') || c.contains('تعلیم')) {
      return const Color(0xFF3B82F6);
    }
    if (c.contains('sports') || c.contains('کھیل')) {
      return const Color(0xFFF59E0B);
    }
    if (c.contains('politic') || c.contains('سیاست') || c.contains('national') || c.contains('قومی')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF64748B);
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      selectedItemColor: green,
      unselectedItemColor: textGrey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UrduNewsScreen()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.newspaper_rounded),
          label: 'News',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_rounded),
          label: 'Saved',
        ),
      ],
    );
  }

  Widget _buildCard(NewsArticle article) {
    final imageUrl = article.imageUrl.trim();

    return Dismissible(
      key: ValueKey(article.id.isNotEmpty ? article.id : article.articleUrl),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(article),
      onDismissed: (_) async {
        await _deleteSavedNews(article);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsSummaryScreen(initialArticle: article),
            ),
          );
          await _loadSaved(reset: true);
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
                  article.shortExcerpt.isNotEmpty ? article.shortExcerpt : article.summaryUrdu,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete saved news',
                    onPressed: () => _deleteSavedNews(article),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
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
          onRefresh: () => _loadSaved(reset: true),
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
                      'Saved News',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _loadSaved(reset: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
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
                  child: const Column(
                    children: [
                      Icon(Icons.bookmark_border_rounded, size: 42, color: textGrey),
                      SizedBox(height: 12),
                      Text(
                        'No saved news yet.',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Saved articles will appear here for future reading.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textGrey),
                      ),
                    ],
                  ),
                )
              else ...[
                  for (final article in _articles) _buildCard(article),
                  const SizedBox(height: 8),
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
                          'Load More Saved News',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
