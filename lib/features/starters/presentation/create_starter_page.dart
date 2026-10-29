import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../recall/domain/transcription_segment.dart';
import '../data/starters_repository.dart';
import '../domain/models/starter_item.dart';
import '../domain/models/notion_library_note.dart';
import 'starter_refine_page.dart';

class CreateStarterPage extends StatefulWidget {
  final List<TranscriptionSegment>? prefillFromBubbles;
  final StarterItem? existingStarter;

  const CreateStarterPage({
    Key? key,
    this.prefillFromBubbles,
    this.existingStarter,
  }) : super(key: key);

  @override
  State<CreateStarterPage> createState() => _CreateStarterPageState();
}

class _CreateStarterPageState extends State<CreateStarterPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _angleInputController;
  late TextEditingController _notionSearchController;

  String _selectedCategory = "AI";
  final List<String> _angles = [];
  final List<NotionLibraryNote> _linkedNotionPages = [];
  final List<String> _suggestedFromPages = [];

  bool _isSearchingNotion = false;
  String _notionSearchQuery = "";
  bool _isSaving = false;

  static const List<String> _categories = [
    "AI", "Markets", "Health", "Energy", "Tech",
    "Real Estate", "Fintech", "Policy", "Other"
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _summaryController = TextEditingController();
    _angleInputController = TextEditingController();
    _notionSearchController = TextEditingController();

    if (widget.existingStarter != null) {
      final s = widget.existingStarter!;
      _titleController.text = s.title;
      _summaryController.text = s.summary ?? '';
      _selectedCategory = s.category ?? "AI";
      _angles.addAll(s.angles);
    } else if (widget.prefillFromBubbles != null && widget.prefillFromBubbles!.isNotEmpty) {
      // Prefill from bubbles (Screen 13)
      final bubbles = widget.prefillFromBubbles!;
      final combined = bubbles.map((b) => b.text.trim()).join(' ');

      // Derive title from first bubble or topic
      String derivedTitle = bubbles.first.contextTopic ?? bubbles.first.bubbleName ?? "";
      if (derivedTitle.isEmpty || derivedTitle.contains("AI") || derivedTitle.contains("Starter")) {
        final words = combined.split(RegExp(r'\s+')).take(4).join(' ');
        derivedTitle = words.length > 30 ? "${words.substring(0, 30)}..." : words;
      }
      _titleController.text = derivedTitle;
      _summaryController.text = combined.length > 250 ? "${combined.substring(0, 250)}..." : combined;
      _selectedCategory = "AI";

      // Extract angles from bubbles
      final extracted = StartersRepository.extractSuggestedAngles(combined, title: derivedTitle);
      _angles.addAll(extracted);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _angleInputController.dispose();
    _notionSearchController.dispose();
    super.dispose();
  }

  void _addAngle(String angle) {
    final clean = angle.trim();
    if (clean.isNotEmpty && !_angles.contains(clean)) {
      setState(() {
        _angles.add(clean);
        _suggestedFromPages.remove(clean);
        _angleInputController.clear();
      });
    }
  }

  void _removeAngle(String angle) {
    setState(() {
      _angles.remove(angle);
    });
  }

  void _linkNotionPage(NotionLibraryNote note) {
    if (!_linkedNotionPages.any((p) => p.id == note.id)) {
      setState(() {
        _linkedNotionPages.add(note);
        for (final angle in note.suggestedAngles) {
          if (!_angles.contains(angle) && !_suggestedFromPages.contains(angle)) {
            _suggestedFromPages.add(angle);
          }
        }
        _notionSearchQuery = "";
        _notionSearchController.clear();
        _isSearchingNotion = false;
      });
    }
  }

  void _unlinkNotionPage(NotionLibraryNote note) {
    setState(() {
      _linkedNotionPages.removeWhere((p) => p.id == note.id);
    });
  }

  Future<StarterItem?> _submitStarter({bool startImmediately = false}) async {
    if (!_formKey.currentState!.validate()) return null;

    setState(() => _isSaving = true);
    final repo = Provider.of<StartersRepository>(context, listen: false);

    final newStarter = StarterItem(
      id: widget.existingStarter?.id ?? "starter_${DateTime.now().millisecondsSinceEpoch}",
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim().isNotEmpty ? _summaryController.text.trim() : null,
      category: _selectedCategory,
      angles: List.from(_angles),
      notionPageIds: _linkedNotionPages.map((p) => p.id).toList(),
      createdAt: widget.existingStarter?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isNew: true,
    );

    final saved = await repo.saveStarter(newStarter);
    setState(() => _isSaving = false);

    if (!mounted) return saved;

    if (startImmediately) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StarterRefinePage(starter: saved),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Starter saved to Recall.Me"),
          backgroundColor: Color(0xFF1E1B4B),
        ),
      );
      Navigator.pop(context, saved);
    }

    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<StartersRepository>(context);
    final isPrefilled = widget.prefillFromBubbles != null && widget.prefillFromBubbles!.isNotEmpty;

    // Filter Notion notes for linking
    final matchingNotionNotes = _notionSearchQuery.isEmpty
        ? repo.notionNotes.take(4).toList()
        : repo.notionNotes.where((n) {
            final q = _notionSearchQuery.toLowerCase();
            return n.title.toLowerCase().contains(q) || n.excerpt.toLowerCase().contains(q);
          }).toList();

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
          children: const [
            Text(
              "New starter",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              "Saved in Supabase · Notion link optional",
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    // Banner if prefilled from bubbles (Screen 13)
                    if (isPrefilled) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B4B).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Prefilled from ${widget.prefillFromBubbles!.length} selected bubbles. Edit anything before saving.",
                                style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // TITLE Field
                    const Text(
                      "TITLE",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "e.g. Tariffs & consumer prices",
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF161619),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Please enter a starter title";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // SUMMARY / CONTEXT Field
                    Row(
                      children: const [
                        Text(
                          "SUMMARY / CONTEXT",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
                        ),
                        Spacer(),
                        Text(
                          "the AI reads this first",
                          style: TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _summaryController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                      decoration: InputDecoration(
                        hintText: "Who ends up paying for tariffs, importers, retailers or shoppers. I want a clear way to explain it when someone asks...",
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF161619),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // CATEGORY Pills
                    const Text(
                      "CATEGORY",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                          backgroundColor: const Color(0xFF161619),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: isSelected ? AppTheme.primary : Colors.white12),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // NOTION PAGES Section (Mockup 5 & 6)
                    Row(
                      children: const [
                        Text(
                          "NOTION PAGES",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
                        ),
                        Spacer(),
                        Text(
                          "optional",
                          style: TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Linked Pages list
                    if (_linkedNotionPages.isNotEmpty) ...[
                      ..._linkedNotionPages.map((page) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161619),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/images/notion_logo.png',
                                width: 14,
                                height: 14,
                                errorBuilder: (_, __, ___) => const Icon(Icons.description, size: 14, color: Colors.white70),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  page.title,
                                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                                onPressed: () => _unlinkNotionPage(page),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],

                    // Search to link a page
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161619),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _notionSearchController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        onChanged: (val) {
                          setState(() {
                            _notionSearchQuery = val.trim();
                            _isSearchingNotion = true;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search your library to link a page...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                          suffixIcon: _notionSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                  onPressed: () {
                                    _notionSearchController.clear();
                                    setState(() {
                                      _notionSearchQuery = "";
                                      _isSearchingNotion = false;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),

                    // Matching Notion Pages Dropdown (Screen 6)
                    if (_isSearchingNotion && matchingNotionNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121215),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "${matchingNotionNotes.length} PAGES IN YOUR LIBRARY",
                                  style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _isSearchingNotion = false),
                                  child: const Text("Close", style: TextStyle(fontSize: 11, color: AppTheme.accent)),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 12),
                            ...matchingNotionNotes.map((note) {
                              final isLinked = _linkedNotionPages.any((p) => p.id == note.id);
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161619),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            note.title,
                                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            note.excerpt,
                                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: isLinked ? null : () => _linkNotionPage(note),
                                      child: Text(
                                        isLinked ? "Linked" : "+ Link",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isLinked ? Colors.white30 : AppTheme.accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ANGLES Section (Mockup 5)
                    Row(
                      children: const [
                        Text(
                          "ANGLES",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
                        ),
                        Spacer(),
                        Text(
                          "optional · add as chips",
                          style: TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Angles Chips
                    if (_angles.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _angles.map((angle) {
                          return Chip(
                            backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.5),
                            side: const BorderSide(color: AppTheme.primary),
                            label: Text(angle, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.accent),
                            onDeleted: () => _removeAngle(angle),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Add angle input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161619),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _angleInputController,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Add an angle, then press Enter...",
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (val) => _addAngle(val),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _addAngle(_angleInputController.text),
                            child: const Text("Add", style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    // Suggested from linked pages
                    if (_suggestedFromPages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Icon(Icons.lightbulb_outline, size: 14, color: Colors.amberAccent),
                          SizedBox(width: 6),
                          Text(
                            "From linked pages:",
                            style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _suggestedFromPages.map((sug) {
                          return ActionChip(
                            backgroundColor: Colors.white.withOpacity(0.06),
                            side: const BorderSide(color: Colors.white12),
                            label: Text("+ $sug", style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            onPressed: () => _addAngle(sug),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Text(
                      "No angles? We'll suggest a few from your context when you refine. Starters live in Recall.Me and are never written to Notion.",
                      style: TextStyle(fontSize: 11, color: Colors.white38, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121215),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => _submitStarter(startImmediately: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Save starter"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _submitStarter(startImmediately: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text("Save & start", style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, size: 16),
                                ],
                              ),
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
  }
}
