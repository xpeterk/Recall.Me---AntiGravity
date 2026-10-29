import 'dart:math';
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

  List<StarterItem> get starters => _starters;
  List<NotionLibraryNote> get notionNotes => _notionNotes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  StartersRepository({
    SupabaseService? supabaseService,
    LocalDatabase? localDb,
    SemanticEmbeddingService? embeddingService,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _localDb = localDb ?? LocalDatabase(),
        _embeddingService = embeddingService ?? SemanticEmbeddingService() {
    _initDefaultSeedData();
  }

  void _initDefaultSeedData() {
    final now = DateTime(2026, 10, 28, 14, 0);

    _starters = [
      StarterItem(
        id: 'seed_starter_1',
        title: 'AI datacenter buildouts',
        summary: 'Hyperscalers keep raising AI capex. The debate is capacity genuinely short, or are we overbuilding? Power, not chips.',
        category: 'AI',
        angles: [
          'Compute must catch up with demand',
          'Misconceptions: water use & electricity prices',
          'Financing: is it a bubble?',
        ],
        notionPageIds: ['note_ai_1'],
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      StarterItem(
        id: 'seed_starter_2',
        title: 'Fed rate path & the soft landing',
        summary: 'Inflation is cooling smoothly while labor markets soften slowly. The question is terminal rate vs neutral rate.',
        category: 'Markets',
        angles: [
          'Terminal rate vs neutral rate',
          'Labor market cooling vs crack',
        ],
        notionPageIds: ['note_mk_1'],
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      StarterItem(
        id: 'seed_starter_3',
        title: 'GLP-1 drugs & the food industry',
        summary: 'GLP-1 adoption is shifting adult calorie consumption. Packaged food and restaurant volume headwinds.',
        category: 'Health',
        angles: [
          'Packaged food volume impact',
          'Healthcare payer adoption curves',
        ],
        notionPageIds: ['note_hl_1'],
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      StarterItem(
        id: 'seed_starter_4',
        title: 'Nuclear & SMRs for baseload power',
        summary: 'Tech demand for clean, always-on power is reviving nuclear interest. Small modular reactors timeline.',
        category: 'Energy',
        angles: [
          'Hyperscaler PPA agreements',
          'Regulatory timeline for SMRs',
        ],
        notionPageIds: ['note_en_1'],
        createdAt: now.subtract(const Duration(days: 13)),
        updatedAt: now.subtract(const Duration(days: 13)),
      ),
      StarterItem(
        id: 'seed_starter_5',
        title: 'Humanoid robots: hype vs. reality',
        summary: 'Demos are impressive, but deployment depends on cost per task-hour and reliability.',
        category: 'Tech',
        angles: [
          'BOM cost scaling',
          'Warehouse vs household deployment',
        ],
        notionPageIds: ['note_th_1'],
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 20)),
      ),
      StarterItem(
        id: 'seed_starter_6',
        title: 'Stablecoins & payments rails',
        summary: 'Stablecoins are moving from crypto trading into cross-border payments and treasury.',
        category: 'Fintech',
        angles: [
          'Cross-border settlement speed',
          'Yield-bearing regulation',
        ],
        notionPageIds: ['note_ft_1'],
        createdAt: now.subtract(const Duration(days: 41)),
        updatedAt: now.subtract(const Duration(days: 41)),
      ),
      StarterItem(
        id: 'seed_starter_7',
        title: 'Remote work & commercial real estate',
        summary: 'Office vacancy has stabilized at a lower level. Older B-buildings face the maturity wall.',
        category: 'Real Estate',
        angles: [
          'CMBS maturity wall',
          'Class A vs Class B divergence',
        ],
        notionPageIds: ['note_re_1'],
        createdAt: now.subtract(const Duration(days: 35)),
        updatedAt: now.subtract(const Duration(days: 35)),
      ),
    ];

    _notionNotes = [
      NotionLibraryNote(
        id: 'note_ai_1',
        title: 'AI datacenter buildouts',
        excerpt: 'Hyperscalers keep raising AI capex. The debate is capacity genuinely short, or are we overbuilding? Cooling, water use is not trivial but small next to agriculture, versus a flat...',
        category: 'AI',
        editedAt: now.subtract(const Duration(days: 4)),
        pageCount: 3,
        url: 'https://notion.so/ai-datacenter-buildouts-master-notes',
        suggestedAngles: [
          'Compute must catch up with demand',
          'Misconceptions: water use & electricity prices',
          'Financing: is it a bubble?',
        ],
      ),
      NotionLibraryNote(
        id: 'note_mk_1',
        title: 'Fed rate path & the soft landing',
        excerpt: 'Inflation is cooling smoothly while labor markets soften slowly. The question is how fast to return to neutral policy.',
        category: 'Markets',
        editedAt: now.subtract(const Duration(days: 7)),
        pageCount: 2,
        url: 'https://notion.so/fed-rate-path-notes',
        suggestedAngles: [
          'Terminal rate vs neutral rate',
          'Labor market cooling vs crack',
        ],
      ),
      NotionLibraryNote(
        id: 'note_hl_1',
        title: 'GLP-1 drugs & the food industry',
        excerpt: 'GLP-1 adoption is shifting adult calorie consumption. Packaged food and restaurant volume impacts.',
        category: 'Health',
        editedAt: now.subtract(const Duration(days: 10)),
        pageCount: 2,
        url: 'https://notion.so/glp1-food-industry-notes',
        suggestedAngles: [
          'Packaged food volume impact',
          'Healthcare payer adoption curves',
        ],
      ),
      NotionLibraryNote(
        id: 'note_en_1',
        title: 'Nuclear & SMRs for baseload power',
        excerpt: 'Tech demand for clean, always-on power is reviving nuclear interest. Small modular reactors regulatory pipeline.',
        category: 'Energy',
        editedAt: now.subtract(const Duration(days: 13)),
        pageCount: 3,
        url: 'https://notion.so/nuclear-smrs-baseload',
        suggestedAngles: [
          'Hyperscaler PPA agreements',
          'Regulatory timeline for SMRs',
        ],
      ),
      NotionLibraryNote(
        id: 'note_th_1',
        title: 'Humanoid robots: hype vs. reality',
        excerpt: 'Demos are impressive, but deployment depends on cost per task-hour, actuator longevity, and real-world safety.',
        category: 'Tech',
        editedAt: now.subtract(const Duration(days: 20)),
        pageCount: 1,
        url: 'https://notion.so/humanoid-robots-notes',
        suggestedAngles: [
          'BOM cost scaling',
          'Warehouse vs household deployment',
        ],
      ),
      NotionLibraryNote(
        id: 'note_ft_1',
        title: 'Stablecoins & payments rails',
        excerpt: 'Stablecoins are moving from crypto trading into cross-border payments, merchant settlements, and treasury management.',
        category: 'Fintech',
        editedAt: now.subtract(const Duration(days: 41)),
        pageCount: 1,
        url: 'https://notion.so/stablecoins-payments-rails',
        suggestedAngles: [
          'Cross-border settlement speed',
          'Yield-bearing regulation',
        ],
      ),
      NotionLibraryNote(
        id: 'note_re_1',
        title: 'Remote work & commercial real estate',
        excerpt: 'Office vacancy has stabilized at a lower level. Older B-buildings face the maturity wall, while Class A commands premiums.',
        category: 'Real Estate',
        editedAt: now.subtract(const Duration(days: 35)),
        pageCount: 2,
        url: 'https://notion.so/commercial-real-estate-stress',
        suggestedAngles: [
          'CMBS maturity wall',
          'Class A vs Class B divergence',
        ],
      ),
      NotionLibraryNote(
        id: 'note_pol_1',
        title: 'Semis Policy Tracker',
        excerpt: 'Tracking CHIPS Act disbursements, export control updates, and packaging capacity constraints in Southeast Asia.',
        category: 'Policy',
        editedAt: now.subtract(const Duration(days: 45)),
        pageCount: 4,
        url: 'https://notion.so/semis-policy-tracker',
        suggestedAngles: [
          'CHIPS Act tranche release timeline',
          'Advanced packaging bottlenecks',
        ],
      ),
    ];
  }

  /// Refreshes starters and notes from Supabase (falling back to local and seeds)
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch from Supabase if configured
      if (_supabaseService.isConfigured) {
        final remoteStarters = await _supabaseService.fetchStarters();
        if (remoteStarters.isNotEmpty) {
          // Merge with seeds without duplicates
          final existingIds = remoteStarters.map((s) => s.id).toSet();
          final merged = [...remoteStarters];
          for (final seed in _starters) {
            if (!existingIds.contains(seed.id)) {
              merged.add(seed);
            }
          }
          _starters = merged;
        }

        final remoteNotes = await _supabaseService.fetchNotionNotes();
        if (remoteNotes.isNotEmpty) {
          final existingNoteIds = remoteNotes.map((n) => n.id).toSet();
          final mergedNotes = [...remoteNotes];
          for (final seed in _notionNotes) {
            if (!existingNoteIds.contains(seed.id)) {
              mergedNotes.add(seed);
            }
          }
          _notionNotes = mergedNotes;
        }
      }

      // 2. Also incorporate synced local SQLite Notion segments
      try {
        final segments = await _localDb.getAllSegments();
        final notionSegments = segments.where((s) => s.type == SegmentType.notion).toList();
        final currentNoteIds = _notionNotes.map((n) => n.id).toSet();

        for (final seg in notionSegments) {
          if (!currentNoteIds.contains(seg.id)) {
            final lines = seg.text.split('\n');
            String title = seg.bubbleName ?? "Synced Note";
            if (lines.first.startsWith("Notion Page: ")) {
              title = lines.first.replaceFirst("Notion Page: ", "").trim();
            }
            final excerpt = lines.length > 1 ? lines.sublist(1).join(' ').trim() : seg.text;
            _notionNotes.add(NotionLibraryNote(
              id: seg.id,
              title: title,
              excerpt: excerpt.length > 200 ? "${excerpt.substring(0, 200)}..." : excerpt,
              category: 'Other',
              editedAt: seg.timestamp,
              url: seg.sourceUrl,
              pageCount: 1,
              suggestedAngles: extractSuggestedAngles(seg.text, title: title),
            ));
          }
        }
      } catch (_) {}
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves a starter to Supabase and in-memory list
  Future<StarterItem> saveStarter(StarterItem starter) async {
    StarterItem toSave = starter;
    if (toSave.id.isEmpty) {
      toSave = toSave.copyWith(id: "starter_${DateTime.now().millisecondsSinceEpoch}");
    }

    if (_supabaseService.isConfigured) {
      final remote = await _supabaseService.saveStarter(toSave);
      if (remote != null) {
        toSave = remote;
      }
    }

    _starters.removeWhere((s) => s.id == toSave.id);
    _starters.insert(0, toSave.copyWith(isNew: true));
    notifyListeners();
    return toSave;
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
