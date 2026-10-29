import 'package:flutter/foundation.dart';
import '../../recall/data/local_database.dart';
import '../../recall/domain/transcription_segment.dart';
import 'package:recall_me_native/core/services/semantic_embedding_service.dart';
import '../domain/models/starter_item.dart';
import '../domain/models/notion_library_note.dart';
import '../domain/models/starter_sort_option.dart';
import 'supabase_service.dart';

class StartersRepository extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final LocalDatabase _localDb;
  final SemanticEmbeddingService _embeddingService;

  List<StarterItem> _starters = [];
  List<NotionLibraryNote> _notionNotes = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _syncNotificationBanner;

  List<StarterItem> get starters => _starters;
  List<NotionLibraryNote> get notionNotes => _notionNotes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get syncNotificationBanner => _syncNotificationBanner;

  void clearSyncNotification() {
    _syncNotificationBanner = null;
    notifyListeners();
  }

  void setSyncNotification(String message) {
    _syncNotificationBanner = message;
    notifyListeners();
  }

  void initRealtimeListener() {
    _supabaseService.subscribeToRealtimeChanges(() {
      setSyncNotification("⚡ Notion updates received from cloud · Tap to refresh");
    });
  }

  StartersRepository({
    SupabaseService? supabaseService,
    LocalDatabase? localDb,
    SemanticEmbeddingService? embeddingService,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _localDb = localDb ?? LocalDatabase(),
        _embeddingService = embeddingService ?? SemanticEmbeddingService();

  /// Refreshes starters and notes directly from live Supabase and local Notion sync
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<StarterItem> fetchedStarters = [];
      final List<NotionLibraryNote> fetchedNotes = [];

      // 1. Fetch from Supabase if configured
      if (_supabaseService.isConfigured) {
        try {
          final remoteStarters = await _supabaseService.fetchStarters();
          fetchedStarters.addAll(remoteStarters);

          final remoteNotes = await _supabaseService.fetchNotionNotes();
          fetchedNotes.addAll(remoteNotes);
        } catch (e) {
          debugPrint('Notice: Error fetching from Supabase: $e');
        }
      }

      // 2. Load from local database (Notion synced segments)
      try {
        final segments = await _localDb.getAllSegments();
        final localNotionSegments = segments.where((s) => s.type == SegmentType.notion).toList();
        final existingNoteIds = fetchedNotes.map((n) => n.id).toSet();

        for (final s in localNotionSegments) {
          if (!existingNoteIds.contains(s.id)) {
            final lines = s.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
            final title = lines.isNotEmpty ? lines.first.replaceAll(RegExp(r'^[#\s]+'), '').trim() : 'Untitled Note';
            final excerpt = lines.length > 1 ? lines.sublist(1).join(' ').trim() : s.text;

            fetchedNotes.add(
              NotionLibraryNote(
                id: s.id,
                title: title.isNotEmpty ? title : 'Untitled Note',
                excerpt: excerpt.length > 180 ? '${excerpt.substring(0, 180)}...' : excerpt,
                category: 'Notion Sync',
                editedAt: s.timestamp,
                pageCount: 1,
                url: s.sourceUrl ?? 'https://notion.so/${s.id.replaceAll("-", "")}',
                suggestedAngles: extractSuggestedAngles(s.text),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Notice: Error loading local Notion segments: $e');
      }

      // 3. If starters are empty but we have Notion notes, auto-derive starter topics from the Notion notes
      if (fetchedStarters.isEmpty && fetchedNotes.isNotEmpty) {
        for (final note in fetchedNotes) {
          fetchedStarters.add(
            StarterItem(
              id: 'starter_${note.id}',
              title: note.title,
              summary: note.excerpt,
              category: note.category ?? 'Notion',
              angles: note.suggestedAngles,
              notionPageIds: [note.id],
              createdAt: note.editedAt,
              updatedAt: note.editedAt,
            ),
          );
        }
      }

      _starters = fetchedStarters;
      _notionNotes = fetchedNotes;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves a starter directly to Supabase and updates in-memory list
  Future<StarterItem> saveStarter(StarterItem starter) async {
    if (!_supabaseService.isConfigured) {
      throw Exception("Cannot save starter: Supabase is not configured.");
    }

    final remote = await _supabaseService.saveStarter(starter);
    if (remote == null) {
      throw Exception("Failed to save starter to Supabase.");
    }

    _starters.removeWhere((s) => s.id == remote.id);
    _starters.insert(0, remote.copyWith(isNew: true));
    notifyListeners();
    return remote;
  }

  /// Hybrid search for Notion notes combining keyword and vector similarity
  Future<List<NotionLibraryNote>> searchNotesHybrid({
    required String query,
    String? category,
    StarterSortOption sort = StarterSortOption.newestFirst,
  }) async {
    final cleanQuery = query.trim().toLowerCase();

    // 1. Filter by category first
    var filtered = filterByCategory(_notionNotes, category);

    if (cleanQuery.isEmpty) {
      return sortNotes(filtered, sort);
    }

    // 2. Keyword score calculation
    final queryTokens = cleanQuery
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toSet();

    final Map<String, double> combinedScores = {};

    List<double>? queryVector;
    try {
      queryVector = await _embeddingService.getEmbedding(cleanQuery);
    } catch (_) {}

    for (final note in filtered) {
      double score = 0.0;
      final titleLower = note.title.toLowerCase();
      final excerptLower = note.excerpt.toLowerCase();
      final categoryLower = (note.category ?? '').toLowerCase();

      // Exact substring match
      if (titleLower.contains(cleanQuery)) score += 10.0;
      if (excerptLower.contains(cleanQuery)) score += 5.0;
      if (categoryLower.contains(cleanQuery)) score += 3.0;

      // Token overlap
      for (final token in queryTokens) {
        if (titleLower.contains(token)) score += 4.0;
        if (excerptLower.contains(token)) score += 2.0;
        for (final angle in note.suggestedAngles) {
          if (angle.toLowerCase().contains(token)) score += 3.0;
        }
      }

      // Vector cosine similarity
      if (queryVector != null) {
        List<double>? noteVector = note.embedding;
        if (noteVector == null || noteVector.isEmpty) {
          try {
            noteVector = await _embeddingService.getEmbedding("${note.title} ${note.excerpt}");
          } catch (_) {}
        }
        if (noteVector != null && noteVector.isNotEmpty) {
          final cosine = SemanticEmbeddingService.cosineSimilarity(queryVector, noteVector);
          if (cosine > 0.1) {
            score += cosine * 5.0;
          }
        }
      }

      combinedScores[note.id] = score;
    }

    // Filter to notes that have a positive score
    final matched = filtered.where((note) => (combinedScores[note.id] ?? 0) > 0.5).toList();

    return sortNotes(
      matched,
      sort,
      query: cleanQuery,
      similarityScores: combinedScores,
    );
  }

  /// Pure sorting logic for Notion notes
  static List<NotionLibraryNote> sortNotes(
    List<NotionLibraryNote> notes,
    StarterSortOption sort, {
    String? query,
    Map<String, double>? similarityScores,
  }) {
    final copy = List<NotionLibraryNote>.from(notes);
    switch (sort) {
      case StarterSortOption.newestFirst:
        copy.sort((a, b) => b.editedAt.compareTo(a.editedAt));
        break;
      case StarterSortOption.oldestFirst:
        copy.sort((a, b) => a.editedAt.compareTo(b.editedAt));
        break;
      case StarterSortOption.relevance:
        if (similarityScores != null && similarityScores.isNotEmpty) {
          copy.sort((a, b) {
            final scoreB = similarityScores[b.id] ?? 0.0;
            final scoreA = similarityScores[a.id] ?? 0.0;
            final scoreComp = scoreB.compareTo(scoreA);
            if (scoreComp != 0) return scoreComp;
            return b.editedAt.compareTo(a.editedAt);
          });
        } else {
          // Fallback to alphabetical topic title A-Z
          copy.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        }
        break;
    }
    return copy;
  }

  /// Pure category filter
  static List<NotionLibraryNote> filterByCategory(
    List<NotionLibraryNote> notes,
    String? category,
  ) {
    if (category == null || category.trim().isEmpty || category == 'All') {
      return notes;
    }
    final cleanCat = category.trim().toLowerCase();
    return notes.where((n) => (n.category ?? '').toLowerCase() == cleanCat).toList();
  }

  /// Pure date grouping matching Mockup #2: "THIS WEEK", "EARLIER THIS MONTH", "SEPTEMBER 2026", "OLDER"
  static Map<String, List<NotionLibraryNote>> groupByDate(
    List<NotionLibraryNote> notes, {
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime(2026, 10, 28);
    final Map<String, List<NotionLibraryNote>> groups = {};

    for (final note in notes) {
      final diff = ref.difference(note.editedAt);
      String groupName;

      if (diff.inDays <= 7 && diff.inDays >= 0) {
        groupName = "THIS WEEK";
      } else if (note.editedAt.year == ref.year && note.editedAt.month == ref.month) {
        groupName = "EARLIER THIS MONTH";
      } else if (note.editedAt.year == ref.year) {
        groupName = "${_monthName(note.editedAt.month)} ${note.editedAt.year}";
      } else {
        groupName = "${_monthName(note.editedAt.month)} ${note.editedAt.year}";
      }

      groups.putIfAbsent(groupName, () => []).add(note);
    }

    return groups;
  }

  static String _monthName(int month) {
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'MONTH';
  }

  /// Extracts 2 to 4 suggested angle chips from note content, title, or selected bubbles
  static List<String> extractSuggestedAngles(String content, {String? title}) {
    final angles = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final tl = line.trim();
      final lower = tl.toLowerCase();
      if (lower.startsWith('question:') || lower.startsWith('alternative question')) {
        final val = tl.split(':').last.trim();
        if (val.length >= 6 && val.length <= 60 && !angles.contains(val)) {
          angles.add(val);
        }
      }
    }

    if (angles.length < 2) {
      // Sentence splitting heuristic
      final sentences = content
          .replaceAll(RegExp(r'\s+'), ' ')
          .split(RegExp(r'(?<=[.?!])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length >= 10 && s.length <= 65)
          .toList();

      for (final s in sentences) {
        if (!angles.contains(s)) {
          angles.add(s);
          if (angles.length >= 4) break;
        }
      }
    }

    if (angles.isEmpty && title != null && title.trim().isNotEmpty) {
      angles.add("Core implications of $title");
      angles.add("Counter-arguments & edge cases");
      angles.add("Actionable next steps");
    }

    return angles.take(4).toList();
  }
}
