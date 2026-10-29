class NotionLibraryNote {
  final String id;
  final String title;
  final String excerpt;
  final String? category;
  final DateTime editedAt;
  final String? url;
  final int pageCount;
  final List<String> suggestedAngles;
  final String? fullContent;
  final List<double>? embedding;

  const NotionLibraryNote({
    required this.id,
    required this.title,
    required this.excerpt,
    this.category,
    required this.editedAt,
    this.url,
    this.pageCount = 1,
    this.suggestedAngles = const [],
    this.fullContent,
    this.embedding,
  });

  NotionLibraryNote copyWith({
    String? id,
    String? title,
    String? excerpt,
    String? category,
    DateTime? editedAt,
    String? url,
    int? pageCount,
    List<String>? suggestedAngles,
    String? fullContent,
    List<double>? embedding,
  }) {
    return NotionLibraryNote(
      id: id ?? this.id,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      category: category ?? this.category,
      editedAt: editedAt ?? this.editedAt,
      url: url ?? this.url,
      pageCount: pageCount ?? this.pageCount,
      suggestedAngles: suggestedAngles ?? this.suggestedAngles,
      fullContent: fullContent ?? this.fullContent,
      embedding: embedding ?? this.embedding,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'excerpt': excerpt,
      'category': category,
      'edited_at': editedAt.toIso8601String(),
      'url': url,
      'page_count': pageCount,
      'suggested_angles': suggestedAngles,
      if (fullContent != null) 'content': fullContent,
      if (embedding != null) 'embedding': embedding,
    };
  }

  factory NotionLibraryNote.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return const [];
      if (value is List) {
        return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (value is String) {
        final clean = value.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
        return clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    List<double>? parseEmbedding(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value.map((e) => (e as num).toDouble()).toList();
      }
      return null;
    }

    return NotionLibraryNote(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Note',
      excerpt: map['excerpt']?.toString() ?? map['summary']?.toString() ?? '',
      category: map['category']?.toString(),
      editedAt: parseDateTime(map['edited_at'] ?? map['updated_at'] ?? map['timestamp']),
      url: map['url']?.toString() ?? map['source_url']?.toString(),
      pageCount: (map['page_count'] as num?)?.toInt() ?? 1,
      suggestedAngles: parseStringList(map['suggested_angles'] ?? map['angles']),
      fullContent: map['content']?.toString() ?? map['text']?.toString(),
      embedding: parseEmbedding(map['embedding']),
    );
  }
}
