import 'package:flutter_test/flutter_test.dart';
import 'package:recall_me_native/features/transcription/presentation/transcription_view_model.dart';
import 'package:recall_me_native/features/recall/domain/transcription_segment.dart';
import 'package:recall_me_native/features/recall/domain/ai_answer_bubble_payload.dart';

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

  group('Option 1A: Topic Accordion Grouping for Older Live Bubbles', () {
    test('keeps newest 3 audio bubbles unfolded and groups older audio bubbles into Topic Accordion cards', () {
      final baseTime = DateTime(2026, 10, 25, 14, 0);
      // 7 audio segments in DESC order (s7 is newest, s1 is oldest)
      final rawDesc = List.generate(7, (idx) {
        final num = 7 - idx;
        return TranscriptionSegment(
          id: 's$num',
          text: 'Spoken sentence number $num about quarterly revenue growth.',
          timestamp: baseTime.add(Duration(minutes: num)),
          type: SegmentType.audio,
        );
      });

      final grouped = TranscriptionViewModel.buildTopicAccordionSegmentList(
        rawDesc,
        keepRecentAudioCount: 3,
        maxGroupSize: 4,
      );

      // Should have 3 newest audio bubbles (s7, s6, s5) + 1 summary group (containing s1..s4)
      expect(grouped.length, equals(4));
      expect(grouped[0].id, equals('s7'));
      expect(grouped[1].id, equals('s6'));
      expect(grouped[2].id, equals('s5'));
      expect(grouped[3].type, equals(SegmentType.summary));
      expect(grouped[3].id, equals('topic_group_s1_s4'));
      expect(grouped[3].includedSegmentIds, equals(['s1', 's2', 's3', 's4']));
    });

    test('marks Topic Accordion as expanded when groupId is in expandedIds', () {
      final baseTime = DateTime(2026, 10, 25, 14, 0);
      final rawDesc = List.generate(6, (idx) {
        final num = 6 - idx;
        return TranscriptionSegment(
          id: 's$num',
          text: 'Discussion point $num on product roadmap.',
          timestamp: baseTime.add(Duration(minutes: num)),
          type: SegmentType.audio,
        );
      });

      final grouped = TranscriptionViewModel.buildTopicAccordionSegmentList(
        rawDesc,
        keepRecentAudioCount: 3,
        maxGroupSize: 4,
        expandedIds: {'topic_group_s1_s3'},
      );

      expect(grouped.last.type, equals(SegmentType.summary));
      expect(grouped.last.id, equals('topic_group_s1_s3'));
      expect(grouped.last.isExpanded, isTrue);
    });
  });

  group('Option 2B: Answer Bubble In-Place Breadcrumb Morph & Secondary AI Drill-Downs', () {
    test('AiAnswerBubblePayload serializes and deserializes responses, drillButtons, and breadcrumbs', () {
      const payload = AiAnswerBubblePayload(
        responses: ['Primary Short Answer', 'Detailed Second Answer'],
        drillButtons: ['📈 Bull Case Metrics', '⚠️ Risk Factors', '🎯 Action Steps'],
        isGeneratingDrillButtons: false,
        breadcrumbs: [
          AiBreadcrumbNode(
            label: 'Overview',
            responses: ['Primary Short Answer', 'Detailed Second Answer'],
            drillButtons: ['📈 Bull Case Metrics', '⚠️ Risk Factors', '🎯 Action Steps'],
          ),
          AiBreadcrumbNode(
            label: '📈 Bull Case Metrics',
            responses: ['Drill-down slide 1', 'Drill-down slide 2'],
            drillButtons: ['💰 Margin Expansion', '🚀 Enterprise ARR'],
          ),
        ],
        currentBreadcrumbIndex: 1,
        originalQuery: 'What is our bull case for Q4?',
      );

      final jsonStr = payload.toJsonString();
      final restored = AiAnswerBubblePayload.fromRawText(jsonStr);

      expect(restored.responses, equals(['Primary Short Answer', 'Detailed Second Answer']));
      expect(restored.drillButtons.length, equals(3));
      expect(restored.breadcrumbs.length, equals(2));
      expect(restored.currentBreadcrumbIndex, equals(1));
      expect(restored.breadcrumbs[1].label, equals('📈 Bull Case Metrics'));
      expect(restored.originalQuery, equals('What is our bull case for Q4?'));
    });

    test('parseSecondaryDrillButtons parses AI JSON array and provides clean fallback on malformed output', () {
      const rawJson = '```json\n["📈 Revenue Drivers", "⚠️ Margin Risks", "🎯 Next Steps"]\n```';
      final parsed = TranscriptionViewModel.parseSecondaryDrillButtons(rawJson);
      expect(parsed, equals(['📈 Revenue Drivers', '⚠️ Margin Risks', '🎯 Next Steps']));

      final fallback = TranscriptionViewModel.parseSecondaryDrillButtons(
        'not json',
        notionContext: 'Short Answer: X\nLong Answer: Detailed breakdown',
      );
      expect(fallback.first, equals('📄 Full Breakdown'));
      expect(fallback.length, equals(3));
    });
  });
}
