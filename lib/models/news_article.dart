class NewsArticle {
  final String id;
  final String title;
  final String imageUrl;
  final String category;
  final String sourceName;
  final String sourceUrl;
  final String articleUrl;
  final DateTime? publishedAt;
  final String shortExcerpt;
  final String articleText;
  final List<String> bulletPointsUrdu;
  final String summaryUrdu;
  final bool saved;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    required this.articleUrl,
    required this.publishedAt,
    required this.shortExcerpt,
    required this.articleText,
    required this.bulletPointsUrdu,
    required this.summaryUrdu,
    required this.saved,
  });

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final resolvedId = _readString(json, const ['_id', 'id', 'articleId']);

    return NewsArticle(
      id: resolvedId,
      title: _readString(json, const ['title']),
      imageUrl: _readString(json, const ['imageUrl']),
      category: _readString(json, const ['category']).isEmpty
          ? 'General'
          : _readString(json, const ['category']),
      sourceName: _readString(json, const ['sourceName']).isEmpty
          ? 'Urdu News'
          : _readString(json, const ['sourceName']),
      sourceUrl: _readString(json, const ['sourceUrl']),
      articleUrl: _readString(json, const ['articleUrl', 'url', 'link']),
      publishedAt: _readDate(json['publishedAt']),
      shortExcerpt: _readString(json, const ['shortExcerpt', 'excerpt']),
      articleText: _readString(json, const ['articleText']),
      bulletPointsUrdu: (json['bulletPointsUrdu'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      summaryUrdu: _readString(json, const ['summaryUrdu', 'summary']),
      saved: json['saved'] == true,
    );
  }

  String get preferredIdentifier {
    if (id.trim().isNotEmpty) return id.trim();
    return articleUrl.trim();
  }

  NewsArticle copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? category,
    String? sourceName,
    String? sourceUrl,
    String? articleUrl,
    DateTime? publishedAt,
    bool clearPublishedAt = false,
    String? shortExcerpt,
    String? articleText,
    List<String>? bulletPointsUrdu,
    String? summaryUrdu,
    bool? saved,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      articleUrl: articleUrl ?? this.articleUrl,
      publishedAt: clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      shortExcerpt: shortExcerpt ?? this.shortExcerpt,
      articleText: articleText ?? this.articleText,
      bulletPointsUrdu: bulletPointsUrdu ?? this.bulletPointsUrdu,
      summaryUrdu: summaryUrdu ?? this.summaryUrdu,
      saved: saved ?? this.saved,
    );
  }
}