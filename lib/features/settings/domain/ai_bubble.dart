import 'package:flutter/material.dart';

class AiBubble {
  final String id;
  String name;
  String icon; // Emoji or asset path
  Color color;
  String systemPrompt;
  bool isEnabled;
  bool useNotionContext;
  bool useGoogleContext;
  bool useWebSearch; // New field
  List<String> linkedPageIds;
  bool isMultiOutput;
  List<String> additionalPrompts;
  bool isGenerated;

  AiBubble({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.systemPrompt,
    this.isEnabled = true,
    this.useNotionContext = false,
    this.useGoogleContext = false,
    this.useWebSearch = false,
    this.linkedPageIds = const [],
    this.isMultiOutput = false,
    this.additionalPrompts = const [],
    this.isGenerated = false,
  });

  // Serialization logic for persistence (future proofing)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color.value,
      'systemPrompt': systemPrompt,
      'isEnabled': isEnabled ? 1 : 0,
      'useNotionContext': useNotionContext ? 1 : 0,
      'useGoogleContext': useGoogleContext ? 1 : 0,
      'useWebSearch': useWebSearch ? 1 : 0,
      'linkedPageIds': linkedPageIds.join(','),
      'isMultiOutput': isMultiOutput ? 1 : 0,
      'additionalPrompts': additionalPrompts.join('|@|'),
      'isGenerated': isGenerated ? 1 : 0,
    };
  }

  factory AiBubble.fromMap(Map<String, dynamic> map) {
    return AiBubble(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: Color(map['color']),
      systemPrompt: map['systemPrompt'],
      isEnabled: map['isEnabled'] == 1,
      useNotionContext: map['useNotionContext'] == 1,
      useGoogleContext: (map['useGoogleContext'] ?? 0) == 1,
      useWebSearch: (map['useWebSearch'] ?? 0) == 1,
      linkedPageIds: (map['linkedPageIds'] as String).split(',').where((e) => e.isNotEmpty).toList(),
      isMultiOutput: (map['isMultiOutput'] ?? 0) == 1,
      additionalPrompts: (map['additionalPrompts'] as String?)?.split('|@|').where((e) => e.isNotEmpty).toList() ?? [],
      isGenerated: (map['isGenerated'] ?? 0) == 1,
    );
  }
}
