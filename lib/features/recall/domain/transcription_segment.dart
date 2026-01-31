enum SegmentType { audio, aiResponse, notion }

class TranscriptionSegment {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isUser;
  final SegmentType type;
  final String? sourceUrl;
  final bool isSynced;
  bool isSelected;
  final String? bubbleName;
  final String? bubbleIcon;

  TranscriptionSegment({
    required this.id,
    required this.text,
    required this.timestamp,
    this.isUser = true,
    this.type = SegmentType.audio,
    this.sourceUrl,
    this.isSynced = false,
    this.isSelected = false,
    this.bubbleName,
    this.bubbleIcon,
  });

  // Convert to Map for Database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'is_user': isUser ? 1 : 0,
      'type': type.index,
      'source_url': sourceUrl,
      'is_synced': isSynced ? 1 : 0,
      'bubble_name': bubbleName,
      'bubble_icon': bubbleIcon,
    };
  }

  // Create from Map (Database)
  factory TranscriptionSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptionSegment(
      id: map['id'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
      isUser: map['is_user'] == 1,
      type: SegmentType.values[map['type'] ?? 0],
      sourceUrl: map['source_url'],
      isSynced: map['is_synced'] == 1,
      isSelected: false, // UI state, not persisted
      bubbleName: map['bubble_name'],
      bubbleIcon: map['bubble_icon'],
    );
  }
}
