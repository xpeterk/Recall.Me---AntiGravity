import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/glass_container.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../domain/ai_bubble.dart';
import 'bubble_editor_sheet.dart';

class BubbleLibraryPage extends StatefulWidget {
  const BubbleLibraryPage({Key? key}) : super(key: key);

  @override
  State<BubbleLibraryPage> createState() => _BubbleLibraryPageState();
}

class _BubbleLibraryPageState extends State<BubbleLibraryPage> {
  // Bubbles now come from Provider

  void _openEditor(AiBubble? bubble, TranscriptionViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BubbleEditorSheet(
        bubble: bubble,
        onSave: (newBubble) {
          vm.saveBubble(newBubble);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bubble Library")),
      floatingActionButton: Consumer<TranscriptionViewModel>(
        builder: (context, vm, _) => FloatingActionButton(
          onPressed: () => _openEditor(null, vm),
          child: const Icon(Icons.add),
        ),
      ),
      body: Stack(
        children: [
          // Ambient Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  Theme.of(context).colorScheme.surface,
                ],
                center: Alignment.center,
                radius: 1.0,
              ),
            ),
          ),
          
          Consumer<TranscriptionViewModel>(
            builder: (context, vm, child) {
              return ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Added bottom padding for FAB
                itemCount: vm.bubbles.length,
                onReorder: (oldIndex, newIndex) {
                  vm.reorderBubbles(oldIndex, newIndex);
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      return Material(
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final bubble = vm.bubbles[index];
                  return Padding(
                    key: ValueKey(bubble.id), // Key is required for ReorderableListView
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassContainer(
                       borderRadius: BorderRadius.circular(16),
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                       child: Row(
                         children: [
                           // Drag Handle
                           ReorderableDragStartListener(
                             index: index,
                             child: const Padding(
                               padding: EdgeInsets.only(right: 12),
                               child: Icon(Icons.drag_handle, color: Colors.grey),
                             ),
                           ),
                           Container(
                             width: 40,
                             height: 40,
                             decoration: BoxDecoration(
                               color: bubble.color.withOpacity(0.2),
                               borderRadius: BorderRadius.circular(8),
                             ),
                             alignment: Alignment.center,
                             child: bubble.icon.endsWith('.png') 
                                 ? Padding(
                                     padding: const EdgeInsets.all(8.0),
                                     child: Image.asset(bubble.icon, fit: BoxFit.contain),
                                   )
                                 : Text(bubble.icon, style: const TextStyle(fontSize: 20)),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   bubble.name,
                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                 ),
                                 if (bubble.useNotionContext)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.link, size: 12, color: Theme.of(context).colorScheme.secondary),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              "Notion Linked",
                                              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                               ],
                             ),
                           ),
                           Switch(
                             value: bubble.isEnabled,
                             onChanged: (val) {
                               bubble.isEnabled = val;
                               vm.saveBubble(bubble);
                             },
                           ),
                           IconButton(
                             icon: const Icon(Icons.edit_outlined),
                             onPressed: () => _openEditor(bubble, vm),
                           ),
                           IconButton(
                             icon: const Icon(Icons.copy, color: Colors.blueGrey),
                             onPressed: () => vm.duplicateBubble(bubble),
                             tooltip: "Duplicate",
                           ),
                           IconButton(
                             icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                             onPressed: () {
                               showDialog(
                                 context: context,
                                 builder: (context) => AlertDialog(
                                   title: const Text("Delete Bubble?"),
                                   content: Text("Are you sure you want to delete '${bubble.name}'?"),
                                   actions: [
                                     TextButton(
                                       onPressed: () => Navigator.pop(context),
                                       child: const Text("Cancel"),
                                     ),
                                     TextButton(
                                       onPressed: () {
                                         vm.deleteBubble(bubble.id);
                                         Navigator.pop(context);
                                       },
                                       child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                     ),
                                   ],
                                 ),
                               );
                             },
                           ),
                         ],
                       ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
