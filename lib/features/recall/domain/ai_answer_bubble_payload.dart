import 'dart:convert';

class AiBreadcrumbNode {
  final String label;
  final List<String> responses;
  final List<String> drillButtons;

  const AiBreadcrumbNode({
    required this.label,
    required this.responses,
    this.drillButtons = const [],
  });

  AiBreadcrumbNode copyWith({
    String? label,
    List<String>? responses,
    List<String>? drillButtons,
  }) {
    return AiBreadcrumbNode(
      label: label ?? this.label,
      responses: responses ?? this.responses,
      drillButtons: drillButtons ?? this.drillButtons,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'responses': responses,
      'drillButtons': drillButtons,
    };
  }

  factory AiBreadcrumbNode.fromMap(Map<String, dynamic> map) {
    final rawResponses = map['responses'];
    final rawButtons = map['drillButtons'];
    return AiBreadcrumbNode(
      label: (map['label'] ?? 'Overview').toString(),
      responses: rawResponses is List
          ? rawResponses.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const [],
      drillButtons: rawButtons is List
          ? rawButtons.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }
}

class AiAnswerBubblePayload {
  final List<String> responses;
  final List<String> drillButtons;
  final bool isGeneratingDrillButtons;
  final List<AiBreadcrumbNode> breadcrumbs;
  final int currentBreadcrumbIndex;
  final String? originalQuery;
  final String? notionContext;

  const AiAnswerBubblePayload({
    required this.responses,
    this.drillButtons = const [],
    this.isGeneratingDrillButtons = false,
    this.breadcrumbs = const [],
    this.currentBreadcrumbIndex = 0,
    this.originalQuery,
    this.notionContext,
  });

  AiAnswerBubblePayload copyWith({
    List<String>? responses,
    List<String>? drillButtons,
    bool? isGeneratingDrillButtons,
    List<AiBreadcrumbNode>? breadcrumbs,
    int? currentBreadcrumbIndex,
    String? originalQuery,
    String? notionContext,
  }) {
    return AiAnswerBubblePayload(
      responses: responses ?? this.responses,
      drillButtons: drillButtons ?? this.drillButtons,
      isGeneratingDrillButtons: isGeneratingDrillButtons ?? this.isGeneratingDrillButtons,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      currentBreadcrumbIndex: currentBreadcrumbIndex ?? this.currentBreadcrumbIndex,
      originalQuery: originalQuery ?? this.originalQuery,
      notionContext: notionContext ?? this.notionContext,
    );
  }

  String toJsonString() {
    return jsonEncode({
      'responses': responses,
      'drillButtons': drillButtons,
      'isGeneratingDrillButtons': isGeneratingDrillButtons,
      'breadcrumbs': breadcrumbs.map((b) => b.toMap()).toList(),
      'currentBreadcrumbIndex': currentBreadcrumbIndex,
      if (originalQuery != null) 'originalQuery': originalQuery,
      if (notionContext != null) 'notionContext': notionContext,
    });
  }

  factory AiAnswerBubblePayload.fromRawText(String rawText) {
    final clean = rawText.trim();
    if (clean.startsWith('{')) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map<String, dynamic>) {
          final rawResponses = decoded['responses'];
          final responses = rawResponses is List
              ? rawResponses.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
              : <String>[];
          final safeResponses = responses.isNotEmpty ? responses : [clean];

          final rawButtons = decoded['drillButtons'];
          final drillButtons = rawButtons is List
              ? rawButtons.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
              : <String>[];

          final isGenerating = decoded['isGeneratingDrillButtons'] == true;

          final rawBreadcrumbs = decoded['breadcrumbs'];
          List<AiBreadcrumbNode> breadcrumbs = [];
          if (rawBreadcrumbs is List) {
            breadcrumbs = rawBreadcrumbs
                .whereType<Map>()
                .map((m) => AiBreadcrumbNode.fromMap(Map<String, dynamic>.from(m)))
                .toList();
          }
          if (breadcrumbs.isEmpty) {
            breadcrumbs = [
              AiBreadcrumbNode(
                label: 'Overview',
                responses: safeResponses,
                drillButtons: drillButtons,
              ),
            ];
          }

          int currentIdx = (decoded['currentBreadcrumbIndex'] as int?) ?? (breadcrumbs.length - 1);
          if (currentIdx < 0 || currentIdx >= breadcrumbs.length) {
            currentIdx = breadcrumbs.length - 1;
          }

          return AiAnswerBubblePayload(
            responses: safeResponses,
            drillButtons: drillButtons,
            isGeneratingDrillButtons: isGenerating,
            breadcrumbs: breadcrumbs,
            currentBreadcrumbIndex: currentIdx,
            originalQuery: decoded['originalQuery'] as String?,
            notionContext: decoded['notionContext'] as String?,
          );
        }
      } catch (_) {}
    }

    final fallbackResponses = clean.isNotEmpty ? [clean] : [''];
    return AiAnswerBubblePayload(
      responses: fallbackResponses,
      drillButtons: const [],
      isGeneratingDrillButtons: false,
      breadcrumbs: [
        AiBreadcrumbNode(
          label: 'Overview',
          responses: fallbackResponses,
          drillButtons: const [],
        ),
      ],
      currentBreadcrumbIndex: 0,
    );
  }
}
