import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../../recall/domain/transcription_segment.dart';
import '../../recall/presentation/transcription_bubble.dart';
import '../../recall/presentation/recall_shelf.dart';
import '../../recall/presentation/ai_result_bottom_sheet.dart';
import '../../settings/presentation/settings_page.dart';
import 'live_transcription_footer.dart';
import 'mic_visualizer.dart';
import 'search_bottom_sheet.dart';

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({Key? key}) : super(key: key);

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      // Show button if we are scrolled up more than 500 pixels
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch ViewModel for UI updates (AppBar, List, Shelf)
    final viewModel = Provider.of<TranscriptionViewModel>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true, // Important for centering the Mic
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/images/logo_v2.png',
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 140, // Increased for wide logo
        title: viewModel.isSelectionMode 
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text("🧊 ", style: TextStyle(fontSize: 20)), // Ice Cube Icon
                   Text("${viewModel.selectionCount} Selected"),
                ],
              )
            : MicVisualizer(
                isListening: viewModel.isListening,
                soundLevelStream: viewModel.soundLevelStream,
                onTap: viewModel.isAvailable ? viewModel.toggleListening : () {},
              ),
        actions: viewModel.isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => viewModel.exitSelectionMode(),
                )
              ]
            : [
                IconButton(
                   icon: const Icon(Icons.search),
                   onPressed: () {
                     showModalBottomSheet(
                       context: context,
                       isScrollControlled: true,
                       backgroundColor: Colors.transparent,
                       builder: (context) => const SearchBottomSheet(),
                     ).then((_) {
                       // Clear search on dismiss? User choice. 
                       // Usually convenient to clear so the list returns to normal.
                       viewModel.setSearchQuery("");
                     });
                   },
                ),
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                     Navigator.of(context).push(
                       MaterialPageRoute(builder: (context) => const SettingsPage()),
                     );
                  },
                ),
                const SizedBox(width: 8),
            ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.05), // Lighter gradient
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
              
              // Transcription List (Frozen or Live)
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Google Messages style (Bottom-to-Top)
                    padding: EdgeInsets.only(
                      left: 16, 
                      right: 16, 
                      bottom: viewModel.isFrozen ? 200 : 100 
                    ),
                    itemCount: viewModel.segments.length + (viewModel.isFrozen ? 0 : 1), 
                    itemBuilder: (context, index) {
                      // Live Bubble Logic (Index 0 is BOTTOM now)
                      if (!viewModel.isFrozen && index == 0) {
                         if (viewModel.text.isEmpty || viewModel.text.contains("Press the mic")) {
                           return Center(
                             child: Padding(
                               padding: const EdgeInsets.only(bottom: 40),
                               child: Text(
                                 "Tap the mic above to start recalling",
                                 style: TextStyle(color: Theme.of(context).disabledColor),
                               ),
                             ),
                           );
                         }
                         return Container(
                           margin: const EdgeInsets.symmetric(vertical: 8),
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                             borderRadius: BorderRadius.only(
                               topLeft: const Radius.circular(16),
                               topRight: const Radius.circular(16),
                               bottomLeft: const Radius.circular(16),
                               bottomRight: const Radius.circular(4), // Looks like "Me" typing
                             ),
                             border: Border.all(
                               color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                               width: 1,
                             ),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 "Live Input...",
                                 style: TextStyle(
                                   color: Theme.of(context).colorScheme.primary,
                                   fontSize: 12,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                               const SizedBox(height: 4),
                               Text(viewModel.text),
                             ],
                           ),
                         );
                      }

                      // Adjust index for reversed list (Newest segment at Bottom/Index 0 or 1)
                      final segmentListIndex = (!viewModel.isFrozen) ? index - 1 : index;
                      // Since DB returns DESC (Newest First), and ListView is Reverse (Index 0 at Bottom),
                      // We want segments[0] (Newest) to be at Index 0 (Visual Bottom).
                      // So we just use segmentListIndex directly!
                      final effectiveIndex = segmentListIndex;
                      
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
                      child: Opacity(
                        opacity: viewModel.isFrozen && !isSelected ? 0.5 : 1.0, 
                        child: TranscriptionBubble(
                          segment: segment,
                          isSelectionMode: viewModel.isSelectionMode,
                          isSelected: isSelected,
                          onTap: (id) {
                            if (segment.type == SegmentType.aiResponse) {
                               viewModel.viewAiSegment(segment);
                               showModalBottomSheet(
                                 context: context,
                                 backgroundColor: Colors.transparent,
                                 isScrollControlled: true,
                                 builder: (context) => const AiResultBottomSheet(),
                               ).then((_) {
                                  // No auto-save needed for existing
                                  viewModel.clearAiResponse(); 
                               });
                            } else if (!viewModel.isFrozen) {
                               viewModel.enterSelectionMode(id);
                            } else {
                               viewModel.toggleSelection(id);
                            }
                          },
                        ),
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
            ],
          ),

          // Layer 2: Live Footer (Only visible when Frozen)
          const LiveTranscriptionFooter(),

          // Layer 3: Bottom Action Shelf ONLY (No Mic Button here anymore)
          if (viewModel.isSelectionMode)
          Positioned(
             bottom: 0,
             left: 0,
             right: 0,
             child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                child: RecallShelf(
                        selectionCount: viewModel.selectionCount,
                        bubbles: viewModel.allBubbles, // Use merged list
                        onBubbleTap: (bubble) {
                           viewModel.processWithBubble(bubble);
                           showModalBottomSheet(
                             context: context,
                             backgroundColor: Colors.transparent,
                             isScrollControlled: true,
                             builder: (context) => const AiResultBottomSheet(),
                           ).then((_) {
                             // "Dismiss to Save" workflow
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
        ],
      ),
    );
  }
}
