class StarterItem {
  final String id;
  final String title;
  final String? summary;
  final String? category;
  final List<String> angles;
  final List<String> notionPageIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isNew;

  const StarterItem({
    required this.id,
    required this.title,
    this.summary,
    this.category,
    this.angles = const [],
    this.notionPageIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isNew = false,
  });

  StarterItem copyWith({
    String? id,
    String? title,
    String? summary,
    String? category,
    List<String>? angles,
    List<String>? notionPageIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isNew,
  }) {
    return StarterItem(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      angles: angles ?? this.angles,
      notionPageIds: notionPageIds ?? this.notionPageIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isNew: isNew ?? this.isNew,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'category': category,
      'angles': angles,
      'notion_page_ids': notionPageIds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StarterItem.fromMap(Map<String, dynamic> map, {bool isNew = false}) {
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

    return StarterItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      summary: map['summary']?.toString(),
      category: map['category']?.toString(),
      angles: parseStringList(map['angles']),
      notionPageIds: parseStringList(map['notion_page_ids']),
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
      isNew: isNew,
    );
  }
}
