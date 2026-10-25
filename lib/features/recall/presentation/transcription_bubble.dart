import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
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
    
    // Swap alignment to match messaging standards (User: Right, AI: Left)
    final alignment = (isAi || isSummary) ? Alignment.centerLeft : Alignment.centerRight;
    final margin = (isAi || isSummary)
        ? const EdgeInsets.only(right: 48, top: 8, bottom: 8) 
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

    final textColor = Colors.white;
    final secondaryTextColor = Colors.white70;

    return GestureDetector(
      onTap: () => onTap(segment.id),
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
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
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
                    Text(
                      (segment.bubbleName ?? "ASK AI").toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF818CF8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
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
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Summary Header
              if (isSummary) ...[
                Row(
                  children: [
                    const Icon(Icons.summarize_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      "SUMMARY",
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

              // Content Body rendering (Only if not user speech since that was rendered in Row above)
              if (isAi || isSummary || isNotion)
                Builder(
                  builder: (context) {
                    final answers = _extractAnswers(segment.text);

                    // Multi-answer single bubble with swipe left/right and nav dots
                    if (isAi && answers.length > 1) {
                      return MultiAnswerSwipeableCard(
                        answers: answers,
                        defaultSourceUrl: segment.sourceUrl,
                        contextTopic: segment.contextTopic,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        onToggleExpand: onToggleExpand,
                        segmentId: segment.id,
                        isExpanded: segment.isExpanded,
                      );
                    }

                    String displayText = answers.isNotEmpty ? answers.first : segment.text;
                    
                    bool hasLongContent = displayText.contains('===LONG_CONTENT===');
                    if (hasLongContent) {
                       final parts = displayText.split('===LONG_CONTENT===');
                       if (segment.isExpanded && parts.length > 1) {
                           displayText = "${parts[0].trim()}\n\n${parts[1].trim()}";
                       } else {
                           displayText = "${parts[0].trim()}... [[more]](expand:${segment.id})";
                       }
                    }

                    final notionUrl = _extractNotionUrl(displayText) ?? segment.sourceUrl;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
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
                        ),
                        if (isAi && notionUrl != null && (notionUrl.contains("notion.so") || notionUrl.contains("notion.site")))
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
                                      errorBuilder: (_, __, ___) => const Icon(Icons.menu_book, size: 14, color: Color(0xFF818CF8)),
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
                    );
                  }
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
                     InkWell(
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
                             Text(
                               segment.contextTopic ?? "Source Link",
                               style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                             ),
                           ],
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

List<String> _extractAnswers(String text) {
  final clean = text.trim();
  if (clean.startsWith('{')) {
    try {
      final json = jsonDecode(clean);
      if (json['responses'] is List) {
        final list = (json['responses'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
  }
  return [clean];
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
  final String? defaultSourceUrl;
  final String? contextTopic;
  final Color textColor;
  final Color secondaryTextColor;
  final Function(String)? onToggleExpand;
  final String segmentId;
  final bool isExpanded;

  const MultiAnswerSwipeableCard({
    Key? key,
    required this.answers,
    this.defaultSourceUrl,
    this.contextTopic,
    required this.textColor,
    required this.secondaryTextColor,
    this.onToggleExpand,
    required this.segmentId,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  State<MultiAnswerSwipeableCard> createState() => _MultiAnswerSwipeableCardState();
}

class _MultiAnswerSwipeableCardState extends State<MultiAnswerSwipeableCard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentAnswer = widget.answers[_currentIndex];
    final notionUrl = _extractNotionUrl(currentAnswer) ?? widget.defaultSourceUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row showing current answer index badge and left/right arrows
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
                "Answer ${_currentIndex + 1} of ${widget.answers.length}",
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
                  onTap: _currentIndex > 0
                      ? () => setState(() => _currentIndex--)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: _currentIndex > 0 ? Colors.white : Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _currentIndex < widget.answers.length - 1
                      ? () => setState(() => _currentIndex++)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: _currentIndex < widget.answers.length - 1 ? Colors.white : Colors.white24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Horizontal Swipe detector for smooth swiping between answers
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -150 && _currentIndex < widget.answers.length - 1) {
                setState(() => _currentIndex++);
              } else if (details.primaryVelocity! > 150 && _currentIndex > 0) {
                setState(() => _currentIndex--);
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MarkdownBody(
                data: currentAnswer,
                selectable: true,
                onTapLink: (text, href, title) async {
                  if (href != null) {
                    await _safeLaunchUrl(href);
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
                            errorBuilder: (_, __, ___) => const Icon(Icons.menu_book, size: 14, color: Color(0xFF818CF8)),
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
        const SizedBox(height: 10),

        // Navigation dots at the bottom
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.answers.length, (index) {
            final isCurrent = index == _currentIndex;
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                width: isCurrent ? 12 : 6,
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
    );
  }
}
