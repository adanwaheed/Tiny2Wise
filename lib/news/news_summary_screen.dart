import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/news_article.dart';
import '../services/api_service.dart';
import 'saved_news.dart';
import 'urdu_news_screen.dart';

class NewsSummaryScreen extends StatefulWidget {
  final NewsArticle initialArticle;

  const NewsSummaryScreen({super.key, required this.initialArticle});

  @override
  State<NewsSummaryScreen> createState() => _NewsSummaryScreenState();
}

class _NewsSummaryScreenState extends State<NewsSummaryScreen> {
  static const Color bg = Color(0xFFF5F5F3);
  static const Color green = Color(0xFF2FC96F);
  static const Color dark = Color(0xFF202428);
  static const Color grey = Color(0xFF8A8F96);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE0E4DE);
  static const Color softGreen = Color(0xFFE6F8EB);

  final FlutterTts _tts = FlutterTts();

  NewsArticle? _article;
  bool _loading = true;
  bool _saving = false;
  bool _isSpeaking = false;
  double _progress = 0;
  double _speechRate = 1.0;
  int _estimatedTotalSeconds = 0;
  String _activeIdentifier = '';

  @override
  void initState() {
    super.initState();
    _article = widget.initialArticle;
    _activeIdentifier = widget.initialArticle.preferredIdentifier;
    _estimatedTotalSeconds = _estimateSeconds(widget.initialArticle.summaryUrdu);
    _setupTts();
    _load();
  }

  TextStyle _urduTitleStyle({double size = 28, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.getFont(
      'Noto Nastaliq Urdu',
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: dark,
        height: 1.95,
      ),
    );
  }

  TextStyle _urduBodyStyle({
    double size = 18,
    FontWeight weight = FontWeight.w600,
    Color color = dark,
    double height = 2.0,
  }) {
    return GoogleFonts.getFont(
      'Noto Nastaliq Urdu',
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      ),
    );
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('ur-PK');
    await _tts.setPitch(1.0);
    await _applySpeechRate();
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = true;
        _progress = 0;
      });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _progress = 1;
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });

    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });

    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted || text.isEmpty) return;
      setState(() {
        _progress = end / text.length;
        if (_progress > 1) _progress = 1;
      });
    });
  }

  Future<void> _applySpeechRate() async {
    final mapped = _speechRate == 1.2
        ? 0.56
        : _speechRate == 0.9
        ? 0.42
        : 0.48;
    await _tts.setSpeechRate(mapped);
  }

  List<String> _identifiersFor(NewsArticle article) {
    final values = <String>[];

    void add(String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (!values.contains(v)) values.add(v);
    }

    add(_activeIdentifier);
    add(article.id);
    add(article.articleUrl);
    return values;
  }

  Future<Map<String, dynamic>> _tryDetail(List<String> identifiers) async {
    Object? lastError;
    for (final identifier in identifiers) {
      try {
        final data = await ApiService.getNewsDetail(identifier);
        _activeIdentifier = identifier;
        return data;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? 'Failed to load news detail';
  }

  Future<Map<String, dynamic>> _trySummary(List<String> identifiers) async {
    Object? lastError;
    for (final identifier in identifiers) {
      try {
        final data = await ApiService.summarizeNews(identifier);
        _activeIdentifier = identifier;
        return data;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? 'Failed to summarize news';
  }

  Future<void> _load() async {
    final preview = _article ?? widget.initialArticle;

    setState(() {
      _loading = true;
      _article = preview;
    });

    try {
      final identifiers = _identifiersFor(preview);
      if (identifiers.isEmpty) {
        throw 'Article identifier missing';
      }

      final detail = await _tryDetail(identifiers);
      final articleJson = Map<String, dynamic>.from(detail['article'] as Map);
      var detailedArticle = NewsArticle.fromJson(articleJson);

      final hasReadySummary =
          detailedArticle.summaryUrdu.trim().isNotEmpty && detailedArticle.bulletPointsUrdu.isNotEmpty;

      if (!hasReadySummary) {
        try {
          final summary = await _trySummary(_identifiersFor(detailedArticle));
          detailedArticle = detailedArticle.copyWith(
            summaryUrdu: summary['summaryUrdu']?.toString().trim().isNotEmpty == true
                ? summary['summaryUrdu']?.toString()
                : detailedArticle.summaryUrdu,
            bulletPointsUrdu: (summary['bulletPointsUrdu'] as List<dynamic>? ?? [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList(),
            saved: summary['saved'] == true ? true : detailedArticle.saved,
          );
        } catch (_) {
          final fallbackSummary = detailedArticle.summaryUrdu.trim().isNotEmpty
              ? detailedArticle.summaryUrdu.trim()
              : detailedArticle.shortExcerpt.trim().isNotEmpty
              ? detailedArticle.shortExcerpt.trim()
              : detailedArticle.title.trim();

          final fallbackPoints = detailedArticle.bulletPointsUrdu.isNotEmpty
              ? detailedArticle.bulletPointsUrdu
              : [fallbackSummary];

          detailedArticle = detailedArticle.copyWith(
            summaryUrdu: fallbackSummary,
            bulletPointsUrdu: fallbackPoints,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _article = detailedArticle;
        _estimatedTotalSeconds = _estimateSeconds(_buildTtsText(detailedArticle));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _buildTtsText(NewsArticle article) {
    return [
      ...article.bulletPointsUrdu.map((e) => 'اہم نکتہ۔ $e۔'),
      article.summaryUrdu,
    ].where((e) => e.trim().isNotEmpty).join(' ');
  }

  int _estimateSeconds(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .length;
    final divisor = _speechRate == 1.2
        ? 3.2
        : _speechRate == 0.9
        ? 2.3
        : 2.7;
    final seconds = (words / divisor).round();
    return seconds.clamp(10, 1800);
  }

  String _formatSeconds(int seconds) {
    final mins = (seconds ~/ 60).toString();
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'recently';
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Future<void> _toggleTts() async {
    final article = _article;
    if (article == null) return;

    if (_isSpeaking) {
      await _tts.stop();
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      return;
    }

    final text = _buildTtsText(article);
    if (text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary is not ready yet')),
      );
      return;
    }

    _estimatedTotalSeconds = _estimateSeconds(text);
    setState(() => _progress = 0);
    await _tts.speak(text);
  }

  Future<void> _toggleSave() async {
    final article = _article;
    if (article == null || _saving) return;

    final identifiers = _identifiersFor(article);
    if (identifiers.isEmpty) return;

    setState(() => _saving = true);
    try {
      Object? lastError;
      Map<String, dynamic>? data;
      for (final identifier in identifiers) {
        try {
          data = await ApiService.saveNewsToLibrary(
            identifier,
            saved: !article.saved,
          );
          _activeIdentifier = identifier;
          break;
        } catch (e) {
          lastError = e;
        }
      }

      if (data == null) throw lastError ?? 'Failed to update library';

      final updated = article.copyWith(saved: data['saved'] == true);
      if (!mounted) return;
      setState(() => _article = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _shareSummary() async {
    final article = _article;
    if (article == null) return;

    final text = [
      article.title,
      '',
      'اہم نکات:',
      ...article.bulletPointsUrdu.map((e) => '• $e'),
      '',
      article.summaryUrdu,
      if (article.articleUrl.isNotEmpty) ...['', article.articleUrl],
    ].join('\n');

    await Share.share(text, subject: article.title);
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
              Icon(icon, color: selected ? green : grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? green : grey,
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
          border: Border.all(color: border),
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
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: _loading && article == null
            ? const Center(child: CircularProgressIndicator(color: green))
            : article == null
            ? const Center(child: Text('Unable to load article'))
            : ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                const Expanded(
                  child: Text(
                    'News Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  article.title,
                  textAlign: TextAlign.center,
                  style: _urduTitleStyle(size: 25, weight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFBF1C2C),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    article.sourceName.isNotEmpty
                        ? article.sourceName.substring(0, 1).toUpperCase()
                        : 'N',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    article.sourceName,
                    style: const TextStyle(
                      color: dark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _timeAgo(article.publishedAt),
                  style: const TextStyle(
                    color: grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.volume_up_rounded, color: green, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Listen to Summary',
                          style: TextStyle(
                            color: dark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          setState(() {
                            _speechRate = _speechRate == 0.9
                                ? 1.0
                                : _speechRate == 1.0
                                ? 1.2
                                : 0.9;
                            _estimatedTotalSeconds = _estimateSeconds(_buildTtsText(article));
                          });
                          await _applySpeechRate();
                        },
                        child: Text(
                          '${_speechRate.toStringAsFixed(1)}x Speed',
                          style: const TextStyle(
                            color: green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        _formatSeconds((_estimatedTotalSeconds * _progress).round()),
                        style: const TextStyle(color: grey, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        _formatSeconds(_estimatedTotalSeconds),
                        style: const TextStyle(color: grey, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress.clamp(0, 1),
                      minHeight: 4,
                      backgroundColor: const Color(0xFFDCE4DA),
                      valueColor: const AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      onTap: _toggleTts,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: green,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: green.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD5EFD9)),
              ),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'KEY POINTS',
                          style: TextStyle(
                            color: grey,
                            fontSize: 12,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          'اہم نکات',
                          style: TextStyle(
                            color: green,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (article.bulletPointsUrdu.isEmpty)
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        'خلاصہ تیار کیا جا رہا ہے۔',
                        style: _urduBodyStyle(size: 16, weight: FontWeight.w600),
                      ),
                    )
                  else
                    for (final point in article.bulletPointsUrdu) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: Icon(Icons.circle, size: 7, color: green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                point,
                                style: _urduBodyStyle(size: 16, weight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  const Text(
                    'FULL SUMMARY',
                    style: TextStyle(
                      color: grey,
                      fontSize: 12,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      article.summaryUrdu.trim().isEmpty
                          ? 'خلاصہ تیار کیا جا رہا ہے۔'
                          : article.summaryUrdu,
                      textAlign: TextAlign.center,
                      style: _urduBodyStyle(size: 20, weight: FontWeight.w600, height: 2.1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _toggleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(article.saved
                          ? Icons.bookmark_rounded
                          : Icons.favorite_border_rounded),
                      label: Text(
                        article.saved ? 'Saved to Library' : 'Save to Library',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: IconButton(
                    onPressed: _shareSummary,
                    icon: const Icon(Icons.share_outlined, color: dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: article.articleUrl));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Article link copied')),
                );
              },
              icon: const Icon(Icons.link_rounded, color: grey),
              label: const Text(
                'Copy original article link',
                style: TextStyle(color: grey, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
