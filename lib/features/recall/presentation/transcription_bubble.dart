import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/transcription_segment.dart';
import '../domain/ai_answer_bubble_payload.dart';

class TranscriptionBubble extends StatelessWidget {
  final TranscriptionSegment segment;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String) onTap;
  final Function(String)? onToggleExpand; // Callback for summary expansion
  final Function(String segmentId, String drillLabel)? onDrillDown;
  final Function(String segmentId, int breadcrumbIndex)? onBreadcrumbTap;
  final List<TranscriptionSegment>? groupedChildren;
  final Set<String>? selectedSegmentIds;
  final bool showDiagnostics;
  final VoidCallback? onLongPress;

  const TranscriptionBubble({
    Key? key,
    required this.segment,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onToggleExpand,
    this.onDrillDown,
    this.onBreadcrumbTap,
    this.groupedChildren,
    this.selectedSegmentIds,
    this.showDiagnostics = false,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAi = segment.type == SegmentType.aiResponse;
    final isNotion = segment.type == SegmentType.notion;
    final isSummary = segment.type == SegmentType.summary;

    // Option 1A: Render Topic Accordion Stack when this is a Summary/Topic Group
    if (isSummary && groupedChildren != null && groupedChildren!.isNotEmpty) {
      return TopicAccordionGroupCard(
        summarySegment: segment,
        children: groupedChildren!,
        selectedSegmentIds: selectedSegmentIds ?? const {},
        onToggleExpand: () {
          if (onToggleExpand != null) {
            onToggleExpand!(segment.id);
          } else {
            onTap(segment.id);
          }
        },
        onChildTap: onTap,
        showDiagnostics: showDiagnostics,
      );
    }

    // Swap alignment to match messaging standards (User: Right, AI: Left)
    final alignment = (isAi || isSummary) ? Alignment.centerLeft : Alignment.centerRight;
    final margin = (isAi || isSummary)
        ? const EdgeInsets.only(right: 36, top: 8, bottom: 8)
        : const EdgeInsets.only(left: 48, top: 8, bottom: 8);

    // Color Palette (Mockup Style)
    BoxDecoration decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
      );
    } else if (isAi) {
      // Mockup Purple Card Style
      decoration = BoxDecoration(
        color: const Color(0xFF140F26), // Deep purple/black card
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else if (isSummary) {
      decoration = BoxDecoration(
        color: const Color(0xFF161619),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
      );
    } else {
      // User Speech Bubble (Mockup Slate Blue Card)
      decoration = BoxDecoration(
        color: const Color(0xFF131D2E), // Deep slate blue
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.8), width: 1.5),
      );
    }

    const textColor = Colors.white;
    const secondaryTextColor = Colors.white70;

    return GestureDetector(
      onTap: () => onTap(segment.id),
      onLongPress: onLongPress,
      child: Align(
        alignment: alignment,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: margin,
          padding: const EdgeInsets.all(16),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Speech specific checklist header (Mockup selection state style)
              if (!isAi && !isSummary && !isNotion)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => onTap(segment.id),
                            activeColor: const Color(0xFF3B82F6),
                            checkColor: Colors.white,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        segment.text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),

              // AI Header Row (Mockup Style)
              if (isAi) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF818CF8)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (segment.bubbleName ?? "ASK AI").toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF818CF8),
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 10, color: Color(0xFFFFD700)),
                          const SizedBox(width: 4),
                          Text(
                            segment.confidence.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    if (isSelectionMode) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => onTap(segment.id),
                          activeColor: const Color(0xFF4F46E5),
                          checkColor: Colors.white,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Summary Header (Fallback if no groupedChildren)
              if (isSummary) ...[
                Row(
                  children: [
                    const Icon(Icons.summarize_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      (segment.bubbleName ?? "SUMMARY").toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: secondaryTextColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Content Body rendering
              if (isAi)
                Builder(
                  builder: (context) {
                    final payload = AiAnswerBubblePayload.fromRawText(segment.text);
                    return MultiAnswerSwipeableCard(
                      answers: payload.responses,
                      drillButtons: payload.drillButtons,
                      isGeneratingDrillButtons: payload.isGeneratingDrillButtons,
                      breadcrumbs: payload.breadcrumbs,
                      currentBreadcrumbIndex: payload.currentBreadcrumbIndex,
                      defaultSourceUrl: segment.sourceUrl,
                      contextTopic: segment.contextTopic,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      onToggleExpand: onToggleExpand,
                      onDrillDown: onDrillDown != null
                          ? (label) => onDrillDown!(segment.id, label)
                          : null,
                      onBreadcrumbTap: onBreadcrumbTap != null
                          ? (idx) => onBreadcrumbTap!(segment.id, idx)
                          : null,
                      segmentId: segment.id,
                      isExpanded: segment.isExpanded,
                    );
                  },
                ),

              if (isSummary || isNotion)
                Builder(
                  builder: (context) {
                    String displayText = segment.text;
                    bool hasLongContent = displayText.contains('===LONG_CONTENT===');
                    if (hasLongContent) {
                      final parts = displayText.split('===LONG_CONTENT===');
                      if (segment.isExpanded && parts.length > 1) {
                        displayText = "${parts[0].trim()}\n\n${parts[1].trim()}";
                      } else {
                        displayText = "${parts[0].trim()}... [[more]](expand:${segment.id})";
                      }
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: MarkdownBody(
                            data: displayText,
                            onTapLink: (text, href, title) async {
                              if (href != null) {
                                if (href.startsWith('expand:')) {
                                  final segId = href.substring(7);
                                  if (onToggleExpand != null) onToggleExpand!(segId);
                                } else {
                                  await _safeLaunchUrl(href);
                                }
                              }
                            },
                            styleSheet: MarkdownStyleSheet(
                              p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                    color: textColor,
                                  ),
                              a: const TextStyle(
                                color: Color(0xFF818CF8),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (isSummary || hasLongContent)
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
                  },
                ),

              // Sources footer
              if (segment.sourceUrl != null && segment.sourceUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      "sources  ",
                      style: TextStyle(fontSize: 10, color: Color(0xFF818CF8), fontWeight: FontWeight.w500),
                    ),
                    Flexible(
                      child: InkWell(
                        onTap: () async {
                          await _safeLaunchUrl(segment.sourceUrl);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (segment.sourceUrl!.contains("notion.so") || segment.sourceUrl!.contains("notion.site"))
                                Image.asset(
                                  'assets/images/notion_logo.png',
                                  width: 12,
                                  height: 12,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.article, size: 12, color: Colors.white70),
                                )
                              else
                                const Icon(Icons.language, size: 12, color: Colors.white70),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  segment.contextTopic ?? "Source Link",
                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 6),
              // Timestamp and Synced state
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showDiagnostics && !isAi && !isSummary && !isNotion) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 8),
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
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    "${segment.timestamp.hour}:${segment.timestamp.minute.toString().padLeft(2, '0')}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor.withOpacity(0.5),
                          fontSize: 9,
                        ),
                  ),
                  if (segment.isSynced)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.cloud_done, size: 10, color: secondaryTextColor.withOpacity(0.5)),
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

/// Option 1A: Topic Accordion Stack for grouped older live conversation bubbles
class TopicAccordionGroupCard extends StatelessWidget {
  final TranscriptionSegment summarySegment;
  final List<TranscriptionSegment> children;
  final Set<String> selectedSegmentIds;
  final VoidCallback onToggleExpand;
  final Function(String) onChildTap;
  final bool showDiagnostics;
  final VoidCallback? onLongPress;

  const TopicAccordionGroupCard({
    Key? key,
    required this.summarySegment,
    required this.children,
    required this.selectedSegmentIds,
    required this.onToggleExpand,
    required this.onChildTap,
    this.showDiagnostics = false,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isExpanded = summarySegment.isExpanded;
    final selectedInGroup = children.where((c) => selectedSegmentIds.contains(c.id)).length;
    final topicTitle = summarySegment.bubbleName ?? "Topic Summary";
    final metaBadge = summarySegment.contextTopic ?? "${children.length} Bubbles Grouped";

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 10, left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked Card Header
          GestureDetector(
            onTap: onToggleExpand,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Subtle stacked deck shadow layers when collapsed
                if (!isExpanded) ...[
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: -8,
                    height: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141824).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7,
                    right: 7,
                    bottom: -4,
                    height: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF181D2C).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.22)),
                      ),
                    ),
                  ),
                ],
                // Main Topic Summary Card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B2032), Color(0xFF141722)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selectedInGroup > 0
                          ? const Color(0xFF3B82F6)
                          : (isExpanded
                              ? const Color(0xFF6366F1).withOpacity(0.75)
                              : const Color(0xFF6366F1).withOpacity(0.4)),
                      width: selectedInGroup > 0 ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.45)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers_outlined, size: 12, color: Color(0xFFA5B4FC)),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 155),
                                  child: Text(
                                    topicTitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFC7D2FE),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              metaBadge,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedInGroup > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: const Color(0xFF60A5FA)),
                              ),
                              child: Text(
                                "$selectedInGroup Selected",
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF93C5FD),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isExpanded ? "Collapse" : "Expand",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFA5B4FC),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  size: 14,
                                  color: const Color(0xFFA5B4FC),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        summarySegment.text,
                        maxLines: isExpanded ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCBD5E1),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Unfolded Child Speech Bubbles when Expanded
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(left: 12, top: 8),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: const Color(0xFF4F46E5).withOpacity(0.65),
                    width: 2.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: children.map((child) {
                  final childSelected = selectedSegmentIds.contains(child.id);
                  return GestureDetector(
                    onTap: () => onChildTap(child.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: childSelected
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFF131D2E),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: childSelected
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF3B82F6).withOpacity(0.55),
                          width: childSelected ? 2.0 : 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8, top: 2),
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  color: childSelected
                                      ? const Color(0xFF3B82F6)
                                      : Colors.white.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: childSelected
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFF3B82F6).withOpacity(0.7),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 9,
                                    color: childSelected ? Colors.white : Colors.white54,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  child.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                childSelected ? "Selected • Tap to deselect" : "Tap to select & process",
                                style: TextStyle(
                                  fontSize: 9,
                                  color: childSelected
                                      ? const Color(0xFF93C5FD)
                                      : Colors.white38,
                                  fontWeight: childSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${child.timestamp.hour}:${child.timestamp.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
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

String? _extractNotionUrl(String text) {
  final match = RegExp(r'https?://[^\s\)]*notion\.[^\s\)]+').firstMatch(text);
  if (match != null) {
    String url = match.group(0)!;
    while (url.endsWith(')') || url.endsWith('"') || url.endsWith("'") || url.endsWith('.')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
  return null;
}

Future<void> _safeLaunchUrl(String? urlString) async {
  if (urlString == null || urlString.trim().isEmpty) return;
  final uri = Uri.parse(urlString.trim());
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    try {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } catch (e) {
      print("SafeLaunchUrl error: $e");
    }
  }
}

class MultiAnswerSwipeableCard extends StatefulWidget {
  final List<String> answers;
  final List<String> drillButtons;
  final bool isGeneratingDrillButtons;
  final List<AiBreadcrumbNode> breadcrumbs;
  final int currentBreadcrumbIndex;
  final String? defaultSourceUrl;
  final String? contextTopic;
  final Color textColor;
  final Color secondaryTextColor;
  final Function(String)? onToggleExpand;
  final Function(String drillLabel)? onDrillDown;
  final Function(int breadcrumbIndex)? onBreadcrumbTap;
  final String segmentId;
  final bool isExpanded;

  const MultiAnswerSwipeableCard({
    Key? key,
    required this.answers,
    this.drillButtons = const [],
    this.isGeneratingDrillButtons = false,
    this.breadcrumbs = const [],
    this.currentBreadcrumbIndex = 0,
    this.defaultSourceUrl,
    this.contextTopic,
    required this.textColor,
    required this.secondaryTextColor,
    this.onToggleExpand,
    this.onDrillDown,
    this.onBreadcrumbTap,
    required this.segmentId,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  State<MultiAnswerSwipeableCard> createState() => _MultiAnswerSwipeableCardState();
}

class _MultiAnswerSwipeableCardState extends State<MultiAnswerSwipeableCard> {
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant MultiAnswerSwipeableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentBreadcrumbIndex != oldWidget.currentBreadcrumbIndex ||
        _currentIndex >= widget.answers.length) {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeAnswers = widget.answers.isNotEmpty ? widget.answers : [''];
    final safeIndex = _currentIndex.clamp(0, safeAnswers.length - 1);
    String currentAnswer = safeAnswers[safeIndex];

    bool hasLongContent = currentAnswer.contains('===LONG_CONTENT===');
    if (hasLongContent) {
      final parts = currentAnswer.split('===LONG_CONTENT===');
      if (widget.isExpanded && parts.length > 1) {
        currentAnswer = "${parts[0].trim()}\n\n${parts[1].trim()}";
      } else {
        currentAnswer = "${parts[0].trim()}... [[more]](expand:${widget.segmentId})";
      }
    }

    final notionUrl = _extractNotionUrl(currentAnswer) ?? widget.defaultSourceUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Option 2B: Interactive Breadcrumb Trail Bar when drilled down
        if (widget.breadcrumbs.length > 1) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.35)),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                const Icon(Icons.account_tree_outlined, size: 12, color: Color(0xFF818CF8)),
                const SizedBox(width: 2),
                for (int i = 0; i < widget.breadcrumbs.length; i++) ...[
                  if (i > 0)
                    const Text(
                      "›",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  InkWell(
                    onTap: i != widget.currentBreadcrumbIndex && widget.onBreadcrumbTap != null
                        ? () => widget.onBreadcrumbTap!(i)
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: i == widget.currentBreadcrumbIndex
                            ? const Color(0xFF4F46E5).withOpacity(0.4)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.breadcrumbs[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: i == widget.currentBreadcrumbIndex
                              ? Colors.white
                              : const Color(0xFFA5B4FC),
                          decoration: i == widget.currentBreadcrumbIndex
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Top row showing current answer index badge and left/right arrows when multiple answers exist
        if (safeAnswers.length > 1) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Answer ${safeIndex + 1} of ${safeAnswers.length} • Swipe ↔",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF818CF8),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: safeIndex > 0 ? () => setState(() => _currentIndex = safeIndex - 1) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: safeIndex > 0 ? Colors.white : Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: safeIndex < safeAnswers.length - 1
                        ? () => setState(() => _currentIndex = safeIndex + 1)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: safeIndex < safeAnswers.length - 1 ? Colors.white : Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Horizontal Swipe detector for smooth swiping between answers
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: safeAnswers.length > 1
              ? (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < -150 && safeIndex < safeAnswers.length - 1) {
                      setState(() => _currentIndex = safeIndex + 1);
                    } else if (details.primaryVelocity! > 150 && safeIndex > 0) {
                      setState(() => _currentIndex = safeIndex - 1);
                    }
                  }
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MarkdownBody(
                      data: currentAnswer,
                      selectable: false,
                      onTapLink: (text, href, title) async {
                        if (href != null) {
                          if (href.startsWith('expand:')) {
                            final segId = href.substring(7);
                            if (widget.onToggleExpand != null) widget.onToggleExpand!(segId);
                          } else {
                            await _safeLaunchUrl(href);
                          }
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              color: widget.textColor,
                            ),
                        a: const TextStyle(
                          color: Color(0xFF818CF8),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (hasLongContent)
                    GestureDetector(
                      onTap: () {
                        if (widget.onToggleExpand != null) widget.onToggleExpand!(widget.segmentId);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: widget.secondaryTextColor,
                        ),
                      ),
                    ),
                ],
              ),

              // Prominent Notion Link pill if present
              if (notionUrl != null && (notionUrl.contains("notion.so") || notionUrl.contains("notion.site")))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    onTap: () => _safeLaunchUrl(notionUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/notion_logo.png',
                            width: 14,
                            height: 14,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.menu_book, size: 14, color: Color(0xFF818CF8)),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Open in Notion",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_outward, size: 12, color: Color(0xFF818CF8)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Navigation dots at the bottom when multiple answers exist
        if (safeAnswers.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(safeAnswers.length, (index) {
              final isCurrent = index == safeIndex;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  width: isCurrent ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF818CF8) : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],

        // Option 2B: AI-Generated Secondary Drill-Down Buttons
        if (widget.drillButtons.isNotEmpty || widget.isGeneratingDrillButtons) ...[
          const SizedBox(height: 10),
          Divider(color: const Color(0xFF4F46E5).withOpacity(0.25), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bolt, size: 12, color: Color(0xFFA5B4FC)),
              const SizedBox(width: 4),
              Text(
                widget.breadcrumbs.length > 1
                    ? "AI DRILL-DOWN DEEPER:"
                    : "AI SECONDARY ANSWER TYPES:",
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFA5B4FC),
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.isGeneratingDrillButtons && widget.drillButtons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: const [
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Generating secondary drill-down buttons...",
                    style: TextStyle(fontSize: 10, color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.drillButtons.map((btnLabel) {
                return InkWell(
                  onTap: widget.onDrillDown != null ? () => widget.onDrillDown!(btnLabel) : null,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4F46E5).withOpacity(0.28),
                          const Color(0xFF7C3AED).withOpacity(0.20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: const Color(0xFF818CF8).withOpacity(0.55),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            btnLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE0E7FF),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 12,
                          color: Color(0xFFA5B4FC),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }
}
