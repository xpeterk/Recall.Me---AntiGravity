import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../../recall/domain/transcription_segment.dart';
import '../../recall/presentation/transcription_bubble.dart';
import '../../recall/presentation/recall_shelf.dart';
import '../../recall/presentation/ai_result_bottom_sheet.dart';
import '../../settings/presentation/settings_page.dart';
import 'mic_visualizer.dart';
import 'search_bottom_sheet.dart';
import 'voice_prompt_dialog.dart';
import '../../settings/domain/ai_bubble.dart';

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({Key? key}) : super(key: key);

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TextEditingController _starterController;
  late TextEditingController _manualInputController;
  late TextEditingController _startersSearchController;
  String _startersSearchQuery = "";
  bool _showScrollButton = false;
  String? _lastParsedUrl;
  String _starterStatus = "";
  bool _showStartersPanel = false;

  @override
  void initState() {
    super.initState();
    _starterController = TextEditingController();
    _manualInputController = TextEditingController();
    _startersSearchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = Provider.of<TranscriptionViewModel>(context, listen: false);
      if (vm.conversationStarter != null) {
         _starterController.text = vm.conversationStarter!;
      }
    });
    _scrollController.addListener(() {
      if (_scrollController.offset > 500 && !_showScrollButton) {
        setState(() => _showScrollButton = true);
      } else if (_scrollController.offset <= 500 && _showScrollButton) {
        setState(() => _showScrollButton = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _starterController.dispose();
    _manualInputController.dispose();
    _startersSearchController.dispose();
    super.dispose();
  }

  void _checkAndParseUrl(String text, TranscriptionViewModel vm) async {
    final url = vm.linkParserService.extractFirstUrl(text);
    if (url != null && url != _lastParsedUrl) {
      _lastParsedUrl = url;
      setState(() => _starterStatus = "â³ Reading link...");
      final success = await vm.processExternalLink(url, onStatus: (status) {
         if (mounted) setState(() => _starterStatus = status);
      });
      if (success) {
         // parsed successfully
      }
    }
  }

  void _showPasteLinkDialog(BuildContext context, TranscriptionViewModel vm) {
    TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Paste Link context"),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(hintText: "https://..."),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String url = urlController.text;
              Navigator.pop(context);
              if (url.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parsing link...")));
                final success = await vm.processExternalLink(url);
                if (success) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Context added successfully")));
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to parse link")));
                }
              }
            },
            child: const Text("Add Context"),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicSuggestorBubble(TranscriptionViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
               Icon(Icons.psychology, size: 20, color: Theme.of(context).colorScheme.primary),
               const SizedBox(width: 8),
               Text("Topic / Context", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
               const Spacer(),
               IconButton(
                 icon: const Icon(Icons.link, size: 20),
                 color: Theme.of(context).colorScheme.secondary,
                 tooltip: "Paste Web Link for Context",
                 onPressed: () => _showPasteLinkDialog(context, viewModel),
               ),
            ]
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _starterController,
            decoration: InputDecoration(
              hintText: "Add context or topic...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (text) {
               viewModel.setConversationStarter(text);
               _checkAndParseUrl(text, viewModel);
            },
          ),
          if (_starterStatus.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text(_starterStatus, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
             ),
          if (viewModel.detectedStarter != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade700, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      "Detected Topic: ${viewModel.detectedStarter!.name} (${(viewModel.detectedStarterSimilarity * 100).toInt()}% match)",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        viewModel.clearDetectedStarter();
                      },
                      child: const Icon(Icons.close, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          if (viewModel.starterSuggestions.isNotEmpty || viewModel.dynamicStarters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  ...viewModel.dynamicStarters.map((starter) {
                    final isDetected = viewModel.detectedStarter?.id == starter.id;
                    return ActionChip(
                      backgroundColor: isDetected 
                          ? Colors.amber.shade300 
                          : Theme.of(context).colorScheme.tertiaryContainer,
                      avatar: isDetected ? const Icon(Icons.auto_awesome, size: 16, color: Colors.orange) : null,
                      label: Text(
                        isDetected 
                            ? "✨ ${starter.name} (${(viewModel.detectedStarterSimilarity * 100).toInt()}%)"
                            : "⚡ ${starter.name}", 
                        style: TextStyle(
                          fontSize: 12, 
                          color: isDetected ? Colors.black87 : Theme.of(context).colorScheme.onTertiaryContainer, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        viewModel.processDynamicStarter(starter);
                      },
                    );
                  }).toList(),
                  ...viewModel.pinnedStarters.map((starter) {
                    return GestureDetector(
                      onLongPress: () => viewModel.pinStarter(starter),
                      child: ActionChip(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        label: Text(starter, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold)),
                        onPressed: () { _starterController.text = starter; viewModel.setConversationStarter(starter); },
                      ),
                    );
                  }).toList(),
                  ...viewModel.recentStarters.map((starter) {
                    return GestureDetector(
                      onLongPress: () => viewModel.pinStarter(starter),
                      child: ActionChip(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        label: Text(starter, style: const TextStyle(fontSize: 12)),
                        onPressed: () { _starterController.text = starter; viewModel.setConversationStarter(starter); },
                      ),
                    );
                  }).toList(),
                  ...viewModel.starterSuggestions.map((suggestion) {
                    return ActionChip(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                      label: Text(
                        suggestion.length > 35 ? "${suggestion.substring(0, 35)}..." : suggestion,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        _starterController.text = suggestion;
                        viewModel.setConversationStarter(suggestion);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<TranscriptionViewModel>(context);

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Image.asset(
                'assets/images/logo_v2.png',
                fit: BoxFit.contain,
              ),
            ),
            leadingWidth: 100,
            title: viewModel.isSelectionMode 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       const SizedBox.shrink(),
                       Text("${viewModel.selectionCount} Selected"),
                    ],
                  )
                : MicVisualizer(
                    isListening: viewModel.isListening,
                    soundLevelStream: viewModel.soundLevelStream,
                    onTap: viewModel.toggleListening,
                  ),
            actions: viewModel.isSelectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => viewModel.exitSelectionMode(),
                    )
                  ]
                : [
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          viewModel.toggleTranscriptionEngine();
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Text(
                                viewModel.isGeminiEngine 
                                    ? "Switched to Gemini 3.5 Transcribe (Live Cloud)" 
                                    : "Switched to On-Device Native Speech (Offline)",
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: viewModel.isGeminiEngine 
                                ? const Color(0xFF4F46E5).withOpacity(0.3)
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: viewModel.isGeminiEngine 
                                  ? const Color(0xFF818CF8) 
                                  : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                viewModel.isGeminiEngine ? Icons.cloud_queue : Icons.phone_android,
                                size: 12,
                                color: viewModel.isGeminiEngine ? const Color(0xFF818CF8) : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                viewModel.isGeminiEngine ? "Gemini 3.5" : "Native",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: viewModel.isGeminiEngine ? const Color(0xFF818CF8) : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                       icon: const Icon(Icons.explore_outlined, color: Colors.amberAccent),
                       tooltip: "Conversation Starters",
                       onPressed: () {
                         setState(() {
                           _showStartersPanel = true;
                         });
                       },
                    ),
                    IconButton(
                       icon: const Icon(Icons.search),
                       onPressed: () {
                         showModalBottomSheet(
                           context: context,
                           isScrollControlled: true,
                           backgroundColor: Colors.transparent,
                           builder: (context) => const SearchBottomSheet(),
                         ).then((_) {
                           viewModel.setSearchQuery("");
                         });
                       },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                ],
          ),
        ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  Theme.of(context).colorScheme.surface,
                ],
                center: Alignment.topLeft,
                radius: 1.5,
              ),
            ),
          ),
          
          Column(
            children: [
              SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
              
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(
                        left: 16, 
                        right: 16, 
                        bottom: 120 
                      ),
                      itemCount: (viewModel.segments.isEmpty && !(viewModel.text.trim().isNotEmpty && !viewModel.text.contains("Press the mic")))
                          ? 1
                          : (viewModel.segments.length + ((viewModel.text.trim().isNotEmpty && !viewModel.text.contains("Press the mic")) ? 1 : 0)),
                      itemBuilder: (context, index) {
                        final isLiveTextValid = viewModel.text.trim().isNotEmpty && !viewModel.text.contains("Press the mic");

                        if (isLiveTextValid && index == 0) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(4),
                              ),
                              border: Border.all(
                                color: viewModel.isGeminiEngine 
                                    ? const Color(0xFF818CF8).withOpacity(0.6) 
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const LiveNowIndicator(),
                                    const SizedBox(width: 8),
                                    Text(
                                      viewModel.isGeminiEngine 
                                          ? "LIVE • GEMINI 3.5 TRANSCRIBE" 
                                          : "LIVE • ON-DEVICE STT",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: viewModel.isGeminiEngine 
                                            ? const Color(0xFF818CF8) 
                                            : Theme.of(context).colorScheme.primary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  viewModel.text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (viewModel.segments.isEmpty && !isLiveTextValid) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 40, top: 40),
                              child: Text(
                                "Tap the mic above to start recalling",
                                style: TextStyle(color: Theme.of(context).disabledColor),
                              ),
                            ),
                          );
                        }

                        final effectiveIndex = isLiveTextValid ? index - 1 : index;
                        
                        if (effectiveIndex < 0 || effectiveIndex >= viewModel.segments.length) return const SizedBox.shrink();

                        final segment = viewModel.segments[effectiveIndex];
                        final isSelected = viewModel.isSelected(segment.id);
                        final isEditing = viewModel.isEditing(segment.id);

                        if (isEditing) {
                          return EditingBubble(
                            initialText: segment.text,
                            onSave: (newText) => viewModel.saveEdit(segment.id, newText),
                            onCancel: () => viewModel.cancelEditing(),
                          );
                        }

                        return Dismissible(
                          key: Key(segment.id),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            viewModel.startEditing(segment.id);
                            return false; 
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.blueAccent.withOpacity(0.5),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                          child: TranscriptionBubble(
                            segment: segment,
                            isSelectionMode: viewModel.isSelectionMode,
                            isSelected: isSelected,
                            onToggleExpand: viewModel.toggleSummaryExpansion,
                            showDiagnostics: viewModel.showDiagnostics,
                            onTap: (id) {
                              if (segment.type == SegmentType.aiResponse) {
                                 viewModel.viewAiSegment(segment);
                                 showModalBottomSheet(
                                   context: context,
                                   backgroundColor: Colors.transparent,
                                   isScrollControlled: true,
                                   builder: (context) => const AiResultBottomSheet(),
                                 ).then((_) {
                                    viewModel.clearAiResponse(); 
                                 });
                              } else if (segment.type == SegmentType.summary) {
                                  viewModel.processWithBubble(viewModel.bubbles.firstWhere((b) => b.name.contains("Fact Check"), orElse: () => viewModel.bubbles.first));
                                  showModalBottomSheet(
                                     context: context,
                                     backgroundColor: Colors.transparent,
                                     isScrollControlled: true,
                                     builder: (context) => const AiResultBottomSheet(),
                                  );
                              } else if (!viewModel.isFrozen) {
                                 viewModel.enterSelectionMode(id);
                              } else {
                                 viewModel.toggleSelection(id);
                              }
                            },
                          ),
                        );
                      },
                    ),
                    
                    if (_showScrollButton)
                      Positioned(
                        bottom: 20,
                        right: 16,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            _scrollController.animateTo(
                              0, 
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ),
                  ],
                ),
              ),
              
              if (viewModel.showBottomTextInput && !viewModel.isSelectionMode)
                 Container(
                    padding: EdgeInsets.only(
                      left: 16, 
                      right: 16, 
                      top: 8, 
                      bottom: MediaQuery.of(context).padding.bottom + 16
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: TextField(
                      controller: _manualInputController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                             if (_manualInputController.text.isNotEmpty) {
                               viewModel.addManualMessage(_manualInputController.text);
                               _manualInputController.clear();
                             }
                          },
                        ),
                      ),
                      onSubmitted: (text) {
                         if (text.isNotEmpty) {
                            viewModel.addManualMessage(text);
                            _manualInputController.clear();
                         }
                      },
                    ),
                 ),
            ],
          ),

          if (viewModel.isSelectionMode)
          Positioned(
             bottom: 0,
             left: 0,
             right: 0,
             child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                child: RecallShelf(
                        selectionCount: viewModel.selectionCount,
                        bubbles: viewModel.allBubbles,
                        onBubbleTap: (bubble) async {
                           if (bubble.id == 'action_speak_prompt') {
                             await viewModel.pauseListeningForPrompt();
                             
                             if (!mounted) return;
                             final spokenPrompt = await showDialog<String>(
                               context: context,
                               builder: (context) => const VoicePromptDialog(),
                             );
                             
                             await viewModel.resumeListeningAfterPrompt();

                             if (spokenPrompt != null && spokenPrompt.isNotEmpty && mounted) {
                               viewModel.processWithCustomPrompt(spokenPrompt);
                               showModalBottomSheet(
                                 context: context,
                                 backgroundColor: Colors.transparent,
                                 isScrollControlled: true,
                                 builder: (context) => const AiResultBottomSheet(),
                               ).then((_) {
                                 if (viewModel.aiResponse.isNotEmpty && !viewModel.isViewingExistingAi) {
                                   viewModel.saveAiMemory("Auto Save", viewModel.aiResponse);
                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis Saved to Chat")));
                                 }
                                 viewModel.exitSelectionMode();
                               });
                             }
                             return;
                           }

                           viewModel.processWithBubble(bubble);
                           showModalBottomSheet(
                             context: context,
                             backgroundColor: Colors.transparent,
                             isScrollControlled: true,
                             builder: (context) => const AiResultBottomSheet(),
                           ).then((_) {
                             if (viewModel.aiResponse.isNotEmpty && !viewModel.isViewingExistingAi) {
                               viewModel.saveAiMemory("Auto Save", viewModel.aiResponse);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis Saved to Chat")));
                             }
                             viewModel.exitSelectionMode();
                           }); 
                        },
                        onBackgroundToggle: () {
                           viewModel.toggleBackgroundMode(true);
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("Background Service Started")),
                           );
                        },
                      ),
              ),
          ),
          
          // Swipe down conversation starters panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            top: _showStartersPanel ? 0 : -MediaQuery.of(context).size.height,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                 if (details.primaryDelta != null && details.primaryDelta! < -6) {
                    setState(() {
                      _showStartersPanel = false;
                    });
                 }
              },
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 24,
                  right: 24,
                  bottom: 24,
                ),
                color: const Color(0xFF0C0C0E),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "Start a conversation",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Pick a starter for context, or just talk.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Text(
                          "Starters",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/notion_logo.png',
                                width: 12,
                                height: 12,
                                errorBuilder: (_, __, ___) => const Icon(Icons.description, size: 12, color: Colors.white70),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "from Notion",
                                style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161619),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _startersSearchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: (val) {
                          setState(() {
                            _startersSearchQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search starters...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                          suffixIcon: _startersSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                  onPressed: () {
                                    _startersSearchController.clear();
                                    setState(() {
                                      _startersSearchQuery = "";
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final allStarters = viewModel.notionConvoStarters;
                        final filteredStarters = _startersSearchQuery.isEmpty
                            ? allStarters
                            : allStarters.where((s) {
                                final title = (s.contextTopic ?? "").toLowerCase();
                                final text = s.text.toLowerCase();
                                final query = _startersSearchQuery.toLowerCase();
                                return title.contains(query) || text.contains(query);
                              }).toList();

                        return Expanded(
                          child: allStarters.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No conversation starters synced.\nMark columns with 'Convo Starter' in Notion and sync context in Settings.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                )
                              : filteredStarters.isEmpty
                                  ? Center(
                                      child: Text(
                                        "No starters matching '$_startersSearchQuery'",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: filteredStarters.length,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index) {
                                        final starter = filteredStarters[index];
                                        final formattedDate = "${starter.timestamp.month}/${starter.timestamp.day} ${starter.timestamp.hour}:${starter.timestamp.minute.toString().padLeft(2, '0')}";
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF161619),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.white10),
                                          ),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            leading: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.05),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Image.asset(
                                                'assets/images/notion_logo.png',
                                                width: 16,
                                                height: 16,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.description, size: 16, color: Colors.white),
                                              ),
                                            ),
                                            title: Text(
                                              starter.contextTopic ?? "Untitled Starter",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Updated $formattedDate",
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey,
                                              size: 16,
                                            ),
                                            onTap: () {
                                              viewModel.triggerConvoStarter(starter);
                                              setState(() {
                                                _showStartersPanel = false;
                                                _startersSearchController.clear();
                                                _startersSearchQuery = "";
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                        );
                      },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                             if (viewModel.isAvailable) viewModel.toggleListening();
                             setState(() {
                               _showStartersPanel = false;
                             });
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD32F2F),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.mic, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                             setState(() {
                               _showStartersPanel = false;
                             });
                          },
                          child: const Text(
                            "or just start talking",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showStartersPanel = false;
                            });
                            _showPasteLinkDialog(context, viewModel);
                          },
                          icon: const Icon(Icons.add_link, color: Colors.amberAccent, size: 18),
                          label: const Text(
                            "Paste Web Link for Context",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveNowIndicator extends StatefulWidget {
  const LiveNowIndicator({Key? key}) : super(key: key);

  @override
  State<LiveNowIndicator> createState() => _LiveNowIndicatorState();
}

class _LiveNowIndicatorState extends State<LiveNowIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
