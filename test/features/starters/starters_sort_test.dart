import 'package:flutter_test/flutter_test.dart';
import 'package:recall_me_native/features/starters/data/starters_repository.dart';
import 'package:recall_me_native/features/starters/domain/models/notion_library_note.dart';
import 'package:recall_me_native/features/starters/domain/models/starter_sort_option.dart';

void main() {
  group('StartersRepository sorting and filtering unit tests', () {
    late List<NotionLibraryNote> testNotes;
    final now = DateTime(2026, 10, 28, 12, 0);

    setUp(() {
      testNotes = [
        NotionLibraryNote(
          id: 'note_1',
          title: 'Zebra Dynamics Analysis',
          excerpt: 'Analysis of zebra dynamics.',
          editedAt: now.subtract(const Duration(days: 10)),
          category: 'Finance',
        ),
        NotionLibraryNote(
          id: 'note_2',
          title: 'Alpha Capex Trends',
          excerpt: 'Capex spending across tech.',
          editedAt: now.subtract(const Duration(days: 2)),
          category: 'AI',
        ),
        NotionLibraryNote(
          id: 'note_3',
          title: 'Beta Power Grid',
          excerpt: 'Power grid constraints for datacenters.',
          editedAt: now.subtract(const Duration(days: 5)),
          category: 'Energy',
        ),
      ];
    });

    test('sortNotes by newestFirst puts most recent note first', () {
      final sorted = StartersRepository.sortNotes(testNotes, StarterSortOption.newestFirst);
      expect(sorted[0].id, equals('note_2')); // 2 days ago
      expect(sorted[1].id, equals('note_3')); // 5 days ago
      expect(sorted[2].id, equals('note_1')); // 10 days ago
    });

    test('sortNotes by oldestFirst puts oldest note first', () {
      final sorted = StartersRepository.sortNotes(testNotes, StarterSortOption.oldestFirst);
      expect(sorted[0].id, equals('note_1')); // 10 days ago
      expect(sorted[1].id, equals('note_3')); // 5 days ago
      expect(sorted[2].id, equals('note_2')); // 2 days ago
    });

    test('sortNotes by relevance with similarityScores orders by highest score', () {
      final scores = {
        'note_1': 0.95,
        'note_2': 0.40,
        'note_3': 0.80,
      };
      final sorted = StartersRepository.sortNotes(
        testNotes,
        StarterSortOption.relevance,
        similarityScores: scores,
      );
      expect(sorted[0].id, equals('note_1'));
      expect(sorted[1].id, equals('note_3'));
      expect(sorted[2].id, equals('note_2'));
    });

    test('sortNotes by relevance fallback orders alphabetically by title A-Z', () {
      final sorted = StartersRepository.sortNotes(testNotes, StarterSortOption.relevance);
      expect(sorted[0].id, equals('note_2')); // "Alpha Capex Trends"
      expect(sorted[1].id, equals('note_3')); // "Beta Power Grid"
      expect(sorted[2].id, equals('note_1')); // "Zebra Dynamics Analysis"
    });

    test('filterByCategory filters accurately and handles All or null', () {
      final aiNotes = StartersRepository.filterByCategory(testNotes, 'AI');
      expect(aiNotes.length, equals(1));
      expect(aiNotes.first.id, equals('note_2'));

      final allNotes = StartersRepository.filterByCategory(testNotes, 'All');
      expect(allNotes.length, equals(3));

      final nullCategoryNotes = StartersRepository.filterByCategory(testNotes, null);
      expect(nullCategoryNotes.length, equals(3));
    });

    test('groupByDate correctly groups notes into THIS WEEK and EARLIER THIS MONTH', () {
      final groups = StartersRepository.groupByDate(testNotes, referenceDate: now);
      expect(groups.containsKey('THIS WEEK'), isTrue);
      // note_2 (2 days ago) and note_3 (5 days ago) fall within 7 days
      final thisWeekIds = groups['THIS WEEK']!.map((n) => n.id).toList();
      expect(thisWeekIds.contains('note_2'), isTrue);
      expect(thisWeekIds.contains('note_3'), isTrue);

      // note_1 (10 days ago in October 2026) falls in EARLIER THIS MONTH
      expect(groups.containsKey('EARLIER THIS MONTH'), isTrue);
      expect(groups['EARLIER THIS MONTH']!.any((n) => n.id == 'note_1'), isTrue);
    });

    test('extractSuggestedAngles extracts angles from content or generates fallback', () {
      const content = '''
Question: What is the power bottleneck?
Alternative Question: Are chips still supply constrained?
The datacenter buildouts continue at record pace.
''';
      final angles = StartersRepository.extractSuggestedAngles(content, title: 'AI Buildouts');
      expect(angles, contains('What is the power bottleneck?'));
      expect(angles, contains('Are chips still supply constrained?'));
    });
  });
}
