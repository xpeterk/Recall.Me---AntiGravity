class DynamicStarter {
  final String id;
  final String name;
  final String notionDatabaseId;
  final String? prompt;
  final bool isActive;
  final List<double>? embedding;

  DynamicStarter({
    required this.id,
    required this.name,
    required this.notionDatabaseId,
    this.prompt,
    this.isActive = true,
    this.embedding,
  });

  DynamicStarter copyWith({
    String? id,
    String? name,
    String? notionDatabaseId,
    String? prompt,
    bool? isActive,
    List<double>? embedding,
  }) {
    return DynamicStarter(
      id: id ?? this.id,
      name: name ?? this.name,
      notionDatabaseId: notionDatabaseId ?? this.notionDatabaseId,
      prompt: prompt ?? this.prompt,
      isActive: isActive ?? this.isActive,
      embedding: embedding ?? this.embedding,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notionDatabaseId': notionDatabaseId,
    'prompt': prompt,
    'isActive': isActive,
    if (embedding != null) 'embedding': embedding,
  };

  factory DynamicStarter.fromJson(Map<String, dynamic> json) {
    return DynamicStarter(
      id: json['id'],
      name: json['name'],
      notionDatabaseId: json['notionDatabaseId'] ?? '',
      prompt: json['prompt'],
      isActive: json['isActive'] ?? true,
      embedding: json['embedding'] != null
          ? List<double>.from((json['embedding'] as List).map((e) => (e as num).toDouble()))
          : null,
    );
  }
}
