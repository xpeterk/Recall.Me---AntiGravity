import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../domain/ai_bubble.dart';

class BubbleEditorSheet extends StatefulWidget {
  final AiBubble? bubble;
  final Function(AiBubble) onSave;

  const BubbleEditorSheet({Key? key, this.bubble, required this.onSave}) : super(key: key);

  @override
  State<BubbleEditorSheet> createState() => _BubbleEditorSheetState();
}

class _BubbleEditorSheetState extends State<BubbleEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _promptController;
  late String _selectedIcon;
  late Color _selectedColor;
  bool _useNotion = false;
  bool _useGoogleContext = false;
  bool _useWebSearch = false; // New State
  
  // Multi-Answer State
  bool _isMultiOutput = false;
  List<TextEditingController> _additionalPromptControllers = [];
  List<String> _linkedPageIds = [];

  // Mock check for Notion Token (Replace with real check)
  final bool _hasNotionToken = true; 

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bubble?.name ?? '');
    _promptController = TextEditingController(text: widget.bubble?.systemPrompt ?? '');
    _selectedIcon = widget.bubble?.icon ?? '✨';
    _selectedColor = widget.bubble?.color ?? Colors.blueAccent;
    _useNotion = widget.bubble?.useNotionContext ?? false;
    _useGoogleContext = widget.bubble?.useGoogleContext ?? false;
    _useWebSearch = widget.bubble?.useWebSearch ?? false;
    
    _isMultiOutput = widget.bubble?.isMultiOutput ?? false;
    if (widget.bubble?.additionalPrompts != null) {
      _additionalPromptControllers = widget.bubble!.additionalPrompts
          .map((p) => TextEditingController(text: p))
          .toList();
    }
    _linkedPageIds = widget.bubble?.linkedPageIds.toList() ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    for (var c in _additionalPromptControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          top: 24, 
          left: 24, 
          right: 24, 
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                widget.bubble == null ? "Create New Bubble" : "Edit Bubble",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Name & Icon Row
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickIcon, 
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _selectedColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _selectedColor, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: _selectedIcon.endsWith('.png') 
                                ? Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(_selectedIcon, fit: BoxFit.contain),
                                  )
                                : Text(_selectedIcon, style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Bubble Name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text("Main Prompt (Answer 1)", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      child: TextField(
                        controller: _promptController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: "Enter instructions for the AI...",
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.black12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Enable Multiple Answers"),
                      subtitle: const Text("Generate multiple distinct responses for one input."),
                      value: _isMultiOutput,
                      onChanged: (val) {
                         setState(() {
                           _isMultiOutput = val;
                           if (val && _additionalPromptControllers.isEmpty) {
                             _additionalPromptControllers.add(TextEditingController());
                           }
                         });
                      },
                    ),

                    if (_isMultiOutput) ...[
                      ..._additionalPromptControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Additional Answer ${idx + 2}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() {
                                        _additionalPromptControllers[idx].dispose();
                                        _additionalPromptControllers.removeAt(idx);
                                        if (_additionalPromptControllers.isEmpty) {
                                          _isMultiOutput = false; // Disable if no extras
                                        }
                                      });
                                    },
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _additionalPromptControllers[idx],
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: "Enter prompt for this additional answer...",
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.black12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: TextButton.icon(
                          onPressed: _additionalPromptControllers.length < 3 
                              ? () => setState(() => _additionalPromptControllers.add(TextEditingController())) 
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text("Add Another Answer"),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    // Google Context Integration
                    Consumer<TranscriptionViewModel>(
                      builder: (context, vm, child) {
                         if (!vm.isGoogleAuthenticated) return const SizedBox.shrink();
                         return SwitchListTile(
                           contentPadding: EdgeInsets.zero,
                           title: const Text("Search Google Context"),
                           subtitle: const Text("Include recent Emails and Calendar events."),
                           value: _useGoogleContext,
                           onChanged: (val) => setState(() => _useGoogleContext = val),
                           secondary: const Icon(Icons.g_mobiledata), // Or similar icon
                         );
                      }
                    ),

                    // Web Search Toggle
                    SwitchListTile(
                       contentPadding: EdgeInsets.zero,
                       title: Text("Search the Web"),
                       subtitle: Text("Allow AI to search Google for real-time info."),
                       value: _useWebSearch,
                       onChanged: (val) => setState(() => _useWebSearch = val),
                       secondary: Icon(Icons.public),
                    ),

                    const SizedBox(height: 12),

                    // Notion Integration
                    if (_hasNotionToken) ...[
                       SwitchListTile(
                         contentPadding: EdgeInsets.zero,
                         title: const Text("Search Notion Knowledge Base"),
                         subtitle: const Text("Include context from your linked Notion pages."),
                         value: _useNotion,
                         onChanged: (val) => setState(() => _useNotion = val),
                         secondary: const Icon(Icons.book),
                       ),
                       if (_useNotion)
                         Padding(
                           padding: const EdgeInsets.only(left: 16, bottom: 16),
                           child: Row(
                             children: [
                                 OutlinedButton.icon(
                                 onPressed: () async {
                                    final vm = Provider.of<TranscriptionViewModel>(context, listen: false);
                                    
                                    // Load SYNCED pages only
                                    await vm.loadSyncedPages(); 
                                    
                                    // Pre-select based on local state
                                    if (_linkedPageIds.isNotEmpty) {
                                       for (var p in vm.availablePages) {
                                          if (_linkedPageIds.contains(p.id)) {
                                             p.isSelected = true;
                                          }
                                       }
                                    }
                                    
                                    if (!context.mounted) return;
                      
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => Container(
                                       height: MediaQuery.of(context).size.height * 0.6,
                                       decoration: BoxDecoration(
                                         color: Theme.of(context).scaffoldBackgroundColor,
                                         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                       ),
                                       padding: const EdgeInsets.all(24),
                                       child: Consumer<TranscriptionViewModel>(
                                         builder: (context, vm, child) {
                                           return Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                    Text("Link Synced Pages", style: Theme.of(context).textTheme.headlineSmall),
                                                    if (vm.isAiProcessing)
                                                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                                 ],
                                               ),
                                               // Summary Info
                                               Padding(
                                                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                 child: Row(
                                                   children: [
                                                     Icon(Icons.description, size: 14, color: Colors.grey),
                                                     const SizedBox(width: 4),
                                                     Text("Available: ${vm.availablePages.length}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                     const SizedBox(width: 16),
                                                     Icon(Icons.access_time, size: 14, color: Colors.grey),
                                                     const SizedBox(width: 4),
                                                     Text("Last Synced: ${vm.lastSyncTimeFormatted}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                   ],
                                                 ),
                                               ),
                                               Text(
                                                  vm.availablePages.isEmpty 
                                                  ? "No synced pages found. Go to AI Services to sync." 
                                                  : "Choose pages to link to this bubble.", 
                                                  style: const TextStyle(color: Colors.grey)
                                               ),
                                               const SizedBox(height: 16),
                                               Expanded(
                                                 child: ListView.builder(
                                                   itemCount: vm.availablePages.length,
                                                   itemBuilder: (context, index) {
                                                     final page = vm.availablePages[index];
                                                     return CheckboxListTile(
                                                       title: Text(page.title),
                                                       subtitle: Text(page.lastEdited.toString().split('.')[0]),
                                                       value: page.isSelected, 
                                                       onChanged: (val) {
                                                          vm.togglePageSelection(page.id);
                                                          // Immediate update to local state
                                                          setState(() {
                                                             if (page.isSelected) {
                                                                if (!_linkedPageIds.contains(page.id)) {
                                                                    _linkedPageIds.add(page.id);
                                                                }
                                                             } else {
                                                                _linkedPageIds.remove(page.id);
                                                             }
                                                          });
                                                       },
                                                     );
                                                   },
                                                 ),
                                               ),
                                               const SizedBox(height: 16),
                                               SizedBox(
                                                 width: double.infinity,
                                                 child: ElevatedButton(
                                                   onPressed: () {
                                                      // Save selection to local state
                                                      Navigator.pop(context);
                                                   },
                                                   child: const Text("Done"),
                                                 ),
                                               ),
                                             ],
                                           );
                                         }
                                       ),
                                      ),
                                    );
                                 },
                                 icon: const Icon(Icons.link),
                                 label: const Text("Edit Linked Pages"),
                               ),
                               const SizedBox(width: 12),
                               // Help Removed per user request
                             ],
                           ),
                         ),
                    ],
                ],
              ),
            ),
          ),


          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Save Bubble"),
            ),
          ),
        ],
      ),
    );
  }

  void _pickIcon() {
    // Simple mock picker for now
    final icons = [
      'assets/images/notion_logo.png', 'assets/images/gmail_logo.png', // Assets
      '✨', '📝', '✅', '👶', '🧠', '💡', '🔥', '🚀', '🎨', '🔬', '✝️', '📓', '⛪', '🛐', '📚', '💼', '📊', '🏋️', '🧘'
    ];
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
          itemCount: icons.length,
          itemBuilder: (context, index) {
            final icon = icons[index];
            return InkWell(
              onTap: () {
                setState(() => _selectedIcon = icon);
                Navigator.pop(ctx);
              },
              child: Center(
                child: icon.endsWith('.png')
                    ? Image.asset(icon, width: 32, height: 32)
                    : Text(icon, style: const TextStyle(fontSize: 32)),
              ),
            );
          },
        ),
      ),
    );
  }

  void _save() {
    if (_nameController.text.isEmpty) return;
    
    final additionalPrompts = _additionalPromptControllers
        .map((c) => c.text)
        .where((text) => text.isNotEmpty)
        .toList();

    final newBubble = AiBubble(
      id: widget.bubble?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      icon: _selectedIcon,
      color: _selectedColor,
      systemPrompt: _promptController.text,
      useNotionContext: _useNotion,
      useGoogleContext: _useGoogleContext,
      useWebSearch: _useWebSearch,
      linkedPageIds: _linkedPageIds,
      isMultiOutput: _isMultiOutput && additionalPrompts.isNotEmpty,
      additionalPrompts: additionalPrompts,
    );
    
    widget.onSave(newBubble);
    Navigator.pop(context);
  }
}
