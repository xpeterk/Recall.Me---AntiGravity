import 'package:flutter/material.dart';
import '../domain/transcription_segment.dart';

class TranscriptionBubble extends StatelessWidget {
  final TranscriptionSegment segment;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String) onTap;
  final Function(String)? onToggleExpand; // Callback for summary expansion
  final bool showDiagnostics;

  const TranscriptionBubble({
    Key? key,
    required this.segment,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onToggleExpand,
    this.showDiagnostics = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAi = segment.type == SegmentType.aiResponse;
    final isNotion = segment.type == SegmentType.notion;
    final isSummary = segment.type == SegmentType.summary;
    
    // Alignment
    final alignment = (isAi || isSummary) ? Alignment.centerRight : Alignment.centerLeft;
    final margin = (isAi || isSummary)
        ? const EdgeInsets.only(left: 48, top: 4, bottom: 4) 
        : const EdgeInsets.only(right: 48, top: 4, bottom: 4);

    // Color Palette (Google Messages Style)
    Color fillColor;
    if (isSelected) {
      fillColor = Theme.of(context).colorScheme.primary.withOpacity(0.4);
    } else if (isAi) {
      // "Sent" bubble style - more vibrant/solid
      fillColor = Theme.of(context).colorScheme.primaryContainer;
    } else if (isNotion) {
      // "System" bubble style - distinct (e.g. Orange/Tertiary)
      fillColor = Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.8);
    } else if (isSummary) {
       // Summary style - distinct (e.g. Surface Variant with outline?)
       fillColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    } else {
      // "Received" bubble style - neutral/surface
      fillColor = Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5);
    }
    
    final textColor = isSelected 
        ? Colors.white 
        : (isAi 
            ? Theme.of(context).colorScheme.onPrimaryContainer 
            : (isNotion 
                ? Theme.of(context).colorScheme.onTertiaryContainer 
                : Colors.white));
    final secondaryTextColor = textColor.withOpacity(0.7);

    return GestureDetector(
      onTap: () => onTap(segment.id),
      child: Align(
        alignment: alignment,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: margin,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              // Chat bubble tails logic
              bottomLeft: (isAi || isSummary) ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: (isAi || isSummary) ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Important for chat bubbles
            children: [
              if (isAi || isNotion || isSummary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       if (isNotion)
                          const Icon(Icons.book, size: 14, color: Colors.white70) // Manual icon for Notion
                       else if (segment.bubbleIcon != null)
                          Text(segment.bubbleIcon!, style: const TextStyle(fontSize: 12)) // Emoji icon
                       else
                          Icon(Icons.auto_awesome, size: 14, color: secondaryTextColor),

                      const SizedBox(width: 6),
                      Text(
                        isNotion 
                            ? "Notion Context" 
                            : (segment.bubbleName ?? "AI Insight"),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    String displayText = segment.text;
                    bool isMulti = displayText.trim().startsWith('{"responses":');

                    if (isMulti) {
                       return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             "Multiple Responses Available",
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                               color: textColor,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           Text(
                             "Tap to view full analysis",
                             style: Theme.of(context).textTheme.bodySmall?.copyWith(
                               color: textColor.withOpacity(0.8),
                               fontStyle: FontStyle.italic,
                             ),
                           ),
                         ],
                       );
                    }
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayText,
                            maxLines: isAi ? 6 : null, // Limit AI bubbles to 6 lines (~150 words)
                            overflow: isAi ? TextOverflow.ellipsis : null,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                  color: textColor,
                                  fontWeight: isSummary ? FontWeight.w600 : FontWeight.normal,
                                ),
                          ),
                        ),
                        if (isSummary)
                           GestureDetector(
                             onTap: () {
                                if (onToggleExpand != null) onToggleExpand!(segment.id);
                             },
                             child: Padding(
                               padding: const EdgeInsets.only(left: 8.0),
                               child: Icon(
                                 segment.isExpanded ? Icons.expand_less : Icons.expand_more,
                                 color: secondaryTextColor,
                               ),
                             ),
                           ),
                      ],
                    );
                  }
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${segment.timestamp.hour}:${segment.timestamp.minute.toString().padLeft(2, '0')}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                          fontSize: 10,
                        ),
                  ),
                   if (segment.isSynced)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Icon(Icons.cloud_done, size: 12, color: secondaryTextColor),
                      ),
                   // Diagnostics Badge
                   if (showDiagnostics && segment.type == SegmentType.audio)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: segment.confidence > 0.8 
                              ? Colors.green.withOpacity(0.2) 
                              : (segment.confidence > 0.5 ? Colors.orange.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: segment.confidence > 0.8 
                                ? Colors.green 
                                : (segment.confidence > 0.5 ? Colors.orange : Colors.red),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "${(segment.confidence * 100).toInt()}%",
                          style: TextStyle(
                            color: segment.confidence > 0.8 
                                ? Colors.green 
                                : (segment.confidence > 0.5 ? Colors.orange : Colors.red),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                 ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditingBubble extends StatefulWidget {
  final String initialText;
  final Function(String) onSave;
  final VoidCallback onCancel;

  const EditingBubble({
    Key? key,
    required this.initialText,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<EditingBubble> createState() => _EditingBubbleState();
}

class _EditingBubbleState extends State<EditingBubble> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: null,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: widget.onCancel,
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.greenAccent),
                onPressed: () => widget.onSave(_controller.text),
              ),
            ],
          ),
        ),
        onSubmitted: (newText) => widget.onSave(newText),
      ),
    );
  }
}
