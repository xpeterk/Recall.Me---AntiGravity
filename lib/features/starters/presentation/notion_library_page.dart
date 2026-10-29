import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/starters_repository.dart';
import '../data/supabase_service.dart';
import '../domain/models/notion_library_note.dart';
import '../domain/models/starter_item.dart';
import '../domain/models/starter_sort_option.dart';
import 'create_starter_page.dart';
import 'notion_page_preview_dialog.dart';
import 'starter_refine_page.dart';

class NotionLibraryPage extends StatefulWidget {
  final bool selectMode;

  const NotionLibraryPage({Key? key, this.selectMode = false}) : super(key: key);

  @override
  State<NotionLibraryPage> createState() => _NotionLibraryPageState();
}

class _NotionLibraryPageState extends State<NotionLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  String _searchQuery = "";
  String _selectedCategory = "All";
  StarterSortOption _sortOption = StarterSortOption.newestFirst;

  List<NotionLibraryNote>? _searchResults;
  bool _isSearching = false;

  static const List<String> _categories = [
    "All", "AI", "Markets", "Health", "Energy", "Tech",
    "Real Estate", "Fintech", "Policy", "Other"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = Provider.of<StartersRepository>(context, listen: false);
      repo.loadAll();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final clean = query.trim();
      setState(() {
        _searchQuery = clean;
        _isSearching = true;
      });

      final repo = Provider.of<StartersRepository>(context, listen: false);
      final results = await repo.searchNotesHybrid(
        query: clean,
        category: _selectedCategory,
        sort: _sortOption,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _onSearchChanged(_searchController.text);
  }

  void _onSortSelected(StarterSortOption sort) {
    setState(() {
      _sortOption = sort;
    });
    _onSearchChanged(_searchController.text);
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161619),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    "SORT BY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...StarterSortOption.values.map((option) {
                  final isSelected = _sortOption == option;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? AppTheme.accent : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppTheme.accent, size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _onSortSelected(option);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<StartersRepository>(context);
    final supabase = Provider.of<SupabaseService>(context);

    // Filter and sort items if not searching
    List<NotionLibraryNote> displayNotes;
    if (_searchQuery.isNotEmpty && _searchResults != null) {
      displayNotes = _searchResults!;
    } else {
      displayNotes = StartersRepository.filterByCategory(repo.notionNotes, _selectedCategory);
      displayNotes = StartersRepository.sortNotes(displayNotes, _sortOption);
    }

    final groupedNotes = StartersRepository.groupByDate(displayNotes);

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
            const Text(
              "Notion Library",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              "${repo.notionNotes.length} notes · synced 4 min ago",
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          // Supabase status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: supabase.isConfigured
                  ? Colors.green.withOpacity(0.15)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: supabase.isConfigured ? Colors.green.shade400 : Colors.white24,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done,
                  size: 11,
                  color: supabase.isConfigured ? Colors.green.shade300 : Colors.white60,
                ),
                const SizedBox(width: 4),
                Text(
                  "Supabase",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: supabase.isConfigured ? Colors.green.shade300 : Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          // + New Starter button
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.accent),
            tooltip: "Create new starter",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateStarterPage()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161619),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: "Search notes, key points, angles...",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged("");
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Filter & Sort Bar (Mockup 2 & 4)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Sort button
                  InkWell(
                    onTap: () => _showSortMenu(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sort, size: 14, color: AppTheme.accent),
                          const SizedBox(width: 4),
                          Text(
                            _sortOption.shortLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.accent),
                        ],
                      ),
                    ),
                  ),

                  // Category pills
                  ..._categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => _onCategorySelected(cat),
                        backgroundColor: const Color(0xFF161619),
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: isSelected ? AppTheme.primary : Colors.white12),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Notes List
            Expanded(
              child: repo.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : repo.errorMessage != null
                      ? Center(
                          child: Text(
                            "Error: ${repo.errorMessage}",
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        )
                      : displayNotes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off, size: 48, color: Colors.white24),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? "No notes matching '$_searchQuery'"
                                        : "No notes found in this category",
                                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: groupedNotes.keys.length,
                              itemBuilder: (context, groupIndex) {
                                final groupKey = groupedNotes.keys.elementAt(groupIndex);
                                final notesInGroup = groupedNotes[groupKey]!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Group Date Header
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14, bottom: 8),
                                      child: Text(
                                        groupKey,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white38,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    // Notes in this group
                                    ...notesInGroup.map((note) {
                                      final formattedDate = "Edited ${_formatMonthDay(note.editedAt)} · ${note.pageCount} page${note.pageCount > 1 ? 's' : ''}";
                                      final isNewStarter = repo.starters.any((s) => s.title == note.title && s.isNew);

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF161619),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isNewStarter ? AppTheme.primary.withOpacity(0.6) : Colors.white10,
                                            width: isNewStarter ? 1.5 : 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            if (widget.selectMode) {
                                              Navigator.pop(context, note);
                                            } else {
                                              NotionPagePreviewDialog.show(context, note);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(16),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              note.title,
                                                              style: const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.white,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (isNewStarter) ...[
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppTheme.primary,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: const Text(
                                                                "NEW",
                                                                style: TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    // Action button on right (Mockup 2 play button)
                                                    InkWell(
                                                      onTap: () {
                                                        final starter = StarterItem(
                                                          id: "from_note_${note.id}",
                                                          title: note.title,
                                                          summary: note.excerpt,
                                                          category: note.category,
                                                          angles: note.suggestedAngles,
                                                          notionPageIds: [note.id],
                                                          createdAt: DateTime.now(),
                                                          updatedAt: DateTime.now(),
                                                        );
                                                        Navigator.of(context).push(
                                                          MaterialPageRoute(
                                                            builder: (_) => StarterRefinePage(starter: starter),
                                                          ),
                                                        );
                                                      },
                                                      borderRadius: BorderRadius.circular(20),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primary,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.play_arrow,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  note.excerpt,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white60,
                                                    height: 1.4,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    if (note.category != null)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        margin: const EdgeInsets.only(right: 8),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primary.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          note.category!,
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.accent,
                                                          ),
                                                        ),
                                                      ),
                                                    Text(
                                                      formattedDate,
                                                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonthDay(DateTime dt) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final m = months[dt.month - 1];
    return "$m ${dt.day}";
  }
}
