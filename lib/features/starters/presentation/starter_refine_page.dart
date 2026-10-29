import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../recall/domain/transcription_segment.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../domain/models/starter_item.dart';

class StarterRefinePage extends StatefulWidget {
  final StarterItem? starter;
  final List<TranscriptionSegment>? seededBubbles;
  final List<String>? initialAngles;

  const StarterRefinePage({
    Key? key,
    this.starter,
    this.seededBubbles,
    this.initialAngles,
  }) : super(key: key);

  @override
  State<StarterRefinePage> createState() => _StarterRefinePageState();
}

class _StarterRefinePageState extends State<StarterRefinePage> {
  final Set<String> _selectedAngles = {};
  late List<String> _availableAngles;
  late List<TranscriptionSegment> _activeSeededBubbles;
  final TextEditingController _customAngleController = TextEditingController();

  bool get isSeededMode => widget.seededBubbles != null && widget.seededBubbles!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _activeSeededBubbles = List<TranscriptionSegment>.from(widget.seededBubbles ?? []);

    if (widget.initialAngles != null && widget.initialAngles!.isNotEmpty) {
      _availableAngles = List<String>.from(widget.initialAngles!);
    } else if (widget.starter != null && widget.starter!.angles.isNotEmpty) {
      _availableAngles = List<String>.from(widget.starter!.angles);
    } else if (isSeededMode) {
      _availableAngles = [
        "Go deeper: Combined view",
        "Go deeper: Likely pushback",
        "How these points connect",
        "Strongest counter-argument",
        "Turn into talking points",
      ];
    } else {
      _availableAngles = [
        "Core implications & primary drivers",
        "Critical risks & failure modes",
        "Timeline & regulatory path",
      ];
    }

    // Pre-select first 1-2 angles by default
    if (_availableAngles.isNotEmpty) {
      _selectedAngles.add(_availableAngles.first);
      if (_availableAngles.length > 1) {
        _selectedAngles.add(_availableAngles[1]);
      }
    }
  }

  @override
  void dispose() {
    _customAngleController.dispose();
    super.dispose();
  }

  void _addCustomAngle() {
    final text = _customAngleController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_availableAngles.contains(text)) {
          _availableAngles.add(text);
        }
        _selectedAngles.add(text);
        _customAngleController.clear();
      });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedAngles.length == _availableAngles.length) {
        _selectedAngles.clear();
      } else {
        _selectedAngles.addAll(_availableAngles);
      }
    });
  }

  void _startConversation({bool skip = false}) {
    final vm = Provider.of<TranscriptionViewModel>(context, listen: false);
    final chosenAngles = skip ? <String>[] : _selectedAngles.toList();

    vm.startConversationWithRefinedStarter(
      starter: widget.starter,
      selectedAngles: chosenAngles,
      seededBubbles: _activeSeededBubbles.isNotEmpty ? _activeSeededBubbles : null,
    );

    // Pop back to main conversation view
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final starterTitle = widget.starter?.title ?? (isSeededMode ? "Selected Conversation Focus" : "Conversation Starter");
    final starterSummary = widget.starter?.summary ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              isSeededMode ? "New conversation" : "Refine your starter",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              isSeededMode ? "Step 2 of 2 · feed from your selection" : "Step 2 of 2 · optional",
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // Seeded context chips if in seeded mode (Mockup 11)
                  if (isSeededMode) ...[
                    Row(
                      children: [
                        Text(
                          "SEEDED CONTEXT · ${_activeSeededBubbles.length} BUBBLES",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _activeSeededBubbles.map((bubble) {
                        final snippet = bubble.text.length > 36 ? "${bubble.text.substring(0, 36)}..." : bubble.text;
                        return Chip(
                          backgroundColor: const Color(0xFF161619),
                          side: const BorderSide(color: Colors.white12),
                          avatar: const Icon(Icons.chat_bubble_outline, size: 14, color: AppTheme.accent),
                          label: Text(
                            snippet,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white38),
                          onDeleted: () {
                            setState(() {
                              _activeSeededBubbles.remove(bubble);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Starter Card (Mockup 8)
                  if (!isSeededMode)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161619),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                                ),
                                child: Text(
                                  (widget.starter?.category ?? "STARTER").toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            starterTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (starterSummary.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              starterSummary,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Section Title
                  Text(
                    isSeededMode
                        ? "Suggested directions from your selection"
                        : "Where do you want the conversation to go?",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSeededMode
                        ? "Derived from the bubbles you picked. Combine several, or add your own."
                        : "Pick one angle or combine several. Answer bubbles will focus on your picks.",
                    style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // Angles Checkbox Cards
                  ..._availableAngles.map((angle) {
                    final isSelected = _selectedAngles.contains(angle);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E1B4B).withOpacity(0.45)
                            : const Color(0xFF161619),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAngles.remove(angle);
                            } else {
                              _selectedAngles.add(angle);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2, right: 12),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : Colors.white30,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      angle,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  // Select all toggle
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _toggleSelectAll,
                      icon: Icon(
                        _selectedAngles.length == _availableAngles.length
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: AppTheme.accent,
                      ),
                      label: Text(
                        _selectedAngles.length == _availableAngles.length ? "Deselect all" : "Select all angles",
                        style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Add custom angle text field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161619),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customAngleController,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Add your own angle...",
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _addCustomAngle(),
                          ),
                        ),
                        TextButton(
                          onPressed: _addCustomAngle,
                          child: const Text("Add", style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121215),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _startConversation(skip: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedAngles.isNotEmpty
                                ? "Start conversation · ${_selectedAngles.length} angle${_selectedAngles.length > 1 ? 's' : ''}"
                                : "Start conversation",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => _startConversation(skip: true),
                    child: const Text(
                      "Skip refinement",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
