import 'package:flutter_test/flutter_test.dart';
import 'package:recall_me_native/features/transcription/presentation/transcription_view_model.dart';

void main() {
  group('TranscriptionViewModel Dynamic Starter Parsing', () {
    test('parses perfect match correctly', () {
      const input = '''
Summary: This is a test summary.
Content: This is the long content block.
It can have multiple lines.
''';
      final result = TranscriptionViewModel.parseDynamicStarterContent(input);
      
      expect(result.contains('This is a test summary.'), isTrue);
      expect(result.contains('===LONG_CONTENT==='), isTrue);
      expect(result.contains('This is the long content block.'), isTrue);
    });

    test('handles missing summary label', () {
      const input = '''
Content: Just the long content here without a summary.
''';
      final result = TranscriptionViewModel.parseDynamicStarterContent(input);
      
      expect(result.contains('Brief contents attached.'), isTrue); // Fallback for short summary if empty
      expect(result.contains('===LONG_CONTENT==='), isTrue);
      expect(result.contains('Just the long content here without a summary.'), isTrue);
    });

    test('handles missing content label', () {
      const input = '''
Summary: Only a short summary provided.
''';
      final result = TranscriptionViewModel.parseDynamicStarterContent(input);
      
      expect(result.contains('Only a short summary provided.'), isTrue);
      expect(result.contains('===LONG_CONTENT==='), isTrue);
      // Wait, our logic says if longContent is empty, it uses shortSummary
      expect(result.endsWith('Only a short summary provided.'), isTrue); 
    });

    test('handles completely missing labels', () {
      const input = '''
This is just raw text from a page.
No labels exist.
''';
      final result = TranscriptionViewModel.parseDynamicStarterContent(input);
      
      expect(result.contains('Daily Brief fetched.'), isTrue); // Fallback short summary
      expect(result.contains('===LONG_CONTENT==='), isTrue);
      expect(result.contains('This is just raw text from a page.'), isTrue);
    });

    test('handles reverse ordered labels gracefully', () {
      const input = '''
Content: This is the long content.
Summary: This is the summary at the bottom.
''';
      final result = TranscriptionViewModel.parseDynamicStarterContent(input);
      
      // Our logic relies on summaryIndex < contentIndex for the ideal split.
      // If content is first, the if/else logic hits the first branch that matches `summaryIndex != -1` and uses everything after "Summary:".
      expect(result.contains('This is the summary at the bottom.'), isTrue);
    });
  });
}
