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

  group('TranscriptionViewModel Convo Starter Relevance & Matching', () {
    test('buildConvoStarterSelectorPrompt includes conversation and candidate topics', () {
      const selected = "We were wondering about faith and patience in trials.";
      const candidates = "[ID: p1] Topic: Faith & Trials | Context: Scripture references...";
      final prompt = TranscriptionViewModel.buildConvoStarterSelectorPrompt(selected, candidates);

      expect(prompt.contains(selected), isTrue);
      expect(prompt.contains(candidates), isTrue);
      expect(prompt.contains("precision relevance classifier"), isTrue);
    });

    test('parseConvoStarterMatchId handles clean IDs, quotes, code fences, and ID prefixes', () {
      expect(TranscriptionViewModel.parseConvoStarterMatchId("page_abc_123"), equals("page_abc_123"));
      expect(TranscriptionViewModel.parseConvoStarterMatchId('"page_abc_123"'), equals("page_abc_123"));
      expect(TranscriptionViewModel.parseConvoStarterMatchId("'page_abc_123'"), equals("page_abc_123"));
      expect(TranscriptionViewModel.parseConvoStarterMatchId("ID: page_abc_123"), equals("page_abc_123"));
      expect(TranscriptionViewModel.parseConvoStarterMatchId("[ID: page_abc_123]"), equals("page_abc_123"));
      expect(TranscriptionViewModel.parseConvoStarterMatchId("`page_abc_123`"), equals("page_abc_123"));
      expect(TranscriptionViewModel.parseConvoStarterMatchId("NONE"), equals("NONE"));
    });

    test('buildConvoStarterSynthesisPrompt includes selected text, topic, and Notion content', () {
      const selected = "What was the main discussion topic?";
      const topic = "Faith & Patience";
      const notionContent = "- Point 1: Endurance\n- Point 2: Hope";

      final prompt = TranscriptionViewModel.buildConvoStarterSynthesisPrompt(
        selectedText: selected,
        topic: topic,
        notionContent: notionContent,
      );

      expect(prompt.contains(selected), isTrue);
      expect(prompt.contains(topic), isTrue);
      expect(prompt.contains(notionContent), isTrue);
      expect(prompt.contains("concise, helpful insight or synthesis"), isTrue);
    });
  });
}
