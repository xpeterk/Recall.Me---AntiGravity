class DynamicStarter {
  final String id;
  final String name;
  final String notionDatabaseId;
  final String? prompt;
  final bool isActive;

  DynamicStarter({
    required this.id,
    required this.name,
    required this.notionDatabaseId,
    this.prompt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notionDatabaseId': notionDatabaseId,
    'prompt': prompt,
    'isActive': isActive,
  };

  factory DynamicStarter.fromJson(Map<String, dynamic> json) {
    return DynamicStarter(
      id: json['id'],
      name: json['name'],
      notionDatabaseId: json['notionDatabaseId'] ?? '',
      prompt: json['prompt'],
      isActive: json['isActive'] ?? true,
    );
  }
}
